import Foundation
import UniformTypeIdentifiers

struct Memo: Identifiable, Codable, Equatable {
    var id: UUID
    var text: String
    var createdAt: Date
    var updatedAt: Date
    var tags: [String]
    var isPinned: Bool
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        tags: [String] = [],
        isPinned: Bool = false,
        isArchived: Bool = false
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
        self.isPinned = isPinned
        self.isArchived = isArchived
    }

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case createdAt
        case updatedAt
        case tags
        case isPinned
        case isArchived
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }
}

extension Memo {
    static let sample = [
        Memo(
            text: "把临时想到的句子先放进来，之后再慢慢整理。#写作",
            createdAt: Date().addingTimeInterval(-3600 * 3),
            tags: ["写作"],
            isPinned: true
        ),
        Memo(
            text: "下次产品迭代可以把输入框做得更短路径：打开、输入、完成。#产品 #灵感",
            createdAt: Date().addingTimeInterval(-3600 * 27),
            tags: ["产品", "灵感"]
        ),
        Memo(
            text: "周末整理一下读书摘录，把同一主题的卡片串起来。#阅读",
            createdAt: Date().addingTimeInterval(-3600 * 51),
            tags: ["阅读"]
        )
    ]
}

struct DailyMemoStat: Identifiable, Equatable {
    let date: Date
    let count: Int

    var id: Date { date }
}

struct ScrapbookPageLayout: Codable, Equatable {
    static let marker = "手帐图层JSON："

    var version: Int
    var canvasWidth: Double
    var canvasHeight: Double
    var backgroundColorHex: String
    var layers: [ScrapbookLayer]

    init(
        version: Int = 1,
        canvasWidth: Double = 1080,
        canvasHeight: Double = 1440,
        backgroundColorHex: String = "#FDF8FA",
        layers: [ScrapbookLayer] = []
    ) {
        self.version = version
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.backgroundColorHex = backgroundColorHex
        self.layers = layers
    }

    var summary: String {
        let imageCount = layers.filter { $0.kind == .image }.count
        let textCount = layers.filter { $0.kind == .text }.count
        let stickerCount = layers.filter { $0.kind == .sticker }.count
        let borderCount = layers.filter { $0.kind == .border }.count
        return "\(Int(canvasWidth))x\(Int(canvasHeight)) · 图片\(imageCount) · 文字\(textCount) · 贴纸\(stickerCount) · 边框\(borderCount)"
    }

    func encodedLine() -> String? {
        guard let data = try? JSONEncoder.memoEncoder.encode(self) else {
            return nil
        }

        return "\(Self.marker)\(data.base64EncodedString())"
    }

    static func layout(in text: String) -> ScrapbookPageLayout? {
        guard let encoded = text
            .components(separatedBy: .newlines)
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { $0.hasPrefix(marker) })?
            .dropFirst(marker.count),
              let data = Data(base64Encoded: String(encoded)) else {
            return nil
        }

        return try? JSONDecoder.memoDecoder.decode(ScrapbookPageLayout.self, from: data)
    }

    static func replacingLayout(in text: String, with layout: ScrapbookPageLayout) -> String? {
        guard let encodedLine = layout.encodedLine() else {
            return nil
        }

        var didReplace = false
        var lines = text.components(separatedBy: .newlines).map { line -> String in
            if line.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(marker) {
                didReplace = true
                return encodedLine
            }
            return line
        }

        if !didReplace {
            lines.append(encodedLine)
        }

        return lines.joined(separator: "\n")
    }

    static func defaultLayout(
        title: String,
        template: String,
        materials: [String],
        decorations: [String],
        font: String?,
        border: String?,
        note: String?,
        attachments: [SharedAttachment]
    ) -> ScrapbookPageLayout {
        var layers: [ScrapbookLayer] = []

        if let imageAttachment = attachments.first(where: \.isImage) {
            layers.append(
                ScrapbookLayer(
                    kind: .image,
                    title: imageAttachment.displayName,
                    attachmentPath: imageAttachment.relativePath,
                    x: 540,
                    y: 520,
                    width: 760,
                    height: 620,
                    cornerRadius: 24,
                    shadowOpacity: 0.12
                )
            )
        }

        layers.append(
            ScrapbookLayer(
                kind: .text,
                title: "标题",
                text: title,
                x: 540,
                y: 155,
                width: 760,
                height: 120,
                fontName: font?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? font : "rounded",
                fontSize: 58,
                textColorHex: "#46525A"
            )
        )

        if !materials.isEmpty || note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            let bodyParts = [materials.joined(separator: " · "), note ?? ""]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            layers.append(
                ScrapbookLayer(
                    kind: .text,
                    title: "正文",
                    text: bodyParts.joined(separator: "\n"),
                    x: 540,
                    y: 1025,
                    width: 780,
                    height: 250,
                    fontName: font,
                    fontSize: 34,
                    textColorHex: "#5F6872"
                )
            )
        }

        if let border = border?.trimmingCharacters(in: .whitespacesAndNewlines), !border.isEmpty {
            layers.append(
                ScrapbookLayer(
                    kind: .border,
                    title: border,
                    x: 540,
                    y: 720,
                    width: 990,
                    height: 1320,
                    borderColorHex: "#D7DDEA",
                    borderWidth: 8,
                    cornerRadius: 38
                )
            )
        }

        for (index, decoration) in decorations.prefix(6).enumerated() {
            layers.append(
                ScrapbookLayer(
                    kind: .sticker,
                    title: decoration,
                    text: decoration,
                    x: 170 + Double(index % 3) * 370,
                    y: 1210 + Double(index / 3) * 90,
                    width: 230,
                    height: 64,
                    rotation: index.isMultiple(of: 2) ? -5 : 5,
                    textColorHex: "#597469",
                    backgroundColorHex: "#EEF7F3",
                    cornerRadius: 32
                )
            )
        }

        return ScrapbookPageLayout(
            backgroundColorHex: backgroundColor(forTemplate: template),
            layers: layers
        )
    }

    private static func backgroundColor(forTemplate template: String) -> String {
        switch template {
        case "工作复盘": return "#F6F8FB"
        case "美食相册": return "#FFF7F0"
        case "穿搭灵感": return "#F7F4FB"
        case "网页摘录": return "#F5FAFA"
        default: return "#FDF8FA"
        }
    }
}

struct ScrapbookLayer: Identifiable, Codable, Equatable {
    var id: UUID
    var kind: Kind
    var title: String
    var text: String?
    var attachmentPath: String?
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var rotation: Double
    var scale: Double
    var fontName: String?
    var fontSize: Double?
    var textColorHex: String?
    var backgroundColorHex: String?
    var borderColorHex: String?
    var borderWidth: Double?
    var cornerRadius: Double?
    var shadowOpacity: Double?

    init(
        id: UUID = UUID(),
        kind: Kind,
        title: String,
        text: String? = nil,
        attachmentPath: String? = nil,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        rotation: Double = 0,
        scale: Double = 1,
        fontName: String? = nil,
        fontSize: Double? = nil,
        textColorHex: String? = nil,
        backgroundColorHex: String? = nil,
        borderColorHex: String? = nil,
        borderWidth: Double? = nil,
        cornerRadius: Double? = nil,
        shadowOpacity: Double? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.text = text
        self.attachmentPath = attachmentPath
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.rotation = rotation
        self.scale = scale
        self.fontName = fontName
        self.fontSize = fontSize
        self.textColorHex = textColorHex
        self.backgroundColorHex = backgroundColorHex
        self.borderColorHex = borderColorHex
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.shadowOpacity = shadowOpacity
    }

    enum Kind: String, Codable, Equatable {
        case image
        case text
        case sticker
        case border
        case shape
    }
}

struct ImageEditRecipe: Codable, Equatable {
    static let marker = "图片编辑JSON："

    var version: Int
    var sourceAttachmentPath: String
    var outputAttachmentPath: String?
    var filter: Filter
    var cropPreset: CropPreset
    var cropAdjustment: CropAdjustment
    var border: Border
    var textOverlays: [TextOverlay]
    var stickerOverlays: [StickerOverlay]
    var cleanupPatches: [CleanupPatch]

    init(
        version: Int = 1,
        sourceAttachmentPath: String,
        outputAttachmentPath: String? = nil,
        filter: Filter = .original,
        cropPreset: CropPreset = .original,
        cropAdjustment: CropAdjustment = CropAdjustment(),
        border: Border = Border(),
        textOverlays: [TextOverlay] = [],
        stickerOverlays: [StickerOverlay] = [],
        cleanupPatches: [CleanupPatch] = []
    ) {
        self.version = version
        self.sourceAttachmentPath = sourceAttachmentPath
        self.outputAttachmentPath = outputAttachmentPath
        self.filter = filter
        self.cropPreset = cropPreset
        self.cropAdjustment = cropAdjustment
        self.border = border
        self.textOverlays = textOverlays
        self.stickerOverlays = stickerOverlays
        self.cleanupPatches = cleanupPatches
    }

    var summary: String {
        var parts = [filter.title, cropPreset.title]
        if cropAdjustment.isAdjusted {
            parts.append("自由裁剪")
        }
        if border.width > 0 {
            parts.append("边框")
        }
        if !textOverlays.isEmpty {
            parts.append("文字\(textOverlays.count)")
        }
        if !stickerOverlays.isEmpty {
            parts.append("贴纸\(stickerOverlays.count)")
        }
        if !cleanupPatches.isEmpty {
            parts.append("清理\(cleanupPatches.count)")
        }
        return parts.joined(separator: " · ")
    }

    enum CodingKeys: String, CodingKey {
        case version
        case sourceAttachmentPath
        case outputAttachmentPath
        case filter
        case cropPreset
        case cropAdjustment
        case border
        case textOverlays
        case stickerOverlays
        case cleanupPatches
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        sourceAttachmentPath = try container.decode(String.self, forKey: .sourceAttachmentPath)
        outputAttachmentPath = try container.decodeIfPresent(String.self, forKey: .outputAttachmentPath)
        filter = try container.decodeIfPresent(Filter.self, forKey: .filter) ?? .original
        cropPreset = try container.decodeIfPresent(CropPreset.self, forKey: .cropPreset) ?? .original
        cropAdjustment = try container.decodeIfPresent(CropAdjustment.self, forKey: .cropAdjustment) ?? CropAdjustment()
        border = try container.decodeIfPresent(Border.self, forKey: .border) ?? Border()
        textOverlays = try container.decodeIfPresent([TextOverlay].self, forKey: .textOverlays) ?? []
        stickerOverlays = try container.decodeIfPresent([StickerOverlay].self, forKey: .stickerOverlays) ?? []
        cleanupPatches = try container.decodeIfPresent([CleanupPatch].self, forKey: .cleanupPatches) ?? []
    }

    func encodedLine() -> String? {
        guard let data = try? JSONEncoder.memoEncoder.encode(self) else {
            return nil
        }
        return "\(Self.marker)\(data.base64EncodedString())"
    }

    static func recipe(in text: String) -> ImageEditRecipe? {
        guard let encoded = text
            .components(separatedBy: .newlines)
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { $0.hasPrefix(marker) })?
            .dropFirst(marker.count),
              let data = Data(base64Encoded: String(encoded)) else {
            return nil
        }

        return try? JSONDecoder.memoDecoder.decode(ImageEditRecipe.self, from: data)
    }

    enum Filter: String, Codable, CaseIterable, Equatable {
        case original
        case fresh
        case warm
        case mono
        case vivid

        var title: String {
            switch self {
            case .original: return "原图"
            case .fresh: return "清新"
            case .warm: return "暖调"
            case .mono: return "黑白"
            case .vivid: return "鲜明"
            }
        }
    }

    enum CropPreset: String, Codable, CaseIterable, Equatable {
        case original
        case square
        case portrait4x5
        case story9x16
        case landscape16x9

        var title: String {
            switch self {
            case .original: return "原比例"
            case .square: return "1:1"
            case .portrait4x5: return "4:5"
            case .story9x16: return "9:16"
            case .landscape16x9: return "16:9"
            }
        }

        var aspectRatio: Double? {
            switch self {
            case .original: return nil
            case .square: return 1
            case .portrait4x5: return 4.0 / 5.0
            case .story9x16: return 9.0 / 16.0
            case .landscape16x9: return 16.0 / 9.0
            }
        }
    }

    struct Border: Codable, Equatable {
        var colorHex: String
        var width: Double

        init(colorHex: String = "#FFFFFF", width: Double = 0) {
            self.colorHex = colorHex
            self.width = width
        }
    }

    struct CropAdjustment: Codable, Equatable {
        var x: Double
        var y: Double
        var scale: Double

        init(x: Double = 0.5, y: Double = 0.5, scale: Double = 1) {
            self.x = x
            self.y = y
            self.scale = scale
        }

        var isAdjusted: Bool {
            abs(x - 0.5) > 0.01 || abs(y - 0.5) > 0.01 || abs(scale - 1) > 0.01
        }
    }

    struct TextOverlay: Codable, Equatable, Identifiable {
        var id: UUID
        var text: String
        var x: Double
        var y: Double
        var fontSize: Double
        var colorHex: String

        init(
            id: UUID = UUID(),
            text: String,
            x: Double = 0.5,
            y: Double = 0.82,
            fontSize: Double = 42,
            colorHex: String = "#46525A"
        ) {
            self.id = id
            self.text = text
            self.x = x
            self.y = y
            self.fontSize = fontSize
            self.colorHex = colorHex
        }
    }

    struct StickerOverlay: Codable, Equatable, Identifiable {
        var id: UUID
        var text: String
        var x: Double
        var y: Double
        var fontSize: Double

        init(
            id: UUID = UUID(),
            text: String,
            x: Double = 0.18,
            y: Double = 0.18,
            fontSize: Double = 52
        ) {
            self.id = id
            self.text = text
            self.x = x
            self.y = y
            self.fontSize = fontSize
        }
    }

    struct CleanupPatch: Codable, Equatable, Identifiable {
        var id: UUID
        var x: Double
        var y: Double
        var radius: Double
        var softness: Double

        init(
            id: UUID = UUID(),
            x: Double = 0.5,
            y: Double = 0.5,
            radius: Double = 0.08,
            softness: Double = 0.7
        ) {
            self.id = id
            self.x = x
            self.y = y
            self.radius = radius
            self.softness = softness
        }
    }
}

enum MemoAssetKind: String, Codable, CaseIterable, Hashable {
    case text
    case link
    case attachment
    case task
    case reference
    case webClip
    case imageEdit
    case scrapbookPage
    case workLog
    case wardrobeItem
    case outfit
    case audio
    case video
    case screenshot
}

extension MemoAssetKind {
    var title: String {
        switch self {
        case .text: return "文本"
        case .link: return "链接"
        case .attachment: return "附件"
        case .task: return "任务"
        case .reference: return "引用"
        case .webClip: return "网页"
        case .imageEdit: return "图片"
        case .scrapbookPage: return "手帐"
        case .workLog: return "日志"
        case .wardrobeItem: return "衣橱"
        case .outfit: return "穿搭"
        case .audio: return "音频"
        case .video: return "视频"
        case .screenshot: return "截图"
        }
    }

    var systemImage: String {
        switch self {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .attachment: return "paperclip"
        case .task: return "checklist"
        case .reference: return "arrow.triangle.branch"
        case .webClip: return "doc.text.magnifyingglass"
        case .imageEdit: return "wand.and.stars"
        case .scrapbookPage: return "rectangle.stack"
        case .workLog: return "doc.text"
        case .wardrobeItem: return "tshirt"
        case .outfit: return "sparkles"
        case .audio: return "waveform"
        case .video: return "video"
        case .screenshot: return "camera.viewfinder"
        }
    }
}

struct MemoAsset: Identifiable, Codable, Equatable {
    var id: UUID
    var memoID: UUID
    var kind: MemoAssetKind
    var title: String
    var summary: String?
    var uri: String?
    var typeIdentifier: String?
    var byteCount: Int?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        memoID: UUID,
        kind: MemoAssetKind,
        title: String,
        summary: String? = nil,
        uri: String? = nil,
        typeIdentifier: String? = nil,
        byteCount: Int? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.memoID = memoID
        self.kind = kind
        self.title = title
        self.summary = summary
        self.uri = uri
        self.typeIdentifier = typeIdentifier
        self.byteCount = byteCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension MemoAsset {
    static func assets(in memo: Memo) -> [MemoAsset] {
        var assets: [MemoAsset] = []
        var seenKeys = Set<String>()

        func append(
            kind: MemoAssetKind,
            title: String,
            summary: String? = nil,
            uri: String? = nil,
            typeIdentifier: String? = nil,
            byteCount: Int? = nil,
            stableKey: String
        ) {
            guard seenKeys.insert(stableKey).inserted else { return }
            assets.append(
                MemoAsset(
                    id: stableID(memoID: memo.id, kind: kind, stableKey: stableKey),
                    memoID: memo.id,
                    kind: kind,
                    title: title,
                    summary: summary,
                    uri: uri,
                    typeIdentifier: typeIdentifier,
                    byteCount: byteCount,
                    createdAt: memo.createdAt,
                    updatedAt: memo.updatedAt
                )
            )
        }

        let visibleText = MemoReferenceParser.displayTextWithoutReferences(
            SharedAttachmentStore.displayTextWithoutAttachmentReferences(memo.text)
        )
        let plainText = visibleText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !plainText.isEmpty {
            append(
                kind: .text,
                title: MemoReferenceParser.title(for: memo),
                summary: plainText,
                typeIdentifier: UTType.plainText.identifier,
                stableKey: "text"
            )
        }

        for url in LinkExtractor.urls(in: memo.text) {
            append(
                kind: .link,
                title: LinkExtractor.displayText(for: url),
                uri: url.absoluteString,
                typeIdentifier: UTType.url.identifier,
                stableKey: "link:\(url.absoluteString)"
            )
        }

        for webClip in LinkExtractor.webClips(in: memo.text) {
            let clipSummary = webClip.summary ?? webClip.highlights.joined(separator: " · ")
            append(
                kind: .webClip,
                title: webClip.title.isEmpty ? LinkExtractor.displayText(for: webClip.url) : webClip.title,
                summary: clipSummary.isEmpty ? nil : clipSummary,
                uri: webClip.url.absoluteString,
                typeIdentifier: UTType.url.identifier,
                stableKey: "webclip:\(webClip.url.absoluteString)"
            )
        }

        if let imageText = imageTextAsset(in: visibleText),
           let attachment = SharedAttachmentStore.attachments(in: memo.text).first(where: \.isImage) {
            append(
                kind: .screenshot,
                title: imageText.title,
                summary: imageText.summary,
                uri: "\(SharedAttachmentStore.referenceScheme)://\(SharedAttachmentStore.encodedReferencePath(attachment.relativePath))",
                typeIdentifier: attachment.typeIdentifier,
                byteCount: attachment.byteCount,
                stableKey: "image-text:\(attachment.relativePath)"
            )
        }

        if let wardrobeItem = wardrobeItemAsset(in: visibleText),
           let attachment = SharedAttachmentStore.attachments(in: memo.text).first(where: \.isImage) {
            append(
                kind: .wardrobeItem,
                title: wardrobeItem.title,
                summary: wardrobeItem.summary,
                uri: "\(SharedAttachmentStore.referenceScheme)://\(SharedAttachmentStore.encodedReferencePath(attachment.relativePath))",
                typeIdentifier: attachment.typeIdentifier,
                byteCount: attachment.byteCount,
                stableKey: "wardrobe:\(attachment.relativePath):\(wardrobeItem.title)"
            )
        } else if let wardrobeItem = wardrobeItemAsset(in: visibleText) {
            append(
                kind: .wardrobeItem,
                title: wardrobeItem.title,
                summary: wardrobeItem.summary,
                typeIdentifier: UTType.text.identifier,
                stableKey: "wardrobe:\(wardrobeItem.title)"
            )
        }

        if let outfit = outfitAsset(in: visibleText) {
            append(
                kind: .outfit,
                title: outfit.title,
                summary: outfit.summary,
                typeIdentifier: UTType.text.identifier,
                stableKey: "outfit:\(outfit.title):\(outfit.summary ?? "")"
            )
        }

        if let scrapbookPage = scrapbookPageAsset(in: visibleText),
           let attachment = SharedAttachmentStore.attachments(in: memo.text).first(where: \.isImage) {
            append(
                kind: .scrapbookPage,
                title: scrapbookPage.title,
                summary: scrapbookPage.summary,
                uri: "\(SharedAttachmentStore.referenceScheme)://\(SharedAttachmentStore.encodedReferencePath(attachment.relativePath))",
                typeIdentifier: attachment.typeIdentifier,
                byteCount: attachment.byteCount,
                stableKey: "scrapbook:\(attachment.relativePath):\(scrapbookPage.title)"
            )
        } else if let scrapbookPage = scrapbookPageAsset(in: visibleText) {
            append(
                kind: .scrapbookPage,
                title: scrapbookPage.title,
                summary: scrapbookPage.summary,
                typeIdentifier: UTType.text.identifier,
                stableKey: "scrapbook:\(scrapbookPage.title):\(scrapbookPage.summary ?? "")"
            )
        }

        if let workLog = workLogAsset(in: visibleText) {
            append(
                kind: .workLog,
                title: workLog.title,
                summary: workLog.summary,
                typeIdentifier: UTType.text.identifier,
                stableKey: "worklog:\(workLog.title):\(workLog.summary ?? "")"
            )
        }

        if let imageEdit = imageEditAsset(in: visibleText) {
            let outputAttachment = SharedAttachmentStore.attachments(in: memo.text)
                .first { imageEdit.outputAttachmentPath == $0.relativePath }
            append(
                kind: .imageEdit,
                title: imageEdit.title,
                summary: imageEdit.summary,
                uri: outputAttachment.map { "\(SharedAttachmentStore.referenceScheme)://\(SharedAttachmentStore.encodedReferencePath($0.relativePath))" },
                typeIdentifier: outputAttachment?.typeIdentifier ?? UTType.image.identifier,
                byteCount: outputAttachment?.byteCount,
                stableKey: "image-edit:\(imageEdit.title):\(imageEdit.summary ?? "")"
            )
        }

        for attachment in SharedAttachmentStore.attachments(in: memo.text) {
            append(
                kind: assetKind(for: attachment),
                title: attachment.displayName,
                uri: "\(SharedAttachmentStore.referenceScheme)://\(SharedAttachmentStore.encodedReferencePath(attachment.relativePath))",
                typeIdentifier: attachment.typeIdentifier,
                byteCount: attachment.byteCount,
                stableKey: "attachment:\(attachment.relativePath)"
            )
        }

        for task in MemoTaskParser.taskItems(in: visibleText) {
            append(
                kind: .task,
                title: task.text.isEmpty ? "未命名任务" : task.text,
                summary: task.isCompleted ? "completed" : "open",
                typeIdentifier: UTType.text.identifier,
                stableKey: "task:\(task.lineIndex):\(task.text)"
            )
        }

        for reference in MemoReferenceParser.references(in: memo.text) {
            append(
                kind: .reference,
                title: reference.title ?? reference.memoID.uuidString,
                uri: "\(MemoReferenceParser.scheme)://\(reference.memoID.uuidString)",
                typeIdentifier: UTType.url.identifier,
                stableKey: "reference:\(reference.memoID.uuidString)"
            )
        }

        return assets
    }

    private static func assetKind(for attachment: SharedAttachment) -> MemoAssetKind {
        guard let type = UTType(attachment.typeIdentifier) else {
            return .attachment
        }

        if type.conforms(to: .audio) {
            return .audio
        }

        if type.conforms(to: .movie) {
            return .video
        }

        return .attachment
    }

    private static func imageTextAsset(in text: String) -> (title: String, summary: String)? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let firstLine = lines.first(where: { !$0.isEmpty }) else {
            return nil
        }

        let prefixes = ["图片文字：", "图片文字:", "截图文字：", "截图文字:"]
        guard let prefix = prefixes.first(where: { firstLine.hasPrefix($0) }) else {
            return nil
        }

        let rawTitle = String(firstLine.dropFirst(prefix.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let title = rawTitle.isEmpty ? "图片文字" : rawTitle
        let textStartIndex = lines.firstIndex { line in
            line == "识别文字：" || line == "识别文字:" || line == "OCR：" || line == "OCR:"
        }.map { $0 + 1 } ?? 1
        let recognizedText = lines
            .dropFirst(textStartIndex)
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        guard !recognizedText.isEmpty else {
            return nil
        }

        return (title, limitedSummary(recognizedText))
    }

    private static func wardrobeItemAsset(in text: String) -> (title: String, summary: String?)? {
        structuredAsset(in: text, prefixes: ["衣橱单品：", "衣橱单品:", "单品：", "单品:"])
    }

    private static func outfitAsset(in text: String) -> (title: String, summary: String?)? {
        structuredAsset(in: text, prefixes: ["穿搭组合：", "穿搭组合:", "穿搭：", "穿搭:"])
    }

    private static func scrapbookPageAsset(in text: String) -> (title: String, summary: String?)? {
        guard let asset = structuredAsset(
            in: text,
            prefixes: ["手帐页面：", "手帐页面:", "手帐：", "手帐:", "手帳頁面：", "手帳頁面:", "电子手帐：", "电子手帐:", "拼贴页面：", "拼贴页面:"]
        ) else {
            return nil
        }

        guard let layout = ScrapbookPageLayout.layout(in: text) else {
            return asset
        }

        let summary = [asset.summary, "图层：\(layout.summary)"]
            .compactMap { $0 }
            .joined(separator: " · ")
        return (asset.title, limitedSummary(summary, maxLength: 500))
    }

    private static func workLogAsset(in text: String) -> (title: String, summary: String?)? {
        structuredAsset(in: text, prefixes: ["工作日志：", "工作日志:", "工作记录：", "工作记录:", "日报：", "日报:", "周报：", "周报:", "项目日志：", "项目日志:"])
    }

    private static func imageEditAsset(in text: String) -> (title: String, summary: String?, outputAttachmentPath: String?)? {
        guard let asset = structuredAsset(in: text, prefixes: ["图片编辑：", "图片编辑:", "图片作品：", "图片作品:", "照片编辑：", "照片编辑:"]) else {
            return nil
        }

        guard let recipe = ImageEditRecipe.recipe(in: text) else {
            return (asset.title, asset.summary, nil)
        }

        let summary = [asset.summary, recipe.summary]
            .compactMap { $0 }
            .joined(separator: " · ")
        return (asset.title, limitedSummary(summary, maxLength: 500), recipe.outputAttachmentPath)
    }

    private static func structuredAsset(in text: String, prefixes: [String]) -> (title: String, summary: String?)? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let firstLine = lines.first(where: { !$0.isEmpty }),
              let prefix = prefixes.first(where: { firstLine.hasPrefix($0) }) else {
            return nil
        }

        let rawTitle = String(firstLine.dropFirst(prefix.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let title = rawTitle.isEmpty ? "未命名" : rawTitle
        let summary = lines
            .dropFirst()
            .filter { line in
                !line.isEmpty
                    && !line.hasPrefix(ScrapbookPageLayout.marker)
                    && !line.hasPrefix(ImageEditRecipe.marker)
                    && SharedAttachmentStore.attachments(in: line).isEmpty
            }
            .joined(separator: " · ")
        return (title, summary.isEmpty ? nil : limitedSummary(summary, maxLength: 500))
    }

    private static func limitedSummary(_ text: String, maxLength: Int = 800) -> String {
        guard text.count > maxLength else {
            return text
        }

        let endIndex = text.index(text.startIndex, offsetBy: maxLength)
        return "\(text[..<endIndex])..."
    }

    private static func stableID(memoID: UUID, kind: MemoAssetKind, stableKey: String) -> UUID {
        let seed = "\(memoID.uuidString)|\(kind.rawValue)|\(stableKey)"
        let hash = fnv1a64(seed)
        let prefix = String(memoID.uuidString.prefix(18))
        let suffix = String(format: "%016llX", hash)
        let middle = String(suffix.prefix(4))
        let tail = String(suffix.suffix(12))
        return UUID(uuidString: "\(prefix)-\(middle)-\(tail)") ?? UUID()
    }

    private static func fnv1a64(_ text: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }
}
