import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: MemoStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var aiSettings = OpenAISettings.shared
    @State private var exportedMarkdown: ExportedMarkdown?
    @State private var exportedJSON: ExportedMarkdown?
    @State private var isShowingImport = false
    @State private var isShowingPrivacyPolicy = false
    @State private var apiKeyDraft = ""
    @State private var aiStatusText: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("数据")
                            .font(.headline)
                            .foregroundStyle(Color.primaryText)

                        Button {
                            exportedMarkdown = ExportedMarkdown(markdown: store.exportMarkdown())
                        } label: {
                            HStack {
                                Label("导出 Markdown", systemImage: "square.and.arrow.up")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                            }
                            .frame(height: 46)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.primaryText)

                        Divider()

                        Button {
                            exportedJSON = ExportedMarkdown(markdown: store.exportJSON())
                        } label: {
                            HStack {
                                Label("导出 JSON 备份", systemImage: "externaldrive")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                            }
                            .frame(height: 46)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.primaryText)

                        Divider()

                        Button {
                            isShowingImport = true
                        } label: {
                            HStack {
                                Label("导入文本或 JSON", systemImage: "square.and.arrow.down")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                            }
                            .frame(height: 46)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.primaryText)
                    }
                    .padding(16)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.border, lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("AI")
                            .font(.headline)
                            .foregroundStyle(Color.primaryText)

                        SecureField(
                            aiSettings.isConfigured ? "已保存，可输入新 Key 覆盖" : "OpenAI API Key",
                            text: $apiKeyDraft
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(Color.appBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.border, lineWidth: 1)
                        )

                        TextField("Responses 模型", text: $aiSettings.responsesModel)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(Color.appBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.border, lineWidth: 1)
                            )

                        TextField("Embedding 模型", text: $aiSettings.embeddingModel)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(Color.appBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.border, lineWidth: 1)
                            )

                        HStack(spacing: 10) {
                            Button {
                                saveAPIKey()
                            } label: {
                                Label("保存 Key", systemImage: "key")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.accentGreen)
                            .disabled(apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button {
                                clearAPIKey()
                            } label: {
                                Label("删除", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!aiSettings.isConfigured)
                        }
                        .font(.footnote.weight(.semibold))

                        Text(aiStatusText ?? (aiSettings.isConfigured ? "Key 已保存在本机 Keychain。" : "未配置 AI。"))
                            .font(.footnote)
                            .foregroundStyle(Color.secondaryText)
                    }
                    .padding(16)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.border, lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("隐私")
                            .font(.headline)
                            .foregroundStyle(Color.primaryText)

                        Button {
                            isShowingPrivacyPolicy = true
                        } label: {
                            HStack {
                                Label("隐私说明", systemImage: "lock.shield")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                            }
                            .frame(height: 46)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.primaryText)

                        Text("内容默认只保存在本机。AI 功能仅在你主动触发时发送所选文本。")
                            .font(.footnote)
                            .foregroundStyle(Color.secondaryText)
                    }
                    .padding(16)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.border, lineWidth: 1)
                    )

                    Spacer()
                }
                .padding(18)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("关闭")
                }
            }
            .sheet(item: $exportedMarkdown) { item in
                ShareSheet(items: [item.markdown])
            }
            .sheet(item: $exportedJSON) { item in
                ShareSheet(items: [item.markdown])
            }
            .sheet(isPresented: $isShowingImport) {
                ImportView()
            }
            .sheet(isPresented: $isShowingPrivacyPolicy) {
                PrivacyPolicyView()
            }
        }
    }

    private func saveAPIKey() {
        do {
            try aiSettings.saveAPIKey(apiKeyDraft)
            apiKeyDraft = ""
            aiStatusText = "OpenAI API Key 已保存。"
        } catch {
            aiStatusText = error.localizedDescription
        }
    }

    private func clearAPIKey() {
        do {
            try aiSettings.clearAPIKey()
            apiKeyDraft = ""
            aiStatusText = "OpenAI API Key 已删除。"
        } catch {
            aiStatusText = error.localizedDescription
        }
    }
}

private struct ImportView: View {
    @EnvironmentObject private var store: MemoStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var resultMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .font(.body)
                    .padding(10)
                    .frame(minHeight: 260)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.border, lineWidth: 1)
                    )

                Text(resultMessage ?? "可粘贴 JSON 备份，或用空行分隔多条普通文本。")
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)

                Spacer()
            }
            .padding(18)
            .background(Color.appBackground)
            .navigationTitle("导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("导入") {
                        importText()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func importText() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if trimmed.first == "[" {
            do {
                let count = try store.importJSON(trimmed)
                resultMessage = "已导入 \(count) 条 JSON 记录。"
                if count > 0 { text = "" }
            } catch {
                resultMessage = "JSON 无法解析：\(error.localizedDescription)"
            }
        } else {
            let count = store.importPlainText(trimmed)
            resultMessage = "已导入 \(count) 条文本记录。"
            if count > 0 { text = "" }
        }
    }
}

private struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("some 不会收集、出售或共享你的个人数据。你写下的内容默认只保存在当前设备。")
                    Text("应用不包含账号系统、广告 SDK、第三方分析 SDK 或追踪功能。使用系统分享表导出内容时，导出行为由你主动触发。")
                    Text("如果你在设置里保存 OpenAI API Key 并使用 AI 功能，应用会把本次操作需要的笔记文本和提示词直接发送给 OpenAI API。未配置或未主动触发 AI 时，不会发送笔记内容。")
                    Text("删除笔记后，内容会从本机应用数据中移除。卸载应用会删除本机保存的数据。")
                }
                .font(.body)
                .lineSpacing(5)
                .foregroundStyle(Color.primaryText)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.appBackground)
            .navigationTitle("隐私说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("关闭")
                }
            }
        }
    }
}

private struct ExportedMarkdown: Identifiable {
    let id = UUID()
    let markdown: String
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
