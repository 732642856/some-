import SwiftUI

struct QuickCaptureView: View {
    @EnvironmentObject private var store: MemoStore
    @AppStorage("some.quickDraft") private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .focused($isFocused)
                    .frame(minHeight: 118)
                    .scrollContentBackground(.hidden)
                    .font(.body)
                    .foregroundStyle(Color.primaryText)

                if text.isEmpty {
                    Text("写下一条闪念... 用 #项目/子类 归类")
                        .foregroundStyle(Color.secondaryText)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                }
            }

            HStack(spacing: 10) {
                Button {
                    text = ""
                    isFocused = false
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.secondaryText)
                .background(Color.subtleSurface)
                .clipShape(Circle())
                .disabled(text.isEmpty)
                .opacity(text.isEmpty ? 0.35 : 1)
                .accessibilityLabel("清空")

                Spacer()

                Text("草稿自动保存")
                    .font(.caption)
                    .foregroundStyle(Color.tertiaryText)

                Button {
                    store.addMemo(text: text)
                    text = ""
                    isFocused = false
                } label: {
                    Label("保存", systemImage: "paperplane.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(minWidth: 84)
                        .frame(height: 38)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white)
                .background(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.disabled : Color.accentGreen)
                .clipShape(Capsule())
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isFocused ? Color.accentGreen.opacity(0.65) : Color.border, lineWidth: 1)
        )
    }
}
