import Foundation

struct OpenAIClient {
    let apiKey: String
    let responsesModel: String
    let embeddingModel: String

    private let baseURL = URL(string: "https://api.openai.com/v1")!

    func embed(_ inputs: [String]) async throws -> [[Double]] {
        let cleanedInputs = inputs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard cleanedInputs.allSatisfy({ !$0.isEmpty }) else {
            throw AIError.emptyInput
        }

        let requestBody = EmbeddingRequest(model: normalizedEmbeddingModel, input: cleanedInputs)
        let response: EmbeddingResponse = try await post(path: "embeddings", body: requestBody)
        return response.data
            .sorted { $0.index < $1.index }
            .map(\.embedding)
    }

    func generateText(prompt: String) async throws -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AIError.emptyInput
        }

        let requestBody = ResponsesRequest(model: normalizedResponsesModel, input: trimmed)
        let response: ResponsesResponse = try await post(path: "responses", body: requestBody)

        if let outputText = response.outputText?.trimmingCharacters(in: .whitespacesAndNewlines), !outputText.isEmpty {
            return outputText
        }

        let text = response.output?
            .flatMap { $0.content ?? [] }
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let text, !text.isEmpty else {
            throw AIError.invalidResponse
        }

        return text
    }

    private var normalizedResponsesModel: String {
        responsesModel.isEmpty ? "gpt-4o-mini" : responsesModel
    }

    private var normalizedEmbeddingModel: String {
        embeddingModel.isEmpty ? "text-embedding-3-small" : embeddingModel
    }

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        body: RequestBody
    ) async throws -> ResponseBody {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data).error.message)
                ?? String(data: data, encoding: .utf8)
                ?? "Unknown error"
            throw AIError.apiError(statusCode: httpResponse.statusCode, message: message)
        }

        return try JSONDecoder().decode(ResponseBody.self, from: data)
    }
}

private struct ResponsesRequest: Encodable {
    let model: String
    let input: String
}

private struct ResponsesResponse: Decodable {
    let outputText: String?
    let output: [ResponsesOutput]?

    enum CodingKeys: String, CodingKey {
        case outputText = "output_text"
        case output
    }
}

private struct ResponsesOutput: Decodable {
    let content: [ResponsesContent]?
}

private struct ResponsesContent: Decodable {
    let text: String?
}

private struct EmbeddingRequest: Encodable {
    let model: String
    let input: [String]
}

private struct EmbeddingResponse: Decodable {
    let data: [EmbeddingData]
}

private struct EmbeddingData: Decodable {
    let index: Int
    let embedding: [Double]
}

private struct OpenAIErrorResponse: Decodable {
    let error: OpenAIAPIError
}

private struct OpenAIAPIError: Decodable {
    let message: String
}
