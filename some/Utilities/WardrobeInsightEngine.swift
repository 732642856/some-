import Foundation

struct WardrobeItemInsight: Identifiable, Equatable {
    var id: UUID
    var memoID: UUID
    var name: String
    var category: String
    var colors: [String]
    var seasons: [String]
    var scenes: [String]
    var outfitCount: Int
    var uri: String?
    var typeIdentifier: String?
    var createdAt: Date
}

struct WardrobeOutfitInsight: Identifiable, Equatable {
    var id: UUID
    var memoID: UUID
    var title: String
    var itemNames: [String]
    var scenes: [String]
    var seasons: [String]
    var note: String?
    var createdAt: Date
}

struct WardrobeInsightMetric: Identifiable, Equatable {
    var label: String
    var count: Int

    var id: String { label }
}

struct WardrobeItemUsage: Identifiable, Equatable {
    var item: WardrobeItemInsight
    var count: Int

    var id: UUID { item.id }
}

struct WardrobeOutfitSuggestion: Identifiable, Equatable {
    var id: String
    var title: String
    var detail: String
    var systemImage: String
    var itemNames: [String]
    var scenes: [String]
    var seasons: [String]
    var note: String?
}

struct WardrobeInsights: Equatable {
    var items: [WardrobeItemInsight]
    var outfits: [WardrobeOutfitInsight]
    var categoryStats: [WardrobeInsightMetric]
    var colorStats: [WardrobeInsightMetric]
    var seasonStats: [WardrobeInsightMetric]
    var sceneStats: [WardrobeInsightMetric]
    var unusedItems: [WardrobeItemInsight]
    var frequentItems: [WardrobeItemUsage]
    var suggestions: [WardrobeOutfitSuggestion]

    static let empty = WardrobeInsights(
        items: [],
        outfits: [],
        categoryStats: [],
        colorStats: [],
        seasonStats: [],
        sceneStats: [],
        unusedItems: [],
        frequentItems: [],
        suggestions: []
    )
}

enum WardrobeInsightEngine {
    static func insights(for assets: [MemoAsset]) -> WardrobeInsights {
        let outfits = assets
            .filter { $0.kind == .outfit }
            .compactMap(outfit(from:))
            .sorted { $0.createdAt == $1.createdAt ? $0.title < $1.title : $0.createdAt > $1.createdAt }

        let usageByName = itemUsageCounts(in: outfits)
        var parsedItems: [WardrobeItemInsight] = []
        for asset in assets where asset.kind == .wardrobeItem {
            let usageCount = usageByName[wardrobeNormalizedName(asset.title)] ?? 0
            if let parsedItem = item(from: asset, outfitCount: usageCount) {
                parsedItems.append(parsedItem)
            }
        }
        let items = parsedItems.sorted(by: sortItemsByDateThenName)

        let categories = items.map { $0.category }.filter { !$0.isEmpty }
        let colors = items.flatMap { $0.colors }
        let seasons = items.flatMap { $0.seasons } + outfits.flatMap { $0.seasons }
        let scenes = items.flatMap { $0.scenes } + outfits.flatMap { $0.scenes }
        let categoryStats = stats(from: categories)
        let colorStats = stats(from: colors)
        let seasonStats = stats(from: seasons)
        let sceneStats = stats(from: scenes)
        let unusedItems = items
            .filter { $0.outfitCount == 0 }
            .sorted(by: sortItemsByDateThenName)
        let usedItems = items.filter { $0.outfitCount > 0 }
        let frequentItems = usedItems
            .map { WardrobeItemUsage(item: $0, count: $0.outfitCount) }
            .sorted(by: sortUsageByCountThenName)

        return WardrobeInsights(
            items: items,
            outfits: outfits,
            categoryStats: categoryStats,
            colorStats: colorStats,
            seasonStats: seasonStats,
            sceneStats: sceneStats,
            unusedItems: unusedItems,
            frequentItems: Array(frequentItems.prefix(5)),
            suggestions: suggestions(items: items, outfits: outfits, unusedItems: unusedItems, sceneStats: sceneStats, seasonStats: seasonStats)
        )
    }

    private static func sortItemsByDateThenName(_ lhs: WardrobeItemInsight, _ rhs: WardrobeItemInsight) -> Bool {
        if lhs.createdAt == rhs.createdAt {
            return lhs.name < rhs.name
        }
        return lhs.createdAt > rhs.createdAt
    }

    private static func sortUsageByCountThenName(_ lhs: WardrobeItemUsage, _ rhs: WardrobeItemUsage) -> Bool {
        if lhs.count == rhs.count {
            return lhs.item.name < rhs.item.name
        }
        return lhs.count > rhs.count
    }

    private static func item(from asset: MemoAsset, outfitCount: Int) -> WardrobeItemInsight? {
        guard asset.kind == .wardrobeItem else { return nil }
        let fields = fields(in: asset.summary)
        return WardrobeItemInsight(
            id: asset.id,
            memoID: asset.memoID,
            name: asset.title,
            category: fields["分类"]?.first ?? "",
            colors: fields["颜色"] ?? [],
            seasons: fields["季节"] ?? [],
            scenes: fields["场景"] ?? [],
            outfitCount: outfitCount,
            uri: asset.uri,
            typeIdentifier: asset.typeIdentifier,
            createdAt: asset.createdAt
        )
    }

    private static func outfit(from asset: MemoAsset) -> WardrobeOutfitInsight? {
        guard asset.kind == .outfit else { return nil }
        let fields = fields(in: asset.summary)
        return WardrobeOutfitInsight(
            id: asset.id,
            memoID: asset.memoID,
            title: asset.title,
            itemNames: fields["单品"] ?? [],
            scenes: fields["场景"] ?? [],
            seasons: fields["季节"] ?? [],
            note: fields["备注"]?.joined(separator: "、"),
            createdAt: asset.createdAt
        )
    }

    private static func itemUsageCounts(in outfits: [WardrobeOutfitInsight]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for outfit in outfits {
            for name in Set(outfit.itemNames.map(wardrobeNormalizedName).filter { !$0.isEmpty }) {
                counts[name, default: 0] += 1
            }
        }
        return counts
    }

    private static func suggestions(
        items: [WardrobeItemInsight],
        outfits: [WardrobeOutfitInsight],
        unusedItems: [WardrobeItemInsight],
        sceneStats: [WardrobeInsightMetric],
        seasonStats: [WardrobeInsightMetric]
    ) -> [WardrobeOutfitSuggestion] {
        guard !items.isEmpty else { return [] }

        var suggestions: [WardrobeOutfitSuggestion] = []
        if let seed = unusedItems.first {
            let companions = companionItems(for: seed, in: items)
            let draftItems = ([seed] + companions).uniquedByName().map(\.name)
            suggestions.append(
                WardrobeOutfitSuggestion(
                    id: "unused-\(seed.id.uuidString)",
                    title: "让 \(seed.name) 出场",
                    detail: draftItems.count > 1
                        ? "低频单品优先，先和 \(draftItems.dropFirst().joined(separator: "、")) 组合。"
                        : "这个单品还没有进入任何穿搭，先给它建一个基础组合。",
                    systemImage: "arrow.triangle.2.circlepath",
                    itemNames: draftItems,
                    scenes: seed.scenes,
                    seasons: seed.seasons,
                    note: "由衣橱洞察生成：优先使用未搭配单品。"
                )
            )
        }

        if let topScene = sceneStats.first,
           let sceneSuggestion = suggestionForScene(topScene.label, items: items) {
            suggestions.append(sceneSuggestion)
        }

        if let topSeason = seasonStats.first,
           let seasonSuggestion = suggestionForSeason(topSeason.label, items: items) {
            suggestions.append(seasonSuggestion)
        }

        if missingAccessoryCategories(in: items) {
            suggestions.append(
                WardrobeOutfitSuggestion(
                    id: "missing-accessory",
                    title: "补齐配件层",
                    detail: "鞋履、包包、饰品会显著提升穿搭组合的可用性，下一次录入时优先补这些类别。",
                    systemImage: "handbag",
                    itemNames: [],
                    scenes: [],
                    seasons: [],
                    note: nil
                )
            )
        }

        if outfits.isEmpty, let first = items.first {
            suggestions.append(
                WardrobeOutfitSuggestion(
                    id: "first-outfit",
                    title: "先建第一套穿搭",
                    detail: "已有单品还没有组合记录，可以从最常穿或最想盘活的单品开始。",
                    systemImage: "sparkles",
                    itemNames: [first.name],
                    scenes: first.scenes,
                    seasons: first.seasons,
                    note: "由衣橱洞察生成：第一套穿搭草稿。"
                )
            )
        }

        return Array(suggestions.uniquedByID().prefix(4))
    }

    private static func suggestionForScene(
        _ scene: String,
        items: [WardrobeItemInsight]
    ) -> WardrobeOutfitSuggestion? {
        let sceneItems = items
            .filter { $0.scenes.contains(scene) }
            .sorted { $0.outfitCount == $1.outfitCount ? $0.name < $1.name : $0.outfitCount < $1.outfitCount }
        guard !sceneItems.isEmpty else { return nil }

        let draftItems = categoryBalancedItems(from: sceneItems).map(\.name)
        guard !draftItems.isEmpty else { return nil }

        return WardrobeOutfitSuggestion(
            id: "scene-\(scene)",
            title: "\(scene) 搭配草稿",
            detail: "按场景筛出低频单品，适合快速生成一套可复用组合。",
            systemImage: "scope",
            itemNames: draftItems,
            scenes: [scene],
            seasons: commonValues(sceneItems.flatMap(\.seasons)),
            note: "由衣橱洞察生成：场景 \(scene)。"
        )
    }

    private static func suggestionForSeason(_ season: String, items: [WardrobeItemInsight]) -> WardrobeOutfitSuggestion? {
        let seasonItems = items
            .filter { $0.seasons.contains(season) }
            .sorted { $0.outfitCount == $1.outfitCount ? $0.name < $1.name : $0.outfitCount < $1.outfitCount }
        let draftItems = categoryBalancedItems(from: seasonItems).map(\.name)
        guard !draftItems.isEmpty else { return nil }

        return WardrobeOutfitSuggestion(
            id: "season-\(season)",
            title: "\(season) 季胶囊组合",
            detail: "从这个季节的单品里挑低频项，避免总穿固定几件。",
            systemImage: "leaf",
            itemNames: draftItems,
            scenes: commonValues(seasonItems.flatMap(\.scenes)),
            seasons: [season],
            note: "由衣橱洞察生成：季节 \(season)。"
        )
    }

    private static func companionItems(for seed: WardrobeItemInsight, in items: [WardrobeItemInsight]) -> [WardrobeItemInsight] {
        let preferredCategories = companionCategories(for: seed.category)
        return items
            .filter { $0.id != seed.id }
            .sorted { lhs, rhs in
                let lhsScore = companionScore(lhs, seed: seed, preferredCategories: preferredCategories)
                let rhsScore = companionScore(rhs, seed: seed, preferredCategories: preferredCategories)
                if lhsScore == rhsScore {
                    return lhs.outfitCount == rhs.outfitCount ? lhs.name < rhs.name : lhs.outfitCount < rhs.outfitCount
                }
                return lhsScore > rhsScore
            }
            .prefix(3)
            .map { $0 }
    }

    private static func companionScore(
        _ item: WardrobeItemInsight,
        seed: WardrobeItemInsight,
        preferredCategories: Set<String>
    ) -> Int {
        var score = 0
        if preferredCategories.contains(item.category) { score += 4 }
        if !Set(item.seasons).isDisjoint(with: Set(seed.seasons)) { score += 2 }
        if !Set(item.scenes).isDisjoint(with: Set(seed.scenes)) { score += 2 }
        if item.outfitCount == 0 { score += 1 }
        return score
    }

    private static func companionCategories(for category: String) -> Set<String> {
        switch category {
        case "上装", "外套":
            return ["下装", "鞋履", "包包", "饰品"]
        case "下装", "连衣裙":
            return ["上装", "外套", "鞋履", "包包", "饰品"]
        case "鞋履", "包包", "饰品":
            return ["上装", "下装", "连衣裙", "外套"]
        default:
            return ["上装", "下装", "外套", "鞋履", "包包", "饰品"]
        }
    }

    private static func categoryBalancedItems(from items: [WardrobeItemInsight]) -> [WardrobeItemInsight] {
        var seenCategories = Set<String>()
        var selected: [WardrobeItemInsight] = []
        for item in items {
            let key = item.category.isEmpty ? item.name : item.category
            guard seenCategories.insert(key).inserted else { continue }
            selected.append(item)
            if selected.count == 4 { break }
        }
        return selected
    }

    private static func missingAccessoryCategories(in items: [WardrobeItemInsight]) -> Bool {
        guard items.count >= 3 else { return false }
        let categories = Set(items.map(\.category))
        return ["鞋履", "包包", "饰品"].contains { !categories.contains($0) }
    }

    private static func fields(in summary: String?) -> [String: [String]] {
        guard let summary = summary else { return [:] }

        var fields: [String: [String]] = [:]
        for part in summary.components(separatedBy: " · ") {
            guard let parsed = field(in: part) else { continue }
            fields[parsed.label] = splitValues(parsed.value)
        }
        return fields
    }

    private static func field(in text: String) -> (label: String, value: String)? {
        if let range = text.range(of: "：") {
            return (
                text[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines),
                text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        if let range = text.range(of: ":") {
            return (
                text[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines),
                text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        return nil
    }

    private static func splitValues(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet(charactersIn: "、,，/ "))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func stats(from values: [String]) -> [WardrobeInsightMetric] {
        var counts: [String: Int] = [:]
        for value in values where !value.isEmpty {
            counts[value, default: 0] += 1
        }
        return counts
            .map { WardrobeInsightMetric(label: $0.key, count: $0.value) }
            .sorted { $0.count == $1.count ? $0.label < $1.label : $0.count > $1.count }
    }

    private static func commonValues(_ values: [String]) -> [String] {
        Array(stats(from: values).prefix(2).map(\.label))
    }
}

private extension Array where Element == WardrobeItemInsight {
    func uniquedByName() -> [WardrobeItemInsight] {
        var seen = Set<String>()
        return filter { seen.insert(wardrobeNormalizedName($0.name)).inserted }
    }
}

private extension Array where Element == WardrobeOutfitSuggestion {
    func uniquedByID() -> [WardrobeOutfitSuggestion] {
        var seen = Set<String>()
        return filter { seen.insert($0.id).inserted }
    }
}

private func wardrobeNormalizedName(_ name: String) -> String {
    name
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
        .replacingOccurrences(of: " ", with: "")
}
