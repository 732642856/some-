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

        if let tableSummary = tableCandidateSummary(for: cleanedLines) {
            lines.append("表格候选：\(tableSummary)")
        }

        if let receiptLineSummary = receiptLineCandidateSummary(for: cleanedLines) {
            lines.append("票据行候选：\(receiptLineSummary)")
        }

        if let fieldSummary = fieldCandidatesSummary(for: cleanedLines) {
            lines.append("字段候选：\(fieldSummary)")
        }

        if let keyInfoSummary = keyInfoCandidatesSummary(for: cleanedLines) {
            lines.append("关键信息候选：\(keyInfoSummary)")
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
        let uniqueLines: [RecognizedLine] = lines.compactMap { line -> RecognizedLine? in
            let normalized = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else {
                return nil
            }
            return RecognizedLine(text: normalized, confidence: line.confidence, region: line.region)
        }

        return readingOrderedLines(uniqueLines)
    }

    private static func readingOrderedLines(_ lines: [RecognizedLine]) -> [RecognizedLine] {
        guard !lines.isEmpty,
              lines.allSatisfy({ $0.region != nil }) else {
            return lines
        }

        return lines.sorted { first, second in
            guard let firstRegion = first.region,
                  let secondRegion = second.region else {
                return false
            }

            let firstCenterY = firstRegion.y + firstRegion.height / 2
            let secondCenterY = secondRegion.y + secondRegion.height / 2
            if abs(firstCenterY - secondCenterY) > 0.02 {
                return firstCenterY < secondCenterY
            }

            return firstRegion.x < secondRegion.x
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

    private static func fieldCandidatesSummary(for lines: [RecognizedLine]) -> String? {
        var seenKeys = Set<String>()
        var fields: [String] = []

        for line in lines {
            guard let field = fieldCandidate(in: line.text),
                  seenKeys.insert(field.key).inserted else {
                continue
            }

            fields.append("\(field.key)=\(field.value)")
        }

        guard fields.count >= 2 else {
            return nil
        }

        return fields.prefix(4).joined(separator: " · ")
    }

    private struct KeyInfoCandidate {
        let label: String
        let value: String

        var summary: String {
            "\(label)=\(value)"
        }
    }

    private static func keyInfoCandidatesSummary(for lines: [RecognizedLine]) -> String? {
        let text = lines.map(\.text).joined(separator: "\n")
        var candidates: [KeyInfoCandidate] = []
        candidates.append(contentsOf: detectedDateCandidates(in: text))
        candidates.append(contentsOf: detectedPhoneCandidates(in: text))
        candidates.append(contentsOf: detectedEmailCandidates(in: text))
        candidates.append(contentsOf: detectedLinkCandidates(in: text))
        candidates.append(contentsOf: detectedAmountCandidates(in: text))

        let uniqueCandidates = uniqueKeyInfoCandidates(candidates)
        let categoryCount = Set(uniqueCandidates.map(\.label)).count
        guard categoryCount >= 2 else {
            return nil
        }

        return uniqueCandidates.prefix(5).map(\.summary).joined(separator: " · ")
    }

    private static func detectedDateCandidates(in text: String) -> [KeyInfoCandidate] {
        matches(in: text, pattern: #"\b\d{4}[./-]\d{1,2}[./-]\d{1,2}(?:\s+\d{1,2}:\d{2})?\b"#)
            .map { normalized in
                KeyInfoCandidate(label: "日期", value: normalized.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ".", with: "-"))
            }
    }

    private static func detectedPhoneCandidates(in text: String) -> [KeyInfoCandidate] {
        let detected = dataDetectorMatches(in: text, checkingTypes: NSTextCheckingResult.CheckingType.phoneNumber.rawValue).compactMap { result in
            result.phoneNumber
        }

        let fallback = matches(in: text, pattern: #"(?<!\d)(?:\+?\d[\d -]{6,}\d)(?!\d)"#)

        return (detected + fallback).compactMap { phone in
            normalizedPhoneNumber(phone).map { KeyInfoCandidate(label: "电话", value: $0) }
        }
    }

    private static func detectedEmailCandidates(in text: String) -> [KeyInfoCandidate] {
        matches(in: text, pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, options: [.caseInsensitive])
            .map { KeyInfoCandidate(label: "邮箱", value: $0) }
    }

    private static func normalizedPhoneNumber(_ candidate: String) -> String? {
        let digits = candidate.filter(\.isNumber)
        guard digits.count >= 7,
              digits.count <= 15,
              !isCompactDateDigits(digits),
              candidate.range(of: #"\d{4}[-/]\d{1,2}[-/]\d{1,2}"#, options: .regularExpression) == nil else {
            return nil
        }

        return candidate
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
    }

    private static func isCompactDateDigits(_ digits: String) -> Bool {
        digits.range(of: #"^(19|20)\d{2}(0[1-9]|1[0-2])([0-2]\d|3[01])$"#, options: .regularExpression) != nil
    }

    private static func detectedLinkCandidates(in text: String) -> [KeyInfoCandidate] {
        let detected = dataDetectorMatches(in: text, checkingTypes: NSTextCheckingResult.CheckingType.link.rawValue).compactMap { result -> String? in
            guard let url = result.url,
                  let scheme = url.scheme?.lowercased(),
                  ["http", "https"].contains(scheme) else {
                return nil
            }

            return url.absoluteString
        }

        let fallback = matches(in: text, pattern: #"https?://[^\s，。；;]+"#)
        return (detected + fallback).map { KeyInfoCandidate(label: "链接", value: $0) }
    }

    private static func detectedAmountCandidates(in text: String) -> [KeyInfoCandidate] {
        matches(in: text, pattern: #"[¥￥]?\s*\d+(?:[\.,]\d{1,2})?\s*元"#)
            .map { amount in
                KeyInfoCandidate(label: "金额", value: amount.replacingOccurrences(of: " ", with: ""))
            }
    }

    private static func dataDetectorMatches(in text: String, checkingTypes: NSTextCheckingResult.CheckingType.RawValue) -> [NSTextCheckingResult] {
        guard let detector = try? NSDataDetector(types: checkingTypes) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.matches(in: text, options: [], range: range)
    }

    private static func matches(
        in text: String,
        pattern: String,
        options: NSRegularExpression.Options = []
    ) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: text) else {
                return nil
            }

            return String(text[matchRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func uniqueKeyInfoCandidates(_ candidates: [KeyInfoCandidate]) -> [KeyInfoCandidate] {
        var seen = Set<String>()
        return candidates.compactMap { candidate in
            let value = candidate.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else {
                return nil
            }

            let key = "\(candidate.label):\(value.lowercased())"
            guard seen.insert(key).inserted else {
                return nil
            }

            return KeyInfoCandidate(label: candidate.label, value: value)
        }
    }

    private static func tableCandidateSummary(for lines: [RecognizedLine]) -> String? {
        delimitedTableCandidateSummary(for: lines) ?? regionTableCandidateSummary(for: lines)
    }

    private static func delimitedTableCandidateSummary(for lines: [RecognizedLine]) -> String? {
        let rows = lines.compactMap { tableCells(in: $0.text) }
        guard let header = rows.first,
              header.count >= 2 else {
            return nil
        }

        let dataRows = rows.dropFirst().filter { $0.count == header.count }
        guard !dataRows.isEmpty else {
            return nil
        }

        let headerSummary = header.prefix(4).joined(separator: "/")
        return "\(header.count)列 · \(dataRows.count)行 · \(headerSummary)"
    }

    private static func regionTableCandidateSummary(for lines: [RecognizedLine]) -> String? {
        let cells = lines.compactMap { line -> RegionTableCell? in
            guard let region = line.region,
                  containsReadableContent(line.text) else {
                return nil
            }

            return RegionTableCell(text: line.text, region: region)
        }

        guard cells.count == lines.count,
              cells.count >= 4 else {
            return nil
        }

        let rows = regionTableRows(from: cells)
            .filter { $0.count >= 2 }
        guard let header = rows.first,
              header.count >= 2 else {
            return nil
        }

        let dataRows = rows.dropFirst().filter { row in
            row.count == header.count && regionTableRow(row, alignsWith: header)
        }
        guard !dataRows.isEmpty else {
            return nil
        }

        let headerSummary = header.prefix(4).map(\.text).joined(separator: "/")
        return "\(header.count)列 · \(dataRows.count)行 · \(headerSummary)"
    }

    private struct RegionTableCell {
        let text: String
        let region: ImageTextRegion

        var centerX: Double {
            region.x + region.width / 2
        }

        var centerY: Double {
            region.y + region.height / 2
        }
    }

    private static func regionTableRows(from cells: [RegionTableCell]) -> [[RegionTableCell]] {
        let sortedCells = cells.sorted { first, second in
            if abs(first.centerY - second.centerY) > 0.02 {
                return first.centerY < second.centerY
            }

            return first.centerX < second.centerX
        }

        var rows: [[RegionTableCell]] = []
        for cell in sortedCells {
            guard let lastRow = rows.last,
                  let referenceCell = lastRow.first,
                  abs(cell.centerY - referenceCell.centerY) <= rowGroupingTolerance(for: lastRow + [cell]) else {
                rows.append([cell])
                continue
            }

            rows[rows.count - 1].append(cell)
        }

        return rows.map { row in
            row.sorted { $0.centerX < $1.centerX }
        }
    }

    private static func rowGroupingTolerance(for cells: [RegionTableCell]) -> Double {
        let tallestCell = cells.map { $0.region.height }.max() ?? 0
        return max(0.025, min(0.08, tallestCell * 0.9))
    }

    private static func regionTableRow(_ row: [RegionTableCell], alignsWith header: [RegionTableCell]) -> Bool {
        guard row.count == header.count else {
            return false
        }

        return zip(row, header).allSatisfy { cell, headerCell in
            abs(cell.centerX - headerCell.centerX) <= columnAlignmentTolerance(headerCell: headerCell, cell: cell)
        }
    }

    private static func columnAlignmentTolerance(headerCell: RegionTableCell, cell: RegionTableCell) -> Double {
        max(0.06, min(0.14, max(headerCell.region.width, cell.region.width) * 0.75))
    }

    private static func tableCells(in line: String) -> [String]? {
        let normalized = line.replacingOccurrences(of: "｜", with: "|")
        let rawCells: [String]
        if normalized.contains("|") {
            rawCells = normalized.components(separatedBy: "|")
        } else if normalized.contains("\t") {
            rawCells = normalized.components(separatedBy: "\t")
        } else {
            return nil
        }

        let cells = rawCells
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard cells.count >= 2,
              cells.contains(where: containsReadableContent) else {
            return nil
        }

        return cells
    }

    private struct ReceiptLineCandidate {
        let title: String
        let amount: String

        var summary: String {
            "\(title) \(amount)"
        }
    }

    private static func receiptLineCandidateSummary(for lines: [RecognizedLine]) -> String? {
        let candidates = lines.compactMap { receiptLineCandidate(in: $0.text) }
        guard candidates.count >= 2 else {
            return nil
        }

        let examples = candidates.prefix(3).map(\.summary).joined(separator: "；")
        return "\(candidates.count)行 · \(examples)"
    }

    private static func receiptLineCandidate(in line: String) -> ReceiptLineCandidate? {
        let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty,
              normalized.rangeOfCharacter(from: CharacterSet(charactersIn: "|｜\t:：")) == nil,
              let amountRange = normalized.range(
                of: #"[¥￥]?\s*\d+(?:[\.,]\d{1,2})?\s*元?$"#,
                options: .regularExpression
              ) else {
            return nil
        }

        let amountEnd = normalized[amountRange.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard amountEnd.isEmpty else {
            return nil
        }

        let title = String(normalized[..<amountRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let amount = String(normalized[amountRange])
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard title.count >= 2,
              containsReadableContent(title),
              isReceiptAmount(amount),
              !isReceiptSummaryLine(title) else {
            return nil
        }

        return ReceiptLineCandidate(title: title, amount: amount)
    }

    private static func isReceiptAmount(_ amount: String) -> Bool {
        amount.contains(".")
            || amount.contains(",")
            || amount.contains("元")
            || amount.contains("¥")
            || amount.contains("￥")
    }

    private static func isReceiptSummaryLine(_ title: String) -> Bool {
        let lowercasedTitle = title.lowercased()
        let summaryKeywords = [
            "合计", "小计", "总计", "应付", "实付", "找零", "支付", "优惠", "税",
            "total", "subtotal", "change", "cash", "card", "tax"
        ]

        return summaryKeywords.contains { lowercasedTitle.contains($0) }
    }

    private static func containsReadableContent(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            CharacterSet.alphanumerics.contains(scalar)
                || (0x4E00...0x9FFF).contains(scalar.value)
        }
    }

    private static func fieldCandidate(in line: String) -> (key: String, value: String)? {
        let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let separatorIndex = normalized.firstIndex(where: { $0 == "：" || $0 == ":" }) else {
            return nil
        }

        let key = String(normalized[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let valueStart = normalized.index(after: separatorIndex)
        let value = String(normalized[valueStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard isReasonableFieldKey(key), !value.isEmpty else {
            return nil
        }

        return (key, value)
    }

    private static func isReasonableFieldKey(_ key: String) -> Bool {
        guard !key.isEmpty, key.count <= 12 else {
            return false
        }

        let lowercasedKey = key.lowercased()
        if ["http", "https", "file", "some-attachment"].contains(lowercasedKey) {
            return false
        }

        let rejectedCharacters = CharacterSet(charactersIn: "/\\[]{}()（）")
        guard key.rangeOfCharacter(from: rejectedCharacters) == nil else {
            return false
        }

        return key.unicodeScalars.contains { scalar in
            CharacterSet.alphanumerics.contains(scalar)
                || (0x4E00...0x9FFF).contains(scalar.value)
        }
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
