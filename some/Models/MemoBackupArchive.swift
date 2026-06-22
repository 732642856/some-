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

struct MemoBackupAttachment: Codable {
    let filename: String
    let relativePath: String
    let typeIdentifier: String
    let base64Data: String?

    init(
        filename: String,
        relativePath: String,
        typeIdentifier: String,
        base64Data: String? = nil
    ) {
        self.filename = filename
        self.relativePath = relativePath
        self.typeIdentifier = typeIdentifier
        self.base64Data = base64Data
    }
}
