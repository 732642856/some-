import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ContentView: View {
    @EnvironmentObject private var store: MemoStore
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
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
                            MemoListView(memos: store.filteredMemos, emptyTitle: "还没有匹配的闪念")
                        case .assets:
                            AssetLibraryView()
                        case .scrapbook:
                            ScrapbookView()
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
                            MemoListView(memos: store.archivedMemos, emptyTitle: "归档里还没有内容")
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
        case .assets: return "整理素材"
        case .scrapbook: return "排一页手帐"
        case .wardrobe: return "搭出今天"
        case .ai: return "让 AI 帮你排版"
        case .review: return "让旧念头冒泡"
        case .stats: return "看见记录习惯"
        case .archive: return "暂时收进抽屉"
        }
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
    @State private var statusText: String?

    private let templates = ["清新拼贴", "日记手帐", "工作复盘", "美食相册", "穿搭灵感", "网页摘录"]

    private var scrapbookAssets: [MemoAsset] {
        store.assets.filter { $0.kind == .scrapbookPage }
    }

    private var imageAttachmentAssets: [MemoAsset] {
        store.assets.filter { asset in
            guard asset.kind == .attachment,
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
                        AssetNavigationRow(asset: asset, memo: memo)
                    }
                }
            }
        }
    }

    private var canSave: Bool {
        !pageTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    private func splitValues(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet(charactersIn: "、,，/ "))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func selectedImageAttachment() -> SharedAttachment? {
        guard let selectedImageAssetID = selectedImageAssetID,
              let asset = imageAttachmentAssets.first(where: { $0.id == selectedImageAssetID }),
              let uri = asset.uri,
              let relativePath = AttachmentReferenceResolver.relativePath(in: uri) else {
            return nil
        }

        return SharedAttachment(
            id: relativePath,
            filename: asset.title,
            relativePath: relativePath,
            typeIdentifier: asset.typeIdentifier ?? UTType.data.identifier,
            byteCount: asset.byteCount ?? 0
        )
    }
}

private struct WardrobeView: View {
    @EnvironmentObject private var store: MemoStore
    @State private var itemName = ""
    @State private var itemCategory = "上装"
    @State private var itemColors = ""
    @State private var itemSeasons = ""
    @State private var itemScenes = ""
    @State private var selectedPhotoAssetID: UUID?
    @State private var outfitTitle = ""
    @State private var outfitItems = ""
    @State private var outfitScenes = ""
    @State private var statusText: String?

    private let categories = ["上装", "下装", "连衣裙", "外套", "鞋履", "包包", "饰品", "其他"]

    private var wardrobeAssets: [MemoAsset] {
        store.assets.filter { $0.kind == .wardrobeItem }
    }

    private var outfitAssets: [MemoAsset] {
        store.assets.filter { $0.kind == .outfit }
    }

    private var imageAttachmentAssets: [MemoAsset] {
        store.assets.filter { asset in
            guard asset.kind == .attachment,
                  let type = asset.typeIdentifier.flatMap(UTType.init) else {
                return false
            }
            return type.conforms(to: .image)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                StatBadge(title: "单品", value: "\(wardrobeAssets.count)", systemImage: "tshirt")
                StatBadge(title: "穿搭", value: "\(outfitAssets.count)", systemImage: "sparkles")
            }

            wardrobeItemForm
            outfitForm
            wardrobeList
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

    private var wardrobeList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("衣橱素材", systemImage: "square.grid.2x2")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.secondaryText)

            let assets = (wardrobeAssets + outfitAssets)
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
            attachment: selectedPhotoAttachment()
        ) != nil else {
            statusText = "单品保存失败。"
            return
        }

        itemName = ""
        itemColors = ""
        itemSeasons = ""
        itemScenes = ""
        selectedPhotoAssetID = nil
        statusText = "已保存单品"
    }

    private func saveOutfit() {
        guard store.addOutfit(
            title: outfitTitle,
            itemNames: splitValues(outfitItems),
            scenes: splitValues(outfitScenes)
        ) != nil else {
            statusText = "穿搭保存失败。"
            return
        }

        outfitTitle = ""
        outfitItems = ""
        outfitScenes = ""
        statusText = "已保存穿搭"
    }

    private func splitValues(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet(charactersIn: "、,，/ "))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func selectedPhotoAttachment() -> SharedAttachment? {
        guard let selectedPhotoAssetID = selectedPhotoAssetID,
              let asset = imageAttachmentAssets.first(where: { $0.id == selectedPhotoAssetID }),
              let uri = asset.uri,
              let relativePath = AttachmentReferenceResolver.relativePath(in: uri) else {
            return nil
        }

        return SharedAttachment(
            id: relativePath,
            filename: asset.title,
            relativePath: relativePath,
            typeIdentifier: asset.typeIdentifier ?? UTType.data.identifier,
            byteCount: asset.byteCount ?? 0
        )
    }
}

private enum AttachmentReferenceResolver {
    static func relativePath(in uri: String) -> String? {
        guard let components = URLComponents(string: uri),
              components.scheme == SharedAttachmentStore.referenceScheme else {
            return nil
        }

        let encodedPath = components.host?.isEmpty == false
            ? components.host
            : components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return encodedPath?.removingPercentEncoding
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
    let emptyTitle: String

    var body: some View {
        if memos.isEmpty {
            EmptyStateView(title: emptyTitle)
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

    private var emptyTitle: String {
        selectedKind.map { "还没有\($0.title)素材" } ?? "还没有素材"
    }

    private func assetCount(_ kind: MemoAssetKind) -> Int {
        store.assets.filter { $0.kind == kind }.count
    }

    private func memo(for asset: MemoAsset) -> Memo? {
        store.memos.first { $0.id == asset.memoID }
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
        } else {
            NavigationLink(value: memo.id) {
                AssetRowView(asset: asset, memo: memo)
            }
            .buttonStyle(.plain)
        }
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
        guard let uri = asset.uri,
              let components = URLComponents(string: uri),
              components.scheme == SharedAttachmentStore.referenceScheme,
              let encodedPath = attachmentReferencePath(from: components),
              let filename = encodedPath.removingPercentEncoding
        else {
            return nil
        }

        return SharedAttachment(
            id: filename,
            filename: asset.title,
            relativePath: filename,
            typeIdentifier: asset.typeIdentifier ?? UTType.data.identifier,
            byteCount: asset.byteCount ?? 0
        )
    }

    private var summaryText: String? {
        if let summary = asset.summary, !summary.isEmpty {
            return summary
        }

        if let byteCount = asset.byteCount, byteCount > 0 {
            return SharedAttachmentStore.formatByteCount(byteCount)
        }

        return asset.uri
    }

    private func storeTitle(for memo: Memo) -> String {
        MemoReferenceParser.title(for: memo)
    }

    private func attachmentReferencePath(from components: URLComponents) -> String? {
        if let host = components.host, !host.isEmpty {
            return host
        }

        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return path.isEmpty ? nil : path
    }
}
