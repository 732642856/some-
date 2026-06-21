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
            guard !absoluteString.isEmpty, !seenURLs.contains(absoluteString) else {
                return nil
            }
            seenURLs.insert(absoluteString)
            return absoluteString
        }

        var parts = cleanedTexts
        for urlString in cleanedURLs where !parts.contains(where: { $0.contains(urlString) }) {
            parts.append(urlString)
        }

        parts.append(contentsOf: attachments.map(\.referenceLine))

        return parts.joined(separator: "\n\n")
    }
}
