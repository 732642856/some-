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

struct SelectedWebClipContent: Equatable {
    var summary: String?
    var highlights: [String]
    var mergedFragmentsText: String?
}

struct ClipFragmentAssetSummary: Equatable {
    var title: String
    var summary: String?
    var uri: String?
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
        fragments.append(contentsOf: mergedFragments(in: text))
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

    static func selectedWebClipContent(
        title: String,
        summary: String?,
        fragments: [ClipFragment]
    ) -> SelectedWebClipContent {
        let selected = unique(fragments)
        let cleanedSummary = summary.map { cleanLine($0, fallback: "") }
            .flatMap { $0.isEmpty ? nil : $0 }
        let selectedSummary = cleanedSummary.flatMap { summary in
            selected.contains { fragment in
                fragment.source == .web && cleanLine(fragment.text, fallback: "") == summary
            } ? summary : nil
        }
        let highlights = uniqueHighlights(
            selected
                .filter { $0.source == .web }
                .map(\.text)
        )
        .filter { highlight in
            guard let selectedSummary = selectedSummary else { return true }
            return highlight != selectedSummary
        }

        return SelectedWebClipContent(
            summary: selectedSummary,
            highlights: highlights,
            mergedFragmentsText: mergedText(title: title, fragments: selected)
        )
    }

    static func assetSummaries(in text: String) -> [ClipFragmentAssetSummary] {
        mergedFragmentBlocks(in: text).map { block in
            ClipFragmentAssetSummary(
                title: block.title,
                summary: block.fragments.map(\.text).joined(separator: " · "),
                uri: block.fragments.first(where: { $0.uri?.isEmpty == false })?.uri
            )
        }
    }

    static func ocrProofreadingChecklist(in text: String) -> String? {
        let fragments = unique(ocrFragments(in: text))
        guard !fragments.isEmpty else { return nil }

        var lines = ["OCR校对：图片文字校对"]
        let sources = uniqueLines(fragments.map(\.title))
        if !sources.isEmpty {
            lines.append("来源：\(sources.joined(separator: "、"))")
        }

        lines.append("")
        lines.append("待校对：")
        lines.append(contentsOf: fragments.map { "- [ ] \(cleanLine($0.text, fallback: $0.title))" })
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

    private static func mergedFragments(in text: String) -> [ClipFragment] {
        mergedFragmentBlocks(in: text).flatMap(\.fragments)
    }

    private static func mergedFragmentBlocks(in text: String) -> [(title: String, fragments: [ClipFragment])] {
        let lines = text.components(separatedBy: .newlines)
        let starts = lines.indices.filter { index in
            lines[index]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .hasPrefix(marker)
        }

        return starts.enumerated().compactMap { offset, start in
            let end = offset + 1 < starts.count ? starts[offset + 1] : lines.endIndex
            return mergedFragmentBlock(in: Array(lines[start..<end]))
        }
    }

    private static func mergedFragmentBlock(in lines: [String]) -> (title: String, fragments: [ClipFragment])? {
        guard let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              firstLine.hasPrefix(marker) else {
            return nil
        }

        let rawTitle = String(firstLine.dropFirst(marker.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let title = rawTitle.isEmpty ? "摘录片段" : rawTitle
        var fragments: [ClipFragment] = []

        for line in lines.dropFirst() {
            guard let item = mergedFragmentItem(in: line) else { continue }
            fragments.append(
                ClipFragment(
                    source: item.source,
                    title: title,
                    text: item.text,
                    stableKey: "clip:\(title):\(item.source.rawValue):\(item.index):\(item.text)"
                )
            )
        }

        return fragments.isEmpty ? nil : (title, fragments)
    }

    private static func mergedFragmentItem(in line: String) -> (source: ClipFragmentSource, index: Int, text: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^-\s*\[(网页|OCR)\]\s*([0-9]+)\.\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)),
              match.numberOfRanges >= 4,
              let sourceRange = Range(match.range(at: 1), in: trimmed),
              let indexRange = Range(match.range(at: 2), in: trimmed),
              let textRange = Range(match.range(at: 3), in: trimmed)
        else {
            return nil
        }

        let source: ClipFragmentSource = trimmed[sourceRange] == "网页" ? .web : .ocr
        let index = Int(trimmed[indexRange]) ?? 0
        let text = String(trimmed[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return nil
        }

        return (source, index, text)
    }

    private static func ocrFragments(in text: String) -> [ClipFragment] {
        imageTextBlocks(in: text).flatMap { imageText in
            imageText.lines.enumerated().map { index, line in
                ClipFragment(
                    source: .ocr,
                    title: imageText.title,
                    text: line,
                    uri: attachmentURI(for: imageText.attachment),
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

        let recognizedLines = extractedImageTextHighlights(from: text, limit: 12)
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
        let prefixes = ["图片文字：", "图片文字:", "截图文字：", "截图文字:", "扫描文字：", "扫描文字:"]
        return prefixes.first(where: { line.hasPrefix($0) })
    }

    private static func attachmentURI(for attachment: SharedAttachment?) -> String? {
        guard let attachment = attachment else {
            return nil
        }

        return "\(SharedAttachmentStore.referenceScheme)://\(SharedAttachmentStore.encodedReferencePath(attachment.relativePath))"
    }

    private static func extractedImageTextHighlights(from text: String, limit: Int) -> [String] {
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

    private static func uniqueHighlights(_ highlights: [String]) -> [String] {
        var seen = Set<String>()
        return highlights.compactMap { highlight in
            let cleaned = cleanLine(highlight, fallback: "")
            guard !cleaned.isEmpty, seen.insert(cleaned).inserted else {
                return nil
            }
            return cleaned
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
