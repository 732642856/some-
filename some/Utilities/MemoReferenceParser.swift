import Foundation

struct MemoReference: Equatable, Identifiable {
    let memoID: UUID
    let title: String?
    let note: String?

    init(memoID: UUID, title: String?, note: String? = nil) {
        self.memoID = memoID
        self.title = title
        self.note = note
    }

    var id: UUID { memoID }

    var referenceLine: String {
        let label = title ?? memoID.uuidString
        let line = "[引用: \(label)](some-memo://\(memoID.uuidString))"
        guard let note = note?.trimmingCharacters(in: .whitespacesAndNewlines),
              !note.isEmpty else {
            return line
        }
        return "引用批注：\(note)\n\(line)"
    }
}

enum MemoReferenceParser {
    static let scheme = "some-memo"

    static func references(in text: String) -> [MemoReference] {
        guard let expression = try? NSRegularExpression(
            pattern: #"\[([^\]]+)\]\(some-memo://([^)]+)\)"#,
            options: []
        ) else {
            return []
        }

        let nsText = text as NSString
        let lines = text.components(separatedBy: .newlines)
        let recognizedTextBodyIndexes = recognizedTextBodyLineIndexes(in: lines)
        let range = NSRange(location: 0, length: nsText.length)
        var references: [MemoReference] = []

        expression.enumerateMatches(in: text, options: [], range: range) { result, _, _ in
            guard let result = result,
                  result.numberOfRanges == 3,
                  let idRange = Range(result.range(at: 2), in: text),
                  let id = UUID(uuidString: String(text[idRange])) else {
                return
            }

            let lineIndex = lineIndex(containing: result.range.location, in: nsText)
            guard !recognizedTextBodyIndexes.contains(lineIndex) else { return }

            let title = title(in: text, match: result)
            let note = referenceNote(in: text, before: result)
            references.append(
                MemoReference(
                    memoID: id,
                    title: title,
                    note: note
                )
            )
        }

        return references
    }

    static func referenceLine(for memo: Memo) -> String {
        MemoReference(memoID: memo.id, title: title(for: memo), note: nil).referenceLine
    }

    static func referenceLine(for memo: Memo, note: String?) -> String {
        MemoReference(memoID: memo.id, title: title(for: memo), note: note).referenceLine
    }

    static func displayTextWithoutReferences(_ text: String) -> String {
        visibleTextModelWithoutReferences(for: text).text
    }

    static func originalLineIndex(forVisibleLine visibleLineIndex: Int, in text: String) -> Int? {
        let lineMap = visibleTextModelWithoutReferences(for: text).originalLineIndices
        guard lineMap.indices.contains(visibleLineIndex) else { return nil }
        return lineMap[visibleLineIndex]
    }

    static func title(for memo: Memo, maxLength: Int = 28) -> String {
        let text = SharedAttachmentStore
            .displayTextWithoutAttachmentReferences(memo.text)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "未命名随记"
        guard text.count > maxLength else {
            return text
        }

        let endIndex = text.index(text.startIndex, offsetBy: maxLength)
        return "\(text[..<endIndex])..."
    }

    private static func visibleTextModelWithoutReferences(for text: String) -> VisibleReferenceTextModel {
        let lines = text.components(separatedBy: .newlines)
        var indexesToRemove: Set<Int> = []

        for index in lines.indices where isReferenceOnlyLine(lines[index]) {
            indexesToRemove.insert(index)
            guard index > lines.startIndex else {
                continue
            }
            var previousIndex = lines.index(before: index)
            while lines.indices.contains(previousIndex) {
                let previousLine = lines[previousIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                if previousLine.isEmpty {
                    if previousIndex == lines.startIndex { break }
                    previousIndex = lines.index(before: previousIndex)
                    continue
                }
                if isReferenceNoteLine(previousLine) {
                    indexesToRemove.insert(previousIndex)
                }
                break
            }
        }

        var rows = lines
            .enumerated()
            .filter { !indexesToRemove.contains($0.offset) }
            .map { ($0.offset, $0.element) }

        while let first = rows.first,
              first.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rows.removeFirst()
        }

        while let last = rows.last,
              last.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rows.removeLast()
        }

        return VisibleReferenceTextModel(
            text: rows.map { $0.1 }.joined(separator: "\n"),
            originalLineIndices: rows.map { $0.0 }
        )
    }

    private static func title(in text: String, match: NSTextCheckingResult) -> String? {
        guard let range = Range(match.range(at: 1), in: text) else {
            return nil
        }

        let label = String(text[range])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return label.replacingOccurrences(of: "引用: ", with: "")
    }

    private static func referenceNote(in text: String, before match: NSTextCheckingResult) -> String? {
        let nsText = text as NSString
        let prefix = nsText.substring(to: match.range.location)
        guard let previousLine = prefix
            .components(separatedBy: .newlines)
            .reversed()
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }),
              isReferenceNoteLine(previousLine) else {
            return nil
        }

        return previousLine
            .dropFirst("引用批注：".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

            if trimmed.hasPrefix("[附件:") || trimmed.hasPrefix("some-attachment://") {
                isInRecognizedText = false
                hasRecognizedContent = false
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

    private static func isReferenceOnlyLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("[引用:") || trimmed.hasPrefix("["),
              trimmed.contains("](\(scheme)://"),
              trimmed.hasSuffix(")") else {
            return false
        }

        return references(in: trimmed).count == 1
    }

    private static func isReferenceNoteLine(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("引用批注：")
    }

    private struct VisibleReferenceTextModel {
        let text: String
        let originalLineIndices: [Int]
    }
}
