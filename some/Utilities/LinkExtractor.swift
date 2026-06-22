import Foundation

enum LinkExtractor {
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
            let key = url.absoluteString

            if seen.insert(key).inserted {
                urls.append(url)
            }
        }

        return urls
    }

    static func displayText(for url: URL) -> String {
        if let host = url.host?.replacingOccurrences(of: "www.", with: ""), !host.isEmpty {
            return host
        }

        return url.absoluteString
    }
}
