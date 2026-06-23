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
        let range = NSRange(location: 0, length: nsText.length)
        var references: [MemoReference] = []
        var seenIDs: Set<UUID> = []

        expression.enumerateMatches(in: text, options: [], range: range) { result, _, _ in
            guard let result = result,
                  result.numberOfRanges == 3,
                  let idRange = Range(result.range(at: 2), in: text),
                  let id = UUID(uuidString: String(text[idRange])),
                  seenIDs.insert(id).inserted else {
                return
            }

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

        return lines
            .enumerated()
            .filter { !indexesToRemove.contains($0.offset) }
            .map(\.element)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
}
