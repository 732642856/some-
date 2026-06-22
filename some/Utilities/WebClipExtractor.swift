import Foundation

struct ExtractedWebClip: Equatable {
    let url: URL
    let title: String?
    let summary: String?
    let highlights: [String]
}

enum WebClipExtractor {
    static func clip(from url: URL, html: String) -> ExtractedWebClip {
        let title = firstNonEmpty(
            metaContent(named: "og:title", in: html),
            metaContent(named: "twitter:title", in: html),
            titleTag(in: html),
            firstMatch(pattern: #"<h1[^>]*>(.*?)</h1>"#, in: html),
            LinkExtractor.displayText(for: url)
        )
        let paragraphs = articleParagraphs(in: html)
        let summary = firstNonEmpty(
            metaContent(named: "description", in: html),
            metaContent(named: "og:description", in: html),
            metaContent(named: "twitter:description", in: html),
            paragraphs.first
        )
        let highlights = paragraphs
            .filter { $0 != summary }
            .prefix(5)

        return ExtractedWebClip(
            url: url,
            title: title,
            summary: summary,
            highlights: Array(highlights)
        )
    }

    static func fallbackClip(for url: URL, title: String? = nil) -> ExtractedWebClip {
        ExtractedWebClip(
            url: url,
            title: firstNonEmpty(title, LinkExtractor.displayText(for: url)),
            summary: nil,
            highlights: []
        )
    }

    static func articleParagraphs(in html: String) -> [String] {
        let scopedHTML = articleScope(in: html)
        let cleanedHTML = removeNoise(from: scopedHTML)
        let blockMatches = [
            rawMatches(pattern: #"<p[^>]*>(.*?)</p>"#, in: cleanedHTML),
            rawMatches(pattern: #"<blockquote[^>]*>(.*?)</blockquote>"#, in: cleanedHTML),
            rawMatches(pattern: #"<li[^>]*>(.*?)</li>"#, in: cleanedHTML)
        ].flatMap { $0 }

        let candidates = blockMatches.isEmpty
            ? fallbackParagraphs(in: cleanedHTML)
            : blockMatches.map(cleanHTML)

        return rankedParagraphs(candidates)
    }

    static func cleanHTML(_ rawText: String) -> String {
        let withoutTags = rawText.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: " ",
            options: .regularExpression
        )
        return decodeEntities(withoutTags)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func articleScope(in html: String) -> String {
        firstRawMatch(pattern: #"<article\b[^>]*>(.*?)</article>"#, in: html)
            ?? firstRawMatch(pattern: #"<main\b[^>]*>(.*?)</main>"#, in: html)
            ?? firstRawMatch(pattern: #"<body\b[^>]*>(.*?)</body>"#, in: html)
            ?? html
    }

    private static func removeNoise(from html: String) -> String {
        var output = html.replacingOccurrences(
            of: #"<!--.*?-->"#,
            with: " ",
            options: [.regularExpression]
        )
        for tag in ["script", "style", "noscript", "nav", "header", "footer", "aside", "form", "svg"] {
            output = output.replacingOccurrences(
                of: #"<\#(tag)\b[^>]*>[\s\S]*?</\#(tag)>"#,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return output
    }

    private static func titleTag(in html: String) -> String? {
        firstMatch(pattern: #"<title[^>]*>(.*?)</title>"#, in: html)
    }

    private static func metaContent(named name: String, in html: String) -> String? {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let patterns = [
            #"<meta[^>]*(?:name|property)\s*=\s*["']\#(escapedName)["'][^>]*content\s*=\s*["']([^"']*)["'][^>]*>"#,
            #"<meta[^>]*content\s*=\s*["']([^"']*)["'][^>]*(?:name|property)\s*=\s*["']\#(escapedName)["'][^>]*>"#
        ]

        for pattern in patterns {
            if let value = firstMatch(pattern: pattern, in: html) {
                return value
            }
        }
        return nil
    }

    private static func fallbackParagraphs(in html: String) -> [String] {
        let text = cleanHTML(html)
        let separators = CharacterSet(charactersIn: "。！？!?")
        return text
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func rankedParagraphs(_ paragraphs: [String]) -> [String] {
        var seen = Set<String>()
        let ranked = paragraphs.enumerated().compactMap { index, paragraph -> ParagraphCandidate? in
            let text = limited(paragraph)
            let key = text.lowercased()
            guard seen.insert(key).inserted,
                  text.count >= 24,
                  !isBoilerplate(text) else {
                return nil
            }
            return ParagraphCandidate(index: index, text: text, score: score(text))
        }
        let selected = ranked
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.index < rhs.index
                }
                return lhs.score > rhs.score
            }
            .prefix(6)
            .sorted { $0.index < $1.index }
        return selected.map(\.text)
    }

    private static func score(_ text: String) -> Int {
        let punctuation = text.filter { "，。；：、,.!?！？;:".contains($0) }.count
        let lengthScore = min(text.count, 320)
        let paragraphBonus = text.count >= 80 ? 24 : 0
        return lengthScore + punctuation * 8 + paragraphBonus
    }

    private static func isBoilerplate(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        let noisyTerms = [
            "cookie", "cookies", "privacy policy", "terms of use", "subscribe",
            "sign in", "log in", "copyright", "all rights reserved",
            "广告", "登录", "注册", "订阅", "隐私政策", "用户协议", "版权所有",
            "相关推荐", "相关阅读", "分享至", "点击查看", "扫码", "下载客户端"
        ]
        if noisyTerms.contains(where: { lowercased.contains($0) }) {
            return true
        }
        let urlLikeCount = lowercased.components(separatedBy: "http").count - 1
        return urlLikeCount > 1
    }

    private static func limited(_ text: String, maxLength: Int = 280) -> String {
        guard text.count > maxLength else { return text }
        let endIndex = text.index(text.startIndex, offsetBy: maxLength)
        return "\(text[..<endIndex])..."
    }

    private static func firstMatch(pattern: String, in text: String) -> String? {
        firstRawMatch(pattern: pattern, in: text).map(cleanHTML)
    }

    private static func firstRawMatch(pattern: String, in text: String) -> String? {
        rawMatches(pattern: pattern, in: text).first
    }

    private static func rawMatches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        return regex.matches(in: text, options: [], range: range).compactMap { result in
            guard result.numberOfRanges >= 2 else { return nil }
            return nsText.substring(with: result.range(at: 1))
        }
    }

    private static func decodeEntities(_ text: String) -> String {
        decodeNumericEntities(text)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
    }

    private static func decodeNumericEntities(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"&#(x?[0-9A-Fa-f]+);"#) else {
            return text
        }

        let nsText = text as NSString
        let matches = regex.matches(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        )
        var output = text
        for match in matches.reversed() {
            guard let fullRange = Range(match.range(at: 0), in: output),
                  let valueRange = Range(match.range(at: 1), in: output) else {
                continue
            }
            let value = String(output[valueRange])
            let radix = value.hasPrefix("x") || value.hasPrefix("X") ? 16 : 10
            let digits = radix == 16 ? String(value.dropFirst()) : value
            guard let scalarValue = UInt32(digits, radix: radix),
                  let scalar = UnicodeScalar(scalarValue) else {
                continue
            }
            output.replaceSubrange(fullRange, with: String(Character(scalar)))
        }
        return output
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

private struct ParagraphCandidate {
    let index: Int
    let text: String
    let score: Int
}
