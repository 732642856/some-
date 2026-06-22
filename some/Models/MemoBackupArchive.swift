import Foundation

struct MemoBackupArchive: Codable {
    let version: Int
    let exportedAt: Date
    let memos: [Memo]
    let attachments: [MemoBackupAttachment]
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
