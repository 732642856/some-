import Foundation

enum TagParser {
    private static let tagPattern = #"(?:^|\s)#([\p{L}\p{N}_\-/]+)"#

    static func extractTags(from text: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: tagPattern) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = expression.matches(in: text, range: range)

        let tags = matches.compactMap { match -> String? in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text) else {
                return nil
            }
            return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return Array(Set(tags)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
