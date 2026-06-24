import Foundation

struct WidgetSnapshot: Codable, Equatable {
    var generatedAt: Date
    var activeCount: Int
    var todayCount: Int
    var recentItems: [WidgetSnapshotItem]

    static let empty = WidgetSnapshot(
        generatedAt: Date(timeIntervalSince1970: 0),
        activeCount: 0,
        todayCount: 0,
        recentItems: []
    )
}

struct WidgetSnapshotItem: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var tags: [String]
}

enum WidgetSnapshotStore {
    static let widgetKind = "SomeQuickWidget"
    static let filename = "some-widget-snapshot.json"

    #if !SOME_WIDGET_EXTENSION
    static func snapshot(from memos: [Memo], now: Date = Date(), limit: Int = 3) -> WidgetSnapshot {
        let activeMemos = memos.filter { !$0.isArchived }
        let calendar = Calendar.current
        let recentItems = activeMemos
            .sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.createdAt > rhs.createdAt
            }
            .prefix(limit)
            .map { memo in
                WidgetSnapshotItem(
                    id: memo.id,
                    title: displayTitle(for: memo.text),
                    createdAt: memo.createdAt,
                    updatedAt: memo.updatedAt,
                    tags: memo.tags
                )
            }

        return WidgetSnapshot(
            generatedAt: now,
            activeCount: activeMemos.count,
            todayCount: activeMemos.filter { calendar.isDate($0.createdAt, inSameDayAs: now) }.count,
            recentItems: Array(recentItems)
        )
    }

    static func refresh(with memos: [Memo], storageDirectory: URL? = nil) {
        let directory = storageDirectory ?? SharedMemoStorage.storageDirectory()
        try? write(snapshot(from: memos), storageDirectory: directory)
    }

    private static func displayTitle(for text: String) -> String {
        let withoutAttachments = SharedAttachmentStore.displayTextWithoutAttachmentReferences(text)
        let withoutMarkdownLinks = withoutAttachments.replacingOccurrences(
            of: #"\[([^\]]+)\]\([^)]+\)"#,
            with: "$1",
            options: .regularExpression
        )
        let collapsed = withoutMarkdownLinks
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return "无标题记录" }
        return collapsed.count > 42 ? "\(collapsed.prefix(42))..." : collapsed
    }
    #endif

    static func read(storageDirectory: URL? = nil) -> WidgetSnapshot {
        let directory = storageDirectory ?? SharedMemoStorage.storageDirectory()
        let url = directory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url),
              let snapshot = try? decoder.decode(WidgetSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    static func write(_ snapshot: WidgetSnapshot, storageDirectory: URL) throws {
        try FileManager.default.createDirectory(
            at: storageDirectory,
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(snapshot)
        try data.write(
            to: storageDirectory.appendingPathComponent(filename),
            options: [.atomic]
        )
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
