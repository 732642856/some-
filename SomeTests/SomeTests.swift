import UniformTypeIdentifiers
import UIKit
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

    func testSharedAttachmentMediaTypeFlags() {
        let image = SharedAttachment(id: "a", filename: "a.jpg", relativePath: "a.jpg", typeIdentifier: UTType.jpeg.identifier, byteCount: 1)
        let video = SharedAttachment(id: "b", filename: "b.mov", relativePath: "b.mov", typeIdentifier: UTType.movie.identifier, byteCount: 1)
        let audio = SharedAttachment(id: "c", filename: "c.m4a", relativePath: "c.m4a", typeIdentifier: UTType.mpeg4Audio.identifier, byteCount: 1)
        let text = SharedAttachment(id: "d", filename: "d.txt", relativePath: "d.txt", typeIdentifier: UTType.plainText.identifier, byteCount: 1)

        XCTAssertTrue(image.isImage)
        XCTAssertFalse(image.isVideo)
        XCTAssertFalse(image.isAudio)
        XCTAssertTrue(video.isVideo)
        XCTAssertFalse(video.isImage)
        XCTAssertFalse(video.isAudio)
        XCTAssertTrue(audio.isAudio)
        XCTAssertFalse(audio.isImage)
        XCTAssertFalse(audio.isVideo)
        XCTAssertFalse(text.isImage)
        XCTAssertFalse(text.isVideo)
        XCTAssertFalse(text.isAudio)
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

    func testURLSchemeAddCreatesMemoFromTextQuery() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let handled = store.handleURL(URL(string: "some://add?text=%E5%BF%AB%E9%80%9F%E8%AE%B0%E5%BD%95%20%23url")!)

        XCTAssertTrue(handled)
        XCTAssertEqual(store.memos.first?.text, "快速记录 #url")
        XCTAssertEqual(store.memos.first?.tags, ["url"])
        XCTAssertEqual(store.homeMode, .timeline)
    }

    func testURLSchemeSearchAppliesQueryWithoutCreatingMemo() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        store.addMemo(text: "项目记录 #项目")

        let handled = store.handleURL(URL(string: "some://search?q=%23%E9%A1%B9%E7%9B%AE%20is:active")!)

        XCTAssertTrue(handled)
        XCTAssertEqual(store.searchText, "#项目 is:active")
        XCTAssertEqual(store.recentSearches.first, "#项目 is:active")
        XCTAssertEqual(store.activeCount, 1)
        XCTAssertEqual(store.homeMode, .timeline)
    }

    func testURLSchemeIgnoresEmptyAndUnknownActions() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")

        XCTAssertFalse(store.handleURL(URL(string: "some://add?text=%20%20")!))
        XCTAssertFalse(store.handleURL(URL(string: "some://search?q=%20")!))
        XCTAssertFalse(store.handleURL(URL(string: "other://add?text=%E8%AE%B0%E5%BD%95")!))
        XCTAssertTrue(store.memos.isEmpty)
    }

    func testSearchQueryParserExtractsTagsAndStateFilters() {
        let query = MemoSearchQueryParser.parse(#""输入体验" #产品/输入 is:pinned is:active"#)

        XCTAssertEqual(query.textTerms, ["输入体验"])
        XCTAssertEqual(query.tagFilters, ["产品/输入"])
        XCTAssertEqual(query.isPinned, true)
        XCTAssertEqual(query.isArchived, false)
    }

    func testSearchQueryParserExtractsContentFilters() {
        let query = MemoSearchQueryParser.parse("has:link has:web has:clip has:ocr has:image-edit has:attachment has:reference has:scrapbook has:worklog has:project-report has:audio has:video has:wardrobe has:outfit has:wear-log has:laundry-log has:packing-list no:task without:backlink 复盘")

        XCTAssertEqual(query.textTerms, ["复盘"])
        XCTAssertEqual(
            Set(query.requiredContentFilters),
            Set([.attachment, .audio, .clipFragment, .imageEdit, .laundryLog, .link, .outfit, .packingList, .reference, .scrapbook, .screenshot, .video, .wardrobe, .webClip, .wearLog, .workLog])
        )
        XCTAssertEqual(
            Set(query.excludedContentFilters),
            Set([.backlink, .task])
        )
    }

    func testSearchQueryParserExtractsChineseWorkLogAliases() {
        let query = MemoSearchQueryParser.parse("has:项目汇报 has:复盘日志")

        XCTAssertEqual(query.requiredContentFilters, [.workLog])
        XCTAssertTrue(query.textTerms.isEmpty)
    }

    func testSearchQueryParserKeepsUnknownContentFiltersAsText() {
        let query = MemoSearchQueryParser.parse("has:unknown 资料")

        XCTAssertEqual(query.textTerms, ["has:unknown", "资料"])
        XCTAssertTrue(query.requiredContentFilters.isEmpty)
    }

    func testSearchQueryParserExtractsDateFilters() {
        let query = MemoSearchQueryParser.parse("created:2026-06 updated:>=2026-06-22 复盘")

        XCTAssertEqual(query.textTerms, ["复盘"])
        XCTAssertEqual(query.dateFilters.count, 2)
        XCTAssertTrue(
            query.dateFilters.contains {
                $0.field == .created
                    && $0.operation == .on
                    && Calendar.current.component(.month, from: $0.start) == 6
            }
        )
        XCTAssertTrue(
            query.dateFilters.contains {
                $0.field == .updated
                    && $0.operation == .onOrAfter
                    && Calendar.current.component(.day, from: $0.start) == 22
            }
        )
    }

    func testSearchQueryParserKeepsInvalidDateFiltersAsText() {
        let query = MemoSearchQueryParser.parse("created:2026-02-31 updated:soon")

        XCTAssertEqual(query.textTerms, ["created:2026-02-31", "updated:soon"])
        XCTAssertTrue(query.dateFilters.isEmpty)
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

    func testSearchCanFilterByCreatedDate() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        try importMemos([
            Memo(text: "五月记录 #日期", createdAt: makeDate(year: 2026, month: 5, day: 31), tags: ["日期"]),
            Memo(text: "六月记录 #日期", createdAt: makeDate(year: 2026, month: 6, day: 15), tags: ["日期"]),
            Memo(text: "七月记录 #日期", createdAt: makeDate(year: 2026, month: 7, day: 1), tags: ["日期"])
        ], into: store)

        store.searchText = "created:2026-06"
        XCTAssertEqual(store.filteredMemos.map(\.text), ["六月记录 #日期"])

        store.searchText = "created:<2026-06"
        XCTAssertEqual(store.filteredMemos.map(\.text), ["五月记录 #日期"])

        store.searchText = "created:>=2026-06"
        XCTAssertEqual(Set(store.filteredMemos.map(\.text)), ["六月记录 #日期", "七月记录 #日期"])
    }

    func testSearchCanFilterByUpdatedDateAndText() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        try importMemos([
            Memo(
                text: "旧更新 复盘",
                createdAt: makeDate(year: 2026, month: 6, day: 1),
                updatedAt: makeDate(year: 2026, month: 6, day: 1)
            ),
            Memo(
                text: "新更新 复盘",
                createdAt: makeDate(year: 2026, month: 5, day: 1),
                updatedAt: makeDate(year: 2026, month: 6, day: 22)
            )
        ], into: store)

        store.searchText = "updated:2026-06-22 复盘"

        XCTAssertEqual(store.filteredMemos.map(\.text), ["新更新 复盘"])
    }

    func testSearchCanFilterByContentTypes() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let audioAttachment = try SharedAttachmentStore.save(
            data: Data("voice payload".utf8),
            suggestedFilename: "voice-\(UUID().uuidString).m4a",
            typeIdentifier: UTType.mpeg4Audio.identifier
        )
        let videoAttachment = try SharedAttachmentStore.save(
            data: Data("video payload".utf8),
            suggestedFilename: "clip-\(UUID().uuidString).mov",
            typeIdentifier: UTType.movie.identifier
        )
        defer {
            SharedAttachmentStore.delete(audioAttachment)
            SharedAttachmentStore.delete(videoAttachment)
        }
        let audioMemoText = "录音\n\n\(audioAttachment.referenceLine)"
        let videoMemoText = "拍摄视频\n\n\(videoAttachment.referenceLine)"

        store.addMemo(text: "链接资料 https://example.com/a")
        store.addMemo(text: LinkExtractor.webClipText(
            title: "网页资料",
            url: URL(string: "https://example.com/web")!,
            summary: "网页摘要",
            highlights: []
        ))
        let clipFragmentText = try XCTUnwrap(ClipFragmentExtractor.mergedText(
            title: "网页和截图摘录",
            fragments: [
                ClipFragment(source: .web, title: "网页资料", text: "网页关键句", uri: "https://example.com/web", stableKey: "clip-web"),
                ClipFragment(source: .ocr, title: "截图", text: "截图关键句", uri: "some-attachment://screen.png", stableKey: "clip-ocr")
            ]
        ))
        store.addMemo(text: clipFragmentText)
        store.addMemo(text: """
        图片文字：receipt.png

        识别文字：
        合计 128 元

        [附件: receipt.png](some-attachment://receipt.png)
        """)
        store.addMemo(text: "附件资料\n\n[附件: image.png](some-attachment://image.png)")
        store.addMemo(text: "任务资料\n- [ ] 写提纲\n- [x] 校对")
        store.addMemo(text: "手帐页面：六月手帐\n模板：日记\n素材：图片、摘录")
        store.addMemo(text: "工作日志：今日工作日志\n范围：今日\n进展：完成视频缩略图")
        store.addMemo(text: audioMemoText)
        store.addMemo(text: videoMemoText)
        store.addMemo(text: "衣橱单品：白衬衫\n分类：上装\n颜色：白")
        store.addMemo(text: "穿搭组合：周一通勤\n单品：白衬衫、黑裤")
        store.addMemo(text: "穿着记录：2026-06-23\n日期：2026-06-23\n单品：白衬衫、黑裤")
        store.addMemo(text: "洗护记录：2026-06-23\n日期：2026-06-23\n单品：白衬衫\n状态：待清洗")
        store.addMemo(text: "旅行打包：杭州周末\n目的地：杭州\n单品：白衬衫、黑裤")
        store.addMemo(text: "普通资料")

        store.searchText = "has:link"
        XCTAssertEqual(
            Set(store.filteredMemos.map(\.text)),
            Set([
                "链接资料 https://example.com/a",
                LinkExtractor.webClipText(
                    title: "网页资料",
                    url: URL(string: "https://example.com/web")!,
                    summary: "网页摘要",
                    highlights: []
                )
            ])
        )

        store.searchText = "has:web"
        XCTAssertEqual(
            store.filteredMemos.map(\.text),
            [
                LinkExtractor.webClipText(
                    title: "网页资料",
                    url: URL(string: "https://example.com/web")!,
                    summary: "网页摘要",
                    highlights: []
                )
            ]
        )

        store.searchText = "has:clip"
        XCTAssertEqual(store.filteredMemos.map(\.text), [clipFragmentText])

        store.searchText = "has:attachment"
        XCTAssertEqual(
            Set(store.filteredMemos.map(\.text)),
            Set([
                """
                图片文字：receipt.png

                识别文字：
                合计 128 元

                [附件: receipt.png](some-attachment://receipt.png)
                """,
                "附件资料\n\n[附件: image.png](some-attachment://image.png)",
                audioMemoText,
                videoMemoText
            ])
        )

        store.searchText = "has:ocr"
        XCTAssertEqual(store.filteredMemos.map(\.text), [
            """
            图片文字：receipt.png

            识别文字：
            合计 128 元

            [附件: receipt.png](some-attachment://receipt.png)
            """
        ])

        store.searchText = "has:task"
        XCTAssertEqual(store.filteredMemos.map(\.text), ["任务资料\n- [ ] 写提纲\n- [x] 校对"])

        store.searchText = "has:open-task"
        XCTAssertEqual(store.filteredMemos.map(\.text), ["任务资料\n- [ ] 写提纲\n- [x] 校对"])

        store.searchText = "has:completed-task"
        XCTAssertEqual(store.filteredMemos.map(\.text), ["任务资料\n- [ ] 写提纲\n- [x] 校对"])

        store.searchText = "has:scrapbook"
        XCTAssertEqual(store.filteredMemos.map(\.text), ["手帐页面：六月手帐\n模板：日记\n素材：图片、摘录"])

        store.searchText = "has:worklog"
        XCTAssertEqual(store.filteredMemos.map(\.text), ["工作日志：今日工作日志\n范围：今日\n进展：完成视频缩略图"])

        store.searchText = "has:audio"
        XCTAssertEqual(store.filteredMemos.map(\.text), [audioMemoText])

        store.searchText = "has:video"
        XCTAssertEqual(store.filteredMemos.map(\.text), [videoMemoText])

        store.searchText = "has:wardrobe"
        XCTAssertEqual(store.filteredMemos.map(\.text), ["衣橱单品：白衬衫\n分类：上装\n颜色：白"])

        store.searchText = "has:outfit"
        XCTAssertEqual(store.filteredMemos.map(\.text), ["穿搭组合：周一通勤\n单品：白衬衫、黑裤"])

        store.searchText = "has:wear-log"
        XCTAssertEqual(store.filteredMemos.map(\.text), ["穿着记录：2026-06-23\n日期：2026-06-23\n单品：白衬衫、黑裤"])

        store.searchText = "has:laundry-log"
        XCTAssertEqual(store.filteredMemos.map(\.text), ["洗护记录：2026-06-23\n日期：2026-06-23\n单品：白衬衫\n状态：待清洗"])

        store.searchText = "has:packing-list"
        XCTAssertEqual(store.filteredMemos.map(\.text), ["旅行打包：杭州周末\n目的地：杭州\n单品：白衬衫、黑裤"])
    }

    func testAddWorkLogCreatesStructuredAssetWithReferences() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        store.addMemo(text: "完成视频预览\n- [x] 接入缩略图")
        store.addMemo(text: "明天继续\n- [ ] 做缓存")

        let sourceMemos = store.memos
        guard let log = store.addWorkLog(
            title: "今日工作日志",
            scope: "今日",
            project: "some",
            dateRange: "2026-06-23",
            template: "日报",
            progress: ["接入缩略图"],
            blockers: ["无"],
            nextSteps: ["做缓存"],
            sourceMemos: sourceMemos,
            note: "媒体体验"
        ) else {
            return XCTFail("Expected work log")
        }

        XCTAssertTrue(log.text.contains("工作日志：今日工作日志"))
        XCTAssertTrue(log.text.contains("范围：今日"))
        XCTAssertTrue(log.text.contains("项目：some"))
        XCTAssertTrue(log.text.contains("日期：2026-06-23"))
        XCTAssertTrue(log.text.contains("模板：日报"))
        XCTAssertTrue(log.text.contains("进展：接入缩略图"))
        XCTAssertTrue(log.text.contains("问题：无"))
        XCTAssertTrue(log.text.contains("下一步：做缓存"))
        XCTAssertTrue(log.text.contains("备注：媒体体验"))
        XCTAssertEqual(MemoReferenceParser.references(in: log.text).count, 2)

        let asset = store.assets(for: log).first { $0.kind == .workLog }
        XCTAssertEqual(asset?.title, "今日工作日志")
        XCTAssertTrue(asset?.summary?.contains("项目：some") == true)
        XCTAssertTrue(asset?.summary?.contains("日期：2026-06-23") == true)
        XCTAssertTrue(asset?.summary?.contains("模板：日报") == true)
        XCTAssertTrue(asset?.summary?.contains("进展：接入缩略图") == true)

        store.searchText = "has:worklog some 2026-06-23 日报"
        XCTAssertEqual(store.filteredMemos.first?.id, log.id)
    }

    func testWorkLogSourceFilterEngineFiltersByTagKindDateAndSearch() {
        let calendar = Calendar(identifier: .gregorian)
        let now = DateFormatters.wardrobeDay.date(from: "2026-06-23")!
        let recentDate = calendar.date(byAdding: .day, value: -1, to: now)!
        let oldDate = calendar.date(byAdding: .day, value: -20, to: now)!
        let matchingMemo = Memo(
            text: "完成视频预览\n- [x] 接入缩略图 #产品/iOS",
            createdAt: recentDate,
            updatedAt: recentDate,
            tags: ["产品/iOS"]
        )
        let linkMemo = Memo(
            text: "资料 https://example.com #资料",
            createdAt: recentDate,
            updatedAt: recentDate,
            tags: ["资料"]
        )
        let oldTaskMemo = Memo(
            text: "旧任务\n- [x] 整理缩略图 #产品",
            createdAt: oldDate,
            updatedAt: oldDate,
            tags: ["产品"]
        )
        let generatedLog = Memo(
            text: "工作日志：旧汇总\n范围：今日",
            createdAt: recentDate,
            updatedAt: recentDate
        )
        let archivedMemo = Memo(
            text: "归档任务\n- [x] 接入缩略图 #产品",
            createdAt: recentDate,
            updatedAt: recentDate,
            tags: ["产品"],
            isArchived: true
        )
        let memos = [matchingMemo, linkMemo, oldTaskMemo, generatedLog, archivedMemo]
        let assets = memos.flatMap { MemoAsset.assets(in: $0) }

        let candidates = WorkLogSourceFilterEngine.candidates(
            from: memos,
            assets: assets,
            filter: WorkLogSourceFilter(
                tag: "产品",
                kind: .task,
                dateScope: .last7Days,
                searchText: "缩略图"
            ),
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(candidates.map(\.id), [matchingMemo.id])
    }

    func testWorkLogSourceFilterEngineLimitsNewestCandidates() {
        let calendar = Calendar(identifier: .gregorian)
        let now = DateFormatters.wardrobeDay.date(from: "2026-06-23")!
        let olderDate = calendar.date(byAdding: .day, value: -2, to: now)!
        let newest = Memo(text: "今天进展", createdAt: now, updatedAt: now)
        let older = Memo(text: "前天进展", createdAt: olderDate, updatedAt: olderDate)
        let generatedLog = Memo(text: "工作日志：今日", createdAt: now, updatedAt: now)
        let archived = Memo(text: "归档进展", createdAt: now, updatedAt: now, isArchived: true)
        let memos = [older, generatedLog, newest, archived]
        let assets = memos.flatMap { MemoAsset.assets(in: $0) }

        let candidates = WorkLogSourceFilterEngine.candidates(
            from: memos,
            assets: assets,
            filter: .empty,
            now: now,
            calendar: calendar,
            limit: 1
        )

        XCTAssertEqual(candidates.map(\.id), [newest.id])
    }

    func testWorkLogExporterBuildsMarkdownForFilteredRecords() {
        let calendar = Calendar(identifier: .gregorian)
        let olderDate = DateFormatters.wardrobeDay.date(from: "2026-06-20")!
        let newerDate = DateFormatters.wardrobeDay.date(from: "2026-06-23")!
        let olderLog = Memo(
            text: """
            工作日志：周报
            范围：本周
            项目：some
            日期：2026-06-17~2026-06-23
            模板：周报
            进展：完成 URL Scheme
            下一步：导出工作日志
            """,
            createdAt: olderDate,
            updatedAt: olderDate
        )
        let newerLog = Memo(
            text: """
            工作日志：日报
            范围：今日
            项目：some
            日期：2026-06-23
            模板：日报
            进展：完成筛选
            问题：CI 等待中
            """,
            createdAt: newerDate,
            updatedAt: newerDate
        )
        let plainMemo = Memo(
            text: "普通记录，不应该出现在工作日志导出里",
            createdAt: newerDate,
            updatedAt: newerDate
        )
        let memos = [olderLog, plainMemo, newerLog]
        let assets = memos.flatMap { MemoAsset.assets(in: $0) }
        let markdown = WorkLogExporter.markdown(
            memos: memos,
            assets: assets,
            calendar: calendar
        )

        XCTAssertTrue(markdown.hasPrefix("# 工作日志导出\n\n共 2 条日志\n\n"))
        XCTAssertLessThan(
            markdown.range(of: "## 日报")!.lowerBound,
            markdown.range(of: "## 周报")!.lowerBound
        )
        XCTAssertTrue(markdown.contains("- 创建时间：\(DateFormatters.export.string(from: newerDate))"))
        XCTAssertTrue(markdown.contains("- 项目：some"))
        XCTAssertTrue(markdown.contains("- 日期：2026-06-23"))
        XCTAssertTrue(markdown.contains("- 模板：日报"))
        XCTAssertTrue(markdown.contains("进展：完成筛选"))
        XCTAssertFalse(markdown.contains("普通记录"))
    }

    func testSearchCanExcludeContentTypes() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        store.addMemo(text: "资料带链接 https://example.com/a")
        store.addMemo(text: "资料无链接")

        store.searchText = "资料 -has:link"

        XCTAssertEqual(store.filteredMemos.map(\.text), ["资料无链接"])
    }

    func testSearchCanFilterByReferencesAndBacklinks() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        store.addMemo(text: "源记录 #关系")
        store.addMemo(text: "目标记录 #关系")
        store.addMemo(text: "旁路记录 #关系")

        guard let source = store.memos.first(where: { $0.text.contains("源记录") }),
              let target = store.memos.first(where: { $0.text.contains("目标记录") }) else {
            return XCTFail("Expected memos")
        }

        XCTAssertTrue(store.addReference(from: source, to: target))

        store.searchText = "has:reference"
        XCTAssertEqual(store.filteredMemos.map(\.id), [source.id])

        store.searchText = "has:backlink"
        XCTAssertEqual(store.filteredMemos.map(\.id), [target.id])
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

    func testRecentSearchesPersistAndDeduplicate() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = MemoStore(filename: "test-\(UUID().uuidString).json", defaults: defaults)

        store.searchText = "  #产品   is:pinned  "
        store.recordCurrentSearch()
        store.searchText = "#产品 is:pinned"
        store.recordCurrentSearch()

        XCTAssertEqual(store.recentSearches, ["#产品 is:pinned"])

        let reloaded = MemoStore(filename: "test-\(UUID().uuidString).json", defaults: defaults)
        XCTAssertEqual(reloaded.recentSearches, ["#产品 is:pinned"])
    }

    func testRecentSearchesKeepMostRecentEightQueries() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = MemoStore(filename: "test-\(UUID().uuidString).json", defaults: defaults)

        for index in 0..<10 {
            store.searchText = "query-\(index)"
            store.recordCurrentSearch()
        }

        XCTAssertEqual(store.recentSearches.count, 8)
        XCTAssertEqual(store.recentSearches.first, "query-9")
        XCTAssertEqual(store.recentSearches.last, "query-2")
    }

    func testSavedSearchesPersistAndCanBeApplied() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = MemoStore(filename: "test-\(UUID().uuidString).json", defaults: defaults)

        store.searchText = "  #项目   is:active  复盘 "
        XCTAssertTrue(store.canSaveCurrentSearch)
        store.saveCurrentSearch()

        XCTAssertEqual(store.savedSearches, ["#项目 is:active 复盘"])
        XCTAssertFalse(store.canSaveCurrentSearch)

        store.clearSearch()
        store.applySearch("#项目 is:active 复盘")
        XCTAssertEqual(store.searchText, "#项目 is:active 复盘")

        let reloaded = MemoStore(filename: "test-\(UUID().uuidString).json", defaults: defaults)
        XCTAssertEqual(reloaded.savedSearches, ["#项目 is:active 复盘"])
    }

    func testTimelineEmptyStateGuidesFirstLaunch() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")

        XCTAssertEqual(store.timelineEmptyState.title, "从第一条随记开始")
        XCTAssertTrue(store.timelineEmptyState.subtitle.contains("写文字"))
        XCTAssertTrue(store.timelineEmptyState.subtitle.contains("本机"))
    }

    func testTimelineEmptyStateDistinguishesSearchNoResults() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        store.addMemo(text: "已有记录 #日常")
        store.searchText = "不存在的关键词"

        XCTAssertEqual(store.timelineEmptyState.title, "还没有匹配的闪念")
        XCTAssertTrue(store.timelineEmptyState.subtitle.contains("换个关键词"))
    }

    func testSearchSnippetUsesMatchingTermContext() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let memo = Memo(text: "前面有一段比较长的上下文，然后出现关键命中词，再继续写一些解释。")

        store.searchText = "关键命中词"

        let snippet = store.searchSnippet(for: memo, contextLength: 4)
        XCTAssertEqual(snippet, "...然后出现关键命中词，再继续...")
    }

    func testMemoReferenceParserExtractsAndHidesReferenceLines() {
        let id = UUID()
        let text = "正文 #关系\n\n[引用: 目标记录](some-memo://\(id.uuidString))"

        let references = MemoReferenceParser.references(in: text)

        XCTAssertEqual(references, [MemoReference(memoID: id, title: "目标记录")])
        XCTAssertEqual(MemoReferenceParser.displayTextWithoutReferences(text), "正文 #关系")
    }

    func testStoreCanAddReferencesAndFindBacklinks() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        store.addMemo(text: "源记录 #关系")
        store.addMemo(text: "目标记录 #关系")

        guard let source = store.memos.first(where: { $0.text.contains("源记录") }),
              let target = store.memos.first(where: { $0.text.contains("目标记录") }) else {
            return XCTFail("Expected memos")
        }

        XCTAssertTrue(store.addReference(from: source, to: target))
        guard let updatedSource = store.memos.first(where: { $0.id == source.id }) else {
            return XCTFail("Expected updated source")
        }

        XCTAssertEqual(store.referencedMemos(from: updatedSource).map(\.id), [target.id])
        XCTAssertEqual(store.backlinkMemos(to: target).map(\.id), [source.id])
        XCTAssertFalse(store.referenceCandidates(for: updatedSource).contains { $0.id == target.id })
    }

    func testStoreDoesNotDuplicateExistingReference() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        store.addMemo(text: "源记录 #关系")
        store.addMemo(text: "目标记录 #关系")

        guard let source = store.memos.first(where: { $0.text.contains("源记录") }),
              let target = store.memos.first(where: { $0.text.contains("目标记录") }) else {
            return XCTFail("Expected memos")
        }

        XCTAssertTrue(store.addReference(from: source, to: target))
        guard let updatedSource = store.memos.first(where: { $0.id == source.id }) else {
            return XCTFail("Expected updated source")
        }
        XCTAssertTrue(store.addReference(from: updatedSource, to: target))

        guard let finalSource = store.memos.first(where: { $0.id == source.id }) else {
            return XCTFail("Expected final source")
        }
        XCTAssertEqual(MemoReferenceParser.references(in: finalSource.text).count, 1)
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

    func testWardrobeReminderIdentifierIsStable() {
        let reminder = WardrobeCareReminder(
            id: "white-shirt-待清洗",
            itemName: "白衬衫",
            status: "待清洗",
            detail: "尽快清洗，避免影响搭配。",
            loggedAt: nil
        )

        XCTAssertEqual(
            ReminderManager.wardrobeReminderIdentifier(for: reminder),
            "some.wardrobeCareReminder.white-shirt-待清洗"
        )
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

    func testLinkExtractorIgnoresMemoReferences() {
        let id = UUID()
        let text = "资料 https://example.com/a\n\n[引用: 目标](some-memo://\(id.uuidString))"
        let urls = LinkExtractor.urls(in: text)

        XCTAssertEqual(urls.map(\.absoluteString), ["https://example.com/a"])
    }

    func testLinkExtractorParsesWebClips() {
        let text = """
        [网页摘录: Example Article](https://example.com/a)
        摘要：这是一段网页摘要
        重点：
        - 第一条重点
        - 第二条重点
        """

        let clips = LinkExtractor.webClips(in: text)

        XCTAssertEqual(clips.count, 1)
        XCTAssertEqual(clips[0].title, "Example Article")
        XCTAssertEqual(clips[0].url.absoluteString, "https://example.com/a")
        XCTAssertEqual(clips[0].summary, "这是一段网页摘要")
        XCTAssertEqual(clips[0].highlights, ["第一条重点", "第二条重点"])
    }

    func testLinkExtractorBuildsWebClipText() {
        let url = URL(string: "https://example.com/a")!
        let text = LinkExtractor.webClipText(
            title: "Example",
            url: url,
            summary: "摘要",
            highlights: ["重点一", "重点二"]
        )

        XCTAssertTrue(text.contains("[网页摘录: Example](https://example.com/a)"))
        XCTAssertTrue(text.contains("来源：example.com"))
        XCTAssertTrue(text.contains("摘要：摘要"))
        XCTAssertTrue(text.contains("摘录卡：摘要 · 重点2条"))
        XCTAssertTrue(text.contains("- 重点一"))
    }

    func testWebClipExtractorCleansArticleParagraphs() {
        let html = """
        <html>
        <head>
        <title>默认标题</title>
        <meta name="description" content="这是一段经过整理的网页摘要 &amp; 背景">
        </head>
        <body>
        <nav><p>登录 注册 订阅 这段导航不应该进入摘录。</p></nav>
        <article>
        <h1>真正标题</h1>
        <script>var tracking = true;</script>
        <p>第一段正文提供了足够的背景信息，说明这个网页为什么值得保存，并且包含多个细节。</p>
        <p>第一段正文提供了足够的背景信息，说明这个网页为什么值得保存，并且包含多个细节。</p>
        <p>第二段正文继续展开关键观点，包含中文标点、案例和后续行动建议，适合成为摘录重点。</p>
        <p>相关推荐 下载客户端 登录后查看更多内容。</p>
        </article>
        </body>
        </html>
        """
        let url = URL(string: "https://example.com/article")!

        let clip = WebClipExtractor.clip(from: url, html: html)

        XCTAssertEqual(clip.title, "默认标题")
        XCTAssertEqual(clip.summary, "这是一段经过整理的网页摘要 & 背景")
        XCTAssertEqual(
            clip.highlights,
            [
                "第一段正文提供了足够的背景信息，说明这个网页为什么值得保存，并且包含多个细节。",
                "第二段正文继续展开关键观点，包含中文标点、案例和后续行动建议，适合成为摘录重点。"
            ]
        )
    }

    func testWebClipExtractorFallsBackToBestParagraphSummary() {
        let html = """
        <main>
        <p>cookie privacy policy 登录注册。</p>
        <p>这是一段没有 description 的正文摘要，包含足够的信息密度和清晰表达，可以作为摘要。</p>
        <p>另一段正文提供补充材料和关键引用，应该保留为重点摘录。</p>
        </main>
        """
        let url = URL(string: "https://example.com/no-description")!

        let clip = WebClipExtractor.clip(from: url, html: html)

        XCTAssertEqual(clip.summary, "这是一段没有 description 的正文摘要，包含足够的信息密度和清晰表达，可以作为摘要。")
        XCTAssertEqual(clip.highlights, ["另一段正文提供补充材料和关键引用，应该保留为重点摘录。"])
    }

    func testClipFragmentExtractorBuildsWebAndOCRFragments() {
        let webText = LinkExtractor.webClipText(
            title: "Example",
            url: URL(string: "https://example.com/a")!,
            summary: "网页摘要",
            highlights: ["重点一", "重点一", "重点二"]
        )
        let ocrText = """
        图片文字：receipt.png

        识别文字：
        合计 128 元
        谢谢惠顾

        [附件: receipt.png](some-attachment://receipt.png)
        """

        let fragments = ClipFragmentExtractor.fragments(in: "\(webText)\n\n\(ocrText)")

        XCTAssertEqual(fragments.map(\.source), [.web, .web, .web, .ocr, .ocr])
        XCTAssertEqual(fragments.map(\.text), ["网页摘要", "重点一", "重点二", "合计 128 元", "谢谢惠顾"])
        XCTAssertEqual(fragments.first?.uri, "https://example.com/a")
        XCTAssertEqual(fragments.last?.uri, "some-attachment://receipt.png")
    }

    func testClipFragmentExtractorKeepsOCRBlocksAcrossBlankLines() {
        let text = """
        图片文字：receipt.png

        识别文字：
        合计 128 元
        谢谢惠顾

        [附件: receipt.png](some-attachment://receipt.png)

        截图文字：article.png

        OCR:
        标题摘录
        正文摘录

        [附件: article.png](some-attachment://article.png)
        """

        let fragments = ClipFragmentExtractor.fragments(in: text)

        XCTAssertEqual(fragments.map(\.source), [.ocr, .ocr, .ocr, .ocr])
        XCTAssertEqual(fragments.map(\.text), ["合计 128 元", "谢谢惠顾", "标题摘录", "正文摘录"])
        XCTAssertEqual(fragments[0].uri, "some-attachment://receipt.png")
        XCTAssertEqual(fragments[2].uri, "some-attachment://article.png")
    }

    func testClipFragmentExtractorBuildsMergedText() throws {
        let fragments = [
            ClipFragment(source: .web, title: "文章", text: "网页摘要", uri: "https://example.com/a", stableKey: "web"),
            ClipFragment(source: .ocr, title: "截图", text: "合计 128 元", uri: "some-attachment://receipt.png", stableKey: "ocr")
        ]

        let text = try XCTUnwrap(ClipFragmentExtractor.mergedText(title: "资料卡", fragments: fragments))

        XCTAssertTrue(text.contains("摘录片段：资料卡"))
        XCTAssertTrue(text.contains("来源：网页1 · OCR1"))
        XCTAssertTrue(text.contains("- [网页] 1. 网页摘要"))
        XCTAssertTrue(text.contains("- [OCR] 2. 合计 128 元"))
    }

    func testClipFragmentExtractorReadsMergedTextBlocks() throws {
        let text = try XCTUnwrap(ClipFragmentExtractor.mergedText(
            title: "资料卡",
            fragments: [
                ClipFragment(source: .web, title: "文章", text: "网页摘要", uri: "https://example.com/a", stableKey: "web"),
                ClipFragment(source: .ocr, title: "截图", text: "合计 128 元", uri: "some-attachment://receipt.png", stableKey: "ocr")
            ]
        ))

        let fragments = ClipFragmentExtractor.fragments(in: text)
        let summaries = ClipFragmentExtractor.assetSummaries(in: text)

        XCTAssertEqual(fragments.map(\.source), [.web, .ocr])
        XCTAssertEqual(fragments.map(\.text), ["网页摘要", "合计 128 元"])
        XCTAssertEqual(summaries.first?.title, "资料卡")
        XCTAssertEqual(summaries.first?.summary, "网页摘要 · 合计 128 元")
    }

    func testSelectedWebClipContentSeparatesWebAndOCRFragments() throws {
        let fragments = [
            ClipFragment(source: .web, title: "文章", text: "网页摘要", uri: "https://example.com/a", stableKey: "web-summary"),
            ClipFragment(source: .web, title: "文章", text: "重点一", uri: "https://example.com/a", stableKey: "web-highlight"),
            ClipFragment(source: .ocr, title: "截图", text: "合计 128 元", uri: "some-attachment://receipt.png", stableKey: "ocr")
        ]

        let content = ClipFragmentExtractor.selectedWebClipContent(
            title: "资料卡",
            summary: "网页摘要",
            fragments: fragments
        )

        XCTAssertEqual(content.summary, "网页摘要")
        XCTAssertEqual(content.highlights, ["重点一"])
        let mergedText = try XCTUnwrap(content.mergedFragmentsText)
        XCTAssertTrue(mergedText.contains("- [网页] 1. 网页摘要"))
        XCTAssertTrue(mergedText.contains("- [OCR] 3. 合计 128 元"))
    }

    func testSelectedWebClipContentDropsUnselectedSummary() throws {
        let fragments = [
            ClipFragment(source: .web, title: "文章", text: "重点一", uri: "https://example.com/a", stableKey: "web-highlight"),
            ClipFragment(source: .ocr, title: "截图", text: "截图摘录", uri: "some-attachment://screen.png", stableKey: "ocr")
        ]

        let content = ClipFragmentExtractor.selectedWebClipContent(
            title: "资料卡",
            summary: "网页摘要",
            fragments: fragments
        )

        XCTAssertNil(content.summary)
        XCTAssertEqual(content.highlights, ["重点一"])
        let mergedText = try XCTUnwrap(content.mergedFragmentsText)
        XCTAssertTrue(mergedText.contains("来源：网页1 · OCR1"))
        XCTAssertTrue(mergedText.contains("- [OCR] 2. 截图摘录"))
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

    func testMemoUpdateKeepsRemovedAttachmentReferencedByRevision() throws {
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

        XCTAssertTrue(FileManager.default.fileExists(atPath: attachmentURL.path))
        SharedAttachmentStore.delete(attachment)
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

    func testMemoDeleteDeletesAttachmentReferencedOnlyByRevision() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let attachment = try SharedAttachmentStore.save(
            data: Data("revision only".utf8),
            suggestedFilename: "revision-delete-\(UUID().uuidString).txt",
            typeIdentifier: UTType.plainText.identifier
        )
        guard let attachmentURL = SharedAttachmentStore.url(for: attachment) else {
            return XCTFail("Expected attachment URL")
        }
        store.addMemo(text: "历史附件\n\n\(attachment.referenceLine)")

        guard let memo = store.memos.first else {
            return XCTFail("Expected memo")
        }

        XCTAssertTrue(store.update(memo, text: "当前正文"))
        guard let updatedMemo = store.memos.first else {
            return XCTFail("Expected updated memo")
        }

        store.delete(updatedMemo)

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

    func testMemoAssetsIndexTextLinksAttachmentsTasksAndReferences() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let attachment = try SharedAttachmentStore.save(
            data: Data("asset attachment".utf8),
            suggestedFilename: "asset-\(UUID().uuidString).txt",
            typeIdentifier: UTType.plainText.identifier
        )
        defer { SharedAttachmentStore.delete(attachment) }

        guard let target = store.addMemo(text: "目标记录 #素材") else {
            return XCTFail("Expected target memo")
        }
        let sourceText = """
        资料 https://example.com/a #素材
        [网页摘录: Example](https://example.com/web)
        摘要：网页摘要
        - [ ] 整理素材

        \(attachment.referenceLine)
        \(MemoReferenceParser.referenceLine(for: target))
        """
        guard let source = store.addMemo(text: sourceText) else {
            return XCTFail("Expected source memo")
        }

        let assets = store.assets(for: source)
        XCTAssertTrue(assets.contains { $0.kind == .text && $0.summary?.contains("资料") == true })
        XCTAssertTrue(assets.contains { $0.kind == .link && $0.uri == "https://example.com/a" })
        XCTAssertTrue(assets.contains { $0.kind == .webClip && $0.title == "Example" && $0.summary == "网页摘要" })
        XCTAssertTrue(assets.contains { $0.kind == .attachment && $0.uri?.contains(attachment.relativePath) == true })
        XCTAssertTrue(assets.contains { $0.kind == .task && $0.title == "整理素材" && $0.summary == "open" })
        XCTAssertTrue(assets.contains { $0.kind == .reference && $0.uri == "some-memo://\(target.id.uuidString)" })
    }

    func testMemoAssetsIndexClipFragments() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let clipText = try XCTUnwrap(ClipFragmentExtractor.mergedText(
            title: "发票摘录",
            fragments: [
                ClipFragment(source: .web, title: "网页", text: "订单页面摘要", uri: "https://example.com/order", stableKey: "web"),
                ClipFragment(source: .ocr, title: "截图", text: "合计 128 元", uri: "some-attachment://receipt.png", stableKey: "ocr")
            ]
        ))
        guard let memo = store.addMemo(text: clipText) else {
            return XCTFail("Expected clip memo")
        }

        let clipAsset = try XCTUnwrap(store.assets(for: memo).first { $0.kind == .clipFragment })

        XCTAssertEqual(clipAsset.title, "发票摘录")
        XCTAssertEqual(clipAsset.summary, "订单页面摘要 · 合计 128 元")
        XCTAssertEqual(clipAsset.typeIdentifier, UTType.text.identifier)

        store.searchText = "has:摘录片段"
        XCTAssertEqual(store.filteredMemos.map(\.id), [memo.id])
    }

    func testMemoAssetsUpdateWhenMemoChanges() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        store.addMemo(text: "资料 https://example.com/a")
        guard let memo = store.memos.first else {
            return XCTFail("Expected memo")
        }

        XCTAssertTrue(store.assets(for: memo).contains { $0.kind == .link })
        XCTAssertTrue(store.update(memo, text: "只有正文"))

        guard let updatedMemo = store.memos.first else {
            return XCTFail("Expected updated memo")
        }
        XCTAssertFalse(store.assets(for: updatedMemo).contains { $0.kind == .link })
        XCTAssertTrue(store.assets(for: updatedMemo).contains { $0.kind == .text })
    }

    func testMemoAssetsAreRemovedWhenMemoIsDeleted() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        store.addMemo(text: "资料 https://example.com/a")
        guard let memo = store.memos.first else {
            return XCTFail("Expected memo")
        }
        XCTAssertFalse(store.assets(for: memo).isEmpty)

        store.delete(memo)

        XCTAssertTrue(store.assets.isEmpty)
    }

    func testAddAttachmentMemoCreatesMemoAndAttachmentAsset() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let payload = Data("imported image data".utf8)
        let attachment = try SharedAttachmentStore.save(
            data: payload,
            suggestedFilename: "import-\(UUID().uuidString).png",
            typeIdentifier: UTType.png.identifier
        )
        defer { SharedAttachmentStore.delete(attachment) }

        guard let memo = store.addAttachmentMemo(attachment, note: "导入图片") else {
            return XCTFail("Expected imported memo")
        }

        let importedAttachments = SharedAttachmentStore.attachments(in: memo.text)
        XCTAssertEqual(importedAttachments.first?.relativePath, attachment.relativePath)
        XCTAssertTrue(memo.text.contains("导入图片"))

        let asset = store.assets(for: memo).first { $0.kind == .attachment }
        XCTAssertEqual(asset?.title, attachment.displayName)
        XCTAssertEqual(asset?.typeIdentifier, UTType.png.identifier)
        XCTAssertEqual(asset?.byteCount, payload.count)
    }

    func testCameraCaptureAttachmentCreatesJPEGAsset() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let payload = Data("captured jpeg data".utf8)
        let attachment = try SharedAttachmentStore.save(
            data: payload,
            suggestedFilename: "camera-\(UUID().uuidString).jpg",
            typeIdentifier: UTType.jpeg.identifier
        )
        defer { SharedAttachmentStore.delete(attachment) }

        guard let memo = store.addAttachmentMemo(attachment, note: "拍照导入") else {
            return XCTFail("Expected camera memo")
        }

        XCTAssertTrue(memo.text.contains("拍照导入"))
        let asset = store.assets(for: memo).first { $0.kind == .attachment }
        XCTAssertEqual(asset?.title, attachment.displayName)
        XCTAssertEqual(asset?.typeIdentifier, UTType.jpeg.identifier)
        XCTAssertEqual(asset?.byteCount, payload.count)
    }

    func testRecordedAudioAttachmentCreatesAudioAsset() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let payload = Data("recorded audio data".utf8)
        let attachment = try SharedAttachmentStore.save(
            data: payload,
            suggestedFilename: "recording-\(UUID().uuidString).m4a",
            typeIdentifier: UTType.mpeg4Audio.identifier
        )
        defer { SharedAttachmentStore.delete(attachment) }

        guard let memo = store.addAttachmentMemo(attachment, note: "录音") else {
            return XCTFail("Expected audio memo")
        }

        XCTAssertTrue(memo.text.contains("录音"))
        let asset = store.assets(for: memo).first { $0.kind == .audio }
        XCTAssertEqual(asset?.title, attachment.displayName)
        XCTAssertTrue(UTType(asset?.typeIdentifier ?? "")?.conforms(to: .audio) == true)
        XCTAssertEqual(asset?.byteCount, payload.count)
    }

    func testCapturedVideoAttachmentCreatesVideoAsset() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let payload = Data("captured video data".utf8)
        let attachment = try SharedAttachmentStore.save(
            data: payload,
            suggestedFilename: "camera-video-\(UUID().uuidString).mov",
            typeIdentifier: UTType.movie.identifier
        )
        defer { SharedAttachmentStore.delete(attachment) }

        guard let memo = store.addAttachmentMemo(attachment, note: "拍摄视频") else {
            return XCTFail("Expected video memo")
        }

        XCTAssertTrue(memo.text.contains("拍摄视频"))
        let asset = store.assets(for: memo).first { $0.kind == .video }
        XCTAssertEqual(asset?.title, attachment.displayName)
        XCTAssertTrue(UTType(asset?.typeIdentifier ?? "")?.conforms(to: .movie) == true)
        XCTAssertEqual(asset?.byteCount, payload.count)
    }

    func testAudioTranscriberBuildsMemoText() {
        let attachment = SharedAttachment(
            id: "voice.m4a",
            filename: "voice.m4a",
            relativePath: "voice.m4a",
            typeIdentifier: UTType.mpeg4Audio.identifier,
            byteCount: 42
        )

        XCTAssertEqual(
            AudioTranscriber.memoText(for: attachment, transcript: "  今天要整理产品方向  "),
            """
            语音转写：voice.m4a

            今天要整理产品方向
            """
        )
        XCTAssertNil(AudioTranscriber.memoText(for: attachment, transcript: "   "))
    }

    func testVideoThumbnailGeneratorReturnsNilForMissingFile() {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).mov")

        XCTAssertNil(VideoThumbnailGenerator.image(for: missingURL))
    }

    func testMediaMetadataDurationFormatting() {
        XCTAssertEqual(MediaMetadata.formatDuration(5), "0:05")
        XCTAssertEqual(MediaMetadata.formatDuration(125), "2:05")
        XCTAssertEqual(MediaMetadata.formatDuration(3_725), "1:02:05")
    }

    func testMediaMetadataExtractorReadsImageDimensionsAndSize() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 8), format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 12, height: 8))
        }
        let data = try XCTUnwrap(image.pngData())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("metadata-\(UUID().uuidString).png")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let metadata = try XCTUnwrap(MediaMetadataExtractor.metadata(
            for: url,
            typeIdentifier: UTType.png.identifier
        ))

        XCTAssertEqual(metadata.pixelWidth, 12)
        XCTAssertEqual(metadata.pixelHeight, 8)
        XCTAssertEqual(metadata.byteCount, data.count)
        XCTAssertTrue(metadata.summary?.contains("12x8") == true)
        XCTAssertTrue(metadata.summary?.contains(SharedAttachmentStore.formatByteCount(data.count)) == true)
    }

    func testVideoThumbnailCacheURLChangesWhenFileChanges() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cache-key-\(UUID().uuidString).mov")
        try Data("one".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let firstURL = try XCTUnwrap(VideoThumbnailGenerator.cachedImageURL(for: url))
        let secondURL = try XCTUnwrap(VideoThumbnailGenerator.cachedImageURL(for: url, at: 1.25))

        XCTAssertNotEqual(firstURL.lastPathComponent, secondURL.lastPathComponent)
    }

    func testVideoThumbnailRemoveCachedImageDeletesExpectedFile() throws {
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cache-delete-\(UUID().uuidString).mov")
        try Data("video placeholder".utf8).write(to: sourceURL)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let cacheURL = try XCTUnwrap(VideoThumbnailGenerator.cachedImageURL(for: sourceURL))
        try FileManager.default.createDirectory(
            at: cacheURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("cached".utf8).write(to: cacheURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: cacheURL.path))
        VideoThumbnailGenerator.removeCachedImage(for: sourceURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheURL.path))
    }

    func testVideoThumbnailPreheatReportsMissingFiles() {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("preheat-missing-\(UUID().uuidString).mov")

        let result = VideoThumbnailGenerator.preheatCache(for: [missingURL, missingURL])

        XCTAssertEqual(result.warmedCount, 0)
        XCTAssertEqual(result.failedCount, 1)
        XCTAssertEqual(result.removedCount, 0)
    }

    func testVideoThumbnailPruneCacheKeepsExpectedFile() throws {
        let keptSourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cache-keep-\(UUID().uuidString).mov")
        let removedSourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cache-remove-\(UUID().uuidString).mov")
        try Data("kept".utf8).write(to: keptSourceURL)
        try Data("removed".utf8).write(to: removedSourceURL)
        defer {
            try? FileManager.default.removeItem(at: keptSourceURL)
            try? FileManager.default.removeItem(at: removedSourceURL)
        }

        let keptCacheURL = try XCTUnwrap(VideoThumbnailGenerator.cachedImageURL(for: keptSourceURL))
        let removedCacheURL = try XCTUnwrap(VideoThumbnailGenerator.cachedImageURL(for: removedSourceURL))
        try FileManager.default.createDirectory(
            at: keptCacheURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("kept-cache".utf8).write(to: keptCacheURL)
        try Data("removed-cache".utf8).write(to: removedCacheURL)
        defer {
            try? FileManager.default.removeItem(at: keptCacheURL)
            try? FileManager.default.removeItem(at: removedCacheURL)
        }

        let result = VideoThumbnailGenerator.pruneCache(keeping: [keptSourceURL])

        XCTAssertEqual(result.removedCount, 1)
        XCTAssertEqual(result.failedCount, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: keptCacheURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: removedCacheURL.path))
    }

    func testVideoThumbnailSourceURLsFilterDeduplicateAndLimitVideoAssets() {
        let memoID = UUID()
        let firstVideo = SharedAttachment(
            id: "first.mov",
            filename: "first.mov",
            relativePath: "first.mov",
            typeIdentifier: UTType.quickTimeMovie.identifier,
            byteCount: 10
        )
        let secondVideo = SharedAttachment(
            id: "second.mp4",
            filename: "second.mp4",
            relativePath: "second.mp4",
            typeIdentifier: UTType.mpeg4Movie.identifier,
            byteCount: 20
        )
        let image = SharedAttachment(
            id: "cover.png",
            filename: "cover.png",
            relativePath: "cover.png",
            typeIdentifier: UTType.png.identifier,
            byteCount: 30
        )
        let assets = [
            MemoAsset(
                memoID: memoID,
                kind: .video,
                title: firstVideo.displayName,
                uri: firstVideo.referenceURI,
                typeIdentifier: firstVideo.typeIdentifier,
                byteCount: firstVideo.byteCount,
                createdAt: Date(),
                updatedAt: Date()
            ),
            MemoAsset(
                memoID: memoID,
                kind: .attachment,
                title: image.displayName,
                uri: image.referenceURI,
                typeIdentifier: image.typeIdentifier,
                byteCount: image.byteCount,
                createdAt: Date(),
                updatedAt: Date()
            ),
            MemoAsset(
                memoID: memoID,
                kind: .video,
                title: firstVideo.displayName,
                uri: firstVideo.referenceURI,
                typeIdentifier: firstVideo.typeIdentifier,
                byteCount: firstVideo.byteCount,
                createdAt: Date(),
                updatedAt: Date()
            ),
            MemoAsset(
                memoID: memoID,
                kind: .attachment,
                title: secondVideo.displayName,
                uri: secondVideo.referenceURI,
                typeIdentifier: secondVideo.typeIdentifier,
                byteCount: secondVideo.byteCount,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]

        let urls = VideoThumbnailGenerator.sourceURLs(in: assets, limit: 1)

        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls.first?.lastPathComponent, firstVideo.relativePath)
    }

    func testImageTextRecognizerBuildsMemoText() {
        let attachment = SharedAttachment(
            id: "receipt.png",
            filename: "receipt.png",
            relativePath: "receipt.png",
            typeIdentifier: UTType.png.identifier,
            byteCount: 128
        )

        let text = ImageTextRecognizer.memoText(
            for: attachment,
            recognizedLines: [" 合计 128 元 ", "合计 128 元", "谢谢惠顾"]
        )

        XCTAssertEqual(
            text,
            """
            图片文字：receipt.png

            识别文字：
            合计 128 元
            谢谢惠顾

            [附件: receipt.png](some-attachment://receipt.png)
            """
        )
    }

    func testImageTextRecognizerBuildsMemoTextWithRegion() {
        let attachment = SharedAttachment(
            id: "receipt.png",
            filename: "receipt.png",
            relativePath: "receipt.png",
            typeIdentifier: UTType.png.identifier,
            byteCount: 128
        )
        let region = ImageTextRegion(x: 0.1, y: 0.2, width: 0.5, height: 0.4)

        let text = ImageTextRecognizer.memoText(
            for: attachment,
            recognizedLines: ["区域文字"],
            region: region
        )

        XCTAssertTrue(text?.contains("图片文字：receipt.png") == true)
        XCTAssertTrue(text?.contains("区域：x10 y20 w50 h40") == true)
        XCTAssertTrue(text?.contains("区域文字") == true)
        XCTAssertTrue(text?.contains(attachment.referenceLine) == true)

        let memo = Memo(text: text ?? "")
        let imageTextAsset = MemoAsset.assets(in: memo).first { $0.kind == .screenshot }
        XCTAssertEqual(imageTextAsset?.summary, "区域文字")
    }

    func testImageTextRecognizerBuildsAppendableRegionMemoText() {
        let attachment = SharedAttachment(
            id: "receipt.png",
            filename: "receipt.png",
            relativePath: "receipt.png",
            typeIdentifier: UTType.png.identifier,
            byteCount: 128
        )

        let text = ImageTextRecognizer.memoText(
            for: attachment,
            recognizedLines: ["小计 88 元"],
            region: ImageTextRegion(x: 0.2, y: 0.2, width: 0.4, height: 0.3),
            includesAttachmentReference: false
        )

        XCTAssertTrue(text?.contains("图片文字：receipt.png") == true)
        XCTAssertTrue(text?.contains("区域：x20 y20 w40 h30") == true)
        XCTAssertTrue(text?.contains("小计 88 元") == true)
        XCTAssertFalse(text?.contains(attachment.referenceLine) == true)
    }

    func testImageTextRegionClampsAndBuildsRect() {
        let region = ImageTextRegion(x: -0.2, y: 0.25, width: 1.4, height: 0.5)
        let rect = region.rect(in: CGSize(width: 200, height: 100))

        XCTAssertEqual(region.x, 0)
        XCTAssertEqual(region.y, 0.25)
        XCTAssertEqual(region.width, 1)
        XCTAssertEqual(region.height, 0.5)
        XCTAssertEqual(rect, CGRect(x: 0, y: 25, width: 200, height: 50))
    }

    func testImageTextRegionKeepsSelectionInsideBounds() {
        let region = ImageTextRegion(x: 0.75, y: 0.8, width: 0.5, height: 0.4)

        XCTAssertEqual(region.x, 0.75)
        XCTAssertEqual(region.y, 0.8)
        XCTAssertEqual(region.width, 0.25)
        XCTAssertEqual(region.height, 0.2, accuracy: 0.0001)
        XCTAssertEqual(region.rect(in: CGSize(width: 400, height: 300)), CGRect(x: 300, y: 240, width: 100, height: 60))
    }

    func testImageTextRecognizerExtractsHighlightsFromMemoText() {
        let text = """
        图片文字：receipt.png

        识别文字：
        合计 128 元
        合计 128 元
        谢谢惠顾

        [附件: receipt.png](some-attachment://receipt.png)
        """

        XCTAssertEqual(
            ImageTextRecognizer.extractedHighlights(from: text, limit: 3),
            ["合计 128 元", "谢谢惠顾"]
        )
    }

    func testImageTextMemoCreatesScreenshotAsset() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let attachment = try SharedAttachmentStore.save(
            data: Data("not a real png but enough for metadata".utf8),
            suggestedFilename: "ocr-\(UUID().uuidString).png",
            typeIdentifier: UTType.png.identifier
        )
        defer { SharedAttachmentStore.delete(attachment) }

        guard let text = ImageTextRecognizer.memoText(
            for: attachment,
            recognizedLines: ["合计 128 元", "谢谢惠顾"]
        ), let memo = store.addMemo(text: text) else {
            return XCTFail("Expected OCR memo")
        }

        let asset = store.assets(for: memo).first { $0.kind == .screenshot }
        XCTAssertEqual(asset?.title, attachment.displayName)
        XCTAssertEqual(asset?.summary, "合计 128 元\n谢谢惠顾")
        XCTAssertEqual(asset?.uri, "some-attachment://\(attachment.relativePath)")
    }

    func testAppendedRegionImageTextCreatesScreenshotAsset() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let attachment = try SharedAttachmentStore.save(
            data: Data("image placeholder".utf8),
            suggestedFilename: "region-\(UUID().uuidString).png",
            typeIdentifier: UTType.png.identifier
        )
        defer { SharedAttachmentStore.delete(attachment) }

        guard let memo = store.addAttachmentMemo(attachment, note: "导入图片"),
              let text = ImageTextRecognizer.memoText(
                for: attachment,
                recognizedLines: ["桌号 A12"],
                region: ImageTextRegion(x: 0.15, y: 0.2, width: 0.5, height: 0.24),
                includesAttachmentReference: false
              ) else {
            return XCTFail("Expected image memo and OCR text")
        }

        XCTAssertTrue(store.update(memo, text: "\(memo.text)\n\n\(text)"))
        let updatedMemo = try XCTUnwrap(store.memos.first(where: { $0.id == memo.id }))
        let asset = store.assets(for: updatedMemo).first { $0.kind == .screenshot }

        XCTAssertEqual(asset?.title, attachment.displayName)
        XCTAssertEqual(asset?.summary, "桌号 A12")
        XCTAssertEqual(asset?.uri, "some-attachment://\(attachment.relativePath)")

        store.searchText = "has:ocr A12"
        XCTAssertEqual(store.filteredMemos.first?.id, memo.id)
        XCTAssertEqual(SharedAttachmentStore.attachments(in: updatedMemo.text).count, 1)
    }

    func testAddWardrobeItemCreatesStructuredMemoAndAsset() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let attachment = try SharedAttachmentStore.save(
            data: Data("wardrobe image".utf8),
            suggestedFilename: "shirt-\(UUID().uuidString).jpg",
            typeIdentifier: UTType.jpeg.identifier
        )
        defer { SharedAttachmentStore.delete(attachment) }

        guard let memo = store.addWardrobeItem(
            name: "白衬衫",
            category: "上装",
            colors: ["白", "蓝"],
            seasons: ["春", "秋"],
            scenes: ["通勤"],
            materials: ["棉", "亚麻"],
            thickness: "轻薄",
            purchasePrice: "399",
            attachment: attachment
        ) else {
            return XCTFail("Expected wardrobe memo")
        }

        XCTAssertTrue(memo.text.contains("衣橱单品：白衬衫"))
        XCTAssertTrue(memo.text.contains("分类：上装"))
        XCTAssertTrue(memo.text.contains("颜色：白、蓝"))
        XCTAssertTrue(memo.text.contains("季节：春、秋"))
        XCTAssertTrue(memo.text.contains("场景：通勤"))
        XCTAssertTrue(memo.text.contains("材质：棉、亚麻"))
        XCTAssertTrue(memo.text.contains("厚薄：轻薄"))
        XCTAssertTrue(memo.text.contains("价格：399"))
        XCTAssertEqual(SharedAttachmentStore.attachments(in: memo.text).first?.relativePath, attachment.relativePath)

        let asset = store.assets(for: memo).first { $0.kind == .wardrobeItem }
        XCTAssertEqual(asset?.title, "白衬衫")
        XCTAssertEqual(asset?.summary, "分类：上装 · 颜色：白、蓝 · 季节：春、秋 · 场景：通勤 · 材质：棉、亚麻 · 厚薄：轻薄 · 价格：399")
        XCTAssertEqual(asset?.uri, "some-attachment://\(attachment.relativePath)")
        XCTAssertEqual(asset?.typeIdentifier, UTType.jpeg.identifier)
    }

    func testAddOutfitCreatesStructuredMemoAndAsset() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")

        guard let memo = store.addOutfit(
            title: "周一通勤",
            itemNames: ["白衬衫", "黑裤"],
            scenes: ["通勤"],
            seasons: ["春"],
            note: "轻便"
        ) else {
            return XCTFail("Expected outfit memo")
        }

        XCTAssertTrue(memo.text.contains("穿搭组合：周一通勤"))
        XCTAssertTrue(memo.text.contains("单品：白衬衫、黑裤"))
        XCTAssertTrue(memo.text.contains("场景：通勤"))
        XCTAssertTrue(memo.text.contains("季节：春"))
        XCTAssertTrue(memo.text.contains("备注：轻便"))

        let asset = store.assets(for: memo).first { $0.kind == .outfit }
        XCTAssertEqual(asset?.title, "周一通勤")
        XCTAssertEqual(asset?.summary, "单品：白衬衫、黑裤 · 场景：通勤 · 季节：春 · 备注：轻便")
        XCTAssertEqual(asset?.typeIdentifier, UTType.text.identifier)
    }

    func testAddWearLogCreatesStructuredMemoAndAsset() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let date = DateFormatters.wardrobeDay.date(from: "2026-06-23")!

        guard let memo = store.addWearLog(
            itemNames: ["白衬衫", "黑裤"],
            date: date,
            scenes: ["通勤"],
            weather: "晴",
            note: "舒适"
        ) else {
            return XCTFail("Expected wear log memo")
        }

        XCTAssertTrue(memo.text.contains("穿着记录：2026-06-23"))
        XCTAssertTrue(memo.text.contains("日期：2026-06-23"))
        XCTAssertTrue(memo.text.contains("单品：白衬衫、黑裤"))
        XCTAssertTrue(memo.text.contains("场景：通勤"))
        XCTAssertTrue(memo.text.contains("天气：晴"))
        XCTAssertTrue(memo.text.contains("备注：舒适"))

        let asset = store.assets(for: memo).first { $0.kind == .wearLog }
        XCTAssertEqual(asset?.title, "2026-06-23")
        XCTAssertEqual(asset?.summary, "日期：2026-06-23 · 单品：白衬衫、黑裤 · 场景：通勤 · 天气：晴 · 备注：舒适")
        XCTAssertEqual(asset?.typeIdentifier, UTType.text.identifier)
    }

    func testAddLaundryLogCreatesStructuredMemoAndAsset() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let date = DateFormatters.wardrobeDay.date(from: "2026-06-23")!

        guard let memo = store.addLaundryLog(
            itemNames: ["白衬衫"],
            status: "待清洗",
            date: date,
            note: "冷水洗"
        ) else {
            return XCTFail("Expected laundry log memo")
        }

        XCTAssertTrue(memo.text.contains("洗护记录：2026-06-23"))
        XCTAssertTrue(memo.text.contains("日期：2026-06-23"))
        XCTAssertTrue(memo.text.contains("单品：白衬衫"))
        XCTAssertTrue(memo.text.contains("状态：待清洗"))
        XCTAssertTrue(memo.text.contains("备注：冷水洗"))

        let asset = store.assets(for: memo).first { $0.kind == .laundryLog }
        XCTAssertEqual(asset?.title, "2026-06-23")
        XCTAssertEqual(asset?.summary, "日期：2026-06-23 · 单品：白衬衫 · 状态：待清洗 · 备注：冷水洗")
        XCTAssertEqual(asset?.typeIdentifier, UTType.text.identifier)
    }

    func testAddPackingListCreatesStructuredMemoAndAsset() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")

        guard let memo = store.addPackingList(
            title: "杭州周末",
            destination: "杭州",
            dateRange: "6/24-6/26",
            tripDays: 3,
            itemNames: ["白衬衫", "黑裤"],
            weather: "多云",
            note: "带伞"
        ) else {
            return XCTFail("Expected packing list memo")
        }

        XCTAssertTrue(memo.text.contains("旅行打包：杭州周末"))
        XCTAssertTrue(memo.text.contains("目的地：杭州"))
        XCTAssertTrue(memo.text.contains("日期：6/24-6/26"))
        XCTAssertTrue(memo.text.contains("天数：3天"))
        XCTAssertTrue(memo.text.contains("单品：白衬衫、黑裤"))
        XCTAssertTrue(memo.text.contains("天气：多云"))
        XCTAssertTrue(memo.text.contains("备注：带伞"))

        let asset = store.assets(for: memo).first { $0.kind == .packingList }
        XCTAssertEqual(asset?.title, "杭州周末")
        XCTAssertEqual(asset?.summary, "目的地：杭州 · 日期：6/24-6/26 · 天数：3天 · 单品：白衬衫、黑裤 · 天气：多云 · 备注：带伞")
        XCTAssertEqual(asset?.typeIdentifier, UTType.text.identifier)
    }

    func testWardrobeInsightsParseMaterialAndThicknessForWeatherPacking() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let wornDate = DateFormatters.wardrobeDay.date(from: "2026-06-23")!
        store.addWardrobeItem(
            name: "亚麻衬衫",
            category: "上装",
            colors: ["白"],
            seasons: ["春"],
            scenes: ["旅行"],
            materials: ["亚麻"],
            thickness: "轻薄"
        )
        store.addWardrobeItem(
            name: "羊毛开衫",
            category: "外套",
            colors: ["灰"],
            seasons: ["冬"],
            scenes: ["旅行"],
            materials: ["羊毛"],
            thickness: "保暖"
        )
        store.addWearLog(
            itemNames: ["亚麻衬衫"],
            date: wornDate,
            scenes: ["旅行"],
            weather: "晴 热 30C"
        )

        let insights = WardrobeInsightEngine.insights(for: store.assets)

        let linenShirt = insights.items.first { $0.name == "亚麻衬衫" }
        XCTAssertEqual(linenShirt?.materials, ["亚麻"])
        XCTAssertEqual(linenShirt?.thickness, "轻薄")
        XCTAssertEqual(insights.suggestions.first { $0.id == "weather-晴 热 30C" }?.itemNames.first, "亚麻衬衫")
        XCTAssertTrue(insights.packingSuggestions.first?.note?.contains("优先轻薄、透气材质") == true)
    }

    func testWardrobeInsightsSummarizeItemsOutfitsAndSuggestions() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        store.addWardrobeItem(
            name: "白衬衫",
            category: "上装",
            colors: ["白"],
            seasons: ["春", "秋"],
            scenes: ["通勤"]
        )
        store.addWardrobeItem(
            name: "黑裤",
            category: "下装",
            colors: ["黑"],
            seasons: ["春", "秋"],
            scenes: ["通勤"]
        )
        store.addWardrobeItem(
            name: "蓝包",
            category: "包包",
            colors: ["蓝"],
            seasons: ["春"],
            scenes: ["通勤", "聚餐"]
        )
        store.addOutfit(
            title: "周一通勤",
            itemNames: ["白衬衫", "黑裤"],
            scenes: ["通勤"],
            seasons: ["春"]
        )

        let insights = WardrobeInsightEngine.insights(for: store.assets)

        XCTAssertEqual(insights.items.count, 3)
        XCTAssertEqual(insights.outfits.count, 1)
        XCTAssertTrue(insights.categoryStats.contains { $0.label == "上装" && $0.count == 1 })
        XCTAssertEqual(insights.sceneStats.first, WardrobeInsightMetric(label: "通勤", count: 4))
        XCTAssertEqual(insights.unusedItems.map(\.name), ["蓝包"])
        XCTAssertEqual(insights.frequentItems.first?.item.name, "白衬衫")
        XCTAssertEqual(insights.frequentItems.first?.count, 1)
        XCTAssertTrue(insights.suggestions.contains { $0.itemNames.contains("蓝包") })
    }

    func testWardrobeInsightsTrackWearCountsAndCostPerWear() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let firstDate = DateFormatters.wardrobeDay.date(from: "2026-06-20")!
        let secondDate = DateFormatters.wardrobeDay.date(from: "2026-06-23")!
        store.addWardrobeItem(
            name: "白衬衫",
            category: "上装",
            colors: ["白"],
            seasons: ["春"],
            scenes: ["通勤"],
            purchasePrice: "¥300"
        )
        store.addWardrobeItem(
            name: "黑裤",
            category: "下装",
            colors: ["黑"],
            seasons: ["春"],
            scenes: ["通勤"]
        )
        store.addWearLog(
            itemNames: ["白衬衫", "黑裤"],
            date: firstDate,
            scenes: ["通勤"],
            weather: "晴"
        )
        store.addWearLog(
            itemNames: ["白衬衫"],
            date: secondDate,
            scenes: ["通勤"],
            weather: "雨"
        )

        let insights = WardrobeInsightEngine.insights(for: store.assets)

        XCTAssertEqual(insights.wearLogs.count, 2)
        XCTAssertEqual(insights.sceneStats.first, WardrobeInsightMetric(label: "通勤", count: 4))
        let shirt = insights.items.first { $0.name == "白衬衫" }
        XCTAssertEqual(shirt?.wearCount, 2)
        XCTAssertEqual(shirt?.purchasePrice, 300)
        XCTAssertEqual(shirt?.lastWornAt, secondDate)
        let frequent = insights.frequentItems.first
        XCTAssertEqual(frequent?.item.name, "白衬衫")
        XCTAssertEqual(frequent?.count, 2)
        XCTAssertEqual(frequent?.costPerWear, 150)
        XCTAssertEqual(frequent?.lastWornAt, secondDate)
    }

    func testWardrobeInsightsSuggestWeatherOutfitAndAvoidUnavailableLaundryItems() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let wornDate = DateFormatters.wardrobeDay.date(from: "2026-06-23")!
        let laundryDate = DateFormatters.wardrobeDay.date(from: "2026-06-24")!
        store.addWardrobeItem(
            name: "白衬衫",
            category: "上装",
            colors: ["白"],
            seasons: ["夏"],
            scenes: ["通勤"]
        )
        store.addWardrobeItem(
            name: "黑裤",
            category: "下装",
            colors: ["黑"],
            seasons: ["春", "秋"],
            scenes: ["通勤"]
        )
        store.addWardrobeItem(
            name: "薄外套",
            category: "外套",
            colors: ["蓝"],
            seasons: ["春", "秋"],
            scenes: ["通勤"]
        )
        store.addWearLog(
            itemNames: ["白衬衫", "黑裤"],
            date: wornDate,
            scenes: ["通勤"],
            weather: "晴 28C"
        )
        store.addLaundryLog(
            itemNames: ["黑裤"],
            status: "待清洗",
            date: laundryDate,
            note: "明早处理"
        )

        let insights = WardrobeInsightEngine.insights(for: store.assets)

        XCTAssertEqual(insights.laundryLogs.count, 1)
        XCTAssertEqual(insights.careReminders.map(\.itemName), ["黑裤"])
        XCTAssertTrue(insights.careReminders.first?.detail.contains("明早处理") == true)
        let weatherSuggestion = insights.suggestions.first { $0.id == "weather-晴 28C" }
        XCTAssertEqual(weatherSuggestion?.title, "晴 28C 天气穿搭")
        XCTAssertTrue(weatherSuggestion?.itemNames.contains("白衬衫") == true)
        XCTAssertFalse(weatherSuggestion?.itemNames.contains("黑裤") == true)
    }

    func testWardrobeWeatherInsightKeepsForecastPhraseIntact() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let wornDate = DateFormatters.wardrobeDay.date(from: "2026-06-23")!
        store.addWardrobeItem(
            name: "轻薄风衣",
            category: "外套",
            colors: ["米"],
            seasons: ["春", "秋"],
            scenes: ["通勤", "旅行"]
        )
        store.addWardrobeItem(
            name: "小白鞋",
            category: "鞋履",
            colors: ["白"],
            seasons: ["春"],
            scenes: ["旅行"]
        )
        store.addWearLog(
            itemNames: ["轻薄风衣", "小白鞋"],
            date: wornDate,
            scenes: ["旅行"],
            weather: "多云，午后阵雨 22C"
        )

        let insights = WardrobeInsightEngine.insights(for: store.assets)

        let weatherSuggestion = insights.suggestions.first { $0.id == "weather-多云，午后阵雨 22C" }
        XCTAssertEqual(weatherSuggestion?.title, "多云，午后阵雨 22C 天气穿搭")
        XCTAssertEqual(insights.packingSuggestions.first?.weather, "多云，午后阵雨 22C")
        XCTAssertTrue(insights.packingSuggestions.first?.note?.contains("多云，午后阵雨 22C") == true)
    }

    func testWardrobePackingSuggestionsUseAvailableItemsAndLatestOutfit() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let wornDate = DateFormatters.wardrobeDay.date(from: "2026-06-23")!
        let laundryDate = DateFormatters.wardrobeDay.date(from: "2026-06-24")!
        store.addWardrobeItem(
            name: "白衬衫",
            category: "上装",
            colors: ["白"],
            seasons: ["夏"],
            scenes: ["旅行", "通勤"]
        )
        store.addWardrobeItem(
            name: "牛仔裤",
            category: "下装",
            colors: ["蓝"],
            seasons: ["春", "夏"],
            scenes: ["旅行"]
        )
        store.addWardrobeItem(
            name: "小白鞋",
            category: "鞋履",
            colors: ["白"],
            seasons: ["春", "夏"],
            scenes: ["旅行"]
        )
        store.addWardrobeItem(
            name: "帆布包",
            category: "包包",
            colors: ["米"],
            seasons: ["春", "夏"],
            scenes: ["旅行"]
        )
        store.addWearLog(
            itemNames: ["白衬衫", "牛仔裤"],
            date: wornDate,
            scenes: ["旅行"],
            weather: "多云 22C"
        )
        store.addLaundryLog(
            itemNames: ["牛仔裤"],
            status: "送洗",
            date: laundryDate
        )
        store.addOutfit(
            title: "杭州周末",
            itemNames: ["白衬衫", "牛仔裤", "小白鞋"],
            scenes: ["旅行"],
            seasons: ["夏"]
        )

        let insights = WardrobeInsightEngine.insights(for: store.assets)

        XCTAssertFalse(insights.packingSuggestions.isEmpty)
        XCTAssertEqual(insights.wearLogs.first?.weather, "多云 22C")
        XCTAssertTrue(insights.packingSuggestions.first?.itemNames.contains("白衬衫") == true)
        XCTAssertFalse(insights.packingSuggestions.first?.itemNames.contains("牛仔裤") == true)
        XCTAssertEqual(insights.packingSuggestions.first?.weather, "多云 22C")
        let outfitPacking = insights.packingSuggestions.first { $0.title == "杭州周末 打包" }
        XCTAssertEqual(outfitPacking?.itemNames, ["白衬衫", "小白鞋"])
    }

    func testWardrobePackingSuggestionsScaleItemsForTripDays() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let wornDate = DateFormatters.wardrobeDay.date(from: "2026-06-23")!
        store.addWardrobeItem(name: "亚麻衬衫", category: "上装", colors: ["白"], seasons: ["夏"], scenes: ["旅行"], materials: ["亚麻"], thickness: "轻薄")
        store.addWardrobeItem(name: "棉T恤", category: "上装", colors: ["蓝"], seasons: ["夏"], scenes: ["旅行"], materials: ["棉"], thickness: "轻薄")
        store.addWardrobeItem(name: "防晒衫", category: "上装", colors: ["米"], seasons: ["夏"], scenes: ["旅行"], materials: ["棉"], thickness: "轻薄")
        store.addWardrobeItem(name: "牛仔短裤", category: "下装", colors: ["蓝"], seasons: ["夏"], scenes: ["旅行"])
        store.addWardrobeItem(name: "半身裙", category: "下装", colors: ["黑"], seasons: ["夏"], scenes: ["旅行"])
        store.addWardrobeItem(name: "小白鞋", category: "鞋履", colors: ["白"], seasons: ["夏"], scenes: ["旅行"])
        store.addWardrobeItem(name: "帆布包", category: "包包", colors: ["米"], seasons: ["夏"], scenes: ["旅行"])
        store.addWearLog(
            itemNames: ["亚麻衬衫"],
            date: wornDate,
            scenes: ["旅行"],
            weather: "晴 热 30C"
        )
        store.addPackingList(
            title: "三天旅行",
            destination: "厦门",
            dateRange: "7/1-7/3",
            tripDays: 3,
            itemNames: ["亚麻衬衫"],
            weather: "晴 热 30C"
        )

        let insights = WardrobeInsightEngine.insights(for: store.assets)
        let suggestion = insights.packingSuggestions.first { $0.id == "packing-weather" }

        XCTAssertTrue(suggestion?.itemNames.contains("亚麻衬衫") == true)
        XCTAssertTrue(suggestion?.itemNames.contains("棉T恤") == true)
        XCTAssertTrue(suggestion?.itemNames.contains("防晒衫") == true)
        XCTAssertTrue(suggestion?.itemNames.contains("牛仔短裤") == true)
        XCTAssertTrue(suggestion?.itemNames.contains("半身裙") == true)
        XCTAssertTrue(suggestion?.itemNames.contains("小白鞋") == true)
        XCTAssertTrue(suggestion?.itemNames.contains("帆布包") == true)
        XCTAssertTrue(suggestion?.note?.contains("按 3 天行程") == true)
    }

    func testAddScrapbookPageCreatesStructuredMemoAndAsset() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let attachment = try SharedAttachmentStore.save(
            data: Data("scrapbook image".utf8),
            suggestedFilename: "scrapbook-\(UUID().uuidString).png",
            typeIdentifier: UTType.png.identifier
        )
        defer { SharedAttachmentStore.delete(attachment) }

        guard let memo = store.addScrapbookPage(
            title: "六月手帐",
            template: "日记",
            materials: ["图片", "网页摘录"],
            decorations: ["贴纸", "花边"],
            font: "圆体",
            border: "胶片",
            note: "周末整理",
            attachments: [attachment]
        ) else {
            return XCTFail("Expected scrapbook memo")
        }

        XCTAssertTrue(memo.text.contains("手帐页面：六月手帐"))
        XCTAssertTrue(memo.text.contains("模板：日记"))
        XCTAssertTrue(memo.text.contains("素材：图片、网页摘录"))
        XCTAssertTrue(memo.text.contains("贴纸/装饰：贴纸、花边"))
        XCTAssertTrue(memo.text.contains(ScrapbookPageLayout.marker))
        XCTAssertEqual(SharedAttachmentStore.attachments(in: memo.text).first?.relativePath, attachment.relativePath)

        let layout = try XCTUnwrap(ScrapbookPageLayout.layout(in: memo.text))
        XCTAssertEqual(layout.canvasWidth, 1080)
        XCTAssertEqual(layout.canvasHeight, 1440)
        XCTAssertEqual(layout.layers.first { $0.kind == .image }?.attachmentPath, attachment.relativePath)
        XCTAssertEqual(layout.layers.first { $0.kind == .text }?.text, "六月手帐")
        XCTAssertEqual(layout.layers.filter { $0.kind == .sticker }.map(\.title), ["贴纸", "花边"])
        XCTAssertEqual(layout.layers.first { $0.kind == .border }?.title, "胶片框")
        XCTAssertEqual(layout.layers.first { $0.kind == .text }?.fontName, "rounded")
        XCTAssertEqual(layout.layers.first { $0.kind == .border }?.borderColorHex, "#7A8A8E")

        let asset = store.assets(for: memo).first { $0.kind == .scrapbookPage }
        XCTAssertEqual(asset?.title, "六月手帐")
        XCTAssertTrue(asset?.summary?.contains("模板：日记") == true)
        XCTAssertTrue(asset?.summary?.contains("图层：1080x1440") == true)
        XCTAssertFalse(asset?.summary?.contains(ScrapbookPageLayout.marker) == true)
        XCTAssertEqual(asset?.uri, "some-attachment://\(attachment.relativePath)")
        XCTAssertEqual(asset?.typeIdentifier, UTType.png.identifier)
    }

    func testScrapbookLayoutReplacementUpdatesEncodedLine() throws {
        let originalLayout = ScrapbookPageLayout(
            backgroundColorHex: "#FDF8FA",
            layers: [
                ScrapbookLayer(kind: .text, title: "标题", text: "旧标题", x: 100, y: 100, width: 300, height: 80)
            ]
        )
        let originalText = """
        手帐页面：六月手帐
        模板：日记
        \(try XCTUnwrap(originalLayout.encodedLine()))
        """

        var updatedLayout = originalLayout
        updatedLayout.layers[0].x = 220
        updatedLayout.layers[0].scale = 1.4
        updatedLayout.layers[0].rotation = 12

        let updatedText = try XCTUnwrap(ScrapbookPageLayout.replacingLayout(in: originalText, with: updatedLayout))
        let decoded = try XCTUnwrap(ScrapbookPageLayout.layout(in: updatedText))

        XCTAssertEqual(decoded.layers[0].x, 220)
        XCTAssertEqual(decoded.layers[0].scale, 1.4, accuracy: 0.0001)
        XCTAssertEqual(decoded.layers[0].rotation, 12)
        XCTAssertEqual(updatedText.components(separatedBy: ScrapbookPageLayout.marker).count, 2)
    }

    func testScrapbookLayoutReplacementAppendsWhenMissing() throws {
        let layout = ScrapbookPageLayout(
            layers: [
                ScrapbookLayer(kind: .sticker, title: "贴纸", text: "今日", x: 100, y: 120, width: 160, height: 60)
            ]
        )
        let updatedText = try XCTUnwrap(ScrapbookPageLayout.replacingLayout(in: "手帐页面：旧手帐\n模板：日记", with: layout))

        XCTAssertTrue(updatedText.contains(ScrapbookPageLayout.marker))
        XCTAssertEqual(ScrapbookPageLayout.layout(in: updatedText)?.layers.first?.title, "贴纸")
    }

    func testUpdateScrapbookLayoutPersistsThroughStore() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        guard let memo = store.addScrapbookPage(
            title: "可编辑手帐",
            template: "日记",
            decorations: ["贴纸"]
        ) else {
            return XCTFail("Expected scrapbook memo")
        }

        var layout = try XCTUnwrap(ScrapbookPageLayout.layout(in: memo.text))
        layout.layers[0].x = 680
        layout.layers[0].scale = 1.25
        layout.layers.append(
            ScrapbookLayer(kind: .shape, title: "色块", x: 540, y: 860, width: 360, height: 180)
        )

        XCTAssertTrue(store.updateScrapbookLayout(layout, for: memo))
        let updatedMemo = try XCTUnwrap(store.memos.first { $0.id == memo.id })
        let updatedLayout = try XCTUnwrap(ScrapbookPageLayout.layout(in: updatedMemo.text))

        XCTAssertEqual(updatedLayout.layers[0].x, 680)
        XCTAssertEqual(updatedLayout.layers[0].scale, 1.25, accuracy: 0.0001)
        XCTAssertEqual(updatedLayout.layers.last?.kind, .shape)
        XCTAssertTrue(store.assets(for: updatedMemo).first { $0.kind == .scrapbookPage }?.summary?.contains("图层：1080x1440") == true)
        XCTAssertEqual(store.revisions(for: updatedMemo).count, 1)
    }

    func testScrapbookStyleCatalogAppliesEditablePresets() throws {
        XCTAssertEqual(ScrapbookStyleCatalog.normalizedFontKey("纸本"), "serif")
        XCTAssertEqual(ScrapbookStyleCatalog.normalizedFontKey("等宽"), "mono")
        XCTAssertEqual(ScrapbookStyleCatalog.borderPreset(matching: "胶片框").borderColorHex, "#7A8A8E")

        var textLayer = ScrapbookLayer(kind: .text, title: "正文", text: "正文", x: 120, y: 120, width: 200, height: 80)
        let fontPreset = try XCTUnwrap(ScrapbookStyleCatalog.fontPresets.first { $0.id == "handwritten" })
        ScrapbookStyleCatalog.applyFontPreset(fontPreset, to: &textLayer)
        XCTAssertEqual(textLayer.fontName, "handwritten")
        XCTAssertEqual(textLayer.fontSize, 50)
        XCTAssertEqual(textLayer.textColorHex, "#8B6F83")

        var stickerLayer = ScrapbookLayer(kind: .sticker, title: "贴纸", text: "贴纸", x: 120, y: 120, width: 180, height: 64)
        let stickerPreset = try XCTUnwrap(ScrapbookStyleCatalog.stickerPreset(matching: "好好吃饭"))
        ScrapbookStyleCatalog.applyStickerPreset(stickerPreset, to: &stickerLayer)
        XCTAssertEqual(stickerLayer.title, "好好吃饭")
        XCTAssertEqual(stickerLayer.fontName, "rounded")
        XCTAssertEqual(stickerLayer.backgroundColorHex, "#FFF7F0")

        var borderLayer = ScrapbookLayer(kind: .border, title: "边框", x: 120, y: 120, width: 220, height: 260)
        let borderPreset = try XCTUnwrap(ScrapbookStyleCatalog.borderPresets.first { $0.id == "lace" })
        ScrapbookStyleCatalog.applyBorderPreset(borderPreset, to: &borderLayer)
        XCTAssertEqual(borderLayer.title, "花边框")
        XCTAssertEqual(borderLayer.borderWidth, 12)
        XCTAssertEqual(borderLayer.cornerRadius, 54)
    }

    func testScrapbookRendererExportsPNGData() throws {
        let layout = ScrapbookPageLayout(
            canvasWidth: 320,
            canvasHeight: 420,
            backgroundColorHex: "#FDF8FA",
            layers: [
                ScrapbookLayer(kind: .shape, title: "底色", x: 160, y: 210, width: 220, height: 160, backgroundColorHex: "#E8F3EE", cornerRadius: 18),
                ScrapbookLayer(kind: .text, title: "标题", text: "六月手帐", x: 160, y: 120, width: 220, height: 70, fontName: "serif", fontSize: 28),
                ScrapbookLayer(kind: .sticker, title: "贴纸", text: "灵感", x: 160, y: 320, width: 130, height: 42, fontName: "handwritten", fontSize: 20, textColorHex: "#8B6F83", backgroundColorHex: "#F2EEF8", cornerRadius: 20),
                ScrapbookLayer(kind: .border, title: "花边", x: 160, y: 210, width: 280, height: 360, borderColorHex: "#E7C7D7", borderWidth: 4, cornerRadius: 20)
            ]
        )

        let data = try XCTUnwrap(ScrapbookRenderer.pngData(layout: layout))

        XCTAssertEqual(Array(data.prefix(4)), [0x89, 0x50, 0x4E, 0x47])
    }

    func testScrapbookRendererExportsPDFData() throws {
        let layout = ScrapbookPageLayout(
            canvasWidth: 320,
            canvasHeight: 420,
            backgroundColorHex: "#FDF8FA",
            layers: [
                ScrapbookLayer(kind: .text, title: "标题", text: "六月手帐", x: 160, y: 120, width: 220, height: 70, fontSize: 28),
                ScrapbookLayer(kind: .border, title: "花边", x: 160, y: 210, width: 280, height: 360, borderColorHex: "#E7C7D7", borderWidth: 4, cornerRadius: 20)
            ]
        )

        let data = ScrapbookRenderer.pdfData(layout: layout)

        XCTAssertEqual(Array(data.prefix(4)), Array("%PDF".utf8))
    }

    func testPhotoCollageLayoutBuildsImageGrid() {
        let attachments = (1...4).map { index in
            SharedAttachment(
                id: "photo-\(index).png",
                filename: "photo-\(index).png",
                relativePath: "photo-\(index).png",
                typeIdentifier: UTType.png.identifier,
                byteCount: 100
            )
        }

        let layout = ScrapbookPageLayout.photoCollageLayout(
            title: "周末拼贴",
            attachments: attachments,
            template: "图片拼贴",
            note: "吃饭和散步"
        )

        XCTAssertEqual(layout.layers.filter { $0.kind == .image }.count, 4)
        XCTAssertEqual(layout.layers.filter { $0.kind == .image }.first?.attachmentPath, "photo-1.png")
        XCTAssertTrue(layout.layers.contains { $0.kind == .text && $0.text == "周末拼贴" })
        XCTAssertTrue(layout.layers.contains { $0.kind == .text && $0.text == "吃饭和散步" })
    }

    func testExportScrapbookLayoutCreatesPNGAttachment() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let layout = ScrapbookPageLayout(
            canvasWidth: 240,
            canvasHeight: 320,
            layers: [
                ScrapbookLayer(kind: .text, title: "标题", text: "导出", x: 120, y: 120, width: 180, height: 80, fontSize: 28)
            ]
        )

        let attachment = try store.exportScrapbookLayout(layout, title: "六月手帐")
        defer { SharedAttachmentStore.delete(attachment) }

        XCTAssertTrue(attachment.isImage)
        XCTAssertTrue(attachment.filename.hasSuffix(".png"))
        XCTAssertNotNil(SharedAttachmentStore.url(for: attachment))
    }

    func testExportScrapbookLayoutCreatesPDFAttachment() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let layout = ScrapbookPageLayout(
            canvasWidth: 240,
            canvasHeight: 320,
            layers: [
                ScrapbookLayer(kind: .text, title: "标题", text: "PDF", x: 120, y: 120, width: 180, height: 80, fontSize: 28)
            ]
        )

        let attachment = try store.exportScrapbookLayout(layout, title: "六月手帐", format: .pdf)
        defer { SharedAttachmentStore.delete(attachment) }

        XCTAssertEqual(attachment.typeIdentifier, UTType.pdf.identifier)
        XCTAssertTrue(attachment.filename.hasSuffix(".pdf"))
        let pdfData = try XCTUnwrap(SharedAttachmentStore.data(for: attachment))
        XCTAssertEqual(pdfData.prefix(4).map { $0 }, Array("%PDF".utf8))
    }

    func testAddPhotoCollageCreatesScrapbookMemoAndPNGAttachment() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let first = try SharedAttachmentStore.save(
            data: try XCTUnwrap(testImage(size: CGSize(width: 60, height: 60)).pngData()),
            suggestedFilename: "collage-a-\(UUID().uuidString).png",
            typeIdentifier: UTType.png.identifier
        )
        let second = try SharedAttachmentStore.save(
            data: try XCTUnwrap(testImage(size: CGSize(width: 80, height: 60)).pngData()),
            suggestedFilename: "collage-b-\(UUID().uuidString).png",
            typeIdentifier: UTType.png.identifier
        )
        defer {
            SharedAttachmentStore.delete(first)
            SharedAttachmentStore.delete(second)
        }

        guard let memo = store.addPhotoCollage(
            title: "周末拼贴",
            attachments: [first, second],
            note: "吃饭照片"
        ) else {
            return XCTFail("Expected photo collage memo")
        }
        let attachments = SharedAttachmentStore.attachments(in: memo.text)
        defer {
            attachments
                .filter { $0.relativePath != first.relativePath && $0.relativePath != second.relativePath }
                .forEach { SharedAttachmentStore.delete($0) }
        }

        XCTAssertTrue(memo.text.contains("手帐页面：周末拼贴"))
        XCTAssertTrue(memo.text.contains("模板：图片拼贴"))
        XCTAssertTrue(memo.text.contains("导出图片："))
        XCTAssertEqual(ScrapbookPageLayout.layout(in: memo.text)?.layers.filter { $0.kind == .image }.count, 2)
        XCTAssertEqual(Set(attachments.map(\.relativePath)).count, 3)
        XCTAssertTrue(attachments.contains { $0.relativePath == first.relativePath })
        XCTAssertTrue(attachments.contains { $0.relativePath == second.relativePath })
        XCTAssertTrue(attachments.contains { $0.filename.contains("collage") && $0.isImage })
        XCTAssertTrue(store.assets(for: memo).contains { $0.kind == .scrapbookPage })
    }

    func testExportScrapbookLayoutReferencesAttachmentInMemo() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let memo = try XCTUnwrap(store.addScrapbookPage(
            title: "六月手帐",
            template: "日记",
            note: "排版草稿"
        ))
        var layout = try XCTUnwrap(ScrapbookPageLayout.layout(in: memo.text))
        layout.layers.append(
            ScrapbookLayer(kind: .text, title: "标题", text: "已导出", x: 120, y: 120, width: 180, height: 80, fontSize: 28)
        )

        let attachment = try store.exportScrapbookLayout(layout, title: "六月手帐", for: memo)
        defer { SharedAttachmentStore.delete(attachment) }
        let updatedMemo = try XCTUnwrap(store.memos.first { $0.id == memo.id })
        let updatedLayout = try XCTUnwrap(ScrapbookPageLayout.layout(in: updatedMemo.text))

        XCTAssertTrue(updatedMemo.text.contains("导出图片：\(attachment.displayName)"))
        XCTAssertTrue(updatedMemo.text.contains(attachment.referenceLine))
        XCTAssertEqual(updatedLayout.layers.last?.text, "已导出")
        let exportedAsset = try XCTUnwrap(
            store.assets(for: updatedMemo).first { $0.uri == attachment.referenceURI }
        )
        XCTAssertEqual(exportedAsset.kind, .attachment)
        XCTAssertTrue(UTType(exportedAsset.typeIdentifier ?? "")?.conforms(to: .image) == true)
    }

    func testExportScrapbookPDFReferencesAttachmentInMemo() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let memo = try XCTUnwrap(store.addScrapbookPage(
            title: "六月手帐",
            template: "日记",
            note: "PDF"
        ))
        let layout = try XCTUnwrap(ScrapbookPageLayout.layout(in: memo.text))

        let attachment = try store.exportScrapbookLayout(layout, title: "六月手帐", for: memo, format: .pdf)
        defer { SharedAttachmentStore.delete(attachment) }
        let updatedMemo = try XCTUnwrap(store.memos.first { $0.id == memo.id })

        XCTAssertTrue(updatedMemo.text.contains("导出PDF：\(attachment.displayName)"))
        XCTAssertTrue(updatedMemo.text.contains(attachment.referenceLine))
        let exportedAsset = try XCTUnwrap(
            store.assets(for: updatedMemo).first { $0.uri == attachment.referenceURI }
        )
        XCTAssertEqual(exportedAsset.kind, .attachment)
        XCTAssertTrue(UTType(exportedAsset.typeIdentifier ?? "")?.conforms(to: .pdf) == true)
    }

    func testAddAttachmentMemoDoesNotDuplicateAttachmentAlreadyInNote() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let attachment = try SharedAttachmentStore.save(
            data: Data("ocr payload".utf8),
            suggestedFilename: "ocr-note-\(UUID().uuidString).png",
            typeIdentifier: UTType.png.identifier
        )
        defer { SharedAttachmentStore.delete(attachment) }

        guard let note = ImageTextRecognizer.memoText(
            for: attachment,
            recognizedLines: ["合计 128 元"]
        ), let memo = store.addAttachmentMemo(attachment, note: note) else {
            return XCTFail("Expected OCR attachment memo")
        }

        XCTAssertEqual(SharedAttachmentStore.attachments(in: memo.text).count, 1)
        XCTAssertTrue(store.assets(for: memo).contains { $0.kind == .screenshot })
    }

    func testImageEditRecipeEncodesAndDecodes() throws {
        let recipe = ImageEditRecipe(
            sourceAttachmentPath: "source.jpg",
            outputAttachmentPath: "edited.png",
            filter: .fresh,
            layoutPreset: .foodCard,
            cropPreset: .square,
            cropAdjustment: ImageEditRecipe.CropAdjustment(x: 0.42, y: 0.58, scale: 1.4),
            border: ImageEditRecipe.Border(colorHex: "#FFFFFF", width: 18),
            background: ImageEditRecipe.Background(mode: .softBlur, colorHex: "#DDEBF7", blurRadius: 18),
            subjectExtraction: ImageEditRecipe.SubjectExtraction(mode: .person),
            textOverlays: [ImageEditRecipe.TextOverlay(text: "晚餐")],
            stickerOverlays: [ImageEditRecipe.StickerOverlay(text: "good")],
            cleanupPatches: [ImageEditRecipe.CleanupPatch(x: 0.3, y: 0.35, radius: 0.07)]
        )

        let line = try XCTUnwrap(recipe.encodedLine())
        let decoded = try XCTUnwrap(ImageEditRecipe.recipe(in: "图片编辑：晚餐\n\(line)"))

        XCTAssertEqual(decoded.sourceAttachmentPath, "source.jpg")
        XCTAssertEqual(decoded.outputAttachmentPath, "edited.png")
        XCTAssertEqual(decoded.filter, .fresh)
        XCTAssertEqual(decoded.layoutPreset, .foodCard)
        XCTAssertEqual(decoded.cropPreset, .square)
        XCTAssertEqual(decoded.cropAdjustment.scale, 1.4, accuracy: 0.001)
        XCTAssertEqual(decoded.background.mode, .softBlur)
        XCTAssertEqual(decoded.background.colorHex, "#DDEBF7")
        XCTAssertEqual(decoded.subjectExtraction.mode, .person)
        XCTAssertEqual(decoded.textOverlays.first?.text, "晚餐")
        XCTAssertEqual(decoded.stickerOverlays.first?.text, "good")
        XCTAssertEqual(decoded.cleanupPatches.count, 1)
        XCTAssertTrue(decoded.summary.contains("自由裁剪"))
        XCTAssertTrue(decoded.summary.contains("美食留白"))
        XCTAssertTrue(decoded.summary.contains("柔化背景"))
        XCTAssertTrue(decoded.summary.contains("人物抠图"))
        XCTAssertTrue(decoded.summary.contains("清理1"))
    }

    func testImageEditLayoutPresetsProvideExportDefaults() {
        let preset = ImageEditRecipe.LayoutPreset.foodCard

        XCTAssertEqual(preset.title, "美食留白")
        XCTAssertEqual(preset.filter, .warm)
        XCTAssertEqual(preset.cropPreset, .square)
        XCTAssertEqual(preset.border.width, 22)
        XCTAssertEqual(preset.background.mode, .solid)
        XCTAssertEqual(preset.defaultCaption, "好好吃饭")
        XCTAssertEqual(preset.textOverlay(text: "晚餐").colorHex, "#A06F55")
        XCTAssertEqual(preset.stickerOverlay(text: "今日").x, 0.18)
    }

    func testAddImageEditCreatesRenderedAttachmentAssetAndSearchResult() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let sourceData = try XCTUnwrap(testImage(size: CGSize(width: 80, height: 60)).pngData())
        let sourceAttachment = try SharedAttachmentStore.save(
            data: sourceData,
            suggestedFilename: "meal-\(UUID().uuidString).png",
            typeIdentifier: UTType.png.identifier
        )
        defer { SharedAttachmentStore.delete(sourceAttachment) }

        let recipe = ImageEditRecipe(
            sourceAttachmentPath: sourceAttachment.relativePath,
            filter: .vivid,
            layoutPreset: .journalSticker,
            cropPreset: .square,
            cropAdjustment: ImageEditRecipe.CropAdjustment(x: 0.4, y: 0.45, scale: 1.3),
            border: ImageEditRecipe.Border(colorHex: "#F8DCE8", width: 6),
            background: ImageEditRecipe.Background(mode: .solid, colorHex: "#FDF8FA", inset: 0.08),
            subjectExtraction: ImageEditRecipe.SubjectExtraction(mode: .person),
            textOverlays: [ImageEditRecipe.TextOverlay(text: "晚餐", fontSize: 18)],
            stickerOverlays: [ImageEditRecipe.StickerOverlay(text: "OK", fontSize: 18)],
            cleanupPatches: [ImageEditRecipe.CleanupPatch(x: 0.3, y: 0.3, radius: 0.06)]
        )

        guard let memo = store.addImageEdit(
            title: "晚餐照片",
            sourceAttachment: sourceAttachment,
            recipe: recipe,
            note: "加边框"
        ) else {
            return XCTFail("Expected image edit memo")
        }
        let attachments = SharedAttachmentStore.attachments(in: memo.text)
        defer { attachments.forEach { SharedAttachmentStore.delete($0) } }

        XCTAssertTrue(memo.text.contains("图片编辑：晚餐照片"))
        XCTAssertTrue(memo.text.contains("模板：手帐贴纸"))
        XCTAssertTrue(memo.text.contains("滤镜：鲜明"))
        XCTAssertTrue(memo.text.contains("裁剪：1:1"))
        XCTAssertTrue(memo.text.contains("裁剪微调："))
        XCTAssertTrue(memo.text.contains("授权清理：1处"))
        XCTAssertTrue(memo.text.contains("背景：纯色背景"))
        XCTAssertTrue(memo.text.contains("主体：人物抠图"))
        XCTAssertNotNil(ImageEditRecipe.recipe(in: memo.text)?.outputAttachmentPath)
        XCTAssertEqual(attachments.count, 2)
        XCTAssertTrue(attachments.contains { $0.relativePath == sourceAttachment.relativePath })
        XCTAssertTrue(attachments.contains { $0.relativePath != sourceAttachment.relativePath && $0.isImage })
        XCTAssertTrue(attachments.contains { $0.filename.contains("journalSticker") })

        let asset = store.assets(for: memo).first { $0.kind == .imageEdit }
        XCTAssertEqual(asset?.title, "晚餐照片")
        XCTAssertTrue(asset?.summary?.contains("鲜明") == true)
        XCTAssertTrue(asset?.summary?.contains("文字1") == true)
        XCTAssertNotNil(asset?.uri)

        store.searchText = "has:image-edit"
        XCTAssertEqual(store.filteredMemos.map(\.id), [memo.id])
    }

    func testImageEditRecipeDecodesLegacyRecipeWithoutNewFields() throws {
        let json = """
        {"version":1,"sourceAttachmentPath":"source.jpg","filter":"fresh","cropPreset":"square","border":{"colorHex":"#FFFFFF","width":0},"textOverlays":[],"stickerOverlays":[]}
        """
        let encoded = try XCTUnwrap(json.data(using: .utf8)?.base64EncodedString())
        let recipe = try XCTUnwrap(ImageEditRecipe.recipe(in: "图片编辑：旧图\n\(ImageEditRecipe.marker)\(encoded)"))

        XCTAssertEqual(recipe.cropAdjustment, ImageEditRecipe.CropAdjustment())
        XCTAssertEqual(recipe.layoutPreset, .manual)
        XCTAssertEqual(recipe.background, ImageEditRecipe.Background())
        XCTAssertEqual(recipe.subjectExtraction, ImageEditRecipe.SubjectExtraction())
        XCTAssertEqual(recipe.cleanupPatches, [])
    }

    func testImageEditRendererAppliesFreeCropAdjustment() throws {
        let source = testImage(size: CGSize(width: 120, height: 80))
        let recipe = ImageEditRecipe(
            sourceAttachmentPath: "source.png",
            filter: .original,
            cropPreset: .square,
            cropAdjustment: ImageEditRecipe.CropAdjustment(x: 0.7, y: 0.5, scale: 2)
        )

        let rendered = try XCTUnwrap(ImageEditRenderer.renderedImage(sourceImage: source, recipe: recipe))

        XCTAssertLessThanOrEqual(abs(rendered.width - rendered.height), 1)
        XCTAssertLessThanOrEqual(rendered.width, source.cgImage?.width ?? rendered.width)
        XCTAssertLessThanOrEqual(rendered.height, source.cgImage?.height ?? rendered.height)
        XCTAssertTrue(ImageEditRenderer.outputFilename(
            source: SharedAttachment(
                id: "source.png",
                filename: "source.png",
                relativePath: "source.png",
                typeIdentifier: UTType.png.identifier,
                byteCount: 0
            ),
            recipe: recipe
        ).contains("freecrop"))
    }

    func testImageEditRendererAppliesAuthorizedCleanupPatch() throws {
        let source = testImage(size: CGSize(width: 80, height: 80))
        let recipe = ImageEditRecipe(
            sourceAttachmentPath: "source.png",
            filter: .original,
            cropPreset: .original,
            cleanupPatches: [
                ImageEditRecipe.CleanupPatch(x: 0.5, y: 0.5, radius: 0.12, softness: 0.8)
            ]
        )

        let rendered = try XCTUnwrap(ImageEditRenderer.renderedImage(sourceImage: source, recipe: recipe))

        XCTAssertEqual(rendered.width, source.cgImage?.width)
        XCTAssertEqual(rendered.height, source.cgImage?.height)
        XCTAssertTrue(recipe.summary.contains("清理1"))
    }

    func testImageEditRendererAppliesBackgroundCanvas() throws {
        let source = testImage(size: CGSize(width: 100, height: 80))
        let recipe = ImageEditRecipe(
            sourceAttachmentPath: "source.png",
            filter: .original,
            cropPreset: .original,
            background: ImageEditRecipe.Background(mode: .solid, colorHex: "#DDEBF7", inset: 0.12)
        )

        let rendered = try XCTUnwrap(ImageEditRenderer.renderedImage(sourceImage: source, recipe: recipe))

        XCTAssertEqual(rendered.width, source.cgImage?.width)
        XCTAssertEqual(rendered.height, source.cgImage?.height)
        XCTAssertTrue(recipe.summary.contains("纯色背景"))
        XCTAssertTrue(ImageEditRenderer.outputFilename(
            source: SharedAttachment(
                id: "source.png",
                filename: "source.png",
                relativePath: "source.png",
                typeIdentifier: UTType.png.identifier,
                byteCount: 0
            ),
            recipe: recipe
        ).contains("background"))
    }

    func testImageEditRendererMarksPersonSubjectExtractionInFilenameAndSummary() {
        let recipe = ImageEditRecipe(
            sourceAttachmentPath: "source.png",
            filter: .original,
            subjectExtraction: ImageEditRecipe.SubjectExtraction(mode: .person)
        )

        XCTAssertTrue(recipe.summary.contains("人物抠图"))
        XCTAssertTrue(ImageEditRenderer.outputFilename(
            source: SharedAttachment(
                id: "source.png",
                filename: "source.png",
                relativePath: "source.png",
                typeIdentifier: UTType.png.identifier,
                byteCount: 0
            ),
            recipe: recipe
        ).contains("subject"))
    }

    func testImageEditRecipeSupportsObjectSubjectExtraction() throws {
        let recipe = ImageEditRecipe(
            sourceAttachmentPath: "source.png",
            filter: .original,
            subjectExtraction: ImageEditRecipe.SubjectExtraction(mode: .object)
        )
        let line = try XCTUnwrap(recipe.encodedLine())
        let decoded = try XCTUnwrap(ImageEditRecipe.recipe(in: "图片编辑：包包\n\(line)"))

        XCTAssertEqual(decoded.subjectExtraction.mode, .object)
        XCTAssertTrue(decoded.summary.contains("智能主体"))
        XCTAssertTrue(ImageEditRenderer.outputFilename(
            source: SharedAttachment(
                id: "source.png",
                filename: "source.png",
                relativePath: "source.png",
                typeIdentifier: UTType.png.identifier,
                byteCount: 0
            ),
            recipe: decoded
        ).contains("subject"))
    }

    func testAddImageEditRecordsObjectSubjectExtraction() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let sourceData = try XCTUnwrap(testImage(size: CGSize(width: 64, height: 64)).pngData())
        let sourceAttachment = try SharedAttachmentStore.save(
            data: sourceData,
            suggestedFilename: "bag-\(UUID().uuidString).png",
            typeIdentifier: UTType.png.identifier
        )
        defer { SharedAttachmentStore.delete(sourceAttachment) }

        let recipe = ImageEditRecipe(
            sourceAttachmentPath: sourceAttachment.relativePath,
            filter: .original,
            subjectExtraction: ImageEditRecipe.SubjectExtraction(mode: .object)
        )

        let memo = try XCTUnwrap(store.addImageEdit(
            title: "包包抠图",
            sourceAttachment: sourceAttachment,
            recipe: recipe
        ))
        let attachments = SharedAttachmentStore.attachments(in: memo.text)
        defer { attachments.forEach { SharedAttachmentStore.delete($0) } }

        XCTAssertTrue(memo.text.contains("主体：智能主体"))
        XCTAssertEqual(ImageEditRecipe.recipe(in: memo.text)?.subjectExtraction.mode, .object)
    }

    func testAddWebClipCreatesMemoAndWebClipAsset() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let url = URL(string: "https://example.com/article")!

        guard let memo = store.addWebClip(
            url: url,
            title: "文章标题",
            summary: "文章摘要",
            highlights: ["重点一"]
        ) else {
            return XCTFail("Expected web clip memo")
        }

        XCTAssertTrue(memo.text.contains("[网页摘录: 文章标题](https://example.com/article)"))
        XCTAssertTrue(memo.text.contains("摘要：文章摘要"))
        XCTAssertTrue(memo.text.contains("- 重点一"))

        let asset = store.assets(for: memo).first { $0.kind == .webClip }
        XCTAssertEqual(asset?.title, "文章标题")
        XCTAssertEqual(asset?.summary, "文章摘要")
        XCTAssertEqual(asset?.uri, "https://example.com/article")
    }

    func testAddExtractedWebClipWithSelectedFragmentsCreatesClipAsset() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let clip = ExtractedWebClip(
            url: URL(string: "https://example.com/article")!,
            title: "文章标题",
            summary: "文章摘要",
            highlights: ["重点一", "重点二"]
        )
        let selected = [
            ClipFragment(source: .web, title: "文章标题", text: "文章摘要", uri: "https://example.com/article", stableKey: "summary"),
            ClipFragment(source: .web, title: "文章标题", text: "重点一", uri: "https://example.com/article", stableKey: "highlight")
        ]

        let memo = try XCTUnwrap(store.addWebClip(clip, selectedFragments: selected))

        XCTAssertTrue(memo.text.contains("[网页摘录: 文章标题](https://example.com/article)"))
        XCTAssertTrue(memo.text.contains("摘要：文章摘要"))
        XCTAssertTrue(memo.text.contains("- 重点一"))
        XCTAssertFalse(memo.text.contains("- 重点二"))
        XCTAssertTrue(memo.text.contains("摘录片段：文章标题"))

        let assets = store.assets(for: memo)
        XCTAssertTrue(assets.contains { $0.kind == .webClip && $0.title == "文章标题" })
        XCTAssertTrue(assets.contains { $0.kind == .clipFragment && $0.summary == "文章摘要 · 重点一" })
    }

    func testAddingMultipleExtractedWebClipsCreatesSeparateWebAssets() throws {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let clips = [
            ExtractedWebClip(
                url: URL(string: "https://example.com/a")!,
                title: "A",
                summary: "A 摘要",
                highlights: ["A 重点"]
            ),
            ExtractedWebClip(
                url: URL(string: "https://example.com/b")!,
                title: "B",
                summary: "B 摘要",
                highlights: ["B 重点"]
            )
        ]

        for clip in clips {
            XCTAssertNotNil(store.addWebClip(clip))
        }

        XCTAssertEqual(store.memos.count, 2)
        XCTAssertEqual(store.assets.filter { $0.kind == .webClip }.count, 2)

        store.searchText = "has:web"
        XCTAssertEqual(Set(store.filteredMemos.map(\.text)), Set(store.memos.map(\.text)))
    }

    private func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }

    private func importMemos(_ memos: [Memo], into store: MemoStore) throws {
        let data = try JSONEncoder.memoEncoder.encode(memos)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertEqual(try store.importJSON(json), memos.count)
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone.current
        components.year = year
        components.month = month
        components.day = day
        return components.date ?? Date(timeIntervalSince1970: 0)
    }

    private func testImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor(red: 0.72, green: 0.84, blue: 0.93, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.98, green: 0.78, blue: 0.86, alpha: 1).setFill()
            context.fill(CGRect(x: size.width * 0.18, y: size.height * 0.2, width: size.width * 0.64, height: size.height * 0.6))
        }
    }
}
