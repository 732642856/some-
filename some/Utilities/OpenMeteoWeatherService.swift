import Foundation

struct WeatherLocation: Equatable {
    var name: String
    var latitude: Double
    var longitude: Double
    var country: String?
    var admin1: String?

    var displayName: String {
        [name, admin1, country]
            .compactMap { value in
                guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !trimmed.isEmpty else {
                    return nil
                }
                return trimmed
            }
            .joined(separator: "，")
    }
}

struct WardrobeWeatherSummary: Equatable {
    var location: WeatherLocation
    var weatherText: String

    var noteText: String {
        "天气来自 Open-Meteo：\(location.displayName)。\(weatherText)。"
    }
}

enum OpenMeteoWeatherError: LocalizedError, Equatable {
    case emptyDestination
    case invalidURL
    case locationNotFound
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .emptyDestination:
            return "请先填写目的地。"
        case .invalidURL:
            return "天气请求地址无效。"
        case .locationNotFound:
            return "没有找到这个目的地的天气。"
        case .invalidResponse:
            return "天气返回内容无法识别。"
        }
    }
}

struct OpenMeteoWeatherService {
    func geocodingURL(for destination: String) throws -> URL {
        let trimmed = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw OpenMeteoWeatherError.emptyDestination
        }

        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "name", value: trimmed),
            URLQueryItem(name: "count", value: "1"),
            URLQueryItem(name: "language", value: "zh"),
            URLQueryItem(name: "format", value: "json")
        ]

        guard let url = components?.url else {
            throw OpenMeteoWeatherError.invalidURL
        }
        return url
    }

    func forecastURL(latitude: Double, longitude: Double) throws -> URL {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: formattedCoordinate(latitude)),
            URLQueryItem(name: "longitude", value: formattedCoordinate(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,precipitation_probability_max"),
            URLQueryItem(name: "forecast_days", value: "1"),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        guard let url = components?.url else {
            throw OpenMeteoWeatherError.invalidURL
        }
        return url
    }

    func fetchWeather(
        for destination: String,
        completion: @escaping (Result<WardrobeWeatherSummary, Error>) -> Void
    ) {
        do {
            let url = try geocodingURL(for: destination)
            URLSession.shared.dataTask(with: url) { data, response, error in
                do {
                    if let error = error {
                        throw error
                    }
                    guard let data = data, let response = response else {
                        throw OpenMeteoWeatherError.invalidResponse
                    }
                    try validate(response: response)

                    let location = try decodeLocation(from: data)
                    let forecastURL = try forecastURL(latitude: location.latitude, longitude: location.longitude)
                    URLSession.shared.dataTask(with: forecastURL) { data, response, error in
                        do {
                            if let error = error {
                                throw error
                            }
                            guard let data = data, let response = response else {
                                throw OpenMeteoWeatherError.invalidResponse
                            }
                            try validate(response: response)
                            completion(.success(try decodeForecast(from: data, location: location)))
                        } catch {
                            completion(.failure(error))
                        }
                    }.resume()
                } catch {
                    completion(.failure(error))
                }
            }.resume()
        } catch {
            completion(.failure(error))
        }
    }

    func decodeLocation(from data: Data) throws -> WeatherLocation {
        let response = try JSONDecoder().decode(OpenMeteoGeocodingResponse.self, from: data)
        guard let result = response.results?.first else {
            throw OpenMeteoWeatherError.locationNotFound
        }
        return WeatherLocation(
            name: result.name,
            latitude: result.latitude,
            longitude: result.longitude,
            country: result.country,
            admin1: result.admin1
        )
    }

    func decodeForecast(from data: Data, location: WeatherLocation) throws -> WardrobeWeatherSummary {
        let response = try JSONDecoder().decode(OpenMeteoForecastResponse.self, from: data)
        guard let current = response.current else {
            throw OpenMeteoWeatherError.invalidResponse
        }

        let description = weatherDescription(for: current.weatherCode)
        let min = response.daily?.temperatureMin?.first
        let max = response.daily?.temperatureMax?.first
        let precipitation = response.daily?.precipitationProbabilityMax?.first
        let temperatureText = temperatureRangeText(min: min, max: max, current: current.temperature)
        let precipitationText = precipitation.map { " 降雨\(Int($0.rounded()))%" } ?? ""

        return WardrobeWeatherSummary(
            location: location,
            weatherText: "\(description) \(temperatureText)\(precipitationText)"
        )
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw OpenMeteoWeatherError.invalidResponse
        }
    }

    private func formattedCoordinate(_ value: Double) -> String {
        String(format: "%.4f", value)
    }

    private func temperatureRangeText(min: Double?, max: Double?, current: Double?) -> String {
        if let min = min, let max = max {
            return "\(Int(min.rounded()))-\(Int(max.rounded()))C"
        }
        if let current = current {
            return "\(Int(current.rounded()))C"
        }
        return ""
    }

    private func weatherDescription(for code: Int?) -> String {
        switch code {
        case 0:
            return "晴"
        case 1, 2:
            return "多云"
        case 3:
            return "阴"
        case 45, 48:
            return "雾"
        case 51, 53, 55, 56, 57:
            return "毛毛雨"
        case 61, 63, 65, 66, 67, 80, 81, 82:
            return "小雨"
        case 71, 73, 75, 77, 85, 86:
            return "雪"
        case 95, 96, 99:
            return "雷雨"
        default:
            return "天气"
        }
    }
}

private struct OpenMeteoGeocodingResponse: Decodable {
    let results: [OpenMeteoGeocodingResult]?
}

private struct OpenMeteoGeocodingResult: Decodable {
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let admin1: String?
}

private struct OpenMeteoForecastResponse: Decodable {
    let current: OpenMeteoCurrentWeather?
    let daily: OpenMeteoDailyWeather?
}

private struct OpenMeteoCurrentWeather: Decodable {
    let temperature: Double?
    let weatherCode: Int?

    enum CodingKeys: String, CodingKey {
        case temperature = "temperature_2m"
        case weatherCode = "weather_code"
    }
}

private struct OpenMeteoDailyWeather: Decodable {
    let temperatureMax: [Double]?
    let temperatureMin: [Double]?
    let precipitationProbabilityMax: [Double]?

    enum CodingKeys: String, CodingKey {
        case temperatureMax = "temperature_2m_max"
        case temperatureMin = "temperature_2m_min"
        case precipitationProbabilityMax = "precipitation_probability_max"
    }
}
