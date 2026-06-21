import Foundation
import SwiftUI

struct MarkdownMemoTextView: View {
    let text: String
    var onToggleTask: ((Int) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(renderLines) { line in
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
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var renderLines: [MarkdownMemoRenderLine] {
        text.components(separatedBy: "\n").enumerated().map { lineIndex, line in
            MarkdownMemoRenderLine(
                lineIndex: lineIndex,
                text: line,
                task: MemoTaskParser.taskItem(in: line, lineIndex: lineIndex)
            )
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
}

private struct MarkdownMemoRenderLine: Identifiable {
    let lineIndex: Int
    let text: String
    let task: MemoTaskItem?

    var id: Int { lineIndex }
}
