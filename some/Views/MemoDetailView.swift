import Foundation
import SwiftUI

struct MemoDetailView: View {
    @EnvironmentObject private var store: MemoStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let memo: Memo
    @State private var text: String
    @State private var isEditing = false
    @State private var isShowingDeleteConfirmation = false
    @State private var editErrorMessage: String?
    @FocusState private var isFocused: Bool

    init(memo: Memo) {
        self.memo = memo
        _text = State(initialValue: memo.text)
    }

    var body: some View {
        let currentMemo = store.memos.first(where: { $0.id == memo.id }) ?? memo
        let displayText = isEditing ? text : currentMemo.text
        let readableText = SharedAttachmentStore.displayTextWithoutAttachmentReferences(displayText)
        let attachments = SharedAttachmentStore.attachments(in: displayText)

        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    if isEditing {
                        TextEditor(text: $text)
                            .focused($isFocused)
                            .scrollContentBackground(.hidden)
                            .font(.system(size: 18))
                            .lineSpacing(5)
                            .foregroundStyle(Color.primaryText)
                            .frame(minHeight: 260)

                        if let editErrorMessage = editErrorMessage {
                            Label(editErrorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(Color.red)
                                .accessibilityIdentifier("memo-edit-error")
                        }
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                if !readableText.isEmpty {
                                    MarkdownMemoTextView(text: readableText) { lineIndex in
                                        let originalLineIndex = SharedAttachmentStore.originalLineIndex(
                                            forVisibleLine: lineIndex,
                                            in: currentMemo.text
                                        ) ?? lineIndex
                                        store.toggleTask(currentMemo, lineIndex: originalLineIndex)
                                        if let updatedMemo = store.memos.first(where: { $0.id == currentMemo.id }) {
                                            text = updatedMemo.text
                                        }
                                    }
                                }

                                AttachmentPreviewList(attachments: attachments)
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(minHeight: 260, alignment: .top)
                    }

                    HStack {
                        Label(DateFormatters.detail.string(from: currentMemo.createdAt), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)

                        Spacer()

                        Button {
                            store.togglePinned(currentMemo)
                        } label: {
                            Image(systemName: currentMemo.isPinned ? "pin.fill" : "pin")
                                .frame(width: 38, height: 38)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(currentMemo.isPinned ? Color.accentGold : Color.secondaryText)
                        .background(Color.subtleSurface)
                        .clipShape(Circle())
                        .accessibilityLabel(currentMemo.isPinned ? "取消置顶" : "置顶")

                        Button {
                            store.toggleArchived(currentMemo)
                            dismiss()
                        } label: {
                            Image(systemName: currentMemo.isArchived ? "tray.and.arrow.up" : "archivebox")
                                .frame(width: 38, height: 38)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.secondaryText)
                        .background(Color.subtleSurface)
                        .clipShape(Circle())
                        .accessibilityLabel(currentMemo.isArchived ? "恢复" : "归档")
                    }

                    if !TagParser.extractTags(from: readableText).isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(TagParser.extractTags(from: readableText), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color.accentGreen)
                                    .padding(.horizontal, 10)
                                    .frame(height: 28)
                                    .background(Color.greenTint)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    if !links(in: readableText).isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("链接")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.secondaryText)

                            ForEach(links(in: readableText), id: \.absoluteString) { url in
                                Button {
                                    openURL(url)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "link")
                                            .font(.caption.weight(.semibold))
                                        Text(LinkExtractor.displayText(for: url))
                                            .lineLimit(1)
                                        Spacer()
                                        Image(systemName: "arrow.up.forward")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .foregroundStyle(Color.accentGreen)
                                    .padding(.horizontal, 12)
                                    .frame(height: 38)
                                    .background(Color.greenTint)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.border, lineWidth: 1)
                )

                Button(role: .destructive) {
                    isShowingDeleteConfirmation = true
                } label: {
                    Label("删除这条", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.red)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Spacer()
            }
            .padding(18)
        }
        .navigationTitle(isEditing ? "编辑" : "详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button {
                        if store.update(currentMemo, text: text) {
                            editErrorMessage = nil
                            isEditing = false
                            isFocused = false
                        } else {
                            editErrorMessage = "保存失败，当前编辑内容已保留。"
                            isFocused = true
                        }
                    } label: {
                        Label("完成", systemImage: "checkmark")
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    Button {
                        text = currentMemo.text
                        editErrorMessage = nil
                        isEditing = true
                        DispatchQueue.main.async {
                            isFocused = true
                        }
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                }
            }
        }
        .confirmationDialog("删除这条闪念？", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                store.delete(memo)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
        .onChange(of: currentMemo.text) { newText in
            guard !isEditing else { return }
            text = newText
        }
    }

    private func links(in text: String) -> [URL] {
        LinkExtractor.urls(in: text)
    }
}
