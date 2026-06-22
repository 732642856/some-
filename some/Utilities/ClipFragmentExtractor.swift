import Foundation

enum ClipFragmentSource: String, Codable, Equatable {
    case web
    case ocr
}

struct ClipFragment: Identifiable, Codable, Equatable {
    var id: String
    var source: ClipFragmentSource
    var title: String
    var text: String
    var uri: String?

    init(
        source: ClipFragmentSource,
        title: String,
        text: String,
        uri: String? = nil,
        stableKey: String
    ) {
        self.id = stableKey
        self.source = source
        self.title = title
        self.text = text
        self.uri = uri
    }
}

enum ClipFragmentExtractor {
    static let marker = "摘录片段："

    static func fragments(in memo: Memo) -> [ClipFragment] {
        fragments(in: memo.text)
    }

    static func fragments(in text: String) -> [ClipFragment] {
        var fragments: [ClipFragment] = []
        fragments.append(contentsOf: webFragments(in: text))
        fragments.append(contentsOf: ocrFragments(in: text))
        return unique(fragments)
    }

    static func mergedText(title: String, fragments: [ClipFragment]) -> String? {
        let selected = unique(fragments).filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !selected.isEmpty else {
            return nil
        }

        var lines = ["\(marker)\(cleanLine(title, fallback: "未命名摘录"))"]
        let webCount = selected.filter { $0.source == .web }.count
        let ocrCount = selected.filter { $0.source == .ocr }.count
        lines.append("来源：网页\(webCount) · OCR\(ocrCount)")
        lines.append("片段：")
        lines.append(contentsOf: selected.enumerated().map { index, fragment in
            "- [\(fragment.source == .web ? "网页" : "OCR")] \(index + 1). \(cleanLine(fragment.text, fallback: fragment.title))"
        })
        return lines.joined(separator: "\n")
    }

    private static func webFragments(in text: String) -> [ClipFragment] {
        LinkExtractor.webClips(in: text).flatMap { clip -> [ClipFragment] in
            var fragments: [ClipFragment] = []
            if let summary = clip.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
                fragments.append(
                    ClipFragment(
                        source: .web,
                        title: clip.title,
                        text: summary,
                        uri: clip.url.absoluteString,
                        stableKey: "web:\(clip.url.absoluteString):summary:\(summary)"
                    )
                )
            }

            fragments.append(contentsOf: clip.highlights.enumerated().map { index, highlight in
                ClipFragment(
                    source: .web,
                    title: clip.title,
                    text: highlight,
                    uri: clip.url.absoluteString,
                    stableKey: "web:\(clip.url.absoluteString):highlight:\(index):\(highlight)"
                )
            })
            return fragments
        }
    }

    private static func ocrFragments(in text: String) -> [ClipFragment] {
        imageTextBlocks(in: text).flatMap { imageText in
            imageText.lines.enumerated().map { index, line in
                ClipFragment(
                    source: .ocr,
                    title: imageText.title,
                    text: line,
                    uri: imageText.attachment?.map {
                        "\(SharedAttachmentStore.referenceScheme)://\(SharedAttachmentStore.encodedReferencePath($0.relativePath))"
                    },
                    stableKey: "ocr:\(imageText.attachment?.relativePath ?? imageText.title):\(index):\(line)"
                )
            }
        }
    }

    private static func imageTextBlocks(in text: String) -> [(title: String, lines: [String], attachment: SharedAttachment?)] {
        let rawLines = text.components(separatedBy: .newlines)
        let starts = rawLines.indices.filter { index in
            isImageTextTitle(rawLines[index].trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return starts.enumerated().compactMap { offset, start in
            let end = offset + 1 < starts.count ? starts[offset + 1] : rawLines.endIndex
            return imageText(in: rawLines[start..<end].joined(separator: "\n"))
        }
    }

    private static func imageText(in text: String) -> (title: String, lines: [String], attachment: SharedAttachment?)? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let firstLine = lines.first(where: { !$0.isEmpty }) else {
            return nil
        }

        guard let prefix = imageTextTitlePrefix(in: firstLine) else {
            return nil
        }

        let title = String(firstLine.dropFirst(prefix.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let textStartIndex = lines.firstIndex { line in
            line == "识别文字：" || line == "识别文字:" || line == "OCR：" || line == "OCR:"
        }.map { $0 + 1 } ?? 1

        let recognizedLines = ImageTextRecognizer.extractedHighlights(from: text, limit: 12)
        let fallbackLines = lines
            .dropFirst(textStartIndex)
            .filter { line in
                !line.isEmpty && SharedAttachmentStore.attachments(in: line).isEmpty
            }
        let finalLines = recognizedLines.isEmpty ? fallbackLines : recognizedLines
        guard !finalLines.isEmpty else {
            return nil
        }

        return (
            title.isEmpty ? "图片文字" : title,
            finalLines,
            SharedAttachmentStore.attachments(in: text).first(where: \.isImage)
        )
    }

    private static func isImageTextTitle(_ line: String) -> Bool {
        imageTextTitlePrefix(in: line) != nil
    }

    private static func imageTextTitlePrefix(in line: String) -> String? {
        let prefixes = ["图片文字：", "图片文字:", "截图文字：", "截图文字:"]
        return prefixes.first(where: { line.hasPrefix($0) })
    }

    private static func unique(_ fragments: [ClipFragment]) -> [ClipFragment] {
        var seen = Set<String>()
        return fragments.compactMap { fragment in
            let normalized = fragment.text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard !normalized.isEmpty, seen.insert("\(fragment.source.rawValue):\(normalized)").inserted else {
                return nil
            }
            return fragment
        }
    }

    private static func cleanLine(_ text: String, fallback: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? fallback : cleaned
    }
}
