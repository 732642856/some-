import Foundation
import Vision

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

    static func memoText(for attachment: SharedAttachment, recognizedLines: [String]) -> String? {
        let cleanedLines = uniqueLines(recognizedLines)
        guard !cleanedLines.isEmpty else {
            return nil
        }

        return """
        图片文字：\(attachment.displayName)

        识别文字：
        \(cleanedLines.joined(separator: "\n"))

        \(attachment.referenceLine)
        """
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
}
