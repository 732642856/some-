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
    struct RecognizedLine: Equatable {
        let text: String
        let confidence: Float?
        let region: ImageTextRegion?

        init(text: String, confidence: Float? = nil, region: ImageTextRegion? = nil) {
            self.text = text
            self.confidence = confidence
            self.region = region
        }
    }

    struct ImageTextLayoutSection: Equatable {
        var leftColumnLineCount: Int
        var rightColumnLineCount: Int
        var topLineCount: Int
        var middleLineCount: Int
        var bottomLineCount: Int

        var summary: String? {
            var parts: [String] = []
            appendPart("左栏", count: leftColumnLineCount, to: &parts)
            appendPart("右栏", count: rightColumnLineCount, to: &parts)
            appendPart("顶部", count: topLineCount, to: &parts)
            appendPart("中部", count: middleLineCount, to: &parts)
            appendPart("底部", count: bottomLineCount, to: &parts)
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }

        private func appendPart(_ title: String, count: Int, to parts: inout [String]) {
            guard count > 0 else { return }
            parts.append("\(title)\(count)行")
        }
    }

    static func recognizeText(in data: Data) async -> [String] {
        await recognizeTextLines(in: data).map(\.text)
    }

    static func recognizeTextLines(in data: Data) async -> [RecognizedLine] {
        await Task.detached(priority: .utility) {
            let request = makeRequest()
            let handler = VNImageRequestHandler(data: data, options: [:])
            do {
                try handler.perform([request])
                return recognizedTextLines(from: request)
            } catch {
                return []
            }
        }.value
    }

    static func recognizeText(in data: Data, region: ImageTextRegion) async -> [String] {
        await recognizeTextLines(in: data, region: region).map(\.text)
    }

    static func recognizeTextLines(in data: Data, region: ImageTextRegion) async -> [RecognizedLine] {
        guard !region.isFullImage,
              let image = UIImage(data: data),
              let regionData = croppedImageData(from: image, region: region) else {
            return await recognizeTextLines(in: data)
        }

        return await recognizeTextLines(in: regionData)
    }

    static func memoText(
        for attachment: SharedAttachment,
        recognizedLines: [String],
        region: ImageTextRegion? = nil,
        includesAttachmentReference: Bool = true,
        titlePrefix: String = "图片文字",
        pageNumber: Int? = nil
    ) -> String? {
        let cleanedLines = uniqueLines(recognizedLines)
        guard !cleanedLines.isEmpty else {
            return nil
        }

        var lines = [
            "\(titlePrefix)：\(attachment.displayName)"
        ]

        if let pageNumber = pageNumber {
            lines.append("扫描页：第 \(pageNumber) 页")
        }

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

    static func memoText(
        for attachment: SharedAttachment,
        recognizedLines: [RecognizedLine],
        region: ImageTextRegion? = nil,
        includesAttachmentReference: Bool = true,
        titlePrefix: String = "图片文字",
        pageNumber: Int? = nil
    ) -> String? {
        let cleanedLines = uniqueRecognizedLines(recognizedLines)
        guard !cleanedLines.isEmpty else {
            return nil
        }

        var lines = [
            "\(titlePrefix)：\(attachment.displayName)"
        ]

        if let pageNumber = pageNumber {
            lines.append("扫描页：第 \(pageNumber) 页")
        }

        if let region = region, !region.isFullImage {
            lines.append("区域：\(region.summary)")
        }

        if let confidenceSummary = confidenceSummary(for: cleanedLines) {
            lines.append("置信度：\(confidenceSummary)")
        }

        if let layoutSummary = layoutSections(for: cleanedLines).summary {
            lines.append("版面分区：\(layoutSummary)")
        }

        lines.append("")
        lines.append("识别文字：")
        lines.append(contentsOf: cleanedLines.map(\.text))

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

    private static func recognizedTextLines(from request: VNRecognizeTextRequest) -> [RecognizedLine] {
        (request.results ?? [])
            .compactMap { observation -> RecognizedLine? in
                guard let candidate = observation.topCandidates(1).first else {
                    return nil
                }

                return RecognizedLine(
                    text: candidate.string.trimmingCharacters(in: .whitespacesAndNewlines),
                    confidence: candidate.confidence,
                    region: imageRegion(fromVisionBoundingBox: observation.boundingBox)
                )
            }
            .filter { !$0.text.isEmpty }
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

    private static func uniqueRecognizedLines(_ lines: [RecognizedLine]) -> [RecognizedLine] {
        var seen = Set<String>()
        return lines.compactMap { line in
            let normalized = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else {
                return nil
            }
            return RecognizedLine(text: normalized, confidence: line.confidence, region: line.region)
        }
    }

    private static func layoutSections(for lines: [RecognizedLine]) -> ImageTextLayoutSection {
        let regions = lines.compactMap(\.region)
        var section = ImageTextLayoutSection(
            leftColumnLineCount: 0,
            rightColumnLineCount: 0,
            topLineCount: 0,
            middleLineCount: 0,
            bottomLineCount: 0
        )

        for region in regions {
            let centerX = region.x + region.width / 2
            let centerY = region.y + region.height / 2

            if centerX < 0.5 {
                section.leftColumnLineCount += 1
            } else {
                section.rightColumnLineCount += 1
            }

            if centerY < 1.0 / 3.0 {
                section.topLineCount += 1
            } else if centerY > 2.0 / 3.0 {
                section.bottomLineCount += 1
            } else {
                section.middleLineCount += 1
            }
        }

        return section
    }

    private static func imageRegion(fromVisionBoundingBox boundingBox: CGRect) -> ImageTextRegion {
        ImageTextRegion(
            x: boundingBox.origin.x,
            y: 1 - boundingBox.origin.y - boundingBox.height,
            width: boundingBox.width,
            height: boundingBox.height
        )
    }

    private static func confidenceSummary(for lines: [RecognizedLine]) -> String? {
        let confidences = lines.compactMap(\.confidence)
        guard !confidences.isEmpty else { return nil }
        let average = confidences.reduce(0, +) / Float(confidences.count)
        let minimum = confidences.min() ?? average
        return "平均 \(percentText(for: average)) · 最低 \(percentText(for: minimum))"
    }

    private static func percentText(for confidence: Float) -> String {
        let clamped = min(max(confidence, 0), 1)
        return "\(Int((clamped * 100).rounded()))%"
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
