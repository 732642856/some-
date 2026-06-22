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
    private let backupFileURL: URL
    private let database: SQLiteMemoDatabase?

    init(filename: String = "some-memos.json") {
        let storageURLs = SharedMemoStorage.urls(filename: filename)
        self.fileURL = storageURLs.fileURL
        self.backupFileURL = storageURLs.backupFileURL
        self.database = try? SQLiteMemoDatabase(databaseURL: storageURLs.databaseURL)

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
            .sorted { sortMemos($0, $1) }
    }

    func filteredMemos(includeArchived: Bool) -> [Memo] {
        let query = MemoSearchQueryParser.parse(searchText)
        let searchRanks = searchRanks(for: query)
        let shouldIncludeArchived = includeArchived || query.isArchived == true

        return memos
            .filter { memo in
                shouldIncludeArchived ? true : !memo.isArchived
            }
            .filter { memo in
                matchesArchiveFilter(memo, query: query)
            }
            .filter { memo in
                matchesPinnedFilter(memo, query: query)
            }
            .filter { memo in
                matchesSelectedTag(memo)
            }
            .filter { memo in
                query.tagFilters.allSatisfy { matchesTag($0, in: memo) }
            }
            .filter { memo in
                matchesText(memo, query: query, searchRanks: searchRanks)
            }
            .sorted { sortMemos($0, $1, searchRanks: searchRanks, query: query) }
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

    @discardableResult
    func addMemo(text: String) -> Memo? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let memo = Memo(text: trimmed, tags: TagParser.extractTags(from: trimmed))
        memos.append(memo)
        reviewMemo = memo
        guard save(memo) else {
            memos.removeAll { $0.id == memo.id }
            if reviewMemo?.id == memo.id {
                reviewMemo = nil
            }
            return nil
        }
        return memo
    }

    func update(_ memo: Memo, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let index = memos.firstIndex(where: { $0.id == memo.id }) else { return }

        let previousMemo = memos[index]
        let previousAttachments = SharedAttachmentStore.attachments(in: memos[index].text)
        let updatedAttachments = SharedAttachmentStore.attachments(in: trimmed)
        memos[index].text = trimmed
        memos[index].tags = TagParser.extractTags(from: trimmed)
        memos[index].updatedAt = Date()
        if save(memos[index]) {
            deleteRemovedAttachments(previousAttachments: previousAttachments, updatedAttachments: updatedAttachments)
        } else {
            memos[index] = previousMemo
        }
    }

    func toggleTask(_ memo: Memo, lineIndex: Int) {
        guard let index = memos.firstIndex(where: { $0.id == memo.id }) else { return }

        let updatedText = MemoTaskParser.toggleTask(atLine: lineIndex, in: memos[index].text)
        guard updatedText != memos[index].text else {
            return
        }

        let previousMemo = memos[index]
        memos[index].text = updatedText
        memos[index].tags = TagParser.extractTags(from: updatedText)
        memos[index].updatedAt = Date()
        if !save(memos[index]) {
            memos[index] = previousMemo
        }
    }

    func togglePinned(_ memo: Memo) {
        guard let index = memos.firstIndex(where: { $0.id == memo.id }) else { return }
        let previousMemo = memos[index]
        memos[index].isPinned.toggle()
        memos[index].updatedAt = Date()
        if !save(memos[index]) {
            memos[index] = previousMemo
        }
    }

    func toggleArchived(_ memo: Memo) {
        guard let index = memos.firstIndex(where: { $0.id == memo.id }) else { return }
        let previousMemo = memos[index]
        let previousReviewMemo = reviewMemo
        memos[index].isArchived.toggle()
        memos[index].updatedAt = Date()
        if reviewMemo?.id == memo.id {
            reviewMemo = nil
        }
        if !save(memos[index]) {
            memos[index] = previousMemo
            reviewMemo = previousReviewMemo
        }
    }

    func delete(_ memo: Memo) {
        guard let index = memos.firstIndex(where: { $0.id == memo.id }) else { return }

        let previousReviewMemo = reviewMemo
        let previousSelectedTag = selectedTag
        let removedMemo = memos.remove(at: index)
        if reviewMemo?.id == memo.id {
            reviewMemo = nil
        }
        if let selectedTag = selectedTag, !allTags.contains(selectedTag) {
            self.selectedTag = nil
        }
        if deleteFromStorage(removedMemo) {
            deleteAttachmentsIfUnreferenced(SharedAttachmentStore.attachments(in: removedMemo.text))
        } else {
            memos.insert(removedMemo, at: index)
            reviewMemo = previousReviewMemo
            selectedTag = previousSelectedTag
        }
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
        let body = memos.sorted { sortMemos($0, $1) }.map { memo -> String in
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
            let data = try JSONEncoder.memoEncoder.encode(memos.sorted { sortMemos($0, $1) })
            return String(decoding: data, as: UTF8.self)
        } catch {
            return "[]"
        }
    }

    func exportBackupArchive() throws -> String {
        let archive = try makeBackupArchive(includeInlineAttachmentData: true)

        do {
            let data = try JSONEncoder.memoEncoder.encode(archive)
            return String(decoding: data, as: UTF8.self)
        } catch {
            throw MemoBackupArchiveError.encodingFailed
        }
    }

    func makeBackupArchive(includeInlineAttachmentData: Bool) throws -> MemoBackupArchive {
        let sortedMemos = memos.sorted { sortMemos($0, $1) }
        let attachments = try uniqueAttachments(in: sortedMemos).map { attachment -> MemoBackupAttachment in
            let base64Data: String?
            if includeInlineAttachmentData {
                guard let data = SharedAttachmentStore.data(for: attachment) else {
                    throw MemoBackupArchiveError.missingAttachmentData(attachment.filename)
                }
                base64Data = data.base64EncodedString()
            } else {
                guard SharedAttachmentStore.exists(attachment) else {
                    throw MemoBackupArchiveError.missingAttachmentData(attachment.filename)
                }
                base64Data = nil
            }
            return MemoBackupAttachment(
                filename: attachment.filename,
                relativePath: attachment.relativePath,
                typeIdentifier: attachment.typeIdentifier,
                base64Data: base64Data
            )
        }
        return MemoBackupArchive(
            version: 1,
            exportedAt: Date(),
            memos: sortedMemos,
            attachments: attachments
        )
    }

    func importJSON(_ text: String) throws -> Int {
        let data = Data(text.utf8)
        if let archive = try? JSONDecoder.memoDecoder.decode(MemoBackupArchive.self, from: data) {
            return try importBackupArchive(archive)
        }

        let incoming = try JSONDecoder.memoDecoder.decode([Memo].self, from: data)
        let previousMemos = memos
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

        if imported > 0, !saveAll() {
            memos = previousMemos
            return 0
        }

        return imported
    }

    func importBackupArchive(_ archive: MemoBackupArchive) throws -> Int {
        let previousMemos = memos
        let importableMemos = archive.memos.filter { memo in
            !memo.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !memos.contains(where: { $0.id == memo.id })
        }
        let existingReferencedAttachmentPaths = Set(memos.flatMap { memo in
            SharedAttachmentStore.attachments(in: memo.text).map(\.relativePath)
        })
        let importableReferencedAttachmentPaths = Set(importableMemos.flatMap { memo in
            SharedAttachmentStore.attachments(in: memo.text).map(\.relativePath)
        })
        var restoredAttachments: [String: SharedAttachment] = [:]
        var newlyRestoredAttachments: [SharedAttachment] = []

        func deleteNewlyRestoredAttachments() {
            newlyRestoredAttachments.forEach { SharedAttachmentStore.delete($0) }
        }

        func deleteUnreferencedNewlyRestoredAttachments() {
            newlyRestoredAttachments
                .filter { !existingReferencedAttachmentPaths.contains($0.relativePath) }
                .forEach { SharedAttachmentStore.delete($0) }
        }

        func attachmentFileExists(relativePath: String) -> Bool {
            let attachment = SharedAttachment(
                id: relativePath,
                filename: relativePath,
                relativePath: relativePath,
                typeIdentifier: "public.data",
                byteCount: 0
            )
            return SharedAttachmentStore.exists(attachment)
        }

        let missingExistingReferencedAttachmentPaths = Set(existingReferencedAttachmentPaths.filter { relativePath in
            !attachmentFileExists(relativePath: relativePath)
        })
        let attachmentPathsNeedingArchiveData = importableReferencedAttachmentPaths
            .union(missingExistingReferencedAttachmentPaths)

        do {
            for attachment in archive.attachments where attachmentPathsNeedingArchiveData.contains(attachment.relativePath) {
                guard let base64Data = attachment.base64Data,
                      let data = Data(base64Encoded: base64Data) else {
                    throw MemoBackupArchiveError.invalidAttachmentData(attachment.filename)
                }

                let originalAttachment = SharedAttachment(
                    id: attachment.relativePath,
                    filename: attachment.filename,
                    relativePath: attachment.relativePath,
                    typeIdentifier: attachment.typeIdentifier,
                    byteCount: data.count
                )
                let existedBeforeRestore = SharedAttachmentStore.exists(originalAttachment)
                let restored = try SharedAttachmentStore.restore(
                    data: data,
                    filename: attachment.filename,
                    relativePath: attachment.relativePath,
                    typeIdentifier: attachment.typeIdentifier
                )
                if !existedBeforeRestore || restored.relativePath != attachment.relativePath {
                    newlyRestoredAttachments.append(restored)
                }
                restoredAttachments[attachment.relativePath] = restored
            }

            let missingImportableAttachmentPaths = importableReferencedAttachmentPaths.filter { relativePath in
                restoredAttachments[relativePath] == nil
            }
            let missingExistingRepairAttachmentPaths = missingExistingReferencedAttachmentPaths.filter { relativePath in
                restoredAttachments[relativePath] == nil
            }
            let missingAttachmentPaths = missingImportableAttachmentPaths
                .union(missingExistingRepairAttachmentPaths)
            if let missingAttachmentPath = missingAttachmentPaths.sorted().first {
                throw MemoBackupArchiveError.missingAttachmentData(missingAttachmentPath)
            }

            var imported = 0
            for memo in importableMemos {
                var normalized = memo
                normalized.text = SharedAttachmentStore.replacingAttachmentReferences(
                    in: memo.text,
                    remapping: restoredAttachments
                )
                normalized.tags = TagParser.extractTags(from: normalized.text)
                memos.append(normalized)
                imported += 1
            }

            guard imported > 0 else {
                deleteUnreferencedNewlyRestoredAttachments()
                return 0
            }

            if !saveAll() {
                memos = previousMemos
                deleteNewlyRestoredAttachments()
                return 0
            }

            return imported
        } catch {
            memos = previousMemos
            deleteNewlyRestoredAttachments()
            throw error
        }
    }

    func importPlainText(_ text: String) -> Int {
        let chunks = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var imported = 0
        for chunk in chunks where addMemo(text: chunk) != nil {
            imported += 1
        }

        return imported
    }

    func addMemo(from url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }

        let text = components.queryItems?.first(where: { $0.name == "text" })?.value
            ?? components.queryItems?.first(where: { $0.name == "content" })?.value
            ?? components.host
            ?? ""
        addMemo(text: text)
    }

    func reloadFromStorage() {
        load()
        if let selectedTag = selectedTag, !allTags.contains(selectedTag) {
            self.selectedTag = nil
        }
    }

    private func sortMemos(_ lhs: Memo, _ rhs: Memo) -> Bool {
        if lhs.isPinned != rhs.isPinned {
            return lhs.isPinned && !rhs.isPinned
        }
        return lhs.createdAt > rhs.createdAt
    }

    private func sortMemos(
        _ lhs: Memo,
        _ rhs: Memo,
        searchRanks: [UUID: Int],
        query: MemoSearchQuery
    ) -> Bool {
        if lhs.isPinned != rhs.isPinned {
            return lhs.isPinned && !rhs.isPinned
        }

        guard query.hasTextTerms else {
            return lhs.createdAt > rhs.createdAt
        }

        let leftRank = searchRanks[lhs.id]
        let rightRank = searchRanks[rhs.id]

        if let leftRank = leftRank, let rightRank = rightRank, leftRank != rightRank {
            return leftRank < rightRank
        }

        if leftRank != nil, rightRank == nil {
            return true
        }

        if leftRank == nil, rightRank != nil {
            return false
        }

        return lhs.createdAt > rhs.createdAt
    }

    private func searchRanks(for query: MemoSearchQuery) -> [UUID: Int] {
        guard query.hasTextTerms, let database = database else {
            return [:]
        }

        do {
            return Dictionary(uniqueKeysWithValues: try database.searchIDs(matching: query.text).map { match in
                (match.id, match.rank)
            })
        } catch {
            return [:]
        }
    }

    private func matchesText(
        _ memo: Memo,
        query: MemoSearchQuery,
        searchRanks: [UUID: Int]
    ) -> Bool {
        guard query.hasTextTerms else {
            return true
        }

        if searchRanks[memo.id] != nil {
            return true
        }

        let searchableText = "\(memo.text) \(memo.tags.joined(separator: " "))"
        return query.textTerms.allSatisfy { term in
            searchableText.localizedCaseInsensitiveContains(term)
        }
    }

    private func matchesSelectedTag(_ memo: Memo) -> Bool {
        guard let selectedTag = selectedTag else {
            return true
        }

        return matchesTag(selectedTag, in: memo)
    }

    private func matchesTag(_ selectedTag: String, in memo: Memo) -> Bool {
        memo.tags.contains { tag in
            tag == selectedTag || tag.hasPrefix("\(selectedTag)/")
        }
    }

    private func matchesPinnedFilter(_ memo: Memo, query: MemoSearchQuery) -> Bool {
        guard let isPinned = query.isPinned else {
            return true
        }

        return memo.isPinned == isPinned
    }

    private func matchesArchiveFilter(_ memo: Memo, query: MemoSearchQuery) -> Bool {
        guard let isArchived = query.isArchived else {
            return true
        }

        return memo.isArchived == isArchived
    }

    private func load() {
        if let database = database {
            do {
                if try database.isEmpty(), let legacyMemos = loadLegacyMemos() {
                    try database.upsert(legacyMemos)
                }
                memos = try database.fetchAll()
                cleanupUnreferencedAttachments()
                return
            } catch {
                assertionFailure("Failed to load SQLite memos: \(error)")
            }
        }

        memos = loadLegacyMemos() ?? []
        cleanupUnreferencedAttachments()
    }

    private func loadLegacyMemos() -> [Memo]? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return loadBackupMemos()
        }

        do {
            return try decodeMemos(from: fileURL)
        } catch {
            return loadBackupMemos()
        }
    }

    @discardableResult
    private func save(_ memo: Memo) -> Bool {
        if let database = database {
            do {
                try database.upsert(memo)
                return true
            } catch {
                assertionFailure("Failed to save memo in SQLite: \(error)")
                return false
            }
        }

        return saveLegacyJSON()
    }

    @discardableResult
    private func saveAll() -> Bool {
        if let database = database {
            do {
                try database.upsert(memos)
                return true
            } catch {
                assertionFailure("Failed to save memos in SQLite: \(error)")
                return false
            }
        }

        return saveLegacyJSON()
    }

    private func deleteFromStorage(_ memo: Memo) -> Bool {
        if let database = database {
            do {
                try database.delete(id: memo.id)
                return true
            } catch {
                assertionFailure("Failed to delete memo in SQLite: \(error)")
                return false
            }
        }

        return saveLegacyJSON()
    }

    private func deleteRemovedAttachments(
        previousAttachments: [SharedAttachment],
        updatedAttachments: [SharedAttachment]
    ) {
        let updatedPaths = Set(updatedAttachments.map(\.relativePath))
        let removedAttachments = previousAttachments
            .filter { !updatedPaths.contains($0.relativePath) }
        deleteAttachmentsIfUnreferenced(removedAttachments)
    }

    private func deleteAttachmentsIfUnreferenced(_ attachments: [SharedAttachment]) {
        guard !attachments.isEmpty else { return }

        let referencedPaths = Set(memos.flatMap { memo in
            SharedAttachmentStore.attachments(in: memo.text).map(\.relativePath)
        })
        var seenPaths: Set<String> = []

        for attachment in attachments {
            guard seenPaths.insert(attachment.relativePath).inserted,
                  !referencedPaths.contains(attachment.relativePath) else {
                continue
            }
            SharedAttachmentStore.delete(attachment)
        }
    }

    private func uniqueAttachments(in memos: [Memo]) -> [SharedAttachment] {
        var seenPaths: Set<String> = []
        var result: [SharedAttachment] = []

        for memo in memos {
            for attachment in SharedAttachmentStore.attachments(in: memo.text) {
                guard !seenPaths.contains(attachment.relativePath) else { continue }
                seenPaths.insert(attachment.relativePath)
                result.append(attachment)
            }
        }

        return result
    }

    private func cleanupUnreferencedAttachments() {
        SharedAttachmentStore.deleteUnreferencedAttachments(
            referencedBy: memos.map(\.text)
        )
    }

    @discardableResult
    private func saveLegacyJSON() -> Bool {
        do {
            try writeBackupIfNeeded()
            let data = try JSONEncoder.memoEncoder.encode(memos)
            try data.write(to: fileURL, options: [.atomic])
            return true
        } catch {
            assertionFailure("Failed to save memos: \(error)")
            return false
        }
    }

    private func decodeMemos(from url: URL) throws -> [Memo] {
        let data = try Data(contentsOf: url)
        return try JSONDecoder.memoDecoder.decode([Memo].self, from: data)
    }

    private func loadBackupMemos() -> [Memo]? {
        guard FileManager.default.fileExists(atPath: backupFileURL.path) else {
            return nil
        }
        return try? decodeMemos(from: backupFileURL)
    }

    private func writeBackupIfNeeded() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        let currentData = try Data(contentsOf: fileURL)
        try currentData.write(to: backupFileURL, options: [.atomic])
    }
}

private enum MemoBackupArchiveError: LocalizedError {
    case invalidAttachmentData(String)
    case missingAttachmentData(String)
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidAttachmentData(let filename):
            return "完整备份中的附件“\(filename)”无法解析。"
        case .missingAttachmentData(let filename):
            return "完整备份缺少附件“\(filename)”。"
        case .encodingFailed:
            return "完整备份无法编码。"
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
