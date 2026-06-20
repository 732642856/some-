import Foundation
import SwiftUI

enum MemoHomeMode: String, CaseIterable, Identifiable {
    case timeline
    case ai
    case review
    case stats
    case archive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timeline: return "记录"
        case .ai: return "AI"
        case .review: return "回顾"
        case .stats: return "统计"
        case .archive: return "归档"
        }
    }

    var systemImage: String {
        switch self {
        case .timeline: return "square.and.pencil"
        case .ai: return "sparkles.rectangle.stack"
        case .review: return "sparkles"
        case .stats: return "chart.xyaxis.line"
        case .archive: return "archivebox"
        }
    }
}

@MainActor
final class MemoStore: ObservableObject {
    @Published private(set) var memos: [Memo] = []
    @Published var searchText: String = ""
    @Published var selectedTag: String? = nil
    @Published var homeMode: MemoHomeMode = .timeline
    @Published private(set) var reviewMemo: Memo?

    private let fileURL: URL

    init(filename: String = "some-memos.json") {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        self.fileURL = (documentsDirectory ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent(filename)

        load()
    }

    var filteredMemos: [Memo] {
        filteredMemos(includeArchived: false)
    }

    var archivedMemos: [Memo] {
        filteredMemos(includeArchived: true)
            .filter(\.isArchived)
    }

    var activeMemos: [Memo] {
        memos.filter { !$0.isArchived }
    }

    var activeCount: Int {
        activeMemos.count
    }

    var archivedCount: Int {
        memos.filter(\.isArchived).count
    }

    var activeTags: [String] {
        Array(Set(activeMemos.flatMap(\.tags))).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    var nestedTagRoots: [String] {
        Array(Set(activeTags.map { $0.components(separatedBy: "/").first ?? $0 })).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    var onThisDayMemos: [Memo] {
        let today = Calendar.current.dateComponents([.month, .day, .year], from: Date())
        return activeMemos
            .filter { memo in
                let components = Calendar.current.dateComponents([.month, .day, .year], from: memo.createdAt)
                return components.month == today.month
                    && components.day == today.day
                    && components.year != today.year
            }
            .sorted(by: sortMemos)
    }

    func filteredMemos(includeArchived: Bool) -> [Memo] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return memos
            .filter { memo in
                includeArchived ? true : !memo.isArchived
            }
            .filter { memo in
                guard let selectedTag else { return true }
                return memo.tags.contains { tag in
                    tag == selectedTag || tag.hasPrefix("\(selectedTag)/")
                }
            }
            .filter { memo in
                guard !needle.isEmpty else { return true }
                return memo.text.localizedCaseInsensitiveContains(needle)
                    || memo.tags.contains { $0.localizedCaseInsensitiveContains(needle) }
            }
            .sorted(by: sortMemos)
    }

    var allTags: [String] {
        Array(Set(memos.flatMap(\.tags))).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    var pinnedCount: Int {
        activeMemos.filter(\.isPinned).count
    }

    var todayCount: Int {
        activeMemos.filter { Calendar.current.isDateInToday($0.createdAt) }.count
    }

    func addMemo(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let memo = Memo(text: trimmed, tags: TagParser.extractTags(from: trimmed))
        memos.append(memo)
        reviewMemo = memo
        save()
    }

    func update(_ memo: Memo, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let index = memos.firstIndex(where: { $0.id == memo.id }) else { return }

        memos[index].text = trimmed
        memos[index].tags = TagParser.extractTags(from: trimmed)
        memos[index].updatedAt = Date()
        save()
    }

    func togglePinned(_ memo: Memo) {
        guard let index = memos.firstIndex(where: { $0.id == memo.id }) else { return }
        memos[index].isPinned.toggle()
        memos[index].updatedAt = Date()
        save()
    }

    func toggleArchived(_ memo: Memo) {
        guard let index = memos.firstIndex(where: { $0.id == memo.id }) else { return }
        memos[index].isArchived.toggle()
        memos[index].updatedAt = Date()
        if reviewMemo?.id == memo.id {
            reviewMemo = nil
        }
        save()
    }

    func delete(_ memo: Memo) {
        memos.removeAll { $0.id == memo.id }
        if reviewMemo?.id == memo.id {
            reviewMemo = nil
        }
        if let selectedTag, !allTags.contains(selectedTag) {
            self.selectedTag = nil
        }
        save()
    }

    func clearTagFilter() {
        selectedTag = nil
    }

    func pickRandomReviewMemo() {
        reviewMemo = activeMemos.randomElement()
    }

    func dailyStats(lastDays: Int = 140) -> [DailyMemoStat] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(lastDays - 1), to: today) ?? today

        let grouped = Dictionary(grouping: activeMemos) { memo in
            calendar.startOfDay(for: memo.createdAt)
        }

        return (0..<lastDays).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return DailyMemoStat(date: date, count: grouped[date]?.count ?? 0)
        }
    }

    func exportMarkdown() -> String {
        let body = memos.sorted(by: sortMemos).map { memo -> String in
            let createdAt = DateFormatters.export.string(from: memo.createdAt)
            let tags = memo.tags.map { "#\($0)" }.joined(separator: " ")
            let pin = memo.isPinned ? " [置顶]" : ""
            let archived = memo.isArchived ? " [归档]" : ""
            return """
            ## \(createdAt)\(pin)\(archived)

            \(memo.text)

            \(tags)
            """
        }.joined(separator: "\n\n---\n\n")

        return "# some 导出\n\n\(body)\n"
    }

    func exportJSON() -> String {
        do {
            let data = try JSONEncoder.memoEncoder.encode(memos.sorted(by: sortMemos))
            return String(decoding: data, as: UTF8.self)
        } catch {
            return "[]"
        }
    }

    func importJSON(_ text: String) throws -> Int {
        let data = Data(text.utf8)
        let incoming = try JSONDecoder.memoDecoder.decode([Memo].self, from: data)
        var imported = 0

        for memo in incoming {
            guard !memo.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            if memos.contains(where: { $0.id == memo.id }) {
                continue
            }
            var normalized = memo
            normalized.tags = TagParser.extractTags(from: memo.text)
            memos.append(normalized)
            imported += 1
        }

        if imported > 0 {
            save()
        }

        return imported
    }

    func importPlainText(_ text: String) -> Int {
        let chunks = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for chunk in chunks {
            addMemo(text: chunk)
        }

        return chunks.count
    }

    func addMemo(from url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }

        let text = components.queryItems?.first(where: { $0.name == "text" })?.value
            ?? components.queryItems?.first(where: { $0.name == "content" })?.value
            ?? components.host
            ?? ""
        addMemo(text: text)
    }

    private func sortMemos(_ lhs: Memo, _ rhs: Memo) -> Bool {
        if lhs.isPinned != rhs.isPinned {
            return lhs.isPinned && !rhs.isPinned
        }
        return lhs.createdAt > rhs.createdAt
    }

    private func load() {
        do {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                memos = []
                return
            }
            let data = try Data(contentsOf: fileURL)
            memos = try JSONDecoder.memoDecoder.decode([Memo].self, from: data)
        } catch {
            memos = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder.memoEncoder.encode(memos)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save memos: \(error)")
        }
    }
}

extension JSONEncoder {
    static var memoEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var memoDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
