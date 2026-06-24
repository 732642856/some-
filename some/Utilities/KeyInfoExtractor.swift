import Foundation

enum KeyInfoExtractor {
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

    private static func detectedDateCandidates(in text: String) -> [Candidate] {
        matches(in: text, pattern: #"\b\d{4}[./-]\d{1,2}[./-]\d{1,2}(?:\s+\d{1,2}:\d{2})?\b"#)
            .map { normalized in
                Candidate(label: "日期", value: normalized.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ".", with: "-"))
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
        matches(in: text, pattern: #"[¥￥]?\s*\d+(?:[\.,]\d{1,2})?\s*元"#)
            .map { amount in
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
}
