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
        let lines = text.components(separatedBy: "\n")
        let recognizedTextBodyIndexes = recognizedTextBodyLineIndexes(in: lines)
        return lines.enumerated().compactMap { lineIndex, line in
            guard !recognizedTextBodyIndexes.contains(lineIndex) else {
                return nil
            }

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
}
