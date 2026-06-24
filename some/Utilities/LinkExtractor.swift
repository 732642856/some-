import Foundation

enum LinkExtractor {
    static let webClipMarker = "网页摘录"

    struct WebClip: Equatable {
        let title: String
        let url: URL
        let summary: String?
        let highlights: [String]
    }

    static func urls(in text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var urls: [URL] = []
        var seen = Set<String>()

        detector.enumerateMatches(in: text, options: [], range: range) { result, _, _ in
            guard let url = result?.url else { return }
            guard url.scheme != SharedAttachmentStore.referenceScheme else { return }
            guard url.scheme != MemoReferenceParser.scheme else { return }
            let key = deduplicationKey(for: url)

            if seen.insert(key).inserted {
                urls.append(url)
            }
        }

        return urls
    }

    static func webClips(in text: String) -> [WebClip] {
        let pattern = #"\[网页摘录: ([^\]]+)\]\((https?://[^)\s]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let nsText = text as NSString
        let lines = text.components(separatedBy: .newlines)
        let recognizedTextBodyIndexes = recognizedTextBodyLineIndexes(in: lines)
        let range = NSRange(location: 0, length: nsText.length)
        var clips: [WebClip] = []
        var seen = Set<String>()

        regex.enumerateMatches(in: text, options: [], range: range) { result, _, _ in
            guard let result = result,
                  result.numberOfRanges >= 3,
                  let titleRange = Range(result.range(at: 1), in: text),
                  let urlRange = Range(result.range(at: 2), in: text),
                  let url = URL(string: String(text[urlRange]))
            else {
                return
            }

            let lineIndex = lineIndex(containing: result.range.location, in: nsText)
            guard !recognizedTextBodyIndexes.contains(lineIndex) else { return }

            let key = deduplicationKey(for: url)
            guard seen.insert(key).inserted else { return }

            let followingLines = Array(lines.dropFirst(lineIndex + 1))
            clips.append(
                WebClip(
                    title: String(text[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines),
                    url: url,
                    summary: summary(after: followingLines),
                    highlights: highlights(after: followingLines)
                )
            )
        }

        return clips
    }

    static func webClipText(title: String, url: URL, summary: String?, highlights: [String]) -> String {
        var lines = ["[\(webClipMarker): \(cleanLine(title, fallback: displayText(for: url)))](\(url.absoluteString))"]
        let source = displayText(for: url)
        lines.append("来源：\(source)")

        if let summary = summary.map({ cleanLine($0, fallback: "") }), !summary.isEmpty {
            lines.append("摘要：\(summary)")
        }

        let cleanedHighlights = highlights
            .map { cleanLine($0, fallback: "") }
            .filter { !$0.isEmpty }
        let cardParts = [
            summary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? "摘要" : nil,
            cleanedHighlights.isEmpty ? nil : "重点\(min(cleanedHighlights.count, 5))条"
        ].compactMap { $0 }
        if !cardParts.isEmpty {
            lines.append("摘录卡：\(cardParts.joined(separator: " · "))")
        }

        if let keyInfoSummary = KeyInfoExtractor.summary(in: [summary].compactMap { $0 } + cleanedHighlights) {
            lines.append("网页关键信息候选：\(keyInfoSummary)")
        }

        if !cleanedHighlights.isEmpty {
            lines.append("重点：")
            lines.append(contentsOf: cleanedHighlights.prefix(5).map { "- \($0)" })
        }

        return lines.joined(separator: "\n")
    }

    static func displayText(for url: URL) -> String {
        if let host = url.host?.replacingOccurrences(of: "www.", with: ""), !host.isEmpty {
            return host
        }

        return url.absoluteString
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

    private static func summary(after lines: [String]) -> String? {
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("[") { return nil }
            if trimmed.hasPrefix("摘要：") {
                return String(trimmed.dropFirst("摘要：".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if trimmed.hasPrefix("摘要:") {
                return String(trimmed.dropFirst("摘要:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if trimmed.hasPrefix("重点：") || trimmed.hasPrefix("重点:") {
                return nil
            }
        }

        return nil
    }

    private static func highlights(after lines: [String]) -> [String] {
        var highlights: [String] = []
        var isInHighlightBlock = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                if isInHighlightBlock { break }
                continue
            }

            if trimmed.hasPrefix("[") {
                break
            }

            if trimmed.hasPrefix("重点：") || trimmed.hasPrefix("重点:") {
                isInHighlightBlock = true
                continue
            }

            guard isInHighlightBlock else { continue }

            if trimmed.hasPrefix("- ") {
                highlights.append(String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                break
            }
        }

        return highlights
    }

    private static func cleanLine(_ text: String, fallback: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? fallback : cleaned
    }

    static func deduplicationKey(for url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }

        components.fragment = nil
        components.queryItems = components.queryItems?
            .filter { !isTrackingQueryItem($0) }
            .sorted { lhs, rhs in
                if lhs.name == rhs.name {
                    return (lhs.value ?? "") < (rhs.value ?? "")
                }
                return lhs.name < rhs.name
            }

        if components.queryItems?.isEmpty == true {
            components.queryItems = nil
        }

        return components.url?.absoluteString ?? url.absoluteString
    }

    private static func isTrackingQueryItem(_ item: URLQueryItem) -> Bool {
        let name = item.name.lowercased()
        return name.hasPrefix("utm_")
            || [
                "fbclid",
                "gclid",
                "gbraid",
                "wbraid",
                "yclid",
                "mc_cid",
                "mc_eid",
                "igshid",
                "spm"
            ].contains(name)
    }
}
