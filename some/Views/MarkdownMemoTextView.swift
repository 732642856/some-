import Foundation
import SwiftUI

struct MarkdownMemoTextView: View {
    let text: String
    var onToggleTask: ((Int) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(renderBlocks) { block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var renderBlocks: [MarkdownMemoBlock] {
        MarkdownMemoBlockParser.blocks(in: text)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownMemoBlock) -> some View {
        switch block {
        case .line(let line):
            if let task = line.task {
                taskLine(task)
            } else if line.text.isEmpty {
                Color.clear.frame(height: 4)
            } else {
                renderedText(line.text)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.primaryText)
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .code(let code):
            codeBlock(code)
        }
    }

    @ViewBuilder
    private func taskLine(_ task: MemoTaskItem) -> some View {
        if let onToggleTask = onToggleTask {
            Button {
                onToggleTask(task.lineIndex)
            } label: {
                taskContent(task)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "标记为未完成" : "标记为已完成")
        } else {
            taskContent(task)
        }
    }

    private func taskContent(_ task: MemoTaskItem) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(task.isCompleted ? Color.accentGreen : Color.secondaryText)
                .frame(width: 22, height: 22)
                .padding(.top, 1)

            renderedText(task.text)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(task.isCompleted ? Color.secondaryText : Color.primaryText)
                .strikethrough(task.isCompleted, color: Color.secondaryText)
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func renderedText(_ value: String) -> Text {
        if let attributedText = try? AttributedString(markdown: value) {
            return Text(attributedText)
        }

        return Text(value)
    }

    private func codeBlock(_ code: MarkdownMemoCodeBlock) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let language = code.language {
                Text(language)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
                    .textCase(.uppercase)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code.code.isEmpty ? " " : code.code)
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.primaryText)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.subtleSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.border, lineWidth: 1)
        )
    }
}

enum MarkdownMemoBlockParser {
    static func blocks(in text: String) -> [MarkdownMemoBlock] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [MarkdownMemoBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            if isFenceLine(line) {
                let startLineIndex = index
                let language = fenceLanguage(in: line)
                var codeLines: [String] = []
                index += 1

                while index < lines.count, !isFenceLine(lines[index]) {
                    codeLines.append(lines[index])
                    index += 1
                }

                let endLineIndex: Int
                if index < lines.count {
                    endLineIndex = index
                    index += 1
                } else {
                    endLineIndex = max(startLineIndex, lines.count - 1)
                }

                blocks.append(
                    .code(
                        MarkdownMemoCodeBlock(
                            startLineIndex: startLineIndex,
                            endLineIndex: endLineIndex,
                            language: language,
                            code: codeLines.joined(separator: "\n")
                        )
                    )
                )
            } else {
                blocks.append(
                    .line(
                        MarkdownMemoRenderLine(
                            lineIndex: index,
                            text: line,
                            task: MemoTaskParser.taskItem(in: line, lineIndex: index)
                        )
                    )
                )
                index += 1
            }
        }

        return blocks
    }

    private static func fenceLanguage(in line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else {
            return nil
        }

        let rawLanguage = String(trimmed.dropFirst(3))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return rawLanguage.isEmpty ? nil : rawLanguage
    }

    private static func isFenceLine(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```")
    }
}

enum MarkdownMemoBlock: Identifiable, Equatable {
    case line(MarkdownMemoRenderLine)
    case code(MarkdownMemoCodeBlock)

    var id: String {
        switch self {
        case .line(let line):
            return "line-\(line.lineIndex)"
        case .code(let code):
            return "code-\(code.startLineIndex)-\(code.endLineIndex)"
        }
    }
}

struct MarkdownMemoCodeBlock: Equatable {
    let startLineIndex: Int
    let endLineIndex: Int
    let language: String?
    let code: String
}

struct MarkdownMemoRenderLine: Identifiable, Equatable {
    let lineIndex: Int
    let text: String
    let task: MemoTaskItem?

    var id: Int { lineIndex }
}
