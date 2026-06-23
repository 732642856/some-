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
        case .referenceNote:
            return MemoReferenceParser.references(in: memo.text).contains { reference in
                reference.note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            }
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

enum WorkLogExporter {
    enum ReportDraftStyle: String, CaseIterable, Hashable {
        case standard
        case standup
        case projectBrief
    }

    static func markdown(
        memos: [Memo],
        assets: [MemoAsset]? = nil
    ) -> String {
        let resolvedAssets = assets ?? memos.flatMap { MemoAsset.assets(in: $0) }
        let records = workLogRecords(from: memos, assets: resolvedAssets)

        guard !records.isEmpty else {
            return "# 工作日志导出\n\n共 0 条日志\n"
        }

        let summary = reportSummary(for: records)
        let body = records.map { record -> String in
            let fields = fields(in: record.asset.summary, fallbackText: record.memo.text)
            var metadata = [
                "- 创建时间：\(DateFormatters.export.string(from: record.memo.createdAt))"
            ]

            appendMetadata("范围", from: fields, to: &metadata)
            appendMetadata("项目", from: fields, to: &metadata)
            appendMetadata("日期", from: fields, to: &metadata)
            appendMetadata("模板", from: fields, to: &metadata)

            return """
            ## \(headingTitle(record.asset.title))

            \(metadata.joined(separator: "\n"))

            \(record.memo.text)
            """
        }.joined(separator: "\n\n---\n\n")

        return "# 工作日志导出\n\n共 \(records.count) 条日志\n\n\(summary)\n\n---\n\n\(body)\n"
    }

    static func csv(
        memos: [Memo],
        assets: [MemoAsset]? = nil
    ) -> String {
        let resolvedAssets = assets ?? memos.flatMap { MemoAsset.assets(in: $0) }
        let records = workLogRecords(from: memos, assets: resolvedAssets)
        let header = ["标题", "创建时间", "范围", "项目", "日期", "模板", "进展", "问题", "下一步"]
        let rows = records.map { record -> [String] in
            let fields = fields(in: record.asset.summary, fallbackText: record.memo.text)
            return [
                headingTitle(record.asset.title),
                DateFormatters.export.string(from: record.memo.createdAt),
                fields["范围"] ?? "",
                fields["项目"] ?? "",
                fields["日期"] ?? "",
                fields["模板"] ?? "",
                fields["进展"] ?? "",
                fields["问题"] ?? "",
                fields["下一步"] ?? ""
            ]
        }

        return ([header] + rows)
            .map { $0.map(csvField).joined(separator: ",") }
            .joined(separator: "\n") + "\n"
    }

    static func reportDraft(
        memos: [Memo],
        assets: [MemoAsset]? = nil,
        style: ReportDraftStyle = .standard
    ) -> String {
        let resolvedAssets = assets ?? memos.flatMap { MemoAsset.assets(in: $0) }
        let records = workLogRecords(from: memos, assets: resolvedAssets)
        guard !records.isEmpty else {
            return emptyReportDraft(style: style)
        }

        let fieldValues = records
            .map { fields(in: $0.asset.summary, fallbackText: $0.memo.text) }
            .sorted(by: sortReportDraftFields)
        switch style {
        case .standard:
            return standardReportDraft(from: fieldValues)
        case .standup:
            return styledReportDraft(
                title: "站会同步",
                inlineKeys: [],
                sections: [
                    ("昨天/已完成", ["进展"]),
                    ("阻塞", ["问题", "风险"]),
                    ("今天/下一步", ["下一步"])
                ],
                from: fieldValues
            )
        case .projectBrief:
            return styledReportDraft(
                title: "项目简报",
                inlineKeys: ["项目", "日期"],
                sections: [
                    ("本期完成", ["进展"]),
                    ("风险/待协助", ["问题", "风险"]),
                    ("后续计划", ["下一步"])
                ],
                from: fieldValues
            )
        }
    }

    private static func emptyReportDraft(style: ReportDraftStyle) -> String {
        switch style {
        case .standard:
            return "工作汇报\n\n暂无可汇总日志。\n"
        case .standup:
            return "站会同步\n\n暂无可汇总日志。\n"
        case .projectBrief:
            return "项目简报\n\n暂无可汇总日志。\n"
        }
    }

    private static func standardReportDraft(from fieldValues: [[String: String]]) -> String {
        var lines = ["工作汇报", ""]
        appendDraftInline("项目", from: fieldValues, to: &lines)
        appendDraftInline("日期", from: fieldValues, to: &lines)
        appendDraftList("进展", from: fieldValues, to: &lines)
        appendDraftList("风险/问题", keys: ["问题", "风险"], from: fieldValues, to: &lines)
        appendDraftList("下一步", from: fieldValues, to: &lines)
        return lines.joined(separator: "\n") + "\n"
    }

    private static func styledReportDraft(
        title: String,
        inlineKeys: [String],
        sections: [(title: String, keys: [String])],
        from fieldValues: [[String: String]]
    ) -> String {
        var lines = [title, ""]
        inlineKeys.forEach { appendDraftInline($0, from: fieldValues, to: &lines) }
        sections.forEach { section in
            appendDraftList(section.title, keys: section.keys, from: fieldValues, to: &lines)
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func workLogRecords(
        from memos: [Memo],
        assets: [MemoAsset]
    ) -> [(memo: Memo, asset: MemoAsset)] {
        let workLogAssetsByMemoID = Dictionary(
            grouping: assets.filter { $0.kind == .workLog },
            by: \.memoID
        )

        return memos.compactMap { memo -> (memo: Memo, asset: MemoAsset)? in
            guard !memo.isArchived,
                  let asset = workLogAssetsByMemoID[memo.id]?.sorted(by: sortAssets).first else {
                return nil
            }
            return (memo, asset)
        }
        .sorted { lhs, rhs in
            if lhs.asset.createdAt == rhs.asset.createdAt {
                return lhs.asset.title < rhs.asset.title
            }
            return lhs.asset.createdAt > rhs.asset.createdAt
        }
    }

    private static func sortAssets(_ lhs: MemoAsset, _ rhs: MemoAsset) -> Bool {
        if lhs.createdAt == rhs.createdAt {
            return lhs.title < rhs.title
        }
        return lhs.createdAt > rhs.createdAt
    }

    private static func reportSummary(for records: [(memo: Memo, asset: MemoAsset)]) -> String {
        let fieldValues = records.map { fields(in: $0.asset.summary, fallbackText: $0.memo.text) }
        var lines = ["## 汇报摘要"]

        appendSummaryLine("项目", from: fieldValues, to: &lines)
        appendSummaryLine("日期", from: fieldValues, to: &lines)
        appendSummaryLine("进展", from: fieldValues, to: &lines)
        appendSummaryLine("风险/问题", keys: ["问题", "风险"], from: fieldValues, to: &lines)
        appendSummaryLine("下一步", from: fieldValues, to: &lines)

        if lines.count == 1 {
            lines.append("- 暂无可汇总字段。")
        }

        return lines.joined(separator: "\n")
    }

    private static func appendSummaryLine(
        _ title: String,
        keys: [String]? = nil,
        from fieldValues: [[String: String]],
        to lines: inout [String]
    ) {
        let values = uniqueValues(
            fieldValues.flatMap { fields -> [String] in
                (keys ?? [title]).compactMap { fields[$0] }
            }
        )
        guard !values.isEmpty else { return }
        lines.append("- \(title)：\(values.joined(separator: "；"))")
    }

    private static func appendDraftInline(
        _ title: String,
        from fieldValues: [[String: String]],
        to lines: inout [String]
    ) {
        let values = uniqueValues(fieldValues.compactMap { $0[title] })
        guard !values.isEmpty else { return }
        lines.append("\(title)：\(values.joined(separator: "；"))")
    }

    private static func sortReportDraftFields(_ lhs: [String: String], _ rhs: [String: String]) -> Bool {
        let lhsPriority = reportDraftTemplatePriority(lhs["模板"])
        let rhsPriority = reportDraftTemplatePriority(rhs["模板"])
        if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
        }
        return (lhs["日期"] ?? "") > (rhs["日期"] ?? "")
    }

    private static func reportDraftTemplatePriority(_ template: String?) -> Int {
        switch template {
        case "项目汇报":
            return 0
        case "周报":
            return 1
        case "日报":
            return 2
        case "复盘":
            return 3
        default:
            return 4
        }
    }

    private static func appendDraftList(
        _ title: String,
        keys: [String]? = nil,
        from fieldValues: [[String: String]],
        to lines: inout [String]
    ) {
        let values = uniqueValues(
            fieldValues.flatMap { fields -> [String] in
                (keys ?? [title]).compactMap { fields[$0] }
            }
        )
        guard !values.isEmpty else { return }
        if let lastLine = lines.last, !lastLine.isEmpty {
            lines.append("")
        }
        lines.append("\(title)：")
        lines.append(contentsOf: values.enumerated().map { index, value in
            "\(index + 1). \(value)"
        })
    }

    private static func appendMetadata(
        _ key: String,
        from fields: [String: String],
        to metadata: inout [String]
    ) {
        guard let value = fields[key], !value.isEmpty else { return }
        metadata.append("- \(key)：\(value)")
    }

    private static func fields(in summary: String?, fallbackText: String) -> [String: String] {
        var result: [String: String] = [:]

        let summaryParts = summary?
            .components(separatedBy: " · ")
            .flatMap { $0.components(separatedBy: .newlines) } ?? []
        (summaryParts + fallbackText.components(separatedBy: .newlines))
            .compactMap(field)
            .forEach { key, value in
                if result[key] == nil {
                    result[key] = value
                }
            }

        return result
    }

    private static func field(in line: String) -> (String, String)? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        for separator in ["：", ":"] {
            guard let range = trimmed.range(of: separator) else { continue }
            let key = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !value.isEmpty else { return nil }
            return (key, value)
        }
        return nil
    }

    private static func uniqueValues(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { continue }
            result.append(normalized)
        }

        return result
    }

    private static func headingTitle(_ title: String) -> String {
        let trimmed = title
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名工作日志" : trimmed
    }

    private static func csvField(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",")
            || escaped.contains("\"")
            || escaped.contains("\n")
            || escaped.contains("\r") {
            return "\"\(escaped)\""
        }
        return escaped
    }
}
