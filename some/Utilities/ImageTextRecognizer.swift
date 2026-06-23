import Foundation
import UIKit
import Vision

struct ImageTextRegion: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(x: Double, y: Double, width: Double, height: Double) {
        let normalizedX = Self.clamped(x)
        let normalizedY = Self.clamped(y)
        self.x = normalizedX
        self.y = normalizedY
        self.width = Self.clampedDimension(width, origin: normalizedX)
        self.height = Self.clampedDimension(height, origin: normalizedY)
    }

    static let full = ImageTextRegion(x: 0, y: 0, width: 1, height: 1)

    var isFullImage: Bool {
        x <= 0.001 && y <= 0.001 && width >= 0.999 && height >= 0.999
    }

    var summary: String {
        "x\(Int(x * 100)) y\(Int(y * 100)) w\(Int(width * 100)) h\(Int(height * 100))"
    }

    func rect(in size: CGSize) -> CGRect {
        return CGRect(
            x: x * size.width,
            y: y * size.height,
            width: width * size.width,
            height: height * size.height
        ).integral
    }

    private static func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private static func clampedDimension(_ value: Double, origin: Double) -> Double {
        min(max(value, 0), max(0, 1 - origin))
    }
}

enum ImageTextRecognizer {
    static func recognizeText(in data: Data) async -> [String] {
        await Task.detached(priority: .utility) {
            let request = makeRequest()
            let handler = VNImageRequestHandler(data: data, options: [:])
            do {
                try handler.perform([request])
                return recognizedLines(from: request)
            } catch {
                return []
            }
        }.value
    }

    static func recognizeText(in data: Data, region: ImageTextRegion) async -> [String] {
        guard !region.isFullImage,
              let image = UIImage(data: data),
              let regionData = croppedImageData(from: image, region: region) else {
            return await recognizeText(in: data)
        }

        return await recognizeText(in: regionData)
    }

    static func memoText(
        for attachment: SharedAttachment,
        recognizedLines: [String],
        region: ImageTextRegion? = nil,
        includesAttachmentReference: Bool = true
    ) -> String? {
        let cleanedLines = uniqueLines(recognizedLines)
        guard !cleanedLines.isEmpty else {
            return nil
        }

        var lines = [
            "图片文字：\(attachment.displayName)"
        ]

        if let region = region, !region.isFullImage {
            lines.append("区域：\(region.summary)")
        }

        lines.append("")
        lines.append("识别文字：")
        lines.append(contentsOf: cleanedLines)

        if includesAttachmentReference {
            lines.append("")
            lines.append(attachment.referenceLine)
        }

        return lines.joined(separator: "\n")
    }

    static func extractedHighlights(from text: String, limit: Int = 3) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var isInRecognizedText = false
        var candidates: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("识别文字：")
                || trimmed.hasPrefix("识别文字:")
                || trimmed.hasPrefix("OCR：")
                || trimmed.hasPrefix("OCR:") {
                isInRecognizedText = true
                continue
            }

            guard isInRecognizedText else {
                continue
            }

            if trimmed.isEmpty {
                if !candidates.isEmpty {
                    break
                }
                continue
            }

            if trimmed.hasPrefix("[附件:") || trimmed.hasPrefix("some-attachment://") {
                break
            }

            candidates.append(trimmed)
        }

        return Array(uniqueLines(candidates).prefix(limit))
    }

    private static func makeRequest() -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.015
        return request
    }

    private static func recognizedLines(from request: VNRecognizeTextRequest) -> [String] {
        (request.results ?? [])
            .compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func uniqueLines(_ lines: [String]) -> [String] {
        var seen = Set<String>()
        return lines.compactMap { line in
            let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else {
                return nil
            }
            return normalized
        }
    }

    private static func croppedImageData(from image: UIImage, region: ImageTextRegion) -> Data? {
        let normalizedImage = normalizedImage(image)
        guard let cgImage = normalizedImage.cgImage else {
            return nil
        }

        let rect = region.rect(in: CGSize(width: cgImage.width, height: cgImage.height))
        guard rect.width > 0,
              rect.height > 0,
              let cropped = cgImage.cropping(to: rect) else {
            return nil
        }

        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up).pngData()
    }

    private static func normalizedImage(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else {
            return image
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}
