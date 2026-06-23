import SwiftUI
import UIKit

@MainActor
struct AIWorkspaceView: View {
    @EnvironmentObject private var store: MemoStore
    @ObservedObject private var settings = OpenAISettings.shared
    @State private var selectedTool: AITool = .insight
    @State private var query = ""
    @State private var relatedSeed: Memo?
    @State private var semanticResults: [SemanticMemoResult] = []
    @State private var selectedRange: AIInsightRange = .lastSevenDays
    @State private var selectedInsightMode: AIInsightMode = .weeklyReview
    @State private var focusText = ""
    @State private var insightOutput = ""
    @State private var memoryProfile: AIMemoryProfile?
    @State private var isWorking = false
    @State private var statusText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            configurationBanner

            Picker("AI", selection: $selectedTool) {
                ForEach(AITool.allCases) { tool in
                    Label(tool.title, systemImage: tool.systemImage)
                        .tag(tool)
                }
            }
            .pickerStyle(.segmented)

            switch selectedTool {
            case .insight:
                insightPanel
            case .search:
                searchPanel
            case .related:
                relatedPanel
            case .memory:
                memoryPanel
            }
        }
        .onAppear {
            if relatedSeed == nil {
                relatedSeed = store.activeMemos.first
            }
        }
    }

    private var configurationBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: settings.isConfigured ? "checkmark.seal" : "key")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(settings.isConfigured ? Color.accentGreen : Color.secondaryText)

            VStack(alignment: .leading, spacing: 3) {
                Text(settings.isConfigured ? "AI 已就绪" : "先在设置里保存 OpenAI API Key")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primaryText)
                Text(settings.isConfigured ? "\(settings.responsesModel) / \(settings.embeddingModel)" : "Key 只存在本机 Keychain。")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.border, lineWidth: 1)
        )
    }

    private var insightPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 10) {
                Picker("范围", selection: $selectedRange) {
                    ForEach(AIInsightRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                Picker("洞察", selection: $selectedInsightMode) {
                    ForEach(AIInsightMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.systemImage).tag(mode)
                    }
                }
                .pickerStyle(.menu)
            }

            TextField("关注点，可留空", text: $focusText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...3)
                .padding(12)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.border, lineWidth: 1)
                )

            actionButton(title: "生成洞察", systemImage: "sparkles") {
                Task { await generateInsight() }
            }
            .disabled(!settings.isConfigured || isWorking)

            if !insightOutput.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(insightOutput)
                        .font(.body)
                        .lineSpacing(5)
                        .textSelection(.enabled)
                        .foregroundStyle(Color.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 10) {
                        Button {
                            UIPasteboard.general.string = insightOutput
                            statusText = "已复制"
                        } label: {
                            Label("复制", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)

                        ShareLink(item: insightOutput) {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            if store.addMemo(text: "\(insightOutput)\n\n#AI洞察") != nil {
                                statusText = "已保存为新记录"
                            } else {
                                statusText = "保存失败，请稍后再试。"
                            }
                        } label: {
                            Label("保存", systemImage: "tray.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .font(.footnote.weight(.semibold))
                }
                .padding(14)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.border, lineWidth: 1)
                )
            }

            statusView
        }
    }

    private var searchPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("自然语言搜索", text: $query, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...3)
                .padding(12)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.border, lineWidth: 1)
                )

            actionButton(title: "搜索相关记录", systemImage: "magnifyingglass") {
                Task { await runSemanticSearch() }
            }
            .disabled(isWorking || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            resultList
            statusView
        }
    }

    private var memoryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("范围", selection: $selectedRange) {
                ForEach(AIInsightRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)

            actionButton(title: "生成记忆档案", systemImage: "person.text.rectangle") {
                generateMemoryProfile()
            }

            if let memoryProfile {
                VStack(alignment: .leading, spacing: 10) {
                    Text(memoryProfile.markdown)
                        .font(.body)
                        .lineSpacing(5)
                        .textSelection(.enabled)
                        .foregroundStyle(Color.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 10) {
                        Button {
                            UIPasteboard.general.string = memoryProfile.markdown
                            statusText = "已复制"
                        } label: {
                            Label("复制", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)

                        ShareLink(item: memoryProfile.markdown) {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            if store.addMemo(text: "\(memoryProfile.markdown)\n\n#AI记忆档案") != nil {
                                statusText = "已保存为新记录"
                            } else {
                                statusText = "保存失败，请稍后再试。"
                            }
                        } label: {
                            Label("保存", systemImage: "tray.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .font(.footnote.weight(.semibold))
                }
                .padding(14)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.border, lineWidth: 1)
                )
            }

            statusView
        }
    }

    private var relatedPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let relatedSeed {
                VStack(alignment: .leading, spacing: 8) {
                    Text("当前记录")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                    Text(relatedSeed.text)
                        .font(.body)
                        .lineLimit(5)
                        .foregroundStyle(Color.primaryText)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.border, lineWidth: 1)
                )
            } else {
                EmptyStateView(title: "还没有可关联的记录")
            }

            HStack(spacing: 10) {
                actionButton(title: "换一条", systemImage: "shuffle") {
                    relatedSeed = store.activeMemos.randomElement()
                    semanticResults = []
                }
                actionButton(title: "找相关", systemImage: "link") {
                    Task { await findRelatedMemos() }
                }
                .disabled(isWorking || relatedSeed == nil)
            }

            resultList
            statusView
        }
    }

    private var resultList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(semanticResults) { result in
                NavigationLink(value: result.memo.id) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(result.percentage)%")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.accentGreen)
                            Spacer()
                            Text(DateFormatters.row.string(for: result.memo.createdAt) ?? "")
                                .font(.caption)
                                .foregroundStyle(Color.secondaryText)
                        }
                        Text(result.memo.text)
                            .font(.body)
                            .lineLimit(4)
                            .foregroundStyle(Color.primaryText)
                    }
                    .padding(14)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        if isWorking {
            HStack(spacing: 8) {
                ProgressView()
                Text("处理中")
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
            }
        } else if let statusText {
            Text(statusText)
                .font(.footnote)
                .foregroundStyle(Color.secondaryText)
        }
    }

    private func actionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 42)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.accentGreen)
    }

    private func generateInsight() async {
        await runAIAction {
            let memos = selectedRange.filter(store.memos)
            guard !memos.isEmpty else {
                throw AIError.emptyInput
            }

            let prompt = AIInsightComposer.prompt(
                mode: selectedInsightMode,
                memos: memos,
                focus: focusText
            )
            insightOutput = try await settings.makeClient().generateText(prompt: prompt)
            statusText = "已生成 \(selectedInsightMode.title)"
        }
    }

    private func runSemanticSearch() async {
        if settings.isConfigured {
            await runAIAction {
                semanticResults = try await SemanticSearchEngine.search(
                    query: query,
                    memos: store.memos,
                    client: settings.makeClient()
                )
                statusText = semanticResults.isEmpty ? "没有找到相关记录" : "找到 \(semanticResults.count) 条"
            }
        } else {
            semanticResults = SemanticSearchEngine.localSearch(
                query: query,
                memos: store.memos
            )
            statusText = semanticResults.isEmpty ? "本地没有找到相关记录" : "本地找到 \(semanticResults.count) 条"
        }
    }

    private func findRelatedMemos() async {
        guard let relatedSeed else { return }

        if settings.isConfigured {
            await runAIAction {
                semanticResults = try await SemanticSearchEngine.search(
                    query: relatedSeed.text,
                    memos: store.memos,
                    client: settings.makeClient(),
                    excluding: relatedSeed.id
                )
                statusText = semanticResults.isEmpty ? "没有找到相关记录" : "找到 \(semanticResults.count) 条"
            }
        } else {
            semanticResults = SemanticSearchEngine.localSearch(
                query: relatedSeed.text,
                memos: store.memos,
                excluding: relatedSeed.id
            )
            statusText = semanticResults.isEmpty ? "本地没有找到相关记录" : "本地找到 \(semanticResults.count) 条"
        }
    }

    private func generateMemoryProfile() {
        memoryProfile = AIMemoryProfileBuilder.profile(
            from: store.memos,
            range: selectedRange
        )
        statusText = "已生成本地记忆档案"
    }

    private func runAIAction(_ action: @escaping @MainActor () async throws -> Void) async {
        isWorking = true
        statusText = nil

        do {
            try await action()
        } catch {
            statusText = error.localizedDescription
        }

        isWorking = false
    }
}

private enum AITool: String, CaseIterable, Identifiable {
    case insight
    case search
    case related
    case memory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .insight: return "洞察"
        case .search: return "搜索"
        case .related: return "相关"
        case .memory: return "记忆"
        }
    }

    var systemImage: String {
        switch self {
        case .insight: return "brain.head.profile"
        case .search: return "magnifyingglass"
        case .related: return "link"
        case .memory: return "person.text.rectangle"
        }
    }
}
