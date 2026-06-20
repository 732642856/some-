import SwiftUI

struct MemoDetailView: View {
    @EnvironmentObject private var store: MemoStore
    @Environment(\.dismiss) private var dismiss

    let memo: Memo
    @State private var text: String
    @State private var isShowingDeleteConfirmation = false
    @FocusState private var isFocused: Bool

    init(memo: Memo) {
        self.memo = memo
        _text = State(initialValue: memo.text)
    }

    var body: some View {
        let currentMemo = store.memos.first(where: { $0.id == memo.id }) ?? memo

        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    TextEditor(text: $text)
                        .focused($isFocused)
                        .scrollContentBackground(.hidden)
                        .font(.system(size: 18))
                        .lineSpacing(5)
                        .foregroundStyle(Color.primaryText)
                        .frame(minHeight: 260)

                    HStack {
                        Label(DateFormatters.detail.string(from: memo.createdAt), systemImage: "calendar")
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

                    if !TagParser.extractTags(from: text).isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(TagParser.extractTags(from: text), id: \.self) { tag in
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
        .navigationTitle("编辑")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    store.update(currentMemo, text: text)
                    dismiss()
                } label: {
                    Label("完成", systemImage: "checkmark")
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .confirmationDialog("删除这条闪念？", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                store.delete(memo)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
    }
}
