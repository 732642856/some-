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

        let fontPreset = ScrapbookStyleCatalog.fontPreset(matching: font)
        layers.append(
            ScrapbookLayer(
                kind: .text,
                title: "标题",
                text: title,
                x: 540,
                y: 155,
                width: 760,
                height: 120,
                fontName: fontPreset.fontName,
                fontSize: 58,
                textColorHex: fontPreset.textColorHex
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
                    fontName: fontPreset.fontName,
                    fontSize: 34,
                    textColorHex: "#5F6872"
                )
            )
        }

        if let border = border?.trimmingCharacters(in: .whitespacesAndNewlines), !border.isEmpty {
            let borderPreset = ScrapbookStyleCatalog.borderPreset(matching: border)
            layers.append(
                ScrapbookLayer(
                    kind: .border,
                    title: borderPreset.title,
                    x: 540,
                    y: 720,
                    width: 990,
                    height: 1320,
                    borderColorHex: borderPreset.borderColorHex,
                    borderWidth: borderPreset.borderWidth,
                    cornerRadius: borderPreset.cornerRadius,
                    shadowOpacity: borderPreset.shadowOpacity
                )
            )
        }

        for (index, decoration) in decorations.prefix(6).enumerated() {
            let stickerPreset = ScrapbookStyleCatalog.stickerPreset(matching: decoration)
            layers.append(
                ScrapbookLayer(
                    kind: .sticker,
                    title: decoration,
                    text: stickerPreset?.text ?? decoration,
                    x: 170 + Double(index % 3) * 370,
                    y: 1210 + Double(index / 3) * 90,
                    width: 230,
                    height: 64,
                    rotation: stickerPreset?.rotation ?? (index.isMultiple(of: 2) ? -5 : 5),
                    fontName: stickerPreset?.fontName ?? "rounded",
                    fontSize: stickerPreset?.fontSize ?? 30,
                    textColorHex: stickerPreset?.textColorHex ?? "#597469",
                    backgroundColorHex: stickerPreset?.backgroundColorHex ?? "#EEF7F3",
                    cornerRadius: stickerPreset?.cornerRadius ?? 32
                )
            )
        }

        return ScrapbookPageLayout(
            backgroundColorHex: backgroundColor(forTemplate: template),
            layers: layers
        )
    }

    static func photoCollageLayout(
        title: String,
        attachments: [SharedAttachment],
        template: String,
        note: String?
    ) -> ScrapbookPageLayout {
        let imageAttachments = attachments.filter(\.isImage)
        var layers: [ScrapbookLayer] = [
            ScrapbookLayer(
                kind: .text,
                title: "标题",
                text: title,
                x: 540,
                y: 116,
                width: 760,
                height: 92,
                fontName: "rounded",
                fontSize: 48,
                textColorHex: "#46525A"
            ),
            ScrapbookLayer(
                kind: .sticker,
                title: "拼贴",
                text: template,
                x: 150,
                y: 118,
                width: 220,
                height: 56,
                rotation: -4,
                fontName: "caption",
                fontSize: 26,
                textColorHex: "#8B6F83",
                backgroundColorHex: "#F2EEF8",
                cornerRadius: 28
            )
        ]

        for (index, attachment) in imageAttachments.prefix(6).enumerated() {
            let rect = collageRect(index: index, count: min(imageAttachments.count, 6))
            layers.append(
                ScrapbookLayer(
                    kind: .image,
                    title: attachment.displayName,
                    attachmentPath: attachment.relativePath,
                    x: rect.midX,
                    y: rect.midY,
                    width: rect.width,
                    height: rect.height,
                    rotation: collageRotation(index: index),
                    cornerRadius: 28,
                    shadowOpacity: 0.12
                )
            )
        }

        if let note = note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            layers.append(
                ScrapbookLayer(
                    kind: .text,
                    title: "备注",
                    text: note,
                    x: 540,
                    y: 1320,
                    width: 760,
                    height: 120,
                    fontName: "caption",
                    fontSize: 30,
                    textColorHex: "#5F6872"
                )
            )
        }

        layers.append(
            ScrapbookLayer(
                kind: .border,
                title: "浅边框",
                x: 540,
                y: 720,
                width: 1000,
                height: 1320,
                borderColorHex: "#D7DDEA",
                borderWidth: 8,
                cornerRadius: 42,
                shadowOpacity: 0.03
            )
        )

        return ScrapbookPageLayout(
            backgroundColorHex: backgroundColor(forTemplate: template),
            layers: layers
        )
    }

    private static func collageRect(index: Int, count: Int) -> CGRect {
        let gap: Double = 34
        switch count {
        case 1:
            return CGRect(x: 150, y: 240, width: 780, height: 880)
        case 2:
            return CGRect(x: 120, y: 245 + Double(index) * (500 + gap), width: 840, height: 500)
        case 3:
            if index == 0 {
                return CGRect(x: 120, y: 235, width: 840, height: 540)
            }
            return CGRect(x: 120 + Double(index - 1) * (403 + gap), y: 815, width: 403, height: 420)
        case 4:
            let column = index % 2
            let row = index / 2
            return CGRect(x: 116 + Double(column) * (407 + gap), y: 235 + Double(row) * (480 + gap), width: 407, height: 480)
        default:
            let column = index % 2
            let row = index / 2
            return CGRect(x: 116 + Double(column) * (407 + gap), y: 220 + Double(row) * (340 + gap), width: 407, height: 340)
        }
    }

    private static func collageRotation(index: Int) -> Double {
        [-2.5, 2, -1.2, 1.6, -1.8, 2.2][min(max(index, 0), 5)]
    }

    private static func backgroundColor(forTemplate template: String) -> String {
        switch template {
        case "工作复盘": return "#F6F8FB"
        case "美食相册": return "#FFF7F0"
        case "穿搭灵感": return "#F7F4FB"
        case "网页摘录": return "#F5FAFA"
        case "图片拼贴": return "#FDF8FA"
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

enum ScrapbookStyleCatalog {
    struct FontPreset: Identifiable, Equatable {
        let id: String
        let title: String
        let fontName: String
        let fontSize: Double
        let textColorHex: String
    }

    struct StickerPreset: Identifiable, Equatable {
        let id: String
        let title: String
        let text: String
        let fontName: String
        let fontSize: Double
        let textColorHex: String
        let backgroundColorHex: String
        let cornerRadius: Double
        let rotation: Double
    }

    struct BorderPreset: Identifiable, Equatable {
        let id: String
        let title: String
        let borderColorHex: String
        let borderWidth: Double
        let cornerRadius: Double
        let shadowOpacity: Double
    }

    static let canvasColorHexes = [
        "#FDF8FA", "#F7FBFB", "#F6F8FB", "#FFF7F0", "#F7F4FB", "#F1F7F0"
    ]

    static let textColorHexes = [
        "#46525A", "#5F6872", "#597469", "#8B6F83", "#A06F55", "#FFFFFF"
    ]

    static let fillColorHexes = [
        "#EEF7F3", "#E8F3EE", "#F2EEF8", "#F8DCE8", "#FFF7F0", "#F6F8FB"
    ]

    static let borderColorHexes = [
        "#D7DDEA", "#A9C9D8", "#C9B8D8", "#E7C7D7", "#D8C7B1", "#7A8A8E"
    ]

    static let fontPresets = [
        FontPreset(id: "rounded", title: "圆润", fontName: "rounded", fontSize: 46, textColorHex: "#46525A"),
        FontPreset(id: "serif", title: "纸本", fontName: "serif", fontSize: 44, textColorHex: "#5F6872"),
        FontPreset(id: "handwritten", title: "手写", fontName: "handwritten", fontSize: 50, textColorHex: "#8B6F83"),
        FontPreset(id: "mono", title: "清单", fontName: "mono", fontSize: 36, textColorHex: "#597469"),
        FontPreset(id: "caption", title: "标签", fontName: "caption", fontSize: 32, textColorHex: "#A06F55")
    ]

    static let stickerPresets = [
        StickerPreset(id: "today", title: "今日", text: "今日", fontName: "rounded", fontSize: 30, textColorHex: "#597469", backgroundColorHex: "#EEF7F3", cornerRadius: 34, rotation: -4),
        StickerPreset(id: "idea", title: "灵感", text: "灵感", fontName: "handwritten", fontSize: 34, textColorHex: "#8B6F83", backgroundColorHex: "#F2EEF8", cornerRadius: 30, rotation: 5),
        StickerPreset(id: "quote", title: "摘录", text: "摘录", fontName: "serif", fontSize: 30, textColorHex: "#5F6872", backgroundColorHex: "#F6F8FB", cornerRadius: 22, rotation: -2),
        StickerPreset(id: "ootd", title: "OOTD", text: "OOTD", fontName: "mono", fontSize: 28, textColorHex: "#46525A", backgroundColorHex: "#FFF7F0", cornerRadius: 18, rotation: 3),
        StickerPreset(id: "food", title: "好好吃饭", text: "好好吃饭", fontName: "rounded", fontSize: 28, textColorHex: "#A06F55", backgroundColorHex: "#FFF7F0", cornerRadius: 28, rotation: -3)
    ]

    static let borderPresets = [
        BorderPreset(id: "linen", title: "浅亚麻", borderColorHex: "#D7DDEA", borderWidth: 8, cornerRadius: 38, shadowOpacity: 0),
        BorderPreset(id: "mint", title: "薄荷线", borderColorHex: "#A9C9D8", borderWidth: 6, cornerRadius: 28, shadowOpacity: 0),
        BorderPreset(id: "film", title: "胶片框", borderColorHex: "#7A8A8E", borderWidth: 10, cornerRadius: 18, shadowOpacity: 0.05),
        BorderPreset(id: "lace", title: "花边框", borderColorHex: "#E7C7D7", borderWidth: 12, cornerRadius: 54, shadowOpacity: 0.04)
    ]

    static func normalizedFontKey(_ fontName: String?) -> String {
        let key = (fontName ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch key {
        case "serif", "paper", "paper-soft", "宋体", "明朝", "纸本", "纸本文字":
            return "serif"
        case "mono", "monospaced", "code", "清单", "等宽":
            return "mono"
        case "handwritten", "handwriting", "script", "手写", "手写体":
            return "handwritten"
        case "caption", "label", "标签", "小标题":
            return "caption"
        case "rounded", "round", "圆体", "圆润":
            return "rounded"
        default:
            return "rounded"
        }
    }

    static func fontPreset(matching value: String?) -> FontPreset {
        let key = normalizedFontKey(value)
        return fontPresets.first { $0.id == key } ?? fontPresets[0]
    }

    static func stickerPreset(matching value: String?) -> StickerPreset? {
        let key = normalizedToken(value)
        guard !key.isEmpty else {
            return nil
        }

        return stickerPresets.first { preset in
            matchesPresetToken(key, preset.id)
                || matchesPresetToken(key, preset.title)
                || matchesPresetToken(key, preset.text)
        }
    }

    static func borderPreset(matching value: String?) -> BorderPreset {
        let key = normalizedToken(value)
        guard !key.isEmpty else {
            return borderPresets[0]
        }

        return borderPresets.first { preset in
            matchesPresetToken(key, preset.id) || matchesPresetToken(key, preset.title)
        } ?? borderPresets[0]
    }

    static func applyFontPreset(_ preset: FontPreset, to layer: inout ScrapbookLayer) {
        guard layer.kind == .text || layer.kind == .sticker else {
            return
        }

        layer.fontName = preset.fontName
        layer.fontSize = preset.fontSize
        layer.textColorHex = preset.textColorHex
    }

    static func applyStickerPreset(_ preset: StickerPreset, to layer: inout ScrapbookLayer) {
        guard layer.kind == .sticker else {
            return
        }

        layer.title = preset.title
        layer.text = preset.text
        layer.fontName = preset.fontName
        layer.fontSize = preset.fontSize
        layer.textColorHex = preset.textColorHex
        layer.backgroundColorHex = preset.backgroundColorHex
        layer.cornerRadius = preset.cornerRadius
        layer.rotation = preset.rotation
    }

    static func applyBorderPreset(_ preset: BorderPreset, to layer: inout ScrapbookLayer) {
        guard layer.kind == .border else {
            return
        }

        layer.title = preset.title
        layer.borderColorHex = preset.borderColorHex
        layer.borderWidth = preset.borderWidth
        layer.cornerRadius = preset.cornerRadius
        layer.shadowOpacity = preset.shadowOpacity
    }

    private static func normalizedToken(_ value: String?) -> String {
        (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
    }

    private static func matchesPresetToken(_ query: String, _ value: String) -> Bool {
        let token = normalizedToken(value)
        return token == query || token.contains(query) || query.contains(token)
    }
}

struct ImageEditRecipe: Codable, Equatable {
    static let marker = "图片编辑JSON："

    var version: Int
    var sourceAttachmentPath: String
    var outputAttachmentPath: String?
    var filter: Filter
    var layoutPreset: LayoutPreset
    var cropPreset: CropPreset
    var cropAdjustment: CropAdjustment
    var border: Border
    var background: Background
    var subjectExtraction: SubjectExtraction
    var textOverlays: [TextOverlay]
    var stickerOverlays: [StickerOverlay]
    var cleanupPatches: [CleanupPatch]

    init(
        version: Int = 1,
        sourceAttachmentPath: String,
        outputAttachmentPath: String? = nil,
        filter: Filter = .original,
        layoutPreset: LayoutPreset = .manual,
        cropPreset: CropPreset = .original,
        cropAdjustment: CropAdjustment = CropAdjustment(),
        border: Border = Border(),
        background: Background = Background(),
        subjectExtraction: SubjectExtraction = SubjectExtraction(),
        textOverlays: [TextOverlay] = [],
        stickerOverlays: [StickerOverlay] = [],
        cleanupPatches: [CleanupPatch] = []
    ) {
        self.version = version
        self.sourceAttachmentPath = sourceAttachmentPath
        self.outputAttachmentPath = outputAttachmentPath
        self.filter = filter
        self.layoutPreset = layoutPreset
        self.cropPreset = cropPreset
        self.cropAdjustment = cropAdjustment
        self.border = border
        self.background = background
        self.subjectExtraction = subjectExtraction
        self.textOverlays = textOverlays
        self.stickerOverlays = stickerOverlays
        self.cleanupPatches = cleanupPatches
    }

    var summary: String {
        var parts = [filter.title, cropPreset.title]
        if layoutPreset != .manual {
            parts.append(layoutPreset.title)
        }
        if cropAdjustment.isAdjusted {
            parts.append("自由裁剪")
        }
        if border.width > 0 {
            parts.append("边框")
        }
        if background.mode != .original {
            parts.append(background.mode.title)
        }
        if subjectExtraction.mode != .none {
            parts.append(subjectExtraction.hasSelectionPoint ? "单主体" : subjectExtraction.mode.title)
        }
        if !textOverlays.isEmpty {
            parts.append("文字\(textOverlays.count)")
        }
        if !stickerOverlays.isEmpty {
            parts.append("贴纸\(stickerOverlays.count)")
        }
        if !cleanupPatches.isEmpty {
            let objectCleanupCount = cleanupPatches.filter { $0.style == .object }.count
            if objectCleanupCount > 0 {
                parts.append("对象清理\(objectCleanupCount)")
            }
            let softBlendCount = cleanupPatches.count - objectCleanupCount
            if softBlendCount > 0 {
                parts.append("清理\(softBlendCount)")
            }
        }
        return parts.joined(separator: " · ")
    }

    enum CodingKeys: String, CodingKey {
        case version
        case sourceAttachmentPath
        case outputAttachmentPath
        case filter
        case layoutPreset
        case cropPreset
        case cropAdjustment
        case border
        case background
        case subjectExtraction
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
        layoutPreset = try container.decodeIfPresent(LayoutPreset.self, forKey: .layoutPreset) ?? .manual
        cropPreset = try container.decodeIfPresent(CropPreset.self, forKey: .cropPreset) ?? .original
        cropAdjustment = try container.decodeIfPresent(CropAdjustment.self, forKey: .cropAdjustment) ?? CropAdjustment()
        border = try container.decodeIfPresent(Border.self, forKey: .border) ?? Border()
        background = try container.decodeIfPresent(Background.self, forKey: .background) ?? Background()
        subjectExtraction = try container.decodeIfPresent(SubjectExtraction.self, forKey: .subjectExtraction) ?? SubjectExtraction()
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

    enum LayoutPreset: String, Codable, CaseIterable, Equatable {
        case manual
        case foodCard
        case journalSticker
        case filmFrame
        case storyCover

        var title: String {
            switch self {
            case .manual: return "手动"
            case .foodCard: return "美食留白"
            case .journalSticker: return "手帐贴纸"
            case .filmFrame: return "胶片边框"
            case .storyCover: return "故事封面"
            }
        }

        var filter: Filter {
            switch self {
            case .manual: return .fresh
            case .foodCard: return .warm
            case .journalSticker: return .fresh
            case .filmFrame: return .mono
            case .storyCover: return .vivid
            }
        }

        var cropPreset: CropPreset {
            switch self {
            case .manual: return .original
            case .foodCard: return .square
            case .journalSticker: return .portrait4x5
            case .filmFrame: return .landscape16x9
            case .storyCover: return .story9x16
            }
        }

        var border: Border {
            switch self {
            case .manual:
                return Border(colorHex: "#FFFFFF", width: 18)
            case .foodCard:
                return Border(colorHex: "#FFFFFF", width: 22)
            case .journalSticker:
                return Border(colorHex: "#F8DCE8", width: 16)
            case .filmFrame:
                return Border(colorHex: "#1D222B", width: 28)
            case .storyCover:
                return Border(colorHex: "#FFFFFF", width: 12)
            }
        }

        var background: Background {
            switch self {
            case .manual:
                return Background()
            case .foodCard:
                return Background(mode: .solid, colorHex: "#FFF7F0", blurRadius: 18, cornerRadius: 34, inset: 0.10)
            case .journalSticker:
                return Background(mode: .softBlur, colorHex: "#F8DCE8", blurRadius: 24, cornerRadius: 30, inset: 0.08)
            case .filmFrame:
                return Background(mode: .original, colorHex: "#1D222B", blurRadius: 18, cornerRadius: 12, inset: 0)
            case .storyCover:
                return Background(mode: .solid, colorHex: "#DDEBF7", blurRadius: 20, cornerRadius: 28, inset: 0.06)
            }
        }

        var defaultCaption: String? {
            switch self {
            case .manual: return nil
            case .foodCard: return "好好吃饭"
            case .journalSticker: return "今日片段"
            case .filmFrame: return nil
            case .storyCover: return "Some day"
            }
        }

        var defaultSticker: String? {
            switch self {
            case .manual: return nil
            case .foodCard: return "今日"
            case .journalSticker: return "灵感"
            case .filmFrame: return "FILM"
            case .storyCover: return "OOTD"
            }
        }

        func textOverlay(text: String) -> TextOverlay {
            switch self {
            case .foodCard:
                return TextOverlay(text: text, x: 0.5, y: 0.84, fontSize: 40, colorHex: "#A06F55")
            case .journalSticker:
                return TextOverlay(text: text, x: 0.5, y: 0.82, fontSize: 42, colorHex: "#8B6F83")
            case .filmFrame:
                return TextOverlay(text: text, x: 0.5, y: 0.88, fontSize: 34, colorHex: "#FFFFFF")
            case .storyCover:
                return TextOverlay(text: text, x: 0.5, y: 0.76, fontSize: 48, colorHex: "#46525A")
            case .manual:
                return TextOverlay(text: text)
            }
        }

        func stickerOverlay(text: String) -> StickerOverlay {
            switch self {
            case .foodCard:
                return StickerOverlay(text: text, x: 0.18, y: 0.18, fontSize: 44)
            case .journalSticker:
                return StickerOverlay(text: text, x: 0.78, y: 0.18, fontSize: 46)
            case .filmFrame:
                return StickerOverlay(text: text, x: 0.16, y: 0.14, fontSize: 30)
            case .storyCover:
                return StickerOverlay(text: text, x: 0.78, y: 0.16, fontSize: 40)
            case .manual:
                return StickerOverlay(text: text)
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

    struct Background: Codable, Equatable {
        var mode: Mode
        var colorHex: String
        var blurRadius: Double
        var cornerRadius: Double
        var inset: Double

        init(
            mode: Mode = .original,
            colorHex: String = "#F8DCE8",
            blurRadius: Double = 22,
            cornerRadius: Double = 28,
            inset: Double = 0.06
        ) {
            self.mode = mode
            self.colorHex = colorHex
            self.blurRadius = blurRadius
            self.cornerRadius = cornerRadius
            self.inset = inset
        }

        enum Mode: String, Codable, CaseIterable, Equatable {
            case original
            case softBlur
            case solid

            var title: String {
                switch self {
                case .original: return "原背景"
                case .softBlur: return "柔化背景"
                case .solid: return "纯色背景"
                }
            }
        }
    }

    struct CropAdjustment: Codable, Equatable {
        static let minimumScale: Double = 1
        static let maximumScale: Double = 3

        var x: Double
        var y: Double
        var scale: Double

        init(x: Double = 0.5, y: Double = 0.5, scale: Double = 1) {
            self.x = x
            self.y = y
            self.scale = scale
        }

        var isAdjusted: Bool {
            let adjustment = clamped()
            return abs(adjustment.x - 0.5) > 0.01
                || abs(adjustment.y - 0.5) > 0.01
                || abs(adjustment.scale - Self.minimumScale) > 0.01
        }

        func clamped() -> CropAdjustment {
            CropAdjustment(
                x: Self.clamped(x, lower: 0, upper: 1),
                y: Self.clamped(y, lower: 0, upper: 1),
                scale: Self.clamped(scale, lower: Self.minimumScale, upper: Self.maximumScale)
            )
        }

        func applyingDrag(
            widthDelta: Double,
            heightDelta: Double,
            imageWidth: Double,
            imageHeight: Double
        ) -> CropAdjustment {
            let adjustment = clamped()
            let safeWidth = max(imageWidth, 1)
            let safeHeight = max(imageHeight, 1)
            return CropAdjustment(
                x: adjustment.x + widthDelta / safeWidth,
                y: adjustment.y + heightDelta / safeHeight,
                scale: adjustment.scale
            ).clamped()
        }

        func applyingMagnification(_ magnification: Double) -> CropAdjustment {
            let adjustment = clamped()
            let multiplier = magnification.isFinite ? magnification : 1
            return CropAdjustment(
                x: adjustment.x,
                y: adjustment.y,
                scale: adjustment.scale * multiplier
            ).clamped()
        }

        private static func clamped(_ value: Double, lower: Double, upper: Double) -> Double {
            min(max(value, lower), upper)
        }
    }

    struct SubjectExtraction: Codable, Equatable {
        var mode: Mode
        var selectionX: Double?
        var selectionY: Double?

        init(mode: Mode = .none, selectionX: Double? = nil, selectionY: Double? = nil) {
            self.mode = mode
            self.selectionX = Self.normalizedSelection(selectionX)
            self.selectionY = Self.normalizedSelection(selectionY)
        }

        var hasSelectionPoint: Bool {
            mode == .object && selectionX != nil && selectionY != nil
        }

        var title: String {
            guard hasSelectionPoint,
                  let selectionX = selectionX,
                  let selectionY = selectionY else {
                return mode.title
            }
            return "\(mode.title)（单主体 \(Int(selectionX * 100))/\(Int(selectionY * 100))）"
        }

        private static func normalizedSelection(_ value: Double?) -> Double? {
            guard let value = value, value.isFinite else {
                return nil
            }
            return min(max(value, 0), 1)
        }

        enum Mode: String, Codable, CaseIterable, Equatable {
            case none
            case person
            case object

            var title: String {
                switch self {
                case .none: return "无"
                case .person: return "人物抠图"
                case .object: return "智能主体"
                }
            }
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
        var style: Style

        init(
            id: UUID = UUID(),
            x: Double = 0.5,
            y: Double = 0.5,
            radius: Double = 0.08,
            softness: Double = 0.7,
            style: Style = .softBlend
        ) {
            self.id = id
            self.x = x
            self.y = y
            self.radius = radius
            self.softness = softness
            self.style = style
        }

        enum Style: String, Codable, CaseIterable, Hashable {
            case softBlend
            case object

            var title: String {
                switch self {
                case .softBlend: return "柔和修补"
                case .object: return "对象清理"
                }
            }
        }

        enum CodingKeys: String, CodingKey {
            case id
            case x
            case y
            case radius
            case softness
            case style
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
            x = try container.decodeIfPresent(Double.self, forKey: .x) ?? 0.5
            y = try container.decodeIfPresent(Double.self, forKey: .y) ?? 0.5
            radius = try container.decodeIfPresent(Double.self, forKey: .radius) ?? 0.08
            softness = try container.decodeIfPresent(Double.self, forKey: .softness) ?? 0.7
            style = try container.decodeIfPresent(Style.self, forKey: .style) ?? .softBlend
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
    case clipFragment
    case imageEdit
    case scrapbookPage
    case workLog
    case wardrobeItem
    case outfit
    case wearLog
    case laundryLog
    case packingList
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
        case .clipFragment: return "摘录"
        case .imageEdit: return "图片"
        case .scrapbookPage: return "手帐"
        case .workLog: return "日志"
        case .wardrobeItem: return "衣橱"
        case .outfit: return "穿搭"
        case .wearLog: return "穿着"
        case .laundryLog: return "洗护"
        case .packingList: return "打包"
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
        case .clipFragment: return "quote.bubble"
        case .imageEdit: return "wand.and.stars"
        case .scrapbookPage: return "rectangle.stack"
        case .workLog: return "doc.text"
        case .wardrobeItem: return "tshirt"
        case .outfit: return "sparkles"
        case .wearLog: return "calendar.badge.clock"
        case .laundryLog: return "washer"
        case .packingList: return "suitcase"
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

        for clipFragment in ClipFragmentExtractor.assetSummaries(in: visibleText) {
            append(
                kind: .clipFragment,
                title: clipFragment.title,
                summary: clipFragment.summary.map { limitedSummary($0, maxLength: 500) },
                uri: clipFragment.uri,
                typeIdentifier: UTType.text.identifier,
                stableKey: "clip-fragment:\(clipFragment.title):\(clipFragment.summary ?? "")"
            )
        }

        let imageAttachments = SharedAttachmentStore.attachments(in: memo.text).filter(\.isImage)
        for imageText in imageTextAssets(in: visibleText, attachments: imageAttachments) {
            append(
                kind: .screenshot,
                title: imageText.title,
                summary: imageText.summary,
                uri: "\(SharedAttachmentStore.referenceScheme)://\(SharedAttachmentStore.encodedReferencePath(imageText.attachment.relativePath))",
                typeIdentifier: imageText.attachment.typeIdentifier,
                byteCount: imageText.attachment.byteCount,
                stableKey: "image-text:\(imageText.attachment.relativePath):\(imageText.summary)"
            )
        }

        if let wardrobeItem = wardrobeItemAsset(in: visibleText),
           let attachment = imageAttachments.first {
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

        if let wearLog = wearLogAsset(in: visibleText) {
            append(
                kind: .wearLog,
                title: wearLog.title,
                summary: wearLog.summary,
                typeIdentifier: UTType.text.identifier,
                stableKey: "wearlog:\(wearLog.title):\(wearLog.summary ?? "")"
            )
        }

        if let laundryLog = laundryLogAsset(in: visibleText) {
            append(
                kind: .laundryLog,
                title: laundryLog.title,
                summary: laundryLog.summary,
                typeIdentifier: UTType.text.identifier,
                stableKey: "laundry:\(laundryLog.title):\(laundryLog.summary ?? "")"
            )
        }

        if let packingList = packingListAsset(in: visibleText) {
            append(
                kind: .packingList,
                title: packingList.title,
                summary: packingList.summary,
                typeIdentifier: UTType.text.identifier,
                stableKey: "packing:\(packingList.title):\(packingList.summary ?? "")"
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

    private static func imageTextAssets(
        in text: String,
        attachments: [SharedAttachment]
    ) -> [(title: String, summary: String, attachment: SharedAttachment)] {
        imageTextBlocks(in: text).compactMap { block in
            let matchedAttachment = block.attachments.first(where: \.isImage)
                ?? attachments.first { attachment in
                    attachment.displayName == block.title || attachment.relativePath == block.title
                }
                ?? attachments.first
            guard let attachment = matchedAttachment else {
                return nil
            }
            return (block.title, block.summary, attachment)
        }
    }

    private static func imageTextBlocks(in text: String) -> [(title: String, summary: String, attachments: [SharedAttachment])] {
        let rawLines = text.components(separatedBy: .newlines)
        let titleIndices = rawLines.indices.filter { index in
            let line = rawLines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            return imageTextTitlePrefix(in: line) != nil
        }

        return titleIndices.enumerated().compactMap { offset, start in
            let end = offset + 1 < titleIndices.count ? titleIndices[offset + 1] : rawLines.endIndex
            return imageTextBlock(in: Array(rawLines[start..<end]))
        }
    }

    private static func imageTextBlock(in rawLines: [String]) -> (title: String, summary: String, attachments: [SharedAttachment])? {
        let lines = rawLines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let prefixes = ["图片文字：", "图片文字:", "截图文字：", "截图文字:"]
        guard let firstLine = lines.first,
              let prefix = prefixes.first(where: { firstLine.hasPrefix($0) }) else {
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
            .filter { line in
                !line.isEmpty
                    && !line.hasPrefix("区域：")
                    && !line.hasPrefix("区域:")
                    && !line.hasPrefix("[附件:")
                    && !line.hasPrefix("some-attachment://")
            }
            .joined(separator: "\n")
        guard !recognizedText.isEmpty else {
            return nil
        }

        return (
            title,
            limitedSummary(recognizedText),
            SharedAttachmentStore.attachments(in: rawLines.joined(separator: "\n"))
        )
    }

    private static func imageTextTitlePrefix(in line: String) -> String? {
        let prefixes = ["图片文字：", "图片文字:", "截图文字：", "截图文字:"]
        return prefixes.first(where: { line.hasPrefix($0) })
    }

    private static func wardrobeItemAsset(in text: String) -> (title: String, summary: String?)? {
        structuredAsset(in: text, prefixes: ["衣橱单品：", "衣橱单品:", "单品：", "单品:"])
    }

    private static func outfitAsset(in text: String) -> (title: String, summary: String?)? {
        structuredAsset(in: text, prefixes: ["穿搭组合：", "穿搭组合:", "穿搭：", "穿搭:"])
    }

    private static func wearLogAsset(in text: String) -> (title: String, summary: String?)? {
        structuredAsset(in: text, prefixes: ["穿着记录：", "穿着记录:", "穿着：", "穿着:", "穿搭记录：", "穿搭记录:"])
    }

    private static func laundryLogAsset(in text: String) -> (title: String, summary: String?)? {
        structuredAsset(in: text, prefixes: ["洗护记录：", "洗护记录:", "洗护：", "洗护:", "护理记录：", "护理记录:"])
    }

    private static func packingListAsset(in text: String) -> (title: String, summary: String?)? {
        structuredAsset(in: text, prefixes: ["旅行打包：", "旅行打包:", "打包清单：", "打包清单:", "行李清单：", "行李清单:"])
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
