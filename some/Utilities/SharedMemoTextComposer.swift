import Foundation

enum SharedMemoTextComposer {
    static func compose(
        texts: [String],
        urls: [URL],
        attachments: [SharedAttachment] = []
    ) -> String {
        let cleanedTexts = texts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var seenURLs: Set<String> = []
        let cleanedURLs = urls.compactMap { url -> String? in
            let absoluteString = url.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = LinkExtractor.deduplicationKey(for: url)
            guard !absoluteString.isEmpty, !seenURLs.contains(key) else {
                return nil
            }
            seenURLs.insert(key)
            return absoluteString
        }

        let textURLKeys = Set(cleanedTexts.flatMap { text in
            LinkExtractor.urls(in: text).map { LinkExtractor.deduplicationKey(for: $0) }
        })

        var parts = cleanedTexts
        for urlString in cleanedURLs {
            guard let url = URL(string: urlString) else { continue }
            let key = LinkExtractor.deduplicationKey(for: url)
            guard !textURLKeys.contains(key),
                  !parts.contains(where: { $0.contains(urlString) }) else {
                continue
            }
            parts.append(urlString)
        }

        parts.append(contentsOf: attachments.map(\.referenceLine))

        return parts.joined(separator: "\n\n")
    }
}
