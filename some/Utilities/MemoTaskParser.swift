import Foundation

struct MemoTaskItem: Equatable, Identifiable {
    let lineIndex: Int
    let isCompleted: Bool
    let text: String

    var id: Int { lineIndex }
}

enum MemoTaskParser {
    private static let taskExpression: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"^(\s*[-*]\s+\[)( |x|X)(\]\s*)(.*)$"#)
    }()

    static func taskItems(in text: String) -> [MemoTaskItem] {
        text.components(separatedBy: "\n").enumerated().compactMap { lineIndex, line in
            taskItem(in: line, lineIndex: lineIndex)
        }
    }

    static func taskItem(in line: String, lineIndex: Int) -> MemoTaskItem? {
        guard let match = firstMatch(in: line) else {
            return nil
        }

        guard
            let stateRange = Range(match.range(at: 2), in: line),
            let textRange = Range(match.range(at: 4), in: line)
        else {
            return nil
        }

        return MemoTaskItem(
            lineIndex: lineIndex,
            isCompleted: line[stateRange].lowercased() == "x",
            text: String(line[textRange])
        )
    }

    static func toggleTask(atLine lineIndex: Int, in text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        guard lines.indices.contains(lineIndex) else {
            return text
        }

        let line = lines[lineIndex]
        guard
            let match = firstMatch(in: line),
            let stateRange = Range(match.range(at: 2), in: line)
        else {
            return text
        }

        var updatedLine = line
        let currentState = String(line[stateRange])
        updatedLine.replaceSubrange(stateRange, with: currentState == " " ? "x" : " ")
        lines[lineIndex] = updatedLine
        return lines.joined(separator: "\n")
    }

    private static func firstMatch(in line: String) -> NSTextCheckingResult? {
        guard let taskExpression = taskExpression else {
            return nil
        }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return taskExpression.firstMatch(in: line, range: range)
    }
}
