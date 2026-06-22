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
    @Published private(set) var revisionsByMemoID: [UUID: [MemoRevision]] = [:]
    @Published private(set) var assets: [MemoAsset] = []
    @Published private(set) var recentSearches: [String] = []
    @Published private(set) var savedSearches: [String] = []

    private let fileURL: URL
    private let backupFileURL: URL
    private let database: SQLiteMemoDatabase?
    private let storageError: Error?
    private let defaults: UserDefaults

    private static let recentSearchesKey = "some.search.recent"
    private static let savedSearchesKey = "some.search.saved"
    private static let maxRecentSearches = 8
    private static let maxSavedSearches = 16

    init(
        filename: String = "some-memos.json",
        storageRequirement: SharedMemoStorage.Requirement = .sharedContainerPreferred,
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults

        do {
            let storageURLs = try SharedMemoStorage.urls(
                filename: filename,
                requirement: storageRequirement
            )
            self.fileURL = storageURLs.fileURL
            self.backupFileURL = storageURLs.backupFileURL
            self.database = try? SQLiteMemoDatabase(databaseURL: storageURLs.databaseURL)
            self.storageError = nil
        } catch {
            let storageURLs = SharedMemoStorage.urls(filename: filename)
            self.fileURL = storageURLs.fileURL
            self.backupFileURL = storageURLs.backupFileURL
            self.database = nil
            self.storageError = error
        }

        loadSearchCollections()
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
                matchesContentFilters(memo, query: query)
            }
            .filter { memo in
                matchesDateFilters(memo, query: query)
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
        guard storageError == nil else {
            return nil
        }

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

    @discardableResult
    func update(_ memo: Memo, text: String) -> Bool {
        guard storageError == nil else {
            return false
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let index = memos.firstIndex(where: { $0.id == memo.id }) else { return false }
        guard trimmed != memos[index].text else { return true }

        let previousMemo = memos[index]
        let previousAttachments = SharedAttachmentStore.attachments(in: memos[index].text)
        let updatedAttachments = SharedAttachmentStore.attachments(in: trimmed)
        let revision = makeRevision(from: previousMemo)
        memos[index].text = trimmed
        memos[index].tags = TagParser.extractTags(from: trimmed)
        memos[index].updatedAt = Date()
        if save(memos[index], revision: revision) {
            deleteRemovedAttachments(previousAttachments: previousAttachments, updatedAttachments: updatedAttachments)
            return true
        } else {
            memos[index] = previousMemo
            return false
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
        let previousRevisions = revisionsByMemoID[memo.id] ?? []
        let attachmentsToDelete = SharedAttachmentStore.attachments(in: memos[index].text)
            + previousRevisions.flatMap { revision in
                SharedAttachmentStore.attachments(in: revision.text)
            }
        let removedMemo = memos.remove(at: index)
        if reviewMemo?.id == memo.id {
            reviewMemo = nil
        }
        revisionsByMemoID[memo.id] = nil
        if let selectedTag = selectedTag, !allTags.contains(selectedTag) {
            self.selectedTag = nil
        }
        if deleteFromStorage(removedMemo) {
            deleteAttachmentsIfUnreferenced(attachmentsToDelete)
        } else {
            memos.insert(removedMemo, at: index)
            reviewMemo = previousReviewMemo
            selectedTag = previousSelectedTag
            revisionsByMemoID[memo.id] = previousRevisions
        }
    }

    func revisions(for memo: Memo) -> [MemoRevision] {
        revisionsByMemoID[memo.id] ?? []
    }

    func assets(for memo: Memo) -> [MemoAsset] {
        assets
            .filter { $0.memoID == memo.id }
            .sorted { $0.kind.rawValue == $1.kind.rawValue ? $0.title < $1.title : $0.kind.rawValue < $1.kind.rawValue }
    }

    @discardableResult
    func restore(_ revision: MemoRevision, for memo: Memo) -> Bool {
        guard storageError == nil else {
            return false
        }

        guard revision.memoID == memo.id,
              let index = memos.firstIndex(where: { $0.id == memo.id }) else {
            return false
        }

        let currentMemo = memos[index]
        let restoredText = revision.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !restoredText.isEmpty else {
            return false
        }
        guard restoredText != currentMemo.text else {
            return true
        }

        let previousAttachments = SharedAttachmentStore.attachments(in: currentMemo.text)
        let restoredAttachments = SharedAttachmentStore.attachments(in: restoredText)
        let currentRevision = makeRevision(from: currentMemo)
        memos[index].text = restoredText
        memos[index].tags = TagParser.extractTags(from: restoredText)
        memos[index].updatedAt = Date()

        if save(memos[index], revision: currentRevision) {
            deleteRemovedAttachments(previousAttachments: previousAttachments, updatedAttachments: restoredAttachments)
            return true
        } else {
            memos[index] = currentMemo
            return false
        }
    }

    func clearTagFilter() {
        selectedTag = nil
    }

    var canSaveCurrentSearch: Bool {
        let query = normalizedSearch(searchText)
        return !query.isEmpty && !containsSearch(query, in: savedSearches)
    }

    func recordCurrentSearch() {
        recordSearch(searchText)
    }

    func applySearch(_ query: String) {
        searchText = normalizedSearch(query)
        recordCurrentSearch()
    }

    func saveCurrentSearch() {
        let query = normalizedSearch(searchText)
        guard !query.isEmpty else { return }

        savedSearches.removeAll { searchesMatch($0, query) }
        savedSearches.insert(query, at: 0)
        trimSearches(&savedSearches, limit: Self.maxSavedSearches)
        persistSavedSearches()
        recordSearch(query)
    }

    func removeSavedSearch(_ query: String) {
        savedSearches.removeAll { searchesMatch($0, query) }
        persistSavedSearches()
    }

    func clearRecentSearches() {
        recentSearches = []
        persistRecentSearches()
    }

    func clearSearch() {
        searchText = ""
    }

    func searchSnippet(for memo: Memo, contextLength: Int = 28) -> String? {
        let query = MemoSearchQueryParser.parse(searchText)
        guard query.hasTextTerms else { return nil }

        let displayText = SharedAttachmentStore
            .displayTextWithoutAttachmentReferences(memo.text)
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !displayText.isEmpty else { return nil }

        let terms = query.textTerms.sorted { $0.count > $1.count }
        for term in terms {
            if let range = displayText.range(
                of: term,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) {
                return excerpt(in: displayText, around: range, contextLength: contextLength)
            }
        }

        return excerptPrefix(displayText, maxLength: contextLength * 2 + 16)
    }

    func memoTitle(for memo: Memo) -> String {
        MemoReferenceParser.title(for: memo)
    }

    func referencedMemos(from memo: Memo) -> [Memo] {
        let referencedIDs = MemoReferenceParser.references(in: memo.text).map(\.memoID)
        return referencedIDs.compactMap { id in
            memos.first { $0.id == id }
        }
    }

    func backlinkMemos(to memo: Memo) -> [Memo] {
        memos
            .filter { candidate in
                candidate.id != memo.id
                    && MemoReferenceParser.references(in: candidate.text).contains { $0.memoID == memo.id }
            }
            .sorted { sortMemos($0, $1) }
    }

    func referenceCandidates(for memo: Memo) -> [Memo] {
        let existingIDs = Set(MemoReferenceParser.references(in: memo.text).map(\.memoID))
        return memos
            .filter { candidate in
                candidate.id != memo.id
                    && !candidate.isArchived
                    && !existingIDs.contains(candidate.id)
            }
            .sorted { sortMemos($0, $1) }
    }

    @discardableResult
    func addReference(from sourceMemo: Memo, to targetMemo: Memo) -> Bool {
        guard sourceMemo.id != targetMemo.id,
              memos.contains(where: { $0.id == targetMemo.id }) else {
            return false
        }

        let existingIDs = Set(MemoReferenceParser.references(in: sourceMemo.text).map(\.memoID))
        guard !existingIDs.contains(targetMemo.id) else {
            return true
        }

        let referenceLine = MemoReferenceParser.referenceLine(for: targetMemo)
        let separator = sourceMemo.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "\n\n"
        return update(sourceMemo, text: "\(sourceMemo.text)\(separator)\(referenceLine)")
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
        let sortedRevisions = revisionsByMemoID
            .values
            .flatMap { $0 }
            .sorted { $0.createdAt > $1.createdAt }
        let attachmentTexts = sortedMemos.map(\.text) + sortedRevisions.map(\.text)
        let attachments = try uniqueAttachments(in: attachmentTexts).map { attachment -> MemoBackupAttachment in
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
            attachments: attachments,
            revisions: sortedRevisions
        )
    }

    func importJSON(_ text: String) throws -> Int {
        if let storageError = storageError {
            throw storageError
        }

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
        if let storageError = storageError {
            throw storageError
        }

        let previousMemos = memos
        let previousRevisions = revisionsByMemoID
        let importableMemos = archive.memos.filter { memo in
            !memo.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !memos.contains(where: { $0.id == memo.id })
        }
        let importableMemoIDs = Set(importableMemos.map(\.id))
        let importableRevisions = archive.revisions.filter { revision in
            importableMemoIDs.contains(revision.memoID)
                && !revision.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let existingReferencedAttachmentPaths = Set(memos.flatMap { memo in
            SharedAttachmentStore.attachments(in: memo.text).map(\.relativePath)
        })
        let existingRevisionAttachmentPaths = Set(revisionsByMemoID.values.flatMap { revisions in
            revisions.flatMap { revision in
                SharedAttachmentStore.attachments(in: revision.text).map(\.relativePath)
            }
        })
        let importableReferencedAttachmentPaths = Set(importableMemos.flatMap { memo in
            SharedAttachmentStore.attachments(in: memo.text).map(\.relativePath)
        })
        let importableRevisionAttachmentPaths = Set(importableRevisions.flatMap { revision in
            SharedAttachmentStore.attachments(in: revision.text).map(\.relativePath)
        })
        var restoredAttachments: [String: SharedAttachment] = [:]
        var newlyRestoredAttachments: [SharedAttachment] = []

        func deleteNewlyRestoredAttachments() {
            newlyRestoredAttachments.forEach { SharedAttachmentStore.delete($0) }
        }

        func deleteUnreferencedNewlyRestoredAttachments() {
            newlyRestoredAttachments
                .filter {
                    !existingReferencedAttachmentPaths.contains($0.relativePath)
                        && !existingRevisionAttachmentPaths.contains($0.relativePath)
                }
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
        let missingExistingRevisionAttachmentPaths = Set(existingRevisionAttachmentPaths.filter { relativePath in
            !attachmentFileExists(relativePath: relativePath)
        })
        let attachmentPathsNeedingArchiveData = importableReferencedAttachmentPaths
            .union(importableRevisionAttachmentPaths)
            .union(missingExistingReferencedAttachmentPaths)
            .union(missingExistingRevisionAttachmentPaths)

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
            let missingImportableRevisionAttachmentPaths = importableRevisionAttachmentPaths.filter { relativePath in
                restoredAttachments[relativePath] == nil
            }
            let missingExistingRepairAttachmentPaths = missingExistingReferencedAttachmentPaths.filter { relativePath in
                restoredAttachments[relativePath] == nil
            }
            let missingExistingRevisionRepairAttachmentPaths = missingExistingRevisionAttachmentPaths.filter { relativePath in
                restoredAttachments[relativePath] == nil
            }
            let missingAttachmentPaths = missingImportableAttachmentPaths
                .union(missingImportableRevisionAttachmentPaths)
                .union(missingExistingRepairAttachmentPaths)
                .union(missingExistingRevisionRepairAttachmentPaths)
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

            for revision in importableRevisions {
                var normalized = revision
                normalized.text = SharedAttachmentStore.replacingAttachmentReferences(
                    in: revision.text,
                    remapping: restoredAttachments
                )
                normalized.tags = TagParser.extractTags(from: normalized.text)
                revisionsByMemoID[normalized.memoID, default: []].append(normalized)
            }
            sortRevisionCache()

            guard imported > 0 else {
                deleteUnreferencedNewlyRestoredAttachments()
                return 0
            }

            if !saveAll() {
                memos = previousMemos
                revisionsByMemoID = previousRevisions
                deleteNewlyRestoredAttachments()
                return 0
            }

            return imported
        } catch {
            memos = previousMemos
            revisionsByMemoID = previousRevisions
            deleteNewlyRestoredAttachments()
            throw error
        }
    }

    func importPlainText(_ text: String) -> Int {
        guard storageError == nil else {
            return 0
        }

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
        guard storageError == nil else {
            return
        }

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

    private func matchesContentFilters(_ memo: Memo, query: MemoSearchQuery) -> Bool {
        guard query.hasContentFilters else {
            return true
        }

        return query.requiredContentFilters.allSatisfy { matchesContentFilter($0, in: memo) }
            && query.excludedContentFilters.allSatisfy { !matchesContentFilter($0, in: memo) }
    }

    private func matchesContentFilter(_ filter: MemoContentFilter, in memo: Memo) -> Bool {
        switch filter {
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
            return !backlinkMemos(to: memo).isEmpty
        }
    }

    private func taskItems(in memo: Memo) -> [MemoTaskItem] {
        let displayText = MemoReferenceParser.displayTextWithoutReferences(
            SharedAttachmentStore.displayTextWithoutAttachmentReferences(memo.text)
        )
        return MemoTaskParser.taskItems(in: displayText)
    }

    private func matchesDateFilters(_ memo: Memo, query: MemoSearchQuery) -> Bool {
        guard query.hasDateFilters else {
            return true
        }

        return query.dateFilters.allSatisfy { matchesDateFilter($0, in: memo) }
    }

    private func matchesDateFilter(_ filter: MemoDateFilter, in memo: Memo) -> Bool {
        let date: Date
        switch filter.field {
        case .created:
            date = memo.createdAt
        case .updated:
            date = memo.updatedAt
        }

        switch filter.operation {
        case .on:
            return date >= filter.start && date < filter.end
        case .before:
            return date < filter.start
        case .onOrBefore:
            return date < filter.end
        case .after:
            return date >= filter.end
        case .onOrAfter:
            return date >= filter.start
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

    private func loadSearchCollections() {
        recentSearches = sanitizedSearches(
            defaults.stringArray(forKey: Self.recentSearchesKey) ?? [],
            limit: Self.maxRecentSearches
        )
        savedSearches = sanitizedSearches(
            defaults.stringArray(forKey: Self.savedSearchesKey) ?? [],
            limit: Self.maxSavedSearches
        )
    }

    private func recordSearch(_ rawQuery: String) {
        let query = normalizedSearch(rawQuery)
        guard !query.isEmpty else { return }

        recentSearches.removeAll { searchesMatch($0, query) }
        recentSearches.insert(query, at: 0)
        trimSearches(&recentSearches, limit: Self.maxRecentSearches)
        persistRecentSearches()
    }

    private func persistRecentSearches() {
        defaults.set(recentSearches, forKey: Self.recentSearchesKey)
    }

    private func persistSavedSearches() {
        defaults.set(savedSearches, forKey: Self.savedSearchesKey)
    }

    private func sanitizedSearches(_ searches: [String], limit: Int) -> [String] {
        var result: [String] = []

        for rawSearch in searches {
            let search = normalizedSearch(rawSearch)
            guard !search.isEmpty, !containsSearch(search, in: result) else { continue }
            result.append(search)
        }

        trimSearches(&result, limit: limit)
        return result
    }

    private func normalizedSearch(_ query: String) -> String {
        query
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func containsSearch(_ query: String, in searches: [String]) -> Bool {
        searches.contains { searchesMatch($0, query) }
    }

    private func searchesMatch(_ lhs: String, _ rhs: String) -> Bool {
        lhs.compare(rhs, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    private func trimSearches(_ searches: inout [String], limit: Int) {
        if searches.count > limit {
            searches.removeSubrange(limit..<searches.count)
        }
    }

    private func excerpt(
        in text: String,
        around range: Range<String.Index>,
        contextLength: Int
    ) -> String {
        let lowerBound = text.index(
            range.lowerBound,
            offsetBy: -contextLength,
            limitedBy: text.startIndex
        ) ?? text.startIndex
        let upperBound = text.index(
            range.upperBound,
            offsetBy: contextLength,
            limitedBy: text.endIndex
        ) ?? text.endIndex

        let prefix = lowerBound == text.startIndex ? "" : "..."
        let suffix = upperBound == text.endIndex ? "" : "..."
        return "\(prefix)\(text[lowerBound..<upperBound])\(suffix)"
    }

    private func excerptPrefix(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else {
            return text
        }

        let endIndex = text.index(text.startIndex, offsetBy: maxLength)
        return "\(text[text.startIndex..<endIndex])..."
    }

    private func load() {
        if storageError != nil {
            memos = []
            assets = []
            return
        }

        if let database = database {
            do {
                if try database.isEmpty(), let legacyMemos = loadLegacyMemos() {
                    try database.upsert(legacyMemos)
                }
                memos = try database.fetchAll()
                loadRevisions()
                loadAssets()
                cleanupUnreferencedAttachments()
                return
            } catch {
                assertionFailure("Failed to load SQLite memos: \(error)")
            }
        }

        memos = loadLegacyMemos() ?? []
        revisionsByMemoID = [:]
        assets = derivedAssets()
        cleanupUnreferencedAttachments()
    }

    private func loadRevisions() {
        guard let database = database else {
            revisionsByMemoID = [:]
            return
        }

        do {
            let revisions = try database.fetchAllRevisions()
            revisionsByMemoID = Dictionary(grouping: revisions, by: \.memoID)
            sortRevisionCache()
        } catch {
            assertionFailure("Failed to load memo revisions: \(error)")
            revisionsByMemoID = [:]
        }
    }

    private func loadAssets() {
        guard let database = database else {
            assets = derivedAssets()
            return
        }

        do {
            assets = try database.fetchAllAssets()
        } catch {
            assertionFailure("Failed to load memo assets: \(error)")
            assets = derivedAssets()
        }
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
    private func save(_ memo: Memo, revision: MemoRevision? = nil) -> Bool {
        if let database = database {
            do {
                try database.upsert(memo, revision: revision)
                if let revision = revision {
                    cache(revision)
                }
                loadAssets()
                return true
            } catch {
                assertionFailure("Failed to save memo in SQLite: \(error)")
                return false
            }
        }

        let saved = saveLegacyJSON()
        if saved {
            assets = derivedAssets()
        }
        return saved
    }

    @discardableResult
    private func saveAll() -> Bool {
        if let database = database {
            do {
                let revisions = revisionsByMemoID.values.flatMap { $0 }
                try database.replaceAll(memos: memos, revisions: revisions)
                loadAssets()
                return true
            } catch {
                assertionFailure("Failed to save memos in SQLite: \(error)")
                return false
            }
        }

        let saved = saveLegacyJSON()
        if saved {
            assets = derivedAssets()
        }
        return saved
    }

    private func deleteFromStorage(_ memo: Memo) -> Bool {
        if let database = database {
            do {
                try database.delete(id: memo.id)
                loadAssets()
                return true
            } catch {
                assertionFailure("Failed to delete memo in SQLite: \(error)")
                return false
            }
        }

        let saved = saveLegacyJSON()
        if saved {
            assets = derivedAssets()
        }
        return saved
    }

    private func derivedAssets() -> [MemoAsset] {
        memos
            .flatMap { MemoAsset.assets(in: $0) }
            .sorted { $0.createdAt == $1.createdAt ? $0.title < $1.title : $0.createdAt > $1.createdAt }
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

        let referencedPaths = referencedAttachmentPaths()
        var seenPaths: Set<String> = []

        for attachment in attachments {
            guard seenPaths.insert(attachment.relativePath).inserted,
                  !referencedPaths.contains(attachment.relativePath) else {
                continue
            }
            SharedAttachmentStore.delete(attachment)
        }
    }

    private func uniqueAttachments(in texts: [String]) -> [SharedAttachment] {
        var seenPaths: Set<String> = []
        var result: [SharedAttachment] = []

        for text in texts {
            for attachment in SharedAttachmentStore.attachments(in: text) {
                guard !seenPaths.contains(attachment.relativePath) else { continue }
                seenPaths.insert(attachment.relativePath)
                result.append(attachment)
            }
        }

        return result
    }

    private func cleanupUnreferencedAttachments() {
        SharedAttachmentStore.deleteUnreferencedAttachments(
            referencedBy: memos.map(\.text) + revisionsByMemoID.values.flatMap { $0.map(\.text) }
        )
    }

    private func referencedAttachmentPaths() -> Set<String> {
        let currentPaths = memos.flatMap { memo in
            SharedAttachmentStore.attachments(in: memo.text).map(\.relativePath)
        }
        let revisionPaths = revisionsByMemoID.values.flatMap { revisions in
            revisions.flatMap { revision in
                SharedAttachmentStore.attachments(in: revision.text).map(\.relativePath)
            }
        }
        return Set(currentPaths + revisionPaths)
    }

    private func makeRevision(from memo: Memo) -> MemoRevision {
        MemoRevision(
            memoID: memo.id,
            text: memo.text,
            tags: memo.tags,
            memoUpdatedAt: memo.updatedAt
        )
    }

    private func cache(_ revision: MemoRevision) {
        var revisions = revisionsByMemoID[revision.memoID] ?? []
        if !revisions.contains(where: { $0.id == revision.id }) {
            revisions.append(revision)
        }
        revisionsByMemoID[revision.memoID] = revisions.sorted { $0.createdAt > $1.createdAt }
    }

    private func sortRevisionCache() {
        for key in revisionsByMemoID.keys {
            revisionsByMemoID[key] = revisionsByMemoID[key]?.sorted { $0.createdAt > $1.createdAt }
        }
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
