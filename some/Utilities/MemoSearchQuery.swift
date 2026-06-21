import Foundation

struct MemoSearchQuery: Equatable {
    let rawText: String
    let textTerms: [String]
    let tagFilters: [String]
    let isPinned: Bool?
    let isArchived: Bool?

    var text: String {
        textTerms.joined(separator: " ")
    }

    var hasTextTerms: Bool {
        !textTerms.isEmpty
    }
}

enum MemoSearchQueryParser {
    static func parse(_ rawText: String) -> MemoSearchQuery {
        var textTerms: [String] = []
        var tagFilters: [String] = []
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
}
