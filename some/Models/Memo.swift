import Foundation

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
