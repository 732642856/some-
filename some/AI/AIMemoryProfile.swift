import Foundation

struct AIMemoryProfile: Equatable {
    struct WeightedItem: Equatable, Identifiable {
        let name: String
        let count: Int

        var id: String { name }
    }

    let generatedAt: Date
    let range: AIInsightRange
    let memoCount: Int
    let topTags: [WeightedItem]
    let recurringTerms: [WeightedItem]
    let openTasks: [String]
    let completedTasks: [String]
    let workLogSignals: [String]

    var markdown: String {
        var lines = [
            "AI 记忆档案",
            "",
            "生成时间：\(DateFormatters.export.string(from: generatedAt))",
            "范围：\(range.title)",
            "记录数：\(memoCount)",
            ""
        ]

        appendWeightedSection("常见主题", items: topTags, to: &lines)
        appendWeightedSection("高频词", items: recurringTerms, to: &lines)
        appendListSection("未完成事项", values: openTasks, to: &lines)
        appendListSection("已完成事项", values: completedTasks, to: &lines)
        appendListSection("工作线索", values: workLogSignals, to: &lines)

        if memoCount == 0 {
            lines.append("暂无可生成档案的记录。")
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func appendWeightedSection(_ title: String, items: [WeightedItem], to lines: inout [String]) {
        guard !items.isEmpty else { return }
        lines.append("## \(title)")
        lines.append(contentsOf: items.map { "- \($0.name)（\($0.count)）" })
        lines.append("")
    }

    private func appendListSection(_ title: String, values: [String], to lines: inout [String]) {
        guard !values.isEmpty else { return }
        lines.append("## \(title)")
        lines.append(contentsOf: values.map { "- \($0)" })
        lines.append("")
    }
}

enum AIMemoryProfileBuilder {
    static func profile(
        from memos: [Memo],
        range: AIInsightRange = .lastThirtyDays,
        now: Date = Date(),
        calendar: Calendar = .current,
        limit: Int = 8
    ) -> AIMemoryProfile {
        let selectedMemos = range.filter(memos, calendar: calendar)
        let visibleTexts = selectedMemos.map(visibleText)
        let tasks = visibleTexts.flatMap(MemoTaskParser.taskItems)
        let fieldValues = visibleTexts.map(fields)
        let topTags = weightedItems(
            selectedMemos.flatMap { memo in
                memo.tags.isEmpty ? TagParser.extractTags(from: memo.text) : memo.tags
            },
            limit: limit
        )
        let recurringTerms = weightedItems(
            visibleTexts.flatMap(terms),
            minimumCount: 2,
            limit: limit
        )
        let openTasks = uniqueValues(
            tasks.filter { !$0.isCompleted }.map(\.text),
            limit: limit
        )
        let completedTasks = uniqueValues(
            tasks.filter(\.isCompleted).map(\.text),
            limit: limit
        )
        let workLogSignals = uniqueValues(
            fieldValues.flatMap { fields in
                ["进展", "问题", "风险", "下一步"].compactMap { fields[$0] }
            },
            limit: limit
        )

        return AIMemoryProfile(
            generatedAt: now,
            range: range,
            memoCount: selectedMemos.count,
            topTags: topTags,
            recurringTerms: recurringTerms,
            openTasks: openTasks,
            completedTasks: completedTasks,
            workLogSignals: workLogSignals
        )
    }

    private static func visibleText(for memo: Memo) -> String {
        MemoReferenceParser.displayTextWithoutReferences(
            SharedAttachmentStore.displayTextWithoutAttachmentReferences(memo.text)
        )
    }

    private static func weightedItems(
        _ values: [String],
        minimumCount: Int = 1,
        limit: Int
    ) -> [AIMemoryProfile.WeightedItem] {
        let counts = values.reduce(into: [String: Int]()) { result, value in
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { return }
            result[normalized, default: 0] += 1
        }

        return counts
            .filter { $0.value >= minimumCount }
            .map { AIMemoryProfile.WeightedItem(name: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.count > rhs.count
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func terms(in text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: " \n\t，。！？、；：,.!?;:()（）[]【】"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { term in
                guard term.count >= 2 else { return false }
                guard !term.hasPrefix("#") else { return false }
                guard field(in: term) == nil else { return false }
                return true
            }
    }

    private static func fields(in text: String) -> [String: String] {
        var result: [String: String] = [:]
        text.components(separatedBy: .newlines)
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

    private static func uniqueValues(_ values: [String], limit: Int) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { continue }
            result.append(normalized)
            if result.count >= limit { break }
        }

        return result
    }
}
