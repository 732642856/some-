import Foundation

struct MemoRevision: Identifiable, Codable, Equatable {
    var id: UUID
    var memoID: UUID
    var text: String
    var tags: [String]
    var createdAt: Date
    var memoUpdatedAt: Date

    init(
        id: UUID = UUID(),
        memoID: UUID,
        text: String,
        tags: [String],
        createdAt: Date = Date(),
        memoUpdatedAt: Date
    ) {
        self.id = id
        self.memoID = memoID
        self.text = text
        self.tags = tags
        self.createdAt = createdAt
        self.memoUpdatedAt = memoUpdatedAt
    }
}
