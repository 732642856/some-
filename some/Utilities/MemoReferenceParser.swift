import Foundation

struct MemoReference: Equatable, Identifiable {
    let memoID: UUID
    let title: String?

    var id: UUID { memoID }

    var referenceLine: String {
        let label = title ?? memoID.uuidString
        return "[引用: \(label)](some-memo://\(memoID.uuidString))"
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
            references.append(
                MemoReference(
                    memoID: id,
                    title: title
                )
            )
        }

        return references
    }

    static func referenceLine(for memo: Memo) -> String {
        MemoReference(memoID: memo.id, title: title(for: memo)).referenceLine
    }

    static func displayTextWithoutReferences(_ text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .filter { !isReferenceOnlyLine($0) }
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

    private static func isReferenceOnlyLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("[引用:") || trimmed.hasPrefix("["),
              trimmed.contains("](\(scheme)://"),
              trimmed.hasSuffix(")") else {
            return false
        }

        return references(in: trimmed).count == 1
    }
}
