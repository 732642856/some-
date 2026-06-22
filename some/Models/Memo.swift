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

enum MemoAssetKind: String, Codable, CaseIterable {
    case text
    case link
    case attachment
    case task
    case reference
    case webClip
    case imageEdit
    case scrapbookPage
    case wardrobeItem
    case outfit
    case audio
    case video
    case screenshot
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

        for attachment in SharedAttachmentStore.attachments(in: memo.text) {
            append(
                kind: .attachment,
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
