import Foundation

enum KeyInfoExtractor {
    private static let keyInfoLinePrefix = "关键信息候选："
    private static let webKeyInfoLinePrefix = "网页关键信息候选："
    private static let ocrLayoutLinePrefix = "版面分区："
    private static let ocrFieldLinePrefix = "字段候选："
    private static let ocrTableLinePrefix = "表格候选："
    private static let receiptLinesLinePrefix = "票据行候选："

    struct Candidate: Equatable {
        let label: String
        let value: String

        var summary: String {
            "\(label)=\(value)"
        }
    }

    static func summary(in texts: [String], minimumCategoryCount: Int = 2, limit: Int = 5) -> String? {
        let text = texts.joined(separator: "\n")
        var candidates: [Candidate] = []
        candidates.append(contentsOf: detectedDateCandidates(in: text))
        candidates.append(contentsOf: detectedPhoneCandidates(in: text))
        candidates.append(contentsOf: detectedEmailCandidates(in: text))
        candidates.append(contentsOf: detectedLinkCandidates(in: text))
        candidates.append(contentsOf: detectedAmountCandidates(in: text))

        let uniqueCandidates = uniqueCandidates(candidates)
        let categoryCount = Set(uniqueCandidates.map(\.label)).count
        guard categoryCount >= minimumCategoryCount else {
            return nil
        }

        return uniqueCandidates.prefix(limit).map(\.summary).joined(separator: " · ")
    }

    static func containsOCRKeyInfoSummary(in text: String) -> Bool {
        containsSummaryLine(prefix: keyInfoLinePrefix, in: text)
    }

    static func containsWebKeyInfoSummary(in text: String) -> Bool {
        containsSummaryLine(prefix: webKeyInfoLinePrefix, in: text)
    }

    static func containsOCRLayoutSummary(in text: String) -> Bool {
        containsSummaryLine(prefix: ocrLayoutLinePrefix, in: text)
    }

    static func containsOCRFieldSummary(in text: String) -> Bool {
        containsSummaryLine(prefix: ocrFieldLinePrefix, in: text)
    }

    static func containsOCRTableSummary(in text: String) -> Bool {
        containsSummaryLine(prefix: ocrTableLinePrefix, in: text)
    }

    static func containsReceiptLinesSummary(in text: String) -> Bool {
        containsSummaryLine(prefix: receiptLinesLinePrefix, in: text)
    }

    private static func detectedDateCandidates(in text: String) -> [Candidate] {
        let numericDates = matches(in: text, pattern: #"\b\d{4}[./-]\d{1,2}[./-]\d{1,2}(?:\s+\d{1,2}:\d{2})?\b"#)
            .map { normalized in
                Candidate(label: "日期", value: normalized.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ".", with: "-"))
            }
        let chineseDates = chineseDateMatches(in: text).map { Candidate(label: "日期", value: $0) }
        return numericDates + chineseDates
    }

    private static func chineseDateMatches(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?<!\d)(\d{4})年\s*(\d{1,2})月\s*(\d{1,2})日(?:\s*(\d{1,2}):(\d{2}))?"#,
            options: []
        ) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard match.numberOfRanges >= 4,
                  let year = capture(in: text, match: match, at: 1),
                  let month = capture(in: text, match: match, at: 2),
                  let day = capture(in: text, match: match, at: 3) else {
                return nil
            }

            var normalized = "\(year)-\(month.leftPadded(to: 2, with: "0"))-\(day.leftPadded(to: 2, with: "0"))"
            if let hour = capture(in: text, match: match, at: 4),
               let minute = capture(in: text, match: match, at: 5) {
                normalized += " \(hour.leftPadded(to: 2, with: "0")):\(minute)"
            }
            return normalized
        }
    }

    private static func detectedPhoneCandidates(in text: String) -> [Candidate] {
        let detected = dataDetectorMatches(in: text, checkingTypes: NSTextCheckingResult.CheckingType.phoneNumber.rawValue).compactMap { result in
            result.phoneNumber
        }
        let fallback = matches(in: text, pattern: #"(?<!\d)(?:\+?\d[\d -]{6,}\d)(?!\d)"#)

        return (detected + fallback).compactMap { phone in
            normalizedPhoneNumber(phone).map { Candidate(label: "电话", value: $0) }
        }
    }

    private static func detectedEmailCandidates(in text: String) -> [Candidate] {
        matches(in: text, pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, options: [.caseInsensitive])
            .map { Candidate(label: "邮箱", value: $0) }
    }

    private static func detectedLinkCandidates(in text: String) -> [Candidate] {
        let detected = dataDetectorMatches(in: text, checkingTypes: NSTextCheckingResult.CheckingType.link.rawValue).compactMap { result -> String? in
            guard let url = result.url,
                  let scheme = url.scheme?.lowercased(),
                  ["http", "https"].contains(scheme) else {
                return nil
            }

            return url.absoluteString
        }

        let fallback = matches(in: text, pattern: #"https?://[^\s，。；;]+"#)
        return (detected + fallback).map { Candidate(label: "链接", value: $0) }
    }

    private static func detectedAmountCandidates(in text: String) -> [Candidate] {
        let amountNumberPattern = #"(?:\d{1,3}(?:,\d{3})+|\d+)(?:[\.,]\d{1,2})?"#
        let yuanAmounts = matches(in: text, pattern: #"[¥￥]?\s*"# + amountNumberPattern + #"\s*元"#)
        let symbolAmounts = matches(in: text, pattern: #"[¥￥]\s*"# + amountNumberPattern + #"(?![\d\.,]|\s*元)"#)

        return (yuanAmounts + symbolAmounts).map { amount in
            Candidate(label: "金额", value: amount.replacingOccurrences(of: " ", with: ""))
        }
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

    private static func uniqueCandidates(_ candidates: [Candidate]) -> [Candidate] {
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

            return Candidate(label: candidate.label, value: value)
        }
    }

    private static func containsSummaryLine(prefix: String, in text: String) -> Bool {
        var isInRecognizedText = false
        var hasRecognizedContent = false

        for line in text.components(separatedBy: .newlines) {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if isRecognizedTextHeader(trimmedLine) {
                isInRecognizedText = true
                hasRecognizedContent = false
                continue
            }

            if isInRecognizedText {
                if trimmedLine.isEmpty {
                    if hasRecognizedContent {
                        isInRecognizedText = false
                        hasRecognizedContent = false
                    }
                    continue
                }

                hasRecognizedContent = true
                continue
            }

            if trimmedLine.hasPrefix(prefix) {
                return true
            }
        }

        return false
    }

    private static func isRecognizedTextHeader(_ line: String) -> Bool {
        line == "识别文字：" || line == "识别文字:" || line == "OCR：" || line == "OCR:"
    }

    private static func capture(in text: String, match: NSTextCheckingResult, at index: Int) -> String? {
        guard index < match.numberOfRanges,
              match.range(at: index).location != NSNotFound,
              let range = Range(match.range(at: index), in: text) else {
            return nil
        }

        return String(text[range])
    }
}

private extension String {
    func leftPadded(to length: Int, with character: Character) -> String {
        guard count < length else {
            return self
        }

        return String(repeating: String(character), count: length - count) + self
    }
}
