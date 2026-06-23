import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ContentView: View {
    @EnvironmentObject private var store: MemoStore
    @State private var isShowingSettings = false
    @State private var isShowingZenCapture = false
    @State private var navigationPath: [UUID] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        HeaderView()
                        HomeModePicker()
                        SearchQuickActionsView()

                        switch store.homeMode {
                        case .timeline:
                            QuickCaptureView()
                            TagFilterView()
                            MemoListView(
                                memos: store.filteredMemos,
                                emptyState: store.timelineEmptyState
                            )
                        case .zen:
                            ZenCaptureView(isModal: false)
                        case .assets:
                            AssetLibraryView()
                        case .scrapbook:
                            ScrapbookView()
                        case .workLog:
                            WorkLogView()
                        case .wardrobe:
                            WardrobeView()
                        case .ai:
                            AIWorkspaceView()
                        case .review:
                            ReviewView()
                        case .stats:
                            StatsDashboardView()
                        case .archive:
                            TagFilterView()
                            MemoListView(
                                memos: store.archivedMemos,
                                emptyState: MemoTimelineEmptyState(
                                    title: "归档里还没有内容",
                                    subtitle: "归档后的记录会在这里集中查看。"
                                )
                            )
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("some")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $store.searchText, prompt: "搜索内容、#标签、has:link 或 created:2026-06")
            .onSubmit(of: .search) {
                store.recordCurrentSearch()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isShowingZenCapture = true
                    } label: {
                        Image(systemName: "leaf")
                    }
                    .accessibilityLabel("禅定记录")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("设置")
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let memo = store.memos.first(where: { $0.id == id }) {
                    MemoDetailView(memo: memo)
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .fullScreenCover(isPresented: $isShowingZenCapture) {
                ZenCaptureView(isModal: true)
            }
            .onChange(of: store.pendingOpenMemoID) { id in
                guard let id = id,
                      store.memos.contains(where: { $0.id == id }) else {
                    return
                }
                navigationPath = [id]
                store.pendingOpenMemoID = nil
            }
        }
    }
}

private struct SearchQuickActionsView: View {
    @EnvironmentObject private var store: MemoStore

    var body: some View {
        if isVisible {
            VStack(alignment: .leading, spacing: 12) {
                if !normalizedQuery.isEmpty {
                    HStack(spacing: 8) {
                        Label("\(store.filteredMemos.count)", systemImage: "magnifyingglass")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.secondaryText)

                        Spacer()

                        Button {
                            store.saveCurrentSearch()
                        } label: {
                            Image(systemName: "bookmark")
                                .frame(width: 34, height: 32)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(store.canSaveCurrentSearch ? Color.accentGreen : Color.disabled)
                        .disabled(!store.canSaveCurrentSearch)
                        .accessibilityLabel("保存搜索")

                        Button {
                            store.clearSearch()
                        } label: {
                            Image(systemName: "xmark")
                                .frame(width: 34, height: 32)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.secondaryText)
                        .accessibilityLabel("清除搜索")
                    }
                }

                if !store.savedSearches.isEmpty {
                    SearchChipRow(
                        title: "已保存",
                        systemImage: "bookmark.fill",
                        searches: store.savedSearches,
                        removable: true
                    )
                }

                if !store.recentSearches.isEmpty {
                    SearchChipRow(
                        title: "最近",
                        systemImage: "clock.arrow.circlepath",
                        searches: store.recentSearches,
                        removable: false
                    )
                }
            }
            .padding(12)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.border, lineWidth: 1)
            )
        }
    }

    private var normalizedQuery: String {
        store.searchText
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private var isVisible: Bool {
        !normalizedQuery.isEmpty || !store.savedSearches.isEmpty || !store.recentSearches.isEmpty
    }
}

private struct SearchChipRow: View {
    @EnvironmentObject private var store: MemoStore

    let title: String
    let systemImage: String
    let searches: [String]
    let removable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondaryText)

            FlowLayout(spacing: 8) {
                ForEach(searches, id: \.self) { query in
                    HStack(spacing: 4) {
                        Button {
                            store.applySearch(query)
                        } label: {
                            Text(query)
                                .font(.footnote.weight(.semibold))
                                .lineLimit(1)
                                .foregroundStyle(Color.primaryText)
                                .padding(.leading, 10)
                                .padding(.trailing, removable ? 2 : 10)
                                .frame(height: 32)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(query)

                        if removable {
                            Button {
                                store.removeSavedSearch(query)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.tertiaryText)
                                    .frame(width: 26, height: 32)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("移除保存搜索")
                        }
                    }
                    .background(Color.subtleSurface)
                    .clipShape(Capsule())
                }
            }
        }
    }
}

private struct HeaderView: View {
    @EnvironmentObject private var store: MemoStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(headerTitle)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primaryText)

            HStack(spacing: 10) {
                StatBadge(title: "记录", value: "\(store.activeCount)", systemImage: "tray.full")
                StatBadge(title: "今日", value: "\(store.todayCount)", systemImage: "sun.max")
                StatBadge(title: "归档", value: "\(store.archivedCount)", systemImage: "archivebox")
            }
        }
        .padding(.top, 6)
    }

    private var headerTitle: String {
        switch store.homeMode {
        case .timeline: return "今天先记下来"
        case .zen: return "只写这一刻"
        case .assets: return "整理素材"
        case .scrapbook: return "排一页手帐"
        case .workLog: return "汇总工作"
        case .wardrobe: return "搭出今天"
        case .ai: return "让 AI 帮你排版"
        case .review: return "让旧念头冒泡"
        case .stats: return "看见记录习惯"
        case .archive: return "暂时收进抽屉"
        }
    }
}

private struct ZenCaptureView: View {
    @EnvironmentObject private var store: MemoStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("some.zenDraft") private var text = ""
    @AppStorage("some.zenWritingPreference") private var writingPreferenceRawValue = ZenWritingPreference.calm.rawValue
    @State private var statusText: String?
    @FocusState private var isFocused: Bool

    let isModal: Bool

    private var stats: ZenDraftStats {
        ZenDraftStats(text: text)
    }

    private var writingPreference: ZenWritingPreference {
        ZenWritingPreference.value(for: writingPreferenceRawValue)
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                if isModal {
                    topBar
                }

                preferencePicker

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .focused($isFocused)
                        .scrollContentBackground(.hidden)
                        .font(.system(size: writingPreference.fontSize, weight: .regular, design: .rounded))
                        .lineSpacing(writingPreference.lineSpacing)
                        .foregroundStyle(Color.primaryText)
                        .padding(.horizontal, 2)

                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(writingPreference.placeholder)
                            .font(.system(size: writingPreference.fontSize, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.secondaryText.opacity(0.72))
                            .padding(.top, 8)
                            .padding(.leading, 7)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomBar
            }
            .padding(.horizontal, 22)
            .padding(.top, isModal ? 18 : 4)
            .padding(.bottom, 18)
        }
        .task {
            isFocused = true
        }
    }

    private var preferencePicker: some View {
        Picker("专注偏好", selection: $writingPreferenceRawValue) {
            ForEach(ZenWritingPreference.allCases) { preference in
                Text(preference.title).tag(preference.rawValue)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("专注记录文字偏好")
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("禅定记录")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primaryText)
                Text("草稿自动保存")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.tertiaryText)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.secondaryText)
            .background(Color.surface)
            .clipShape(Circle())
            .accessibilityLabel("关闭禅定记录")
        }
    }

    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let statusText = statusText {
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
            }

            HStack(spacing: 10) {
                Label(stats.summaryText, systemImage: "leaf")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(1)

                Spacer(minLength: 10)

                Button {
                    text = ""
                    statusText = nil
                    isFocused = true
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.secondaryText)
                .background(Color.surface)
                .clipShape(Circle())
                .disabled(!stats.canSave)
                .opacity(stats.canSave ? 1 : 0.35)
                .accessibilityLabel("清空禅定草稿")

                Button {
                    save()
                } label: {
                    Label("保存", systemImage: "paperplane.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(height: 38)
                        .padding(.horizontal, 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white)
                .background(stats.canSave ? Color.accentGreen : Color.disabled)
                .clipShape(Capsule())
                .disabled(!stats.canSave)
            }
        }
    }

    private func save() {
        guard stats.canSave else { return }

        if store.addMemo(text: text) != nil {
            text = ""
            statusText = "已保存到时间线"
        } else {
            statusText = "保存失败，草稿已保留。"
        }
        isFocused = true
    }
}

private struct ScrapbookView: View {
    @EnvironmentObject private var store: MemoStore
    @State private var pageTitle = ""
    @State private var template = "清新拼贴"
    @State private var materials = ""
    @State private var decorations = ""
    @State private var font = ""
    @State private var border = ""
    @State private var note = ""
    @State private var selectedImageAssetID: UUID?
    @State private var selectedCollageImageIDs: Set<UUID> = []
    @State private var editingMemo: Memo?
    @State private var statusText: String?

    private let templates = ["清新拼贴", "日记手帐", "工作复盘", "美食相册", "穿搭灵感", "网页摘录"]

    private var scrapbookAssets: [MemoAsset] {
        store.assets.filter { $0.kind == .scrapbookPage }
    }

    private var imageAttachmentAssets: [MemoAsset] {
        store.assets.filter { asset in
            guard (asset.kind == .attachment || asset.kind == .imageEdit),
                  let type = asset.typeIdentifier.flatMap(UTType.init) else {
                return false
            }
            return type.conforms(to: .image)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                StatBadge(title: "手帐", value: "\(scrapbookAssets.count)", systemImage: "rectangle.stack")
                StatBadge(title: "图片", value: "\(imageAttachmentAssets.count)", systemImage: "photo")
            }

            pageForm
            scrapbookList
        }
        .sheet(item: $editingMemo) { memo in
            NavigationStack {
                if let currentMemo = store.memos.first(where: { $0.id == memo.id }) {
                    ScrapbookEditorView(memo: currentMemo)
                } else {
                    EmptyStateView(title: "找不到手帐页")
                }
            }
        }
    }

    private var pageForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("新手帐页", systemImage: "plus.circle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.secondaryText)

            TextField("标题，例如 周末小记", text: $pageTitle)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Picker("模板", selection: $template) {
                ForEach(templates, id: \.self) { template in
                    Text(template).tag(template)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.accentGreen)

            TextField("素材：今天的照片、摘录、想法", text: $materials)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            TextField("贴纸/装饰：星星、胶带、花边", text: $decorations)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 8) {
                TextField("字体：圆体、手写", text: $font)
                TextField("边框：白边、细线", text: $border)
            }
            .textFieldStyle(.plain)
            .padding(10)
            .background(Color.subtleSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            TextField("备注：排版想法、尺寸、导出用途", text: $note)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            if !imageAttachmentAssets.isEmpty {
                Picker("图片素材", selection: $selectedImageAssetID) {
                    Text("不绑定图片").tag(Optional<UUID>.none)
                    ForEach(imageAttachmentAssets) { asset in
                        Text(asset.title).tag(Optional(asset.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.accentGreen)

                collageImagePicker
            }

            HStack(spacing: 10) {
                if let statusText = statusText {
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }

                Spacer()

                Button {
                    savePage()
                } label: {
                    Label("保存页面", systemImage: "checkmark.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .frame(height: 34)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white)
                .background(canSave ? Color.accentGreen : Color.disabled)
                .clipShape(Capsule())
                .disabled(!canSave)

                Button {
                    saveCollage()
                } label: {
                    Label("保存拼贴", systemImage: "photo.on.rectangle")
                        .font(.footnote.weight(.semibold))
                        .frame(height: 34)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white)
                .background(canSaveCollage ? Color.accentGold : Color.disabled)
                .clipShape(Capsule())
                .disabled(!canSaveCollage)
            }
        }
        .padding(14)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.border, lineWidth: 1)
        )
    }

    private var collageImagePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("拼贴图片", systemImage: "photo.on.rectangle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
                Spacer()
                Text("\(selectedCollageImageIDs.count)/6")
                    .font(.caption)
                    .foregroundStyle(Color.tertiaryText)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(imageAttachmentAssets.prefix(12)) { asset in
                        Button {
                            toggleCollageImage(asset)
                        } label: {
                            Text(asset.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .foregroundStyle(selectedCollageImageIDs.contains(asset.id) ? Color.white : Color.primaryText)
                                .padding(.horizontal, 10)
                                .frame(height: 30)
                                .background(selectedCollageImageIDs.contains(asset.id) ? Color.accentGold : Color.subtleSurface)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var scrapbookList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("手帐素材", systemImage: "square.grid.2x2")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.secondaryText)

            let assets = scrapbookAssets.sorted {
                $0.createdAt == $1.createdAt ? $0.title < $1.title : $0.createdAt > $1.createdAt
            }

            if assets.isEmpty {
                EmptyStateView(title: "还没有手帐页")
            } else {
                ForEach(assets) { asset in
                    if let memo = store.memos.first(where: { $0.id == asset.memoID }) {
                        Button {
                            editingMemo = memo
                        } label: {
                            ScrapbookPageRow(asset: asset, memo: memo)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var canSave: Bool {
        !pageTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSaveCollage: Bool {
        canSave && selectedCollageImageIDs.count >= 2
    }

    private func savePage() {
        guard store.addScrapbookPage(
            title: pageTitle,
            template: template,
            materials: splitValues(materials),
            decorations: splitValues(decorations),
            font: font,
            border: border,
            note: note,
            attachments: selectedImageAttachment().map { [$0] } ?? []
        ) != nil else {
            statusText = "页面保存失败。"
            return
        }

        pageTitle = ""
        materials = ""
        decorations = ""
        font = ""
        border = ""
        note = ""
        selectedImageAssetID = nil
        statusText = "已保存手帐页"
    }

    private func saveCollage() {
        let attachments = selectedCollageAttachments()
        guard store.addPhotoCollage(
            title: pageTitle,
            attachments: attachments,
            template: "图片拼贴",
            note: note
        ) != nil else {
            statusText = "拼贴保存失败。"
            return
        }

        pageTitle = ""
        materials = ""
        decorations = ""
        font = ""
        border = ""
        note = ""
        selectedImageAssetID = nil
        selectedCollageImageIDs = []
        statusText = "已保存图片拼贴"
    }

    private func splitValues(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet(charactersIn: "、,，/ "))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func selectedImageAttachment() -> SharedAttachment? {
        guard let selectedImageAssetID = selectedImageAssetID,
              let asset = imageAttachmentAssets.first(where: { $0.id == selectedImageAssetID }),
              let attachment = AttachmentReferenceResolver.attachment(from: asset) else {
            return nil
        }

        return attachment
    }

    private func selectedCollageAttachments() -> [SharedAttachment] {
        imageAttachmentAssets
            .filter { selectedCollageImageIDs.contains($0.id) }
            .prefix(6)
            .compactMap(AttachmentReferenceResolver.attachment(from:))
    }

    private func toggleCollageImage(_ asset: MemoAsset) {
        if selectedCollageImageIDs.contains(asset.id) {
            selectedCollageImageIDs.remove(asset.id)
        } else if selectedCollageImageIDs.count < 6 {
            selectedCollageImageIDs.insert(asset.id)
        } else {
            statusText = "最多选择 6 张图片"
        }
    }
}

private struct ScrapbookPageRow: View {
    let asset: MemoAsset
    let memo: Memo

    private var layout: ScrapbookPageLayout {
        ScrapbookPageLayout.layout(in: memo.text) ?? ScrapbookPageLayout()
    }

    var body: some View {
        HStack(spacing: 12) {
            ScrapbookPagePreview(layout: layout)
                .frame(width: 74, height: 98)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(asset.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primaryText)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text("手帐")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentGreen)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(Color.greenTint)
                        .clipShape(Capsule())
                }

                if let summary = asset.summary {
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(Color.secondaryText)
                        .lineLimit(2)
                }

                Text("图层 \(layout.layers.count) · \(Int(layout.canvasWidth))x\(Int(layout.canvasHeight))")
                    .font(.caption)
                    .foregroundStyle(Color.tertiaryText)
            }
        }
        .padding(12)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.border, lineWidth: 1)
        )
    }
}

private struct ScrapbookPagePreview: View {
    let layout: ScrapbookPageLayout

    var body: some View {
        GeometryReader { proxy in
            let scale = min(
                proxy.size.width / max(layout.canvasWidth, 1),
                proxy.size.height / max(layout.canvasHeight, 1)
            )

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color(hex: layout.backgroundColorHex) ?? Color.surface)

                ForEach(layout.layers.prefix(8)) { layer in
                    previewLayer(layer)
                        .frame(width: layer.width * scale, height: layer.height * scale)
                        .position(x: layer.x * scale, y: layer.y * scale)
                        .rotationEffect(.degrees(layer.rotation))
                }
            }
            .frame(width: layout.canvasWidth * scale, height: layout.canvasHeight * scale)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.border, lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func previewLayer(_ layer: ScrapbookLayer) -> some View {
        switch layer.kind {
        case .image:
            if let attachmentPath = layer.attachmentPath,
               let url = SharedAttachmentStore.url(for: attachment(relativePath: attachmentPath)),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: CGFloat(layer.cornerRadius ?? 0), style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.greenTint)
                    .overlay(Image(systemName: "photo").foregroundStyle(Color.accentGreen))
            }
        case .text:
            Text(layer.text ?? layer.title)
                .font(scrapbookFont(for: layer, size: max(6, CGFloat((layer.fontSize ?? 32) / 7))))
                .foregroundStyle(color(hex: layer.textColorHex) ?? Color.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
        case .sticker:
            Text(layer.text ?? layer.title)
                .font(scrapbookFont(for: layer, size: 6))
                .foregroundStyle(color(hex: layer.textColorHex) ?? Color.accentGreen)
                .padding(.horizontal, 4)
                .background(color(hex: layer.backgroundColorHex) ?? Color.greenTint)
                .clipShape(Capsule())
        case .border:
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(color(hex: layer.borderColorHex) ?? Color.border, lineWidth: 1)
        case .shape:
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color(hex: layer.backgroundColorHex) ?? Color.greenTint)
        }
    }

    private func attachment(relativePath: String) -> SharedAttachment {
        SharedAttachment(
            id: relativePath,
            filename: relativePath,
            relativePath: relativePath,
            typeIdentifier: UTType.image.identifier,
            byteCount: 0
        )
    }

    private func color(hex: String?) -> Color? {
        guard let hex = hex else { return nil }
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else {
            return nil
        }

        return Color(
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0
        )
    }

    private func scrapbookFont(for layer: ScrapbookLayer, size: CGFloat) -> Font {
        switch ScrapbookStyleCatalog.normalizedFontKey(layer.fontName) {
        case "serif":
            return .system(size: size, weight: .semibold, design: .serif)
        case "mono":
            return .system(size: size, weight: .semibold, design: .monospaced)
        case "handwritten":
            return .system(size: size, weight: .medium, design: .rounded).italic()
        case "caption":
            return .system(size: size, weight: .medium, design: .rounded)
        default:
            return .system(size: size, weight: .semibold, design: .rounded)
        }
    }
}

private struct WorkLogView: View {
    @EnvironmentObject private var store: MemoStore
    @ObservedObject private var aiSettings = OpenAISettings.shared
    @State private var logTitle = ""
    @State private var scope = "今日"
    @State private var project = ""
    @State private var dateRange = DateFormatters.wardrobeDay.string(from: Date())
    @State private var template = "日报"
    @State private var progress = ""
    @State private var blockers = ""
    @State private var nextSteps = ""
    @State private var note = ""
    @State private var selectedMemoIDs = Set<UUID>()
    @State private var selectedProjectFilter = ""
    @State private var selectedTemplateFilter = ""
    @State private var workLogDateFilter = ""
    @State private var sourceTagFilter = ""
    @State private var sourceKindFilter: MemoContentFilter?
    @State private var sourceDateScope: WorkLogSourceFilter.DateScope = .all
    @State private var sourceSearchText = ""
    @State private var exportedWorkLog: ExportedDocument?
    @State private var statusText: String?
    @State private var isPolishingWorkLog = false

    private let scopes = ["今日", "本周", "项目", "复盘"]
    private let templates = ["日报", "周报", "项目汇报", "复盘"]
    private let sourceKindOptions: [MemoContentFilter] = [.task, .openTask, .completedTask, .link, .webClip, .clipFragment, .attachment, .reference, .referenceNote, .audio, .video, .screenshot, .imageEdit, .scrapbook, .wardrobe, .outfit, .wearLog, .laundryLog, .packingList]

    private var workLogAssets: [MemoAsset] {
        store.assets.filter { $0.kind == .workLog }
    }

    private var workLogRecords: [WorkLogRecord] {
        workLogAssets.compactMap { asset in
            guard let memo = store.memos.first(where: { $0.id == asset.memoID }) else {
                return nil
            }
            return WorkLogRecord(asset: asset, memo: memo)
        }
    }

    private var filteredWorkLogRecords: [WorkLogRecord] {
        let dateNeedle = workLogDateFilter.trimmingCharacters(in: .whitespacesAndNewlines)

        return workLogRecords.filter { record in
            let matchesProject = selectedProjectFilter.isEmpty || record.project == selectedProjectFilter
            let matchesTemplate = selectedTemplateFilter.isEmpty || record.template == selectedTemplateFilter
            let matchesDate = dateNeedle.isEmpty
                || record.dateRange.localizedCaseInsensitiveContains(dateNeedle)
                || record.asset.summary?.localizedCaseInsensitiveContains(dateNeedle) == true
            return matchesProject && matchesTemplate && matchesDate
        }
    }

    private var projectFilterOptions: [String] {
        uniqueValues(workLogRecords.map(\.project))
    }

    private var templateFilterOptions: [String] {
        uniqueValues(workLogRecords.map(\.template))
    }

    private var sourceTagOptions: [String] {
        uniqueValues(store.activeMemos.flatMap(\.tags))
    }

    private var sourceFilter: WorkLogSourceFilter {
        WorkLogSourceFilter(
            tag: sourceTagFilter,
            kind: sourceKindFilter,
            dateScope: sourceDateScope,
            searchText: sourceSearchText
        )
    }

    private var candidateMemos: [Memo] {
        WorkLogSourceFilterEngine.candidates(
            from: store.memos,
            assets: store.assets,
            filter: sourceFilter
        )
    }

    private var selectedMemos: [Memo] {
        candidateMemos.filter { selectedMemoIDs.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    StatBadge(title: "日志", value: "\(workLogAssets.count)", systemImage: "doc.text")
                    StatBadge(title: "项目", value: "\(projectFilterOptions.count)", systemImage: "folder")
                    StatBadge(title: "模板", value: "\(templateFilterOptions.count)", systemImage: "doc.on.doc")
                    StatBadge(title: "已选", value: "\(selectedMemoIDs.count)", systemImage: "checklist")
                }
            }

            logForm
            sourcePicker
            workLogList
        }
        .sheet(item: $exportedWorkLog) { item in
            ShareSheet(items: [item.url])
        }
    }

    private var logForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("新工作日志", systemImage: "plus.circle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.secondaryText)

            TextField("日志标题", text: $logTitle)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Picker("范围", selection: $scope) {
                ForEach(scopes, id: \.self) { scope in
                    Text(scope).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 8) {
                TextField("项目：可选", text: $project)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color.subtleSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                TextField("日期：2026-06-23 或本周", text: $dateRange)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color.subtleSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(templates, id: \.self) { option in
                        Button {
                            applyTemplate(option)
                        } label: {
                            Text(option)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .frame(height: 28)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(template == option ? Color.white : Color.secondaryText)
                        .background(template == option ? Color.accentGreen : Color.subtleSurface)
                        .clipShape(Capsule())
                    }
                }
            }

            TextField("进展：完成了什么，可用顿号分隔", text: $progress)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            TextField("问题：卡点、风险、等待事项", text: $blockers)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            TextField("下一步：后续动作", text: $nextSteps)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            TextField("备注：项目、背景或要汇报的人", text: $note)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 10) {
                if let statusText = statusText {
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }

                Spacer()

                Button {
                    autofillFromSelection()
                } label: {
                    Image(systemName: "wand.and.stars")
                        .font(.footnote.weight(.semibold))
                        .frame(width: 36, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentGreen)
                .background(Color.greenTint)
                .clipShape(Capsule())
                .disabled(selectedMemoIDs.isEmpty)
                .accessibilityLabel("从已选记录提取日志")

                Button {
                    saveLog()
                } label: {
                    Label("保存日志", systemImage: "checkmark.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .frame(height: 34)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white)
                .background(canSave ? Color.accentGreen : Color.disabled)
                .clipShape(Capsule())
                .disabled(!canSave)
            }
        }
        .padding(14)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.border, lineWidth: 1)
        )
    }

    private var sourcePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("勾选记录", systemImage: "checklist")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)

                Spacer()

                Text("\(candidateMemos.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.tertiaryText)

                Button {
                    toggleVisibleCandidates()
                } label: {
                    Image(systemName: "checklist.checked")
                        .frame(width: 34, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentGreen)
                .accessibilityLabel("选择当前筛选记录")
            }

            sourceFilterBar

            if candidateMemos.isEmpty {
                EmptyStateView(title: "还没有可汇总的记录")
            } else {
                VStack(spacing: 8) {
                    ForEach(candidateMemos) { memo in
                        Button {
                            toggle(memo)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: selectedMemoIDs.contains(memo.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedMemoIDs.contains(memo.id) ? Color.accentGreen : Color.tertiaryText)
                                    .frame(width: 24, height: 24)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(MemoReferenceParser.title(for: memo, maxLength: 42))
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(Color.primaryText)
                                        .lineLimit(1)

                                    Text(sourceSummary(for: memo))
                                        .font(.caption)
                                        .foregroundStyle(Color.secondaryText)
                                        .lineLimit(2)
                                }

                                Spacer(minLength: 8)

                                Text(DateFormatters.row.localizedString(for: memo.createdAt, relativeTo: Date()))
                                    .font(.caption)
                                    .foregroundStyle(Color.tertiaryText)
                                    .lineLimit(1)
                            }
                            .padding(10)
                            .background(selectedMemoIDs.contains(memo.id) ? Color.greenTint : Color.subtleSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var sourceFilterBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Picker("标签", selection: $sourceTagFilter) {
                    Text("全部标签").tag("")
                    ForEach(sourceTagOptions, id: \.self) { tag in
                        Text(tag).tag(tag)
                    }
                }
                .pickerStyle(.menu)

                Picker("类型", selection: $sourceKindFilter) {
                    Text("全部类型").tag(Optional<MemoContentFilter>.none)
                    ForEach(sourceKindOptions, id: \.self) { kind in
                        Text(sourceKindTitle(kind)).tag(Optional(kind))
                    }
                }
                .pickerStyle(.menu)
            }

            HStack(spacing: 8) {
                Picker("时间", selection: $sourceDateScope) {
                    ForEach(WorkLogSourceFilter.DateScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    clearSourceFilters()
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .frame(width: 32, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.secondaryText)
                .accessibilityLabel("清除来源筛选")
                .disabled(sourceFilter.isEmpty)
            }

            TextField("筛选可汇总记录", text: $sourceSearchText)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var workLogList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("工作日志", systemImage: "square.grid.2x2")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)

                Spacer()

                Text("\(filteredWorkLogRecords.count)/\(workLogRecords.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.tertiaryText)

                Menu {
                    ForEach(WorkLogExportFormat.allCases, id: \.self) { format in
                        Button {
                            exportFilteredWorkLogs(format: format)
                        } label: {
                            Label(format.title, systemImage: format.systemImage)
                        }
                    }

                    Divider()

                    Button {
                        Task {
                            await exportAIPolishedWorkLog()
                        }
                    } label: {
                        Label("AI 润色汇报", systemImage: "sparkles")
                    }
                    .disabled(!aiSettings.isConfigured || isPolishingWorkLog)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 34, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentGreen)
                .accessibilityLabel("导出当前工作日志")
                .disabled(filteredWorkLogRecords.isEmpty)
            }

            workLogFilterBar

            let records = filteredWorkLogRecords.sorted {
                $0.asset.createdAt == $1.asset.createdAt
                    ? $0.asset.title < $1.asset.title
                    : $0.asset.createdAt > $1.asset.createdAt
            }

            if records.isEmpty {
                EmptyStateView(title: "还没有工作日志")
            } else {
                ForEach(records) { record in
                    AssetNavigationRow(asset: record.asset, memo: record.memo)
                }
            }
        }
    }

    @ViewBuilder
    private var workLogFilterBar: some View {
        if !workLogRecords.isEmpty {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Picker("项目", selection: $selectedProjectFilter) {
                        Text("全部项目").tag("")
                        ForEach(projectFilterOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("模板", selection: $selectedTemplateFilter) {
                        Text("全部模板").tag("")
                        ForEach(templateFilterOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    Button {
                        clearLogFilters()
                    } label: {
                        Image(systemName: "xmark.circle")
                            .frame(width: 32, height: 30)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.secondaryText)
                    .accessibilityLabel("清除工作日志筛选")
                    .disabled(selectedProjectFilter.isEmpty && selectedTemplateFilter.isEmpty && workLogDateFilter.isEmpty)
                }

                TextField("日期或周期筛选", text: $workLogDateFilter)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color.subtleSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var defaultTitle: String {
        let projectName = project.trimmingCharacters(in: .whitespacesAndNewlines)
        return projectName.isEmpty ? "\(scope)工作日志" : "\(projectName) \(scope)工作日志"
    }

    private var canSave: Bool {
        !resolvedTitle.isEmpty
            && (!splitValues(progress).isEmpty || !splitValues(blockers).isEmpty || !splitValues(nextSteps).isEmpty || !selectedMemoIDs.isEmpty)
    }

    private var resolvedTitle: String {
        let title = logTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? defaultTitle : title
    }

    private func toggle(_ memo: Memo) {
        if selectedMemoIDs.contains(memo.id) {
            selectedMemoIDs.remove(memo.id)
        } else {
            selectedMemoIDs.insert(memo.id)
        }
    }

    private func toggleVisibleCandidates() {
        let visibleIDs = candidateMemos.map(\.id)
        let allSelected = !visibleIDs.isEmpty && visibleIDs.allSatisfy { selectedMemoIDs.contains($0) }

        if allSelected {
            visibleIDs.forEach { selectedMemoIDs.remove($0) }
        } else {
            visibleIDs.forEach { selectedMemoIDs.insert($0) }
        }
    }

    private func autofillFromSelection() {
        let progressValues = inferredProgress()
        let nextStepValues = inferredNextSteps()

        if progress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            progress = progressValues.joined(separator: "、")
        }

        if nextSteps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            nextSteps = nextStepValues.joined(separator: "、")
        }

        if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            note = selectedMemos
                .map { MemoReferenceParser.title(for: $0, maxLength: 18) }
                .prefix(6)
                .joined(separator: "、")
        }

        statusText = "已从勾选记录提取"
    }

    private func applyTemplate(_ option: String) {
        template = option
        switch option {
        case "周报":
            scope = "本周"
            if dateRange.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || dateRange == DateFormatters.wardrobeDay.string(from: Date()) {
                dateRange = currentWeekRange()
            }
            fillEmptyFields(
                progress: inferredProgress(),
                blockers: [],
                nextSteps: inferredNextSteps(),
                notePrefix: "本周汇总"
            )
        case "项目汇报":
            scope = "项目"
            fillEmptyFields(
                progress: inferredProgress(),
                blockers: [],
                nextSteps: inferredNextSteps(),
                notePrefix: project.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "项目进展" : project
            )
        case "复盘":
            scope = "复盘"
            fillEmptyFields(
                progress: inferredProgress(),
                blockers: blockers.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? ["待复盘问题"] : splitValues(blockers),
                nextSteps: inferredNextSteps(),
                notePrefix: "复盘"
            )
        default:
            scope = "今日"
            if dateRange.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                dateRange = DateFormatters.wardrobeDay.string(from: Date())
            }
            fillEmptyFields(
                progress: inferredProgress(),
                blockers: [],
                nextSteps: inferredNextSteps(),
                notePrefix: "今日同步"
            )
        }
        statusText = "已套用\(option)模板"
    }

    private func fillEmptyFields(
        progress progressValues: [String],
        blockers blockerValues: [String],
        nextSteps nextStepValues: [String],
        notePrefix: String
    ) {
        if progress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            progress = progressValues.joined(separator: "、")
        }
        if blockers.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blockers = blockerValues.joined(separator: "、")
        }
        if nextSteps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            nextSteps = nextStepValues.joined(separator: "、")
        }
        if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            note = notePrefix
        }
    }

    private func saveLog() {
        guard store.addWorkLog(
            title: resolvedTitle,
            scope: scope,
            project: project,
            dateRange: dateRange,
            template: template,
            progress: splitValues(progress).isEmpty ? inferredProgress() : splitValues(progress),
            blockers: splitValues(blockers),
            nextSteps: splitValues(nextSteps).isEmpty ? inferredNextSteps() : splitValues(nextSteps),
            sourceMemos: selectedMemos,
            note: note
        ) != nil else {
            statusText = "日志保存失败。"
            return
        }

        logTitle = ""
        project = ""
        dateRange = DateFormatters.wardrobeDay.string(from: Date())
        template = "日报"
        scope = "今日"
        progress = ""
        blockers = ""
        nextSteps = ""
        note = ""
        selectedMemoIDs = []
        statusText = "已保存工作日志"
    }

    private func clearLogFilters() {
        selectedProjectFilter = ""
        selectedTemplateFilter = ""
        workLogDateFilter = ""
    }

    private func clearSourceFilters() {
        sourceTagFilter = ""
        sourceKindFilter = nil
        sourceDateScope = .all
        sourceSearchText = ""
    }

    private func inferredProgress() -> [String] {
        let completedTasks = selectedMemos
            .flatMap { MemoTaskParser.taskItems(in: displayText(for: $0)) }
            .filter(\.isCompleted)
            .map(\.text)

        if !completedTasks.isEmpty {
            return uniqueValues(completedTasks)
        }

        return uniqueValues(
            selectedMemos.map { MemoReferenceParser.title(for: $0, maxLength: 24) }
        )
    }

    private func selectedExportPayload() -> (memos: [Memo], assets: [MemoAsset]) {
        let records = filteredWorkLogRecords
        let memoIDs = Set(records.map(\.memo.id))
        let selectedMemos = store.memos.filter { memoIDs.contains($0.id) }
        let assetIDs = Set(records.map(\.asset.id))
        let selectedAssets = store.assets.filter { assetIDs.contains($0.id) }
        return (selectedMemos, selectedAssets)
    }

    private func exportFilteredWorkLogs(format: WorkLogExportFormat = .markdown) {
        let payload = selectedExportPayload()
        let content: String
        switch format {
        case .markdown:
            content = WorkLogExporter.markdown(memos: payload.memos, assets: payload.assets)
        case .csv:
            content = WorkLogExporter.csv(memos: payload.memos, assets: payload.assets)
        case .reportDraft:
            content = WorkLogExporter.reportDraft(memos: payload.memos, assets: payload.assets)
        case .standupDraft:
            content = WorkLogExporter.reportDraft(memos: payload.memos, assets: payload.assets, style: .standup)
        case .projectBriefDraft:
            content = WorkLogExporter.reportDraft(memos: payload.memos, assets: payload.assets, style: .projectBrief)
        case .teamWeeklyDraft:
            content = WorkLogExporter.reportDraft(memos: payload.memos, assets: payload.assets, style: .teamWeekly)
        case .actionReviewDraft:
            content = WorkLogExporter.reportDraft(memos: payload.memos, assets: payload.assets, style: .actionReview)
        }

        do {
            exportedWorkLog = try ExportedDocument(
                prefix: "some-worklog",
                fileExtension: format.fileExtension,
                content: content
            )
            statusText = "已准备导出\(format.title)"
        } catch {
            statusText = "导出失败：\(error.localizedDescription)"
        }
    }

    @MainActor
    private func exportAIPolishedWorkLog() async {
        let payload = selectedExportPayload()
        let draft = WorkLogExporter.reportDraft(memos: payload.memos, assets: payload.assets)
        let prompt = WorkLogPolishComposer.prompt(draft: draft)

        isPolishingWorkLog = true
        statusText = "AI 正在润色汇报..."
        defer { isPolishingWorkLog = false }

        do {
            let polished = try await aiSettings.makeClient().generateText(prompt: prompt)
            exportedWorkLog = try ExportedDocument(
                prefix: "some-worklog-ai",
                fileExtension: "txt",
                content: polished
            )
            statusText = "已准备导出 AI 润色汇报"
        } catch {
            statusText = error.localizedDescription
        }
    }

    private func inferredNextSteps() -> [String] {
        uniqueValues(
            selectedMemos
                .flatMap { MemoTaskParser.taskItems(in: displayText(for: $0)) }
                .filter { !$0.isCompleted }
                .map(\.text)
        )
    }

    private func sourceSummary(for memo: Memo) -> String {
        let text = displayText(for: memo)
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > 80 else {
            return text.isEmpty ? "空记录" : text
        }

        let endIndex = text.index(text.startIndex, offsetBy: 80)
        return "\(text[..<endIndex])..."
    }

    private func displayText(for memo: Memo) -> String {
        MemoReferenceParser.displayTextWithoutReferences(
            SharedAttachmentStore.displayTextWithoutAttachmentReferences(memo.text)
        )
    }

    private func splitValues(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet(charactersIn: "、,，/"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func uniqueValues(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, !seen.contains(normalized) else {
                continue
            }
            seen.insert(normalized)
            result.append(normalized)
        }

        return result
    }

    private func sourceKindTitle(_ kind: MemoContentFilter) -> String {
        switch kind {
        case .link: return "链接"
        case .attachment: return "附件"
        case .task: return "任务"
        case .openTask: return "未完成"
        case .completedTask: return "已完成"
        case .reference: return "引用"
        case .referenceNote: return "引用批注"
        case .backlink: return "被引用"
        case .webClip: return "网页"
        case .clipFragment: return "摘录"
        case .imageEdit: return "图片"
        case .screenshot: return "OCR"
        case .scrapbook: return "手帐"
        case .audio: return "音频"
        case .video: return "视频"
        case .wardrobe: return "衣橱"
        case .outfit: return "穿搭"
        case .wearLog: return "穿着"
        case .laundryLog: return "洗护"
        case .packingList: return "打包"
        case .workLog: return "日志"
        }
    }

    private func currentWeekRange() -> String {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? now
        return "\(DateFormatters.wardrobeDay.string(from: start))~\(DateFormatters.wardrobeDay.string(from: end))"
    }
}

private struct WorkLogRecord: Identifiable {
    let asset: MemoAsset
    let memo: Memo
    let scope: String
    let project: String
    let dateRange: String
    let template: String

    var id: UUID { asset.id }

    init(asset: MemoAsset, memo: Memo) {
        self.asset = asset
        self.memo = memo

        let fields = Self.fields(in: asset.summary)
        self.scope = fields["范围"] ?? ""
        self.project = fields["项目"] ?? ""
        self.dateRange = fields["日期"] ?? ""
        self.template = fields["模板"] ?? ""
    }

    private static func fields(in summary: String?) -> [String: String] {
        guard let summary = summary else {
            return [:]
        }

        var result: [String: String] = [:]
        for part in summary.components(separatedBy: " · ") {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let parsed = field(in: trimmed) else {
                continue
            }
            result[parsed.label] = parsed.value
        }
        return result
    }

    private static func field(in text: String) -> (label: String, value: String)? {
        let separators = ["：", ":"]
        for separator in separators {
            guard let range = text.range(of: separator) else {
                continue
            }

            let label = text[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty, !value.isEmpty else {
                return nil
            }
            return (String(label), String(value))
        }
        return nil
    }
}

private enum WorkLogExportFormat: String, CaseIterable, Hashable {
    case markdown
    case csv
    case reportDraft
    case standupDraft
    case projectBriefDraft
    case teamWeeklyDraft
    case actionReviewDraft

    var title: String {
        switch self {
        case .markdown: return "Markdown"
        case .csv: return "CSV"
        case .reportDraft: return "汇报稿"
        case .standupDraft: return "站会稿"
        case .projectBriefDraft: return "项目简报"
        case .teamWeeklyDraft: return "团队周报"
        case .actionReviewDraft: return "行动复盘"
        }
    }

    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .csv: return "csv"
        case .reportDraft, .standupDraft, .projectBriefDraft, .teamWeeklyDraft, .actionReviewDraft: return "txt"
        }
    }

    var systemImage: String {
        switch self {
        case .markdown: return "doc.text"
        case .csv: return "tablecells"
        case .reportDraft: return "text.quote"
        case .standupDraft: return "person.2.wave.2"
        case .projectBriefDraft: return "folder.badge.gearshape"
        case .teamWeeklyDraft: return "person.3.sequence"
        case .actionReviewDraft: return "checklist"
        }
    }
}

private struct WardrobeView: View {
    @EnvironmentObject private var store: MemoStore
    @EnvironmentObject private var reminders: ReminderManager
    @State private var itemName = ""
    @State private var itemCategory = "上装"
    @State private var itemColors = ""
    @State private var itemSeasons = ""
    @State private var itemScenes = ""
    @State private var itemMaterials = ""
    @State private var itemThickness = ""
    @State private var itemPrice = ""
    @State private var selectedPhotoAssetID: UUID?
    @State private var outfitTitle = ""
    @State private var outfitItems = ""
    @State private var outfitScenes = ""
    @State private var outfitSeasons = ""
    @State private var wearItems = ""
    @State private var wearScenes = ""
    @State private var wearWeather = ""
    @State private var wearDate = Date()
    @State private var wearNote = ""
    @State private var laundryItems = ""
    @State private var laundryStatus = "待清洗"
    @State private var laundryDate = Date()
    @State private var laundryNote = ""
    @State private var packingTitle = ""
    @State private var packingDestination = ""
    @State private var packingDates = ""
    @State private var packingTripDays = ""
    @State private var packingItems = ""
    @State private var packingWeather = ""
    @State private var packingNote = ""
    @State private var isFetchingPackingWeather = false
    @State private var statusText: String?

    private let categories = ["上装", "下装", "连衣裙", "外套", "鞋履", "包包", "饰品", "其他"]
    private let laundryStatuses = ["待清洗", "已清洗", "送洗", "待熨烫", "待修补"]

    private var wardrobeAssets: [MemoAsset] {
        store.assets.filter { $0.kind == .wardrobeItem }
    }

    private var outfitAssets: [MemoAsset] {
        store.assets.filter { $0.kind == .outfit }
    }

    private var wearLogAssets: [MemoAsset] {
        store.assets.filter { $0.kind == .wearLog }
    }

    private var laundryLogAssets: [MemoAsset] {
        store.assets.filter { $0.kind == .laundryLog }
    }

    private var packingListAssets: [MemoAsset] {
        store.assets.filter { $0.kind == .packingList }
    }

    private var imageAttachmentAssets: [MemoAsset] {
        store.assets.filter { asset in
            guard (asset.kind == .attachment || asset.kind == .imageEdit),
                  let type = asset.typeIdentifier.flatMap(UTType.init) else {
                return false
            }
            return type.conforms(to: .image)
        }
    }

    private var insights: WardrobeInsights {
        WardrobeInsightEngine.insights(for: store.assets)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    StatBadge(title: "单品", value: "\(insights.items.count)", systemImage: "tshirt")
                    StatBadge(title: "穿搭", value: "\(insights.outfits.count)", systemImage: "sparkles")
                    StatBadge(title: "穿着", value: "\(insights.wearLogs.count)", systemImage: "calendar.badge.clock")
                    StatBadge(title: "洗护", value: "\(laundryLogAssets.count)", systemImage: "washer")
                    StatBadge(title: "打包", value: "\(packingListAssets.count)", systemImage: "suitcase")
                    StatBadge(title: "提醒", value: "\(insights.careReminders.count)", systemImage: "bell.badge")
                    StatBadge(title: "未搭配", value: "\(insights.unusedItems.count)", systemImage: "arrow.triangle.2.circlepath")
                    StatBadge(title: "场景", value: "\(insights.sceneStats.count)", systemImage: "scope")
                }
            }

            wardrobeInsightPanel
            wardrobeItemForm
            outfitForm
            wearLogForm
            laundryLogForm
            packingListForm
            wardrobeList
        }
    }

    private var wardrobeInsightPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("衣橱洞察", systemImage: "chart.bar.doc.horizontal")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.secondaryText)

            if insights.items.isEmpty {
                EmptyStateView(title: "还没有衣橱统计")
            } else {
                metricStrip(title: "分类", metrics: insights.categoryStats)
                metricStrip(title: "颜色", metrics: insights.colorStats)
                metricStrip(title: "季节", metrics: insights.seasonStats)
                metricStrip(title: "场景", metrics: insights.sceneStats)

                if !insights.unusedItems.isEmpty {
                    namedStrip(
                        title: "未搭配",
                        values: insights.unusedItems.prefix(6).map(\.name)
                    )
                }

                if !insights.frequentItems.isEmpty {
                    namedStrip(
                        title: "常用",
                        values: insights.frequentItems.map { usage in
                            let cost = usage.costPerWear.map { " · \(formatCurrency($0))/次" } ?? ""
                            return "\(usage.item.name) \(usage.count)次\(cost)"
                        }
                    )
                }

                if !insights.wearLogs.isEmpty {
                    namedStrip(
                        title: "最近穿着",
                        values: insights.wearLogs.prefix(6).map { log in
                            "\(DateFormatters.compactDay.string(from: log.wornAt)) \(log.itemNames.joined(separator: "、"))"
                        }
                    )
                }

                if !insights.careReminders.isEmpty {
                    wardrobeCareReminderList
                }

                if !insights.suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("建议")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.secondaryText)

                        ForEach(insights.suggestions) { suggestion in
                            Button {
                                applySuggestion(suggestion)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: suggestion.systemImage)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.accentGreen)
                                        .frame(width: 24, height: 24)
                                        .background(Color.greenTint)
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(suggestion.title)
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(Color.primaryText)
                                        Text(suggestion.detail)
                                            .font(.caption)
                                            .lineLimit(2)
                                            .foregroundStyle(Color.secondaryText)
                                    }

                                    Spacer()

                                    Label("填入", systemImage: "wand.and.stars")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.accentGreen)
                                }
                                .padding(10)
                                .background(Color.subtleSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !insights.packingSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("打包建议")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.secondaryText)

                        ForEach(insights.packingSuggestions) { suggestion in
                            Button {
                                applyPackingSuggestion(suggestion)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "suitcase.rolling")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.accentGold)
                                        .frame(width: 24, height: 24)
                                        .background(Color.appBackground)
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(suggestion.title)
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(Color.primaryText)
                                        Text(suggestion.itemNames.joined(separator: "、"))
                                            .font(.caption)
                                            .lineLimit(2)
                                            .foregroundStyle(Color.secondaryText)
                                    }

                                    Spacer()

                                    Label("填入", systemImage: "list.bullet.clipboard")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.accentGold)
                                }
                                .padding(10)
                                .background(Color.subtleSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.border, lineWidth: 1)
        )
    }

    private var wardrobeCareReminderList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("洗护提醒")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondaryText)

            ForEach(insights.careReminders) { reminder in
                HStack(spacing: 10) {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentGreen)
                        .frame(width: 24, height: 24)
                        .background(Color.greenTint)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(reminder.itemName) · \(reminder.status)")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.primaryText)
                        Text(reminder.detail)
                            .font(.caption)
                            .lineLimit(2)
                            .foregroundStyle(Color.secondaryText)
                    }

                    Spacer(minLength: 8)

                    Button {
                        Task {
                            await reminders.scheduleWardrobeCareReminder(for: reminder)
                        }
                    } label: {
                        Image(systemName: "bell.and.waves.left.and.right")
                            .frame(width: 34, height: 32)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentGreen)
                    .background(Color.subtleSurface)
                    .clipShape(Circle())
                    .accessibilityLabel("安排 \(reminder.itemName) 洗护提醒")
                }
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if let message = reminders.wardrobeStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            }
        }
    }

    private var wardrobeItemForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("新单品", systemImage: "plus.circle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.secondaryText)

            TextField("名称，例如 白色衬衫", text: $itemName)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Picker("分类", selection: $itemCategory) {
                ForEach(categories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                TextField("颜色：白、蓝", text: $itemColors)
                TextField("季节：春、秋", text: $itemSeasons)
            }
            .textFieldStyle(.plain)
            .padding(10)
            .background(Color.subtleSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            TextField("场景：通勤、约会、旅行", text: $itemScenes)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 8) {
                TextField("材质：棉、亚麻", text: $itemMaterials)
                TextField("厚薄：轻薄、保暖", text: $itemThickness)
            }
            .textFieldStyle(.plain)
            .padding(10)
            .background(Color.subtleSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            TextField("价格：399", text: $itemPrice)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            if !imageAttachmentAssets.isEmpty {
                Picker("照片", selection: $selectedPhotoAssetID) {
                    Text("不绑定照片").tag(Optional<UUID>.none)
                    ForEach(imageAttachmentAssets) { asset in
                        Text(asset.title).tag(Optional(asset.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.accentGreen)
            }

            actionRow(
                buttonTitle: "保存单品",
                systemImage: "checkmark.circle.fill",
                disabled: itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                saveWardrobeItem()
            }
        }
        .padding(14)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.border, lineWidth: 1)
        )
    }

    private var outfitForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("新穿搭", systemImage: "sparkles")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.secondaryText)

            TextField("名称，例如 周一通勤", text: $outfitTitle)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            TextField("单品：白色衬衫、牛仔裤、黑色包", text: $outfitItems)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            TextField("场景：通勤、聚餐", text: $outfitScenes)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            TextField("季节：春、秋", text: $outfitSeasons)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            actionRow(
                buttonTitle: "保存穿搭",
                systemImage: "checkmark.circle.fill",
                disabled: outfitTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || outfitItems.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                saveOutfit()
            }
        }
        .padding(14)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.border, lineWidth: 1)
        )
    }

    private var wearLogForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("穿着记录", systemImage: "calendar.badge.clock")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.secondaryText)

            DatePicker("日期", selection: $wearDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .tint(Color.accentGreen)

            TextField("单品：白色衬衫、牛仔裤、黑色包", text: $wearItems)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 8) {
                TextField("场景：通勤、聚餐", text: $wearScenes)
                TextField("天气：晴", text: $wearWeather)
            }
            .textFieldStyle(.plain)
            .padding(10)
            .background(Color.subtleSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            TextField("备注：舒适、偏冷、需要换鞋", text: $wearNote)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            actionRow(
                buttonTitle: "保存穿着",
                systemImage: "checkmark.circle.fill",
                disabled: wearItems.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                saveWearLog()
            }
        }
        .padding(14)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.border, lineWidth: 1)
        )
    }

    private var laundryLogForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("洗护状态", systemImage: "washer")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.secondaryText)

            DatePicker("日期", selection: $laundryDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .tint(Color.accentGreen)

            TextField("单品：白色衬衫、羊毛外套", text: $laundryItems)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Picker("状态", selection: $laundryStatus) {
                ForEach(laundryStatuses, id: \.self) { status in
                    Text(status).tag(status)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.accentGreen)

            TextField("备注：冷水洗、不可烘干", text: $laundryNote)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            actionRow(
                buttonTitle: "保存洗护",
                systemImage: "checkmark.circle.fill",
                disabled: laundryItems.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || laundryStatus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                saveLaundryLog()
            }
        }
        .padding(14)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.border, lineWidth: 1)
        )
    }

    private var packingListForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("旅行打包", systemImage: "suitcase")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.secondaryText)

            TextField("名称，例如 杭州周末", text: $packingTitle)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 8) {
                TextField("目的地", text: $packingDestination)
                TextField("日期：6/24-6/26", text: $packingDates)
            }
            .textFieldStyle(.plain)
            .padding(10)
            .background(Color.subtleSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            TextField("单品：白衬衫、牛仔裤、风衣", text: $packingItems)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            TextField("天数：3", text: $packingTripDays)
                .textFieldStyle(.plain)
                .keyboardType(.numberPad)
                .padding(10)
                .background(Color.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 8) {
                TextField("天气：多云 18-25C", text: $packingWeather)
                TextField("备注：带伞", text: $packingNote)
            }
            .textFieldStyle(.plain)
            .padding(10)
            .background(Color.subtleSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 8) {
                Spacer()
                Button {
                    fetchPackingWeather()
                } label: {
                    Label(isFetchingPackingWeather ? "获取中" : "获取天气", systemImage: "cloud.sun")
                        .font(.footnote.weight(.semibold))
                        .frame(height: 32)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentGreen)
                .background(Color.greenTint)
                .clipShape(Capsule())
                .disabled(
                    isFetchingPackingWeather
                    || packingDestination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }

            actionRow(
                buttonTitle: "保存打包",
                systemImage: "checkmark.circle.fill",
                disabled: packingTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || packingItems.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                savePackingList()
            }
        }
        .padding(14)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.border, lineWidth: 1)
        )
    }

    private var wardrobeList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("衣橱素材", systemImage: "square.grid.2x2")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.secondaryText)

            let assets = (wardrobeAssets + outfitAssets + wearLogAssets + laundryLogAssets + packingListAssets)
                .sorted { $0.createdAt == $1.createdAt ? $0.title < $1.title : $0.createdAt > $1.createdAt }

            if assets.isEmpty {
                EmptyStateView(title: "还没有衣橱单品")
            } else {
                ForEach(assets) { asset in
                    if let memo = store.memos.first(where: { $0.id == asset.memoID }) {
                        AssetNavigationRow(asset: asset, memo: memo)
                    }
                }
            }
        }
    }

    private func actionRow(
        buttonTitle: String,
        systemImage: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            if let statusText = statusText {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            }

            Spacer()

            Button(action: action) {
                Label(buttonTitle, systemImage: systemImage)
                    .font(.footnote.weight(.semibold))
                    .frame(height: 34)
                    .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.white)
            .background(disabled ? Color.disabled : Color.accentGreen)
            .clipShape(Capsule())
            .disabled(disabled)
        }
    }

    private func saveWardrobeItem() {
        guard store.addWardrobeItem(
            name: itemName,
            category: itemCategory,
            colors: splitValues(itemColors),
            seasons: splitValues(itemSeasons),
            scenes: splitValues(itemScenes),
            materials: splitValues(itemMaterials),
            thickness: itemThickness,
            purchasePrice: itemPrice,
            attachment: selectedPhotoAttachment()
        ) != nil else {
            statusText = "单品保存失败。"
            return
        }

        itemName = ""
        itemColors = ""
        itemSeasons = ""
        itemScenes = ""
        itemMaterials = ""
        itemThickness = ""
        itemPrice = ""
        selectedPhotoAssetID = nil
        statusText = "已保存单品"
    }

    private func saveOutfit() {
        guard store.addOutfit(
            title: outfitTitle,
            itemNames: splitValues(outfitItems),
            scenes: splitValues(outfitScenes),
            seasons: splitValues(outfitSeasons)
        ) != nil else {
            statusText = "穿搭保存失败。"
            return
        }

        outfitTitle = ""
        outfitItems = ""
        outfitScenes = ""
        outfitSeasons = ""
        statusText = "已保存穿搭"
    }

    private func saveWearLog() {
        guard store.addWearLog(
            itemNames: splitValues(wearItems),
            date: wearDate,
            scenes: splitValues(wearScenes),
            weather: wearWeather,
            note: wearNote
        ) != nil else {
            statusText = "穿着记录保存失败。"
            return
        }

        wearItems = ""
        wearScenes = ""
        wearWeather = ""
        wearNote = ""
        wearDate = Date()
        statusText = "已保存穿着记录"
    }

    private func saveLaundryLog() {
        guard store.addLaundryLog(
            itemNames: splitValues(laundryItems),
            status: laundryStatus,
            date: laundryDate,
            note: laundryNote
        ) != nil else {
            statusText = "洗护记录保存失败。"
            return
        }

        laundryItems = ""
        laundryStatus = laundryStatuses.first ?? "待清洗"
        laundryNote = ""
        laundryDate = Date()
        statusText = "已保存洗护记录"
    }

    private func savePackingList() {
        guard store.addPackingList(
            title: packingTitle,
            destination: packingDestination,
            dateRange: packingDates,
            tripDays: parsedTripDays,
            itemNames: splitValues(packingItems),
            weather: packingWeather,
            note: packingNote
        ) != nil else {
            statusText = "打包清单保存失败。"
            return
        }

        packingTitle = ""
        packingDestination = ""
        packingDates = ""
        packingTripDays = ""
        packingItems = ""
        packingWeather = ""
        packingNote = ""
        statusText = "已保存打包清单"
    }

    private func applySuggestion(_ suggestion: WardrobeOutfitSuggestion) {
        outfitTitle = suggestion.title
        outfitItems = suggestion.itemNames.joined(separator: "、")
        outfitScenes = suggestion.scenes.joined(separator: "、")
        outfitSeasons = suggestion.seasons.joined(separator: "、")
        statusText = "已填入穿搭草稿"
    }

    private func applyPackingSuggestion(_ suggestion: WardrobePackingSuggestion) {
        packingTitle = suggestion.title
        packingDestination = suggestion.destination ?? packingDestination
        packingItems = suggestion.itemNames.joined(separator: "、")
        packingWeather = suggestion.weather ?? packingWeather
        packingNote = suggestion.note ?? packingNote
        statusText = "已填入打包草稿"
    }

    private func fetchPackingWeather() {
        let destination = packingDestination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !destination.isEmpty else {
            statusText = "请先填写目的地。"
            return
        }

        isFetchingPackingWeather = true
        statusText = "正在获取天气"
        OpenMeteoWeatherService().fetchWeather(for: destination) { result in
            DispatchQueue.main.async {
                isFetchingPackingWeather = false
                switch result {
                case .success(let summary):
                    packingWeather = summary.weatherText
                    packingNote = mergePackingNote(existing: packingNote, weatherNote: summary.noteText)
                    statusText = "已填入 \(summary.location.displayName) 天气"
                case .failure(let error):
                    statusText = (error as? LocalizedError)?.errorDescription ?? "天气获取失败。"
                }
            }
        }
    }

    private func mergePackingNote(existing: String, weatherNote: String) -> String {
        let trimmedExisting = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingLines = trimmedExisting
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.contains("天气来自 Open-Meteo") }

        guard !existingLines.isEmpty else {
            return weatherNote
        }
        return "\(existingLines.joined(separator: "\n"))\n\(weatherNote)"
    }

    private func metricStrip(title: String, metrics: [WardrobeInsightMetric]) -> some View {
        namedStrip(
            title: title,
            values: metrics.prefix(6).map { "\($0.label) \($0.count)" }
        )
    }

    private func formatCurrency(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if rounded.rounded() == rounded {
            return "¥\(Int(rounded))"
        }

        return String(format: "¥%.2f", rounded)
    }

    private func namedStrip<T: Collection>(title: String, values: T) -> some View where T.Element == String {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondaryText)

            if values.isEmpty {
                Text("暂无")
                    .font(.caption)
                    .foregroundStyle(Color.tertiaryText)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(Array(values), id: \.self) { value in
                            Text(value)
                                .font(.caption)
                                .foregroundStyle(Color.primaryText)
                                .padding(.horizontal, 9)
                                .frame(height: 28)
                                .background(Color.subtleSurface)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private func splitValues(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet(charactersIn: "、,，/ "))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var parsedTripDays: Int? {
        let digits = packingTripDays.filter { $0.isNumber }
        guard let value = Int(digits), value > 0 else {
            return nil
        }

        return value
    }

    private func selectedPhotoAttachment() -> SharedAttachment? {
        guard let selectedPhotoAssetID = selectedPhotoAssetID,
              let asset = imageAttachmentAssets.first(where: { $0.id == selectedPhotoAssetID }),
              let attachment = AttachmentReferenceResolver.attachment(from: asset) else {
            return nil
        }

        return attachment
    }
}

private struct StatBadge: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentGreen)
            Text(title)
                .foregroundStyle(Color.secondaryText)
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(Color.primaryText)
        }
        .font(.footnote)
        .padding(.horizontal, 11)
        .frame(height: 34)
        .background(Color.surface)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.border, lineWidth: 1)
        )
    }
}

private struct HomeModePicker: View {
    @EnvironmentObject private var store: MemoStore

    var body: some View {
        HStack(spacing: 6) {
            ForEach(MemoHomeMode.allCases) { mode in
                Button {
                    store.homeMode = mode
                    if mode == .review, store.reviewMemo == nil {
                        store.pickRandomReviewMemo()
                    }
                } label: {
                    Label(mode.title, systemImage: mode.systemImage)
                        .labelStyle(.iconOnly)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(store.homeMode == mode ? Color.accentGreen : Color.clear)
                        .foregroundStyle(store.homeMode == mode ? Color.white : Color.secondaryText)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mode.title)
            }
        }
        .padding(4)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.border, lineWidth: 1)
        )
    }
}

private struct MemoListView: View {
    let memos: [Memo]
    let emptyState: MemoTimelineEmptyState

    var body: some View {
        if memos.isEmpty {
            EmptyStateView(title: emptyState.title, subtitle: emptyState.subtitle)
                .padding(.top, 12)
        } else {
            ForEach(memos) { memo in
                NavigationLink(value: memo.id) {
                    MemoRowView(memo: memo)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct AssetLibraryView: View {
    @EnvironmentObject private var store: MemoStore
    @State private var selectedKind: MemoAssetKind?
    @State private var warmedMediaSignature = ""

    private var filteredAssets: [MemoAsset] {
        guard let selectedKind = selectedKind else {
            return store.assets
        }

        return store.assets.filter { $0.kind == selectedKind }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            assetSummary
            assetFilter

            if filteredAssets.isEmpty {
                EmptyStateView(title: emptyTitle)
                    .padding(.top, 12)
            } else {
                ForEach(filteredAssets) { asset in
                    if let memo = memo(for: asset) {
                        AssetNavigationRow(asset: asset, memo: memo)
                    } else {
                        AssetRowView(asset: asset, memo: nil)
                    }
                }
            }
        }
        .onAppear(perform: maintainMediaCaches)
        .onChange(of: mediaAssetSignature) { _ in
            maintainMediaCaches()
        }
    }

    private var assetSummary: some View {
        HStack(spacing: 10) {
            StatBadge(title: "素材", value: "\(store.assets.count)", systemImage: "square.grid.2x2")
            StatBadge(title: "附件", value: "\(assetCount(.attachment))", systemImage: "paperclip")
            StatBadge(title: "链接", value: "\(assetCount(.link))", systemImage: "link")
        }
    }

    private var assetFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                assetFilterButton(title: "全部", systemImage: "tray.full", isSelected: selectedKind == nil) {
                    selectedKind = nil
                }

                ForEach(visibleKinds, id: \.self) { kind in
                    assetFilterButton(
                        title: kind.title,
                        systemImage: kind.systemImage,
                        isSelected: selectedKind == kind
                    ) {
                        selectedKind = kind
                    }
                }
            }
        }
    }

    private var visibleKinds: [MemoAssetKind] {
        MemoAssetKind.allCases.filter { assetCount($0) > 0 }
    }

    private var mediaAssetSignature: String {
        MediaMetadataExtractor
            .sourceAttachments(in: store.assets)
            .map { "\($0.relativePath):\($0.typeIdentifier):\($0.byteCount)" }
            .joined(separator: "|")
    }

    private var emptyTitle: String {
        selectedKind.map { "还没有\($0.title)素材" } ?? "还没有素材"
    }

    private func assetCount(_ kind: MemoAssetKind) -> Int {
        store.assets.filter { $0.kind == kind }.count
    }

    private func memo(for asset: MemoAsset) -> Memo? {
        store.memos.first { $0.id == asset.memoID }
    }

    private func maintainMediaCaches() {
        let signature = mediaAssetSignature
        guard signature != warmedMediaSignature else {
            return
        }

        warmedMediaSignature = signature
        let attachments = MediaMetadataExtractor.sourceAttachments(in: store.assets)
        let urls = VideoThumbnailGenerator.sourceURLs(in: store.assets)
        DispatchQueue.global(qos: .utility).async {
            _ = MediaMetadataExtractor.preheatSummaries(for: attachments)
            _ = VideoThumbnailGenerator.preheatCache(for: urls)
            _ = VideoThumbnailGenerator.pruneCache(keeping: urls)
        }
    }

    private func assetFilterButton(
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 11)
                .frame(height: 34)
                .foregroundStyle(isSelected ? Color.white : Color.secondaryText)
                .background(isSelected ? Color.accentGreen : Color.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct AssetNavigationRow: View {
    @Environment(\.openURL) private var openURL
    @State private var editingImageAttachment: SharedAttachment?

    let asset: MemoAsset
    let memo: Memo

    var body: some View {
        if asset.kind == .webClip,
           let uri = asset.uri,
           let url = URL(string: uri) {
            Button {
                openURL(url)
            } label: {
                AssetRowView(asset: asset, memo: memo)
            }
            .buttonStyle(.plain)
        } else if let attachment = imageAttachment {
            Button {
                editingImageAttachment = attachment
            } label: {
                AssetRowView(asset: asset, memo: memo)
            }
            .buttonStyle(.plain)
            .sheet(item: $editingImageAttachment) { attachment in
                NavigationStack {
                    ImageEditorView(attachment: attachment)
                }
            }
        } else {
            NavigationLink(value: memo.id) {
                AssetRowView(asset: asset, memo: memo)
            }
            .buttonStyle(.plain)
        }
    }

    private var imageAttachment: SharedAttachment? {
        guard asset.kind == .attachment || asset.kind == .screenshot || asset.kind == .imageEdit,
              let typeIdentifier = asset.typeIdentifier,
              UTType(typeIdentifier)?.conforms(to: .image) == true else {
            return nil
        }

        return AttachmentReferenceResolver.attachment(from: asset)
    }
}

private struct AssetRowView: View {
    let asset: MemoAsset
    let memo: Memo?

    var body: some View {
        HStack(spacing: 12) {
            preview

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(asset.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primaryText)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(asset.kind.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentGreen)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(Color.greenTint)
                        .clipShape(Capsule())
                }

                if let summary = summaryText {
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(Color.secondaryText)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption2.weight(.semibold))
                    Text(DateFormatters.row.localizedString(for: asset.createdAt, relativeTo: Date()))
                    if let memo = memo {
                        Text("·")
                        Text(storeTitle(for: memo))
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(Color.tertiaryText)
            }
        }
        .padding(12)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var preview: some View {
        if let attachment = attachment,
           attachment.isImage,
           let url = SharedAttachmentStore.url(for: attachment),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else if let attachment = attachment,
                  attachment.isVideo,
                  let url = SharedAttachmentStore.url(for: attachment) {
            VideoThumbnailPreview(
                url: url,
                size: 54,
                cornerRadius: 8,
                fallbackSystemImage: iconName
            )
        } else {
            Image(systemName: iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.accentGreen)
                .frame(width: 54, height: 54)
                .background(Color.greenTint)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var iconName: String {
        if let type = asset.typeIdentifier.flatMap(UTType.init) {
            if type.conforms(to: .image) {
                return "photo"
            }

            if type.conforms(to: .movie) {
                return "video"
            }

            if type.conforms(to: .audio) {
                return "waveform"
            }
        }

        return asset.kind.systemImage
    }

    private var attachment: SharedAttachment? {
        AttachmentReferenceResolver.attachment(from: asset)
    }

    private var summaryText: String? {
        if let summary = asset.summary, !summary.isEmpty {
            return summary
        }

        if let attachment = attachment,
           let mediaSummary = MediaMetadataExtractor.summary(for: attachment) {
            return mediaSummary
        }

        if let byteCount = asset.byteCount, byteCount > 0 {
            return SharedAttachmentStore.formatByteCount(byteCount)
        }

        return asset.uri
    }

    private func storeTitle(for memo: Memo) -> String {
        MemoReferenceParser.title(for: memo)
    }

}
