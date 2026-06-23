import Foundation

struct WorkLogSourceFilter: Equatable {
    enum DateScope: String, CaseIterable, Identifiable {
        case all
        case today
        case last7Days
        case last30Days

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "全部时间"
            case .today: return "今天"
            case .last7Days: return "近7天"
            case .last30Days: return "近30天"
            }
        }
    }

    var tag: String = ""
    var kind: MemoContentFilter?
    var dateScope: DateScope = .all
    var searchText: String = ""

    static let empty = WorkLogSourceFilter()

    var isEmpty: Bool {
        tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && kind == nil
            && dateScope == .all
            && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum WorkLogSourceFilterEngine {
    static func candidates(
        from memos: [Memo],
        assets: [MemoAsset],
        filter: WorkLogSourceFilter = .empty,
        now: Date = Date(),
        calendar: Calendar = .current,
        limit: Int = 24
    ) -> [Memo] {
        guard limit > 0 else { return [] }

        let assetsByMemoID = Dictionary(grouping: assets, by: \.memoID)
        return memos
            .filter { memo in
                !memo.isArchived
                    && !hasAsset(.workLog, in: memo, assetsByMemoID: assetsByMemoID)
                    && matchesTag(filter.tag, in: memo)
                    && matchesDateScope(filter.dateScope, date: memo.createdAt, now: now, calendar: calendar)
                    && matchesKind(filter.kind, in: memo, assetsByMemoID: assetsByMemoID)
                    && matchesSearch(filter.searchText, in: memo, assetsByMemoID: assetsByMemoID)
            }
            .sorted {
                if $0.createdAt == $1.createdAt {
                    return $0.text < $1.text
                }
                return $0.createdAt > $1.createdAt
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func matchesTag(_ tag: String, in memo: Memo) -> Bool {
        let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return true }

        return memo.tags.contains { memoTag in
            memoTag == normalized || memoTag.hasPrefix("\(normalized)/")
        }
    }

    private static func matchesDateScope(
        _ scope: WorkLogSourceFilter.DateScope,
        date: Date,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        switch scope {
        case .all:
            return true
        case .today:
            return calendar.isDate(date, inSameDayAs: now)
        case .last7Days:
            return isDate(date, withinDays: 7, now: now, calendar: calendar)
        case .last30Days:
            return isDate(date, withinDays: 30, now: now, calendar: calendar)
        }
    }

    private static func isDate(_ date: Date, withinDays days: Int, now: Date, calendar: Calendar) -> Bool {
        let end = calendar.dateInterval(of: .day, for: now)?.end ?? now
        let startOfToday = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: startOfToday) ?? startOfToday
        return date >= start && date < end
    }

    private static func matchesKind(
        _ kind: MemoContentFilter?,
        in memo: Memo,
        assetsByMemoID: [UUID: [MemoAsset]]
    ) -> Bool {
        guard let kind = kind else { return true }

        switch kind {
        case .link:
            return !LinkExtractor.urls(in: memo.text).isEmpty
        case .attachment:
            return !SharedAttachmentStore.attachments(in: memo.text).isEmpty
        case .task:
            return !taskItems(in: memo).isEmpty
        case .openTask:
            return taskItems(in: memo).contains { !$0.isCompleted }
        case .completedTask:
            return taskItems(in: memo).contains { $0.isCompleted }
        case .reference:
            return !MemoReferenceParser.references(in: memo.text).isEmpty
        case .backlink:
            return false
        case .webClip:
            return !LinkExtractor.webClips(in: memo.text).isEmpty
        case .clipFragment:
            return hasAsset(.clipFragment, in: memo, assetsByMemoID: assetsByMemoID)
        case .imageEdit:
            return hasAsset(.imageEdit, in: memo, assetsByMemoID: assetsByMemoID)
        case .screenshot:
            return hasAsset(.screenshot, in: memo, assetsByMemoID: assetsByMemoID)
        case .scrapbook:
            return hasAsset(.scrapbookPage, in: memo, assetsByMemoID: assetsByMemoID)
        case .audio:
            return hasAsset(.audio, in: memo, assetsByMemoID: assetsByMemoID)
        case .video:
            return hasAsset(.video, in: memo, assetsByMemoID: assetsByMemoID)
        case .wardrobe:
            return hasAsset(.wardrobeItem, in: memo, assetsByMemoID: assetsByMemoID)
        case .outfit:
            return hasAsset(.outfit, in: memo, assetsByMemoID: assetsByMemoID)
        case .wearLog:
            return hasAsset(.wearLog, in: memo, assetsByMemoID: assetsByMemoID)
        case .laundryLog:
            return hasAsset(.laundryLog, in: memo, assetsByMemoID: assetsByMemoID)
        case .packingList:
            return hasAsset(.packingList, in: memo, assetsByMemoID: assetsByMemoID)
        case .workLog:
            return hasAsset(.workLog, in: memo, assetsByMemoID: assetsByMemoID)
        }
    }

    private static func matchesSearch(
        _ text: String,
        in memo: Memo,
        assetsByMemoID: [UUID: [MemoAsset]]
    ) -> Bool {
        let terms = splitSearchTerms(text)
        guard !terms.isEmpty else { return true }

        let assetText = assetsByMemoID[memo.id, default: []]
            .map { [$0.title, $0.summary].compactMap { $0 }.joined(separator: " ") }
            .joined(separator: " ")
        let searchableText = "\(memo.text) \(memo.tags.joined(separator: " ")) \(assetText)"
        return terms.allSatisfy { searchableText.localizedCaseInsensitiveContains($0) }
    }

    private static func splitSearchTerms(_ text: String) -> [String] {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func taskItems(in memo: Memo) -> [MemoTaskItem] {
        let displayText = MemoReferenceParser.displayTextWithoutReferences(
            SharedAttachmentStore.displayTextWithoutAttachmentReferences(memo.text)
        )
        return MemoTaskParser.taskItems(in: displayText)
    }

    private static func hasAsset(
        _ kind: MemoAssetKind,
        in memo: Memo,
        assetsByMemoID: [UUID: [MemoAsset]]
    ) -> Bool {
        assetsByMemoID[memo.id, default: []].contains { $0.kind == kind }
    }
}
