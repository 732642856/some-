import Foundation

struct MemoBackupArchive: Codable {
    let version: Int
    let exportedAt: Date
    let memos: [Memo]
    let attachments: [MemoBackupAttachment]
    let revisions: [MemoRevision]

    init(
        version: Int,
        exportedAt: Date,
        memos: [Memo],
        attachments: [MemoBackupAttachment],
        revisions: [MemoRevision] = []
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.memos = memos
        self.attachments = attachments
        self.revisions = revisions
    }

    enum CodingKeys: String, CodingKey {
        case version
        case exportedAt
        case memos
        case attachments
        case revisions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        memos = try container.decode([Memo].self, forKey: .memos)
        attachments = try container.decode([MemoBackupAttachment].self, forKey: .attachments)
        revisions = try container.decodeIfPresent([MemoRevision].self, forKey: .revisions) ?? []
    }
}

struct MemoBackupSummary: Equatable {
    let memoCount: Int
    let revisionCount: Int
    let attachmentCount: Int
    let attachmentByteCount: Int

    init(
        memoCount: Int,
        revisionCount: Int,
        attachmentCount: Int,
        attachmentByteCount: Int
    ) {
        self.memoCount = memoCount
        self.revisionCount = revisionCount
        self.attachmentCount = attachmentCount
        self.attachmentByteCount = max(0, attachmentByteCount)
    }

    init(archive: MemoBackupArchive) {
        self.init(
            memoCount: archive.memos.count,
            revisionCount: archive.revisions.count,
            attachmentCount: archive.attachments.count,
            attachmentByteCount: archive.attachments.reduce(0) { total, attachment in
                total + attachment.byteCount
            }
        )
    }

    var displayText: String {
        let parts = [
            "\(memoCount) 条记录",
            "\(revisionCount) 条历史版本",
            "\(attachmentCount) 个附件",
            Self.formattedByteCount(attachmentByteCount)
        ]
        return parts.joined(separator: " · ")
    }

    private static func formattedByteCount(_ byteCount: Int) -> String {
        let bytes = max(0, byteCount)
        let units: [(name: String, size: Double)] = [
            ("GB", 1_073_741_824),
            ("MB", 1_048_576),
            ("KB", 1_024)
        ]

        for unit in units where Double(bytes) >= unit.size {
            let value = Double(bytes) / unit.size
            if value >= 10 || value.rounded() == value {
                return "\(Int(value.rounded())) \(unit.name)"
            }
            return "\(String(format: "%.1f", value)) \(unit.name)"
        }

        return "\(bytes) B"
    }
}

struct MemoBackupAttachment: Codable {
    let filename: String
    let relativePath: String
    let typeIdentifier: String
    let base64Data: String?
    let byteCount: Int

    init(
        filename: String,
        relativePath: String,
        typeIdentifier: String,
        base64Data: String? = nil,
        byteCount: Int = 0
    ) {
        self.filename = filename
        self.relativePath = relativePath
        self.typeIdentifier = typeIdentifier
        self.base64Data = base64Data
        self.byteCount = max(0, byteCount)
    }

    enum CodingKeys: String, CodingKey {
        case filename
        case relativePath
        case typeIdentifier
        case base64Data
        case byteCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        filename = try container.decode(String.self, forKey: .filename)
        relativePath = try container.decode(String.self, forKey: .relativePath)
        typeIdentifier = try container.decode(String.self, forKey: .typeIdentifier)
        base64Data = try container.decodeIfPresent(String.self, forKey: .base64Data)
        byteCount = max(0, try container.decodeIfPresent(Int.self, forKey: .byteCount) ?? 0)
    }
}
