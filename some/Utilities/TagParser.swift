import Foundation

enum TagParser {
    private static let tagPattern = #"(?:^|\s)#([\p{L}\p{N}_\-/]+)"#

    static func extractTags(from text: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: tagPattern) else {
            return []
        }

        let nsText = text as NSString
        let lines = text.components(separatedBy: .newlines)
        let recognizedTextBodyIndexes = recognizedTextBodyLineIndexes(in: lines)
        let range = NSRange(location: 0, length: nsText.length)
        let matches = expression.matches(in: text, range: range)

        let tags = matches.compactMap { match -> String? in
            let lineIndex = lineIndex(containing: match.range.location, in: nsText)
            guard !recognizedTextBodyIndexes.contains(lineIndex) else {
                return nil
            }

            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text) else {
                return nil
            }
            return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return Array(Set(tags)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private static func lineIndex(containing location: Int, in text: NSString) -> Int {
        var index = 0
        var position = 0

        while position < location {
            let lineRange = text.lineRange(for: NSRange(location: position, length: 0))
            guard NSMaxRange(lineRange) <= location else {
                return index
            }
            position = NSMaxRange(lineRange)
            index += 1
        }

        return index
    }

    private static func recognizedTextBodyLineIndexes(in lines: [String]) -> Set<Int> {
        var indexes = Set<Int>()
        var isInRecognizedText = false
        var hasRecognizedContent = false

        for index in lines.indices {
            let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if isRecognizedTextHeader(trimmed) {
                isInRecognizedText = true
                hasRecognizedContent = false
                continue
            }

            guard isInRecognizedText else {
                continue
            }

            if trimmed.isEmpty {
                if hasRecognizedContent {
                    isInRecognizedText = false
                    hasRecognizedContent = false
                }
                continue
            }

            indexes.insert(index)
            hasRecognizedContent = true
        }

        return indexes
    }

    private static func isRecognizedTextHeader(_ line: String) -> Bool {
        line == "识别文字：" || line == "识别文字:" || line == "OCR：" || line == "OCR:"
    }
}
