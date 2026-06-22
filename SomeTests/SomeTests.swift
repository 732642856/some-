import UniformTypeIdentifiers
import XCTest
@testable import Some

@MainActor
final class SomeTests: XCTestCase {
    func testNestedTagExtraction() {
        let tags = TagParser.extractTags(from: "今天记录 #产品/输入 和 #写作-素材，还有重复 #产品/输入")
        XCTAssertEqual(tags, ["产品/输入", "写作-素材"])
    }

    func testArchiveIsExcludedFromTimeline() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        store.addMemo(text: "一条 #测试")

        guard let memo = store.memos.first else {
            return XCTFail("Expected memo")
        }

        store.toggleArchived(memo)
        XCTAssertTrue(store.filteredMemos.isEmpty)
        XCTAssertEqual(store.archivedMemos.count, 1)
    }

    func testJSONRoundTrip() throws {
        let source = MemoStore(filename: "test-\(UUID().uuidString).json")
        source.addMemo(text: "可以备份 #导出")
        let exported = source.exportJSON()

        let target = MemoStore(filename: "test-\(UUID().uuidString).json")
        let imported = try target.importJSON(exported)

        XCTAssertEqual(imported, 1)
        XCTAssertEqual(target.memos.first?.tags, ["导出"])
    }

    func testBackupArchiveRoundTripRestoresAttachments() throws {
        let source = MemoStore(filename: "test-\(UUID().uuidString).json")
        let attachment = try SharedAttachmentStore.save(
            data: Data("archive attachment".utf8),
            suggestedFilename: "archive-\(UUID().uuidString).txt",
            typeIdentifier: UTType.plainText.identifier
        )
        defer { SharedAttachmentStore.delete(attachment) }

        source.addMemo(text: "带附件备份 #导出\n\n\(attachment.referenceLine)")
        let exported = try source.exportBackupArchive()
        SharedAttachmentStore.delete(attachment)

        let target = MemoStore(filename: "test-\(UUID().uuidString).json")
        let imported = try target.importJSON(exported)

        XCTAssertEqual(imported, 1)
        let restoredAttachments = SharedAttachmentStore.attachments(in: target.memos.first?.text ?? "")
        XCTAssertEqual(restoredAttachments.count, 1)
        XCTAssertEqual(
            SharedAttachmentStore.data(for: restoredAttachments[0]),
            Data("archive attachment".utf8)
        )
        SharedAttachmentStore.delete(restoredAttachments[0])
    }

    func testBackupPackageRoundTripRestoresAttachments() throws {
        let source = MemoStore(filename: "test-\(UUID().uuidString).json")
        let attachment = try SharedAttachmentStore.save(
            data: Data("zip package attachment".utf8),
            suggestedFilename: "zip-\(UUID().uuidString).txt",
            typeIdentifier: UTType.plainText.identifier
        )
        defer { SharedAttachmentStore.delete(attachment) }

        source.addMemo(text: "ZIP 完整备份 #导出\n\n\(attachment.referenceLine)")
        let packageURL = try MemoBackupPackage.export(from: source)
        defer { try? FileManager.default.removeItem(at: packageURL) }
        XCTAssertEqual(packageURL.pathExtension, MemoBackupPackage.fileExtension)
        SharedAttachmentStore.delete(attachment)

        let target = MemoStore(filename: "test-\(UUID().uuidString).json")
        let imported = try MemoBackupPackage.importPackage(at: packageURL, into: target)

        XCTAssertEqual(imported, 1)
        let restoredAttachments = SharedAttachmentStore.attachments(in: target.memos.first?.text ?? "")
        XCTAssertEqual(restoredAttachments.count, 1)
        XCTAssertEqual(
            SharedAttachmentStore.data(for: restoredAttachments[0]),
            Data("zip package attachment".utf8)
        )
        SharedAttachmentStore.delete(restoredAttachments[0])
    }

    func testBackupArchiveRoundTripRestoresRevisionsAndTheirAttachments() throws {
        let source = MemoStore(filename: "test-\(UUID().uuidString).json")
        let attachment = try SharedAttachmentStore.save(
            data: Data("revision attachment".utf8),
            suggestedFilename: "revision-\(UUID().uuidString).txt",
            typeIdentifier: UTType.plainText.identifier
        )
        defer { SharedAttachmentStore.delete(attachment) }

        source.addMemo(text: "历史里有附件 #导出\n\n\(attachment.referenceLine)")
        guard let memo = source.memos.first else {
            return XCTFail("Expected memo")
        }
        XCTAssertTrue(source.update(memo, text: "当前正文 #导出"))

        let exported = try source.exportBackupArchive()
        SharedAttachmentStore.delete(attachment)

        let target = MemoStore(filename: "test-\(UUID().uuidString).json")
        let imported = try target.importJSON(exported)

        XCTAssertEqual(imported, 1)
        guard let importedMemo = target.memos.first,
              let importedRevision = target.revisions(for: importedMemo).first else {
            return XCTFail("Expected imported revision")
        }
        XCTAssertEqual(importedRevision.text, "历史里有附件 #导出\n\n\(attachment.referenceLine)")
        XCTAssertEqual(
            SharedAttachmentStore.data(for: attachment),
            Data("revision attachment".utf8)
        )
        SharedAttachmentStore.delete(attachment)
    }

    func testBackupPackageRoundTripRestoresRevisions() throws {
        let source = MemoStore(filename: "test-\(UUID().uuidString).json")
        source.addMemo(text: "ZIP 第一版 #历史")

        guard let memo = source.memos.first else {
            return XCTFail("Expected memo")
        }

        XCTAssertTrue(source.update(memo, text: "ZIP 第二版 #历史"))
        let packageURL = try MemoBackupPackage.export(from: source)
        defer { try? FileManager.default.removeItem(at: packageURL) }

        let target = MemoStore(filename: "test-\(UUID().uuidString).json")
        XCTAssertEqual(try MemoBackupPackage.importPackage(at: packageURL, into: target), 1)

        guard let importedMemo = target.memos.first else {
            return XCTFail("Expected imported memo")
        }

        XCTAssertEqual(target.revisions(for: importedMemo).first?.text, "ZIP 第一版 #历史")
    }

    func testBackupArchiveExportFailsWhenReferencedAttachmentIsMissing() throws {
        let source = MemoStore(filename: "test-\(UUID().uuidString).json")
        let attachment = try SharedAttachmentStore.save(
            data: Data("missing at export".utf8),
            suggestedFilename: "missing-export-\(UUID().uuidString).txt",
            typeIdentifier: UTType.plainText.identifier
        )
        source.addMemo(text: "导出前丢失附件\n\n\(attachment.referenceLine)")
        SharedAttachmentStore.delete(attachment)

        XCTAssertThrowsError(try source.exportBackupArchive())
    }

    func testBackupPackageExportFailsWhenReferencedAttachmentIsMissing() throws {
        let source = MemoStore(filename: "test-\(UUID().uuidString).json")
        let attachment = try SharedAttachmentStore.save(
            data: Data("missing zip export".utf8),
            suggestedFilename: "missing-package-\(UUID().uuidString).txt",
            typeIdentifier: UTType.plainText.identifier
        )
        source.addMemo(text: "ZIP 导出前丢失附件\n\n\(attachment.referenceLine)")
        SharedAttachmentStore.delete(attachment)

        XCTAssertThrowsError(try MemoBackupPackage.export(from: source))
    }

    func testBackupArchiveRejectsMissingAttachmentDataForImportedMemo() throws {
        let missingPath = "missing-\(UUID().uuidString).txt"
        let memo = Memo(
            text: "缺附件的备份\n\n[附件: missing.txt](some-attachment://\(missingPath))",
            tags: ["备份"]
        )
        let archive = MemoBackupArchive(
            version: 1,
            exportedAt: Date(),
            memos: [memo],
            attachments: []
        )
        let exported = String(
            decoding: try JSONEncoder.memoEncoder.encode(archive),
            as: UTF8.self
        )

        let target = MemoStore(filename: "test-\(UUID().uuidString).json")

        XCTAssertThrowsError(try target.importJSON(exported))
        XCTAssertTrue(target.memos.isEmpty)
    }

    func testBackupArchiveRejectsInvalidAttachmentDataWithoutPartialImport() throws {
        let relativePath = "invalid-\(UUID().uuidString).txt"
        let memo = Memo(
            text: "坏附件的备份\n\n[附件: invalid.txt](some-attachment://\(relativePath))",
            tags: ["备份"]
        )
        let archive = MemoBackupArchive(
            version: 1,
            exportedAt: Date(),
            memos: [memo],
            attachments: [
                MemoBackupAttachment(
                    filename: "invalid.txt",
                    relativePath: relativePath,
                    typeIdentifier: UTType.plainText.identifier,
                    base64Data: "not-base64"
                )
            ]
        )
        let exported = String(
            decoding: try JSONEncoder.memoEncoder.encode(archive),
            as: UTF8.self
        )

        let target = MemoStore(filename: "test-\(UUID().uuidString).json")

        XCTAssertThrowsError(try target.importJSON(exported))
        XCTAssertTrue(target.memos.isEmpty)
    }

    func testBackupArchiveCanRestoreMissingAttachmentForExistingMemo() throws {
        let attachment = try SharedAttachmentStore.save(
            data: Data("existing memo attachment".utf8),
            suggestedFilename: "existing-\(UUID().uuidString).txt",
            typeIdentifier: UTType.plainText.identifier
        )
        let memo = Memo(
            text: "已有记录缺附件\n\n\(attachment.referenceLine)",
            tags: ["备份"]
        )
        let archive = MemoBackupArchive(
            version: 1,
            exportedAt: Date(),
            memos: [memo],
            attachments: [
                MemoBackupAttachment(
                    filename: attachment.filename,
                    relativePath: attachment.relativePath,
                    typeIdentifier: attachment.typeIdentifier,
                    base64Data: Data("existing memo attachment".utf8).base64EncodedString()
                )
            ]
        )
        let legacyJSON = String(
            decoding: try JSONEncoder.memoEncoder.encode([memo]),
            as: UTF8.self
        )
        let exported = String(
            decoding: try JSONEncoder.memoEncoder.encode(archive),
            as: UTF8.self
        )

        let target = MemoStore(filename: "test-\(UUID().uuidString).json")
        XCTAssertEqual(try target.importJSON(legacyJSON), 1)
        SharedAttachmentStore.delete(attachment)

        XCTAssertEqual(try target.importJSON(exported), 0)
        XCTAssertEqual(
            SharedAttachmentStore.data(for: attachment),
            Data("existing memo attachment".utf8)
        )

        SharedAttachmentStore.delete(attachment)
    }

    func testBackupArchiveDoesNotRestoreUnreferencedDuplicateAttachment() throws {
        let relativePath = "unreferenced-\(UUID().uuidString).txt"
        let memo = Memo(text: "重复记录但没有附件", tags: ["备份"])
        let archive = MemoBackupArchive(
            version: 1,
            exportedAt: Date(),
            memos: [memo],
            attachments: [
                MemoBackupAttachment(
                    filename: "unreferenced.txt",
                    relativePath: relativePath,
                    typeIdentifier: UTType.plainText.identifier,
                    base64Data: Data("unused".utf8).base64EncodedString()
                )
            ]
        )
        let legacyJSON = String(
            decoding: try JSONEncoder.memoEncoder.encode([memo]),
            as: UTF8.self
        )
        let exported = String(
            decoding: try JSONEncoder.memoEncoder.encode(archive),
            as: UTF8.self
        )
        let attachment = SharedAttachment(
            id: relativePath,
            filename: "unreferenced.txt",
            relativePath: relativePath,
            typeIdentifier: UTType.plainText.identifier,
            byteCount: 0
        )

        let target = MemoStore(filename: "test-\(UUID().uuidString).json")
        XCTAssertEqual(try target.importJSON(legacyJSON), 1)

        XCTAssertEqual(try target.importJSON(exported), 0)
        XCTAssertFalse(SharedAttachmentStore.exists(attachment))
    }

    func testSQLitePersistsAcrossStoreInstances() throws {
        let filename = "test-\(UUID().uuidString).json"
        let store = MemoStore(filename: filename)
        store.addMemo(text: "第一条 #数据库")

        let reloaded = MemoStore(filename: filename)

        XCTAssertEqual(reloaded.memos.map(\.text), ["第一条 #数据库"])
        XCTAssertEqual(reloaded.memos.first?.tags, ["数据库"])
    }

    func testSharedStorageRequiresSharedContainerWhenConfigured() throws {
        let standardDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("standard-\(UUID().uuidString)", isDirectory: true)

        XCTAssertThrowsError(
            try SharedMemoStorage.resolveStorageDirectory(
                standardDirectory: standardDirectory,
                sharedDirectory: nil,
                appGroupIdentifier: "group.missing.some",
                requirement: .sharedContainerRequired
            )
        )
    }

    func testSharedStorageFallsBackWhenSharedContainerIsPreferred() throws {
        let standardDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("standard-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: standardDirectory) }

        let resolved = try SharedMemoStorage.resolveStorageDirectory(
            standardDirectory: standardDirectory,
            sharedDirectory: nil,
            appGroupIdentifier: "group.missing.some",
            requirement: .sharedContainerPreferred
        )

        XCTAssertEqual(resolved.path, standardDirectory.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: standardDirectory.path))
    }

    func testSQLiteMigrationFallsBackToBackupWhenMainJSONIsCorrupt() throws {
        let filename = "test-\(UUID().uuidString).json"
        let fileURL = documentsURL().appendingPathComponent(filename)
        let backupURL = fileURL
            .deletingPathExtension()
            .appendingPathExtension("bak.json")
        let memo = Memo(text: "备份里还有这一条 #安全", tags: ["安全"])
        let backupData = try JSONEncoder.memoEncoder.encode([memo])

        try Data("not json".utf8).write(to: fileURL, options: [.atomic])
        try backupData.write(to: backupURL, options: [.atomic])

        let store = MemoStore(filename: filename)

        XCTAssertEqual(store.memos.map(\.text), ["备份里还有这一条 #安全"])

        let reloaded = MemoStore(filename: filename)
        XCTAssertEqual(reloaded.memos.map(\.text), ["备份里还有这一条 #安全"])
    }

    func testPlainTextImportSplitsByBlankLine() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let count = store.importPlainText("第一条 #a\n\n第二条 #b")

        XCTAssertEqual(count, 2)
        XCTAssertEqual(store.activeCount, 2)
    }

    func testAddMemoTrimsIntentStyleInputAndKeepsTags() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let memo = store.addMemo(text: "  快捷指令记录 #输入/系统  \n")

        XCTAssertEqual(memo?.text, "快捷指令记录 #输入/系统")
        XCTAssertEqual(store.memos.first?.tags, ["输入/系统"])
    }

    func testAddMemoIgnoresEmptyIntentStyleInput() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let memo = store.addMemo(text: " \n\t ")

        XCTAssertNil(memo)
        XCTAssertTrue(store.memos.isEmpty)
    }

    func testSearchQueryParserExtractsTagsAndStateFilters() {
        let query = MemoSearchQueryParser.parse(#""输入体验" #产品/输入 is:pinned is:active"#)

        XCTAssertEqual(query.textTerms, ["输入体验"])
        XCTAssertEqual(query.tagFilters, ["产品/输入"])
        XCTAssertEqual(query.isPinned, true)
        XCTAssertEqual(query.isArchived, false)
    }

    func testSearchCanFilterByTagAndPinnedState() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        store.addMemo(text: "优化输入体验 #产品/输入")
        store.addMemo(text: "周末买菜 #生活")

        guard let productMemo = store.memos.first(where: { $0.text.contains("优化输入体验") }) else {
            return XCTFail("Expected product memo")
        }

        store.togglePinned(productMemo)
        store.searchText = "#产品 is:pinned 输入"

        XCTAssertEqual(store.filteredMemos.map(\.text), ["优化输入体验 #产品/输入"])
    }

    func testSearchCanIncludeArchivedFromQuery() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        store.addMemo(text: "旧项目复盘 #项目")

        guard let memo = store.memos.first else {
            return XCTFail("Expected memo")
        }

        store.toggleArchived(memo)
        store.searchText = "is:archived 复盘"

        XCTAssertEqual(store.filteredMemos.map(\.text), ["旧项目复盘 #项目"])
    }

    func testSearchIndexTracksUpdatesAndDeletes() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        store.addMemo(text: "初始内容 #草稿")

        guard let memo = store.memos.first else {
            return XCTFail("Expected memo")
        }

        XCTAssertTrue(store.update(memo, text: "最终内容 #发布"))
        store.searchText = "最终 发布"
        XCTAssertEqual(store.filteredMemos.map(\.text), ["最终内容 #发布"])

        if let updatedMemo = store.memos.first {
            store.delete(updatedMemo)
        }

        XCTAssertTrue(store.filteredMemos.isEmpty)
    }

    func testMemoUpdateRejectsEmptyTextAndKeepsExistingMemo() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        store.addMemo(text: "保留原文 #编辑")

        guard let memo = store.memos.first else {
            return XCTFail("Expected memo")
        }

        XCTAssertFalse(store.update(memo, text: "   \n\t"))
        XCTAssertEqual(store.memos.first?.text, "保留原文 #编辑")
        XCTAssertEqual(store.memos.first?.tags, ["编辑"])
    }

    func testMemoUpdateReturnsFalseForMissingMemo() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let missingMemo = Memo(text: "不在当前仓库里", tags: [])

        XCTAssertFalse(store.update(missingMemo, text: "不会保存"))
        XCTAssertTrue(store.memos.isEmpty)
    }

    func testMemoUpdateCreatesRestorableRevision() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        store.addMemo(text: "第一版 #历史")

        guard let memo = store.memos.first else {
            return XCTFail("Expected memo")
        }

        XCTAssertTrue(store.update(memo, text: "第二版 #历史"))

        guard let updatedMemo = store.memos.first else {
            return XCTFail("Expected updated memo")
        }
        let revisions = store.revisions(for: updatedMemo)
        XCTAssertEqual(revisions.count, 1)
        XCTAssertEqual(revisions.first?.text, "第一版 #历史")
        XCTAssertEqual(revisions.first?.tags, ["历史"])
    }

    func testMemoUpdateDoesNotCreateRevisionWhenTextIsUnchanged() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        store.addMemo(text: "不变内容 #历史")

        guard let memo = store.memos.first else {
            return XCTFail("Expected memo")
        }

        XCTAssertTrue(store.update(memo, text: "不变内容 #历史"))

        guard let unchangedMemo = store.memos.first else {
            return XCTFail("Expected unchanged memo")
        }
        XCTAssertTrue(store.revisions(for: unchangedMemo).isEmpty)
    }

    func testMemoRestoreCreatesReverseRevision() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        store.addMemo(text: "原始内容 #历史")

        guard let memo = store.memos.first else {
            return XCTFail("Expected memo")
        }

        XCTAssertTrue(store.update(memo, text: "当前内容 #恢复"))
        guard let updatedMemo = store.memos.first,
              let revision = store.revisions(for: updatedMemo).first else {
            return XCTFail("Expected revision")
        }

        XCTAssertTrue(store.restore(revision, for: updatedMemo))

        guard let restoredMemo = store.memos.first else {
            return XCTFail("Expected restored memo")
        }
        XCTAssertEqual(restoredMemo.text, "原始内容 #历史")
        XCTAssertEqual(restoredMemo.tags, ["历史"])
        XCTAssertTrue(store.revisions(for: restoredMemo).contains { $0.text == "当前内容 #恢复" })
    }

    func testMemoRevisionsPersistAcrossStoreReloads() {
        let filename = "test-\(UUID().uuidString).json"
        let source = MemoStore(filename: filename)
        source.addMemo(text: "重载前 #历史")

        guard let memo = source.memos.first else {
            return XCTFail("Expected memo")
        }

        XCTAssertTrue(source.update(memo, text: "重载后 #历史"))

        let reloaded = MemoStore(filename: filename)
        guard let reloadedMemo = reloaded.memos.first else {
            return XCTFail("Expected reloaded memo")
        }

        XCTAssertEqual(reloaded.revisions(for: reloadedMemo).first?.text, "重载前 #历史")
    }

    func testMemoTaskParserFindsMarkdownTasks() {
        let items = MemoTaskParser.taskItems(in: "今天要处理\n- [ ] 写发布说明\n  - [x] 检查截图")

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].lineIndex, 1)
        XCTAssertFalse(items[0].isCompleted)
        XCTAssertEqual(items[0].text, "写发布说明")
        XCTAssertEqual(items[1].lineIndex, 2)
        XCTAssertTrue(items[1].isCompleted)
        XCTAssertEqual(items[1].text, "检查截图")
    }

    func testMemoTaskParserTogglesTaskState() {
        let text = "第一行\n- [ ] 写发布说明\n- [x] 已完成"

        let checked = MemoTaskParser.toggleTask(atLine: 1, in: text)
        XCTAssertEqual(checked, "第一行\n- [x] 写发布说明\n- [x] 已完成")

        let unchecked = MemoTaskParser.toggleTask(atLine: 2, in: checked)
        XCTAssertEqual(unchecked, "第一行\n- [x] 写发布说明\n- [ ] 已完成")
    }

    func testStoreToggleTaskUpdatesMemoTextAndTags() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        store.addMemo(text: "- [ ] 跟进 #产品\n普通行")

        guard let memo = store.memos.first else {
            return XCTFail("Expected memo")
        }

        store.toggleTask(memo, lineIndex: 0)

        XCTAssertEqual(store.memos.first?.text, "- [x] 跟进 #产品\n普通行")
        XCTAssertEqual(store.memos.first?.tags, ["产品"])
    }

    func testDailyStatsIncludesToday() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        store.addMemo(text: "今天的记录")

        let stats = store.dailyStats(lastDays: 7)

        XCTAssertEqual(stats.count, 7)
        XCTAssertEqual(stats.last?.count, 1)
    }

    func testCosineSimilarityRanksIdenticalVectorsHighest() {
        let same = SemanticSearchEngine.cosineSimilarity([1, 0, 1], [1, 0, 1])
        let different = SemanticSearchEngine.cosineSimilarity([1, 0, 1], [0, 1, 0])

        XCTAssertGreaterThan(same, different)
        XCTAssertEqual(same, 1, accuracy: 0.0001)
    }

    func testInsightPromptKeepsProvidedMemoContent() {
        let memo = Memo(
            text: "下午整理产品灵感 #产品",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            tags: ["产品"]
        )

        let prompt = AIInsightComposer.prompt(mode: .weeklyReview, memos: [memo], focus: "")

        XCTAssertTrue(prompt.contains("AI 洞察"))
        XCTAssertTrue(prompt.contains("下午整理产品灵感 #产品"))
        XCTAssertTrue(prompt.contains("不要编造事实"))
    }

    func testInsightRangeExcludesArchivedMemos() {
        let active = Memo(text: "保留", createdAt: Date(), isArchived: false)
        let archived = Memo(text: "归档", createdAt: Date(), isArchived: true)

        let filtered = AIInsightRange.all.filter([active, archived])

        XCTAssertEqual(filtered.map(\.text), ["保留"])
    }

    func testAppLockStartsLockedWhenPreviouslyEnabled() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        defaults.set(true, forKey: "some.appLock.isEnabled")

        let appLock = AppLockManager(defaults: defaults)

        XCTAssertTrue(appLock.isEnabled)
        XCTAssertTrue(appLock.isLocked)
    }

    func testReminderDefaultsToEveningReviewTime() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let reminders = ReminderManager(defaults: defaults)
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminders.reminderDate)

        XCTAssertFalse(reminders.isEnabled)
        XCTAssertEqual(components.hour, 21)
        XCTAssertEqual(components.minute, 30)
    }

    func testLinkExtractorDeduplicatesURLs() {
        let urls = LinkExtractor.urls(in: "资料 https://example.com/a 和 https://example.com/a")

        XCTAssertEqual(urls.map(\.absoluteString), ["https://example.com/a"])
        XCTAssertEqual(LinkExtractor.displayText(for: urls[0]), "example.com")
    }

    func testLinkExtractorIgnoresAttachmentReferences() {
        let text = "资料 https://example.com/a\n\n[附件: image.png](some-attachment://image.png)"
        let urls = LinkExtractor.urls(in: text)

        XCTAssertEqual(urls.map(\.absoluteString), ["https://example.com/a"])
    }

    func testSharedMemoComposerKeepsTextAndDeduplicatesURL() {
        let text = SharedMemoTextComposer.compose(
            texts: ["  这是一段摘录  "],
            urls: [
                URL(string: "https://example.com/a")!,
                URL(string: "https://example.com/a")!
            ]
        )

        XCTAssertEqual(text, "这是一段摘录\n\nhttps://example.com/a")
    }

    func testSharedMemoComposerDoesNotAppendURLAlreadyInText() {
        let text = SharedMemoTextComposer.compose(
            texts: ["资料 https://example.com/a"],
            urls: [URL(string: "https://example.com/a")!]
        )

        XCTAssertEqual(text, "资料 https://example.com/a")
    }

    func testSharedMemoComposerAppendsAttachmentReferences() {
        let attachment = SharedAttachment(
            id: "image.png",
            filename: "image.png",
            relativePath: "image.png",
            typeIdentifier: UTType.png.identifier,
            byteCount: 12
        )
        let text = SharedMemoTextComposer.compose(texts: ["截图"], urls: [], attachments: [attachment])

        XCTAssertEqual(text, "截图\n\n[附件: image.png](some-attachment://image.png)")
    }

    func testAttachmentStoreParsesReferencesAndStripsDisplayText() {
        let text = "截图备忘 #素材\n\n[附件: image.png](some-attachment://image.png)"
        let attachments = SharedAttachmentStore.attachments(in: text)

        XCTAssertEqual(attachments.map(\.filename), ["image.png"])
        XCTAssertEqual(
            SharedAttachmentStore.displayTextWithoutAttachmentReferences(text),
            "截图备忘 #素材"
        )
    }

    func testAttachmentStoreMapsVisibleLineToOriginalLine() {
        let text = "第一行\n[附件: image.png](some-attachment://image.png)\n- [ ] 任务"

        XCTAssertEqual(
            SharedAttachmentStore.originalLineIndex(forVisibleLine: 1, in: text),
            2
        )
    }

    func testAttachmentStoreMapsVisibleLineAfterTrimmingBlankLines() {
        let text = "\n\n[附件: image.png](some-attachment://image.png)\n- [ ] 任务"

        XCTAssertEqual(SharedAttachmentStore.displayTextWithoutAttachmentReferences(text), "- [ ] 任务")
        XCTAssertEqual(
            SharedAttachmentStore.originalLineIndex(forVisibleLine: 0, in: text),
            3
        )
    }

    func testAttachmentStoreRejectsUnsafeReferencePaths() {
        let text = "[附件: bad.txt](some-attachment://..%2Fsome-memos.sqlite)"

        XCTAssertTrue(SharedAttachmentStore.attachments(in: text).isEmpty)
    }

    func testAttachmentStoreSavesUniqueFilenames() throws {
        let first = try SharedAttachmentStore.save(
            data: Data("first".utf8),
            suggestedFilename: "same-name.txt",
            typeIdentifier: UTType.plainText.identifier
        )
        let second = try SharedAttachmentStore.save(
            data: Data("second".utf8),
            suggestedFilename: "same-name.txt",
            typeIdentifier: UTType.plainText.identifier
        )
        defer {
            SharedAttachmentStore.delete(first)
            SharedAttachmentStore.delete(second)
        }

        XCTAssertEqual(first.filename, "same-name.txt")
        XCTAssertEqual(second.filename, "same-name-2.txt")
    }

    func testAttachmentStoreCopiesFileAttachmentsWithoutChangingSource() throws {
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("shared-source-\(UUID().uuidString).txt")
        try Data("copied from file".utf8).write(to: sourceURL, options: [.atomic])
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let attachment = try SharedAttachmentStore.save(
            fileAt: sourceURL,
            suggestedFilename: "file-copy.txt",
            typeIdentifier: UTType.plainText.identifier
        )
        defer { SharedAttachmentStore.delete(attachment) }

        XCTAssertEqual(attachment.filename, "file-copy.txt")
        XCTAssertEqual(attachment.byteCount, Data("copied from file".utf8).count)
        XCTAssertEqual(SharedAttachmentStore.data(for: attachment), Data("copied from file".utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
    }

    func testMemoUpdateDeletesRemovedAttachmentFile() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let attachment = try SharedAttachmentStore.save(
            data: Data("temporary".utf8),
            suggestedFilename: "removed-\(UUID().uuidString).txt",
            typeIdentifier: UTType.plainText.identifier
        )
        guard let attachmentURL = SharedAttachmentStore.url(for: attachment) else {
            return XCTFail("Expected attachment URL")
        }
        store.addMemo(text: "保留正文\n\n\(attachment.referenceLine)")

        guard let memo = store.memos.first else {
            return XCTFail("Expected memo")
        }

        XCTAssertTrue(store.update(memo, text: "保留正文"))

        XCTAssertFalse(FileManager.default.fileExists(atPath: attachmentURL.path))
    }

    func testMemoUpdateKeepsAttachmentReferencedByAnotherMemo() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let attachment = try SharedAttachmentStore.save(
            data: Data("shared".utf8),
            suggestedFilename: "shared-update-\(UUID().uuidString).txt",
            typeIdentifier: UTType.plainText.identifier
        )
        defer { SharedAttachmentStore.delete(attachment) }
        guard let attachmentURL = SharedAttachmentStore.url(for: attachment) else {
            return XCTFail("Expected attachment URL")
        }
        store.addMemo(text: "第一条引用\n\n\(attachment.referenceLine)")
        store.addMemo(text: "第二条引用\n\n\(attachment.referenceLine)")

        guard let firstMemo = store.memos.first(where: { $0.text.contains("第一条引用") }) else {
            return XCTFail("Expected first memo")
        }

        XCTAssertTrue(store.update(firstMemo, text: "第一条移除附件"))

        XCTAssertTrue(FileManager.default.fileExists(atPath: attachmentURL.path))
    }

    func testMemoUpdateKeepsAttachmentReferencedByRevision() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let attachment = try SharedAttachmentStore.save(
            data: Data("revision referenced".utf8),
            suggestedFilename: "revision-kept-\(UUID().uuidString).txt",
            typeIdentifier: UTType.plainText.identifier
        )
        defer { SharedAttachmentStore.delete(attachment) }
        guard let attachmentURL = SharedAttachmentStore.url(for: attachment) else {
            return XCTFail("Expected attachment URL")
        }
        store.addMemo(text: "第一版带附件\n\n\(attachment.referenceLine)")

        guard let memo = store.memos.first else {
            return XCTFail("Expected memo")
        }

        XCTAssertTrue(store.update(memo, text: "第二版移除附件"))

        XCTAssertTrue(FileManager.default.fileExists(atPath: attachmentURL.path))
        XCTAssertEqual(store.revisions(for: store.memos[0]).first?.text, "第一版带附件\n\n\(attachment.referenceLine)")
    }

    func testMemoDeleteDeletesAttachmentAfterStorageDeleteSucceeds() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let attachment = try SharedAttachmentStore.save(
            data: Data("temporary".utf8),
            suggestedFilename: "deleted-\(UUID().uuidString).txt",
            typeIdentifier: UTType.plainText.identifier
        )
        guard let attachmentURL = SharedAttachmentStore.url(for: attachment) else {
            return XCTFail("Expected attachment URL")
        }
        store.addMemo(text: "准备删除\n\n\(attachment.referenceLine)")

        guard let memo = store.memos.first else {
            return XCTFail("Expected memo")
        }

        store.delete(memo)

        XCTAssertFalse(FileManager.default.fileExists(atPath: attachmentURL.path))
    }

    func testMemoDeleteKeepsAttachmentReferencedByAnotherMemo() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let attachment = try SharedAttachmentStore.save(
            data: Data("shared delete".utf8),
            suggestedFilename: "shared-delete-\(UUID().uuidString).txt",
            typeIdentifier: UTType.plainText.identifier
        )
        defer { SharedAttachmentStore.delete(attachment) }
        guard let attachmentURL = SharedAttachmentStore.url(for: attachment) else {
            return XCTFail("Expected attachment URL")
        }
        store.addMemo(text: "准备删除\n\n\(attachment.referenceLine)")
        store.addMemo(text: "仍然保留\n\n\(attachment.referenceLine)")

        guard let memo = store.memos.first(where: { $0.text.contains("准备删除") }) else {
            return XCTFail("Expected memo")
        }

        store.delete(memo)

        XCTAssertTrue(FileManager.default.fileExists(atPath: attachmentURL.path))
    }

    func testAttachmentCleanupKeepsReferencedAndRecentFiles() throws {
        let referenced = try SharedAttachmentStore.save(
            data: Data("referenced".utf8),
            suggestedFilename: "referenced-\(UUID().uuidString).txt",
            typeIdentifier: UTType.plainText.identifier
        )
        let oldUnreferenced = try SharedAttachmentStore.save(
            data: Data("old".utf8),
            suggestedFilename: "old-\(UUID().uuidString).txt",
            typeIdentifier: UTType.plainText.identifier
        )
        let recentUnreferenced = try SharedAttachmentStore.save(
            data: Data("recent".utf8),
            suggestedFilename: "recent-\(UUID().uuidString).txt",
            typeIdentifier: UTType.plainText.identifier
        )

        guard let referencedURL = SharedAttachmentStore.url(for: referenced),
              let oldURL = SharedAttachmentStore.url(for: oldUnreferenced),
              let recentURL = SharedAttachmentStore.url(for: recentUnreferenced) else {
            return XCTFail("Expected attachment URLs")
        }
        defer {
            SharedAttachmentStore.delete(referenced)
            SharedAttachmentStore.delete(oldUnreferenced)
            SharedAttachmentStore.delete(recentUnreferenced)
        }

        let now = Date()
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-172_800)],
            ofItemAtPath: oldURL.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: now],
            ofItemAtPath: recentURL.path
        )

        SharedAttachmentStore.deleteUnreferencedAttachments(
            referencedBy: ["正文\n\n\(referenced.referenceLine)"],
            olderThan: 86_400,
            now: now
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: referencedURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: recentURL.path))
    }

    private func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }
}
