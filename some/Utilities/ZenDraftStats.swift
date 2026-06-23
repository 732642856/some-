import Foundation

struct ZenDraftStats: Equatable {
    let characterCount: Int
    let lineCount: Int
    let tagCount: Int

    init(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        characterCount = trimmed.filter { !$0.isWhitespace }.count
        lineCount = trimmed
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .count
        tagCount = TagParser.extractTags(from: text).count
    }

    var canSave: Bool {
        characterCount > 0
    }

    var summaryText: String {
        guard canSave else {
            return "空白草稿"
        }

        return "\(characterCount) 字 · \(lineCount) 行 · \(tagCount) 个标签"
    }
}
