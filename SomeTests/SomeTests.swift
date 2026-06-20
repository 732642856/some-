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

    func testPlainTextImportSplitsByBlankLine() {
        let store = MemoStore(filename: "test-\(UUID().uuidString).json")
        let count = store.importPlainText("第一条 #a\n\n第二条 #b")

        XCTAssertEqual(count, 2)
        XCTAssertEqual(store.activeCount, 2)
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
}
