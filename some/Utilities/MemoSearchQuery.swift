import Foundation

enum MemoContentFilter: String, CaseIterable, Hashable {
    case link
    case attachment
    case task
    case openTask = "open-task"
    case completedTask = "completed-task"
    case reference
    case backlink
}

struct MemoSearchQuery: Equatable {
    let rawText: String
    let textTerms: [String]
    let tagFilters: [String]
    let requiredContentFilters: [MemoContentFilter]
    let excludedContentFilters: [MemoContentFilter]
    let isPinned: Bool?
    let isArchived: Bool?

    var text: String {
        textTerms.joined(separator: " ")
    }

    var hasTextTerms: Bool {
        !textTerms.isEmpty
    }

    var hasContentFilters: Bool {
        !requiredContentFilters.isEmpty || !excludedContentFilters.isEmpty
    }
}

enum MemoSearchQueryParser {
    static func parse(_ rawText: String) -> MemoSearchQuery {
        var textTerms: [String] = []
        var tagFilters: [String] = []
        var requiredContentFilters: [MemoContentFilter] = []
        var excludedContentFilters: [MemoContentFilter] = []
        var isPinned: Bool?
        var isArchived: Bool?

        for token in tokenize(rawText) {
            let lowercased = token.lowercased()

            if token.hasPrefix("#") {
                let tag = String(token.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                if !tag.isEmpty {
                    tagFilters.append(tag)
                }
            } else if lowercased == "is:pinned" || lowercased == "is:pin" || token == "is:置顶" {
                isPinned = true
            } else if lowercased == "is:unpinned" || lowercased == "is:unpin" || token == "is:未置顶" {
                isPinned = false
            } else if lowercased == "is:archived" || lowercased == "is:archive" || token == "is:归档" {
                isArchived = true
            } else if lowercased == "is:active" || lowercased == "is:inbox" || token == "is:记录" {
                isArchived = false
            } else if lowercased.hasPrefix("tag:") {
                let tag = String(token.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !tag.isEmpty {
                    tagFilters.append(tag)
                }
            } else if let filter = contentFilter(in: token, prefix: "has:") {
                requiredContentFilters.append(filter)
            } else if let filter = contentFilter(in: token, prefix: "-has:") {
                excludedContentFilters.append(filter)
            } else if let filter = contentFilter(in: token, prefix: "no:") {
                excludedContentFilters.append(filter)
            } else if let filter = contentFilter(in: token, prefix: "without:") {
                excludedContentFilters.append(filter)
            } else {
                textTerms.append(token)
            }
        }

        return MemoSearchQuery(
            rawText: rawText,
            textTerms: textTerms,
            tagFilters: Array(Set(tagFilters)).sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            },
            requiredContentFilters: uniqueContentFilters(requiredContentFilters),
            excludedContentFilters: uniqueContentFilters(excludedContentFilters),
            isPinned: isPinned,
            isArchived: isArchived
        )
    }

    private static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var isInsideQuotes = false

        for character in text {
            if character == "\"" {
                isInsideQuotes.toggle()
                continue
            }

            if character.isWhitespace && !isInsideQuotes {
                appendToken(current, to: &tokens)
                current = ""
            } else {
                current.append(character)
            }
        }

        appendToken(current, to: &tokens)
        return tokens
    }

    private static func appendToken(_ token: String, to tokens: inout [String]) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            tokens.append(trimmed)
        }
    }

    private static func contentFilter(in token: String, prefix: String) -> MemoContentFilter? {
        let lowercased = token.lowercased()
        guard lowercased.hasPrefix(prefix) else {
            return nil
        }

        let value = String(token.dropFirst(prefix.count))
        return contentFilter(from: value)
    }

    private static func contentFilter(from value: String) -> MemoContentFilter? {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")

        switch normalized {
        case "link", "links", "url", "urls", "链接", "网址":
            return .link
        case "attachment", "attachments", "file", "files", "resource", "resources", "附件", "文件":
            return .attachment
        case "task", "tasks", "todo", "todos", "checkbox", "checkboxes", "任务", "待办":
            return .task
        case "open-task", "open-tasks", "unchecked", "incomplete-task", "incomplete-tasks", "未完成":
            return .openTask
        case "done-task", "done-tasks", "completed-task", "completed-tasks", "checked", "已完成":
            return .completedTask
        case "reference", "references", "ref", "refs", "引用":
            return .reference
        case "backlink", "backlinks", "incoming-reference", "incoming-references", "被引用", "反向引用":
            return .backlink
        default:
            return nil
        }
    }

    private static func uniqueContentFilters(_ filters: [MemoContentFilter]) -> [MemoContentFilter] {
        Array(Set(filters)).sorted { $0.rawValue < $1.rawValue }
    }
}
