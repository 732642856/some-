import SwiftUI

struct QuickCaptureView: View {
    @EnvironmentObject private var store: MemoStore
    @AppStorage("some.quickDraft") private var text = ""
    @State private var statusText: String?
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

            if !tagSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tagSuggestions, id: \.self) { tag in
                            Button {
                                applyTag(tag)
                            } label: {
                                Label(tag, systemImage: "number")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .frame(height: 28)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.primaryText)
                            .background(Color.subtleSurface)
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            if let firstURL = detectedURLs.first {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .foregroundStyle(Color.accentGreen)
                    Text(LinkExtractor.displayText(for: firstURL))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(detectedURLs.count > 1 ? "+\(detectedURLs.count - 1)" : "链接")
                        .foregroundStyle(Color.tertiaryText)
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if let statusText {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            }

            HStack(spacing: 10) {
                Button {
                    text = ""
                    statusText = nil
                    isFocused = true
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
                    submit()
                } label: {
                    Label("保存并继续", systemImage: "paperplane.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(minWidth: 112)
                        .frame(height: 38)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white)
                .background(trimmedText.isEmpty ? Color.disabled : Color.accentGreen)
                .clipShape(Capsule())
                .disabled(trimmedText.isEmpty)
            }
        }
        .padding(16)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isFocused ? Color.accentGreen.opacity(0.65) : Color.border, lineWidth: 1)
        )
        .task {
            isFocused = true
        }
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var detectedURLs: [URL] {
        LinkExtractor.urls(in: text)
    }

    private var tagSuggestions: [String] {
        guard let query = currentTagQuery else { return [] }

        return Array(store.activeTags
            .filter { tag in
                query.isEmpty || tag.localizedCaseInsensitiveContains(query)
            }
            .prefix(5))
    }

    private var currentTagQuery: String? {
        guard let tail = text.split(whereSeparator: { $0.isWhitespace }).last,
              tail.hasPrefix("#") else {
            return nil
        }

        return String(tail.dropFirst())
    }

    private func submit() {
        if store.addMemo(text: text) != nil {
            text = ""
            statusText = "已保存"
        } else {
            statusText = "保存失败，草稿已保留。"
        }
        isFocused = true
    }

    private func applyTag(_ tag: String) {
        guard let query = currentTagQuery,
              let range = text.range(of: "#\(query)", options: .backwards) else {
            text += text.isEmpty || text.hasSuffix(" ") ? "#\(tag) " : " #\(tag) "
            isFocused = true
            return
        }

        text.replaceSubrange(range, with: "#\(tag) ")
        isFocused = true
    }
}
