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
    var wearCount: Int
    var purchasePrice: Double?
    var lastWornAt: Date?
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

struct WardrobeWearLogInsight: Identifiable, Equatable {
    var id: UUID
    var memoID: UUID
    var title: String
    var itemNames: [String]
    var scenes: [String]
    var weather: String?
    var note: String?
    var wornAt: Date
    var createdAt: Date
}

struct WardrobeLaundryLogInsight: Identifiable, Equatable {
    var id: UUID
    var memoID: UUID
    var title: String
    var itemNames: [String]
    var status: String
    var note: String?
    var loggedAt: Date
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
    var costPerWear: Double?
    var lastWornAt: Date?

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

struct WardrobePackingSuggestion: Identifiable, Equatable {
    var id: String
    var title: String
    var destination: String?
    var weather: String?
    var itemNames: [String]
    var note: String?
}

struct WardrobeCareReminder: Identifiable, Equatable {
    var id: String
    var itemName: String
    var status: String
    var detail: String
    var loggedAt: Date?
}

struct WardrobeInsights: Equatable {
    var items: [WardrobeItemInsight]
    var outfits: [WardrobeOutfitInsight]
    var wearLogs: [WardrobeWearLogInsight]
    var laundryLogs: [WardrobeLaundryLogInsight]
    var categoryStats: [WardrobeInsightMetric]
    var colorStats: [WardrobeInsightMetric]
    var seasonStats: [WardrobeInsightMetric]
    var sceneStats: [WardrobeInsightMetric]
    var unusedItems: [WardrobeItemInsight]
    var frequentItems: [WardrobeItemUsage]
    var suggestions: [WardrobeOutfitSuggestion]
    var packingSuggestions: [WardrobePackingSuggestion]
    var careReminders: [WardrobeCareReminder]

    static let empty = WardrobeInsights(
        items: [],
        outfits: [],
        wearLogs: [],
        laundryLogs: [],
        categoryStats: [],
        colorStats: [],
        seasonStats: [],
        sceneStats: [],
        unusedItems: [],
        frequentItems: [],
        suggestions: [],
        packingSuggestions: [],
        careReminders: []
    )
}

enum WardrobeInsightEngine {
    static func insights(for assets: [MemoAsset]) -> WardrobeInsights {
        let outfits = assets
            .filter { $0.kind == .outfit }
            .compactMap(outfit(from:))
            .sorted { $0.createdAt == $1.createdAt ? $0.title < $1.title : $0.createdAt > $1.createdAt }
        let wearLogs = assets
            .filter { $0.kind == .wearLog }
            .compactMap(wearLog(from:))
            .sorted { $0.wornAt == $1.wornAt ? $0.title < $1.title : $0.wornAt > $1.wornAt }
        let laundryLogs = assets
            .filter { $0.kind == .laundryLog }
            .compactMap(laundryLog(from:))
            .sorted { $0.loggedAt == $1.loggedAt ? $0.title < $1.title : $0.loggedAt > $1.loggedAt }

        let usageByName = itemUsageCounts(in: outfits)
        let wearStatsByName = wearStats(in: wearLogs)
        let unavailableNames = unavailableItemNames(in: laundryLogs)
        var parsedItems: [WardrobeItemInsight] = []
        for asset in assets where asset.kind == .wardrobeItem {
            let usageCount = usageByName[wardrobeNormalizedName(asset.title)] ?? 0
            let wearStats = wearStatsByName[wardrobeNormalizedName(asset.title)]
            if let parsedItem = item(
                from: asset,
                outfitCount: usageCount,
                wearCount: wearStats?.count ?? 0,
                lastWornAt: wearStats?.lastWornAt
            ) {
                parsedItems.append(parsedItem)
            }
        }
        let items = parsedItems.sorted(by: sortItemsByDateThenName)

        let categories = items.map { $0.category }.filter { !$0.isEmpty }
        let colors = items.flatMap { $0.colors }
        let seasons = items.flatMap { $0.seasons } + outfits.flatMap { $0.seasons }
        let scenes = items.flatMap { $0.scenes } + outfits.flatMap { $0.scenes } + wearLogs.flatMap { $0.scenes }
        let categoryStats = stats(from: categories)
        let colorStats = stats(from: colors)
        let seasonStats = stats(from: seasons)
        let sceneStats = stats(from: scenes)
        let unusedItems = items
            .filter { $0.outfitCount == 0 }
            .sorted(by: sortItemsByDateThenName)
        let usedItems = items.filter { $0.outfitCount > 0 || $0.wearCount > 0 }
        let frequentItems = usedItems
            .map {
                WardrobeItemUsage(
                    item: $0,
                    count: max($0.wearCount, $0.outfitCount),
                    costPerWear: costPerWear(price: $0.purchasePrice, wearCount: $0.wearCount),
                    lastWornAt: $0.lastWornAt
                )
            }
            .sorted(by: sortUsageByCountThenName)

        return WardrobeInsights(
            items: items,
            outfits: outfits,
            wearLogs: wearLogs,
            laundryLogs: laundryLogs,
            categoryStats: categoryStats,
            colorStats: colorStats,
            seasonStats: seasonStats,
            sceneStats: sceneStats,
            unusedItems: unusedItems,
            frequentItems: Array(frequentItems.prefix(5)),
            suggestions: suggestions(
                items: items,
                outfits: outfits,
                wearLogs: wearLogs,
                unusedItems: unusedItems,
                unavailableNames: unavailableNames,
                sceneStats: sceneStats,
                seasonStats: seasonStats
            ),
            packingSuggestions: packingSuggestions(
                items: items,
                outfits: outfits,
                wearLogs: wearLogs,
                unavailableNames: unavailableNames,
                sceneStats: sceneStats,
                seasonStats: seasonStats
            ),
            careReminders: careReminders(in: laundryLogs)
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

    private static func item(
        from asset: MemoAsset,
        outfitCount: Int,
        wearCount: Int,
        lastWornAt: Date?
    ) -> WardrobeItemInsight? {
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
            wearCount: wearCount,
            purchasePrice: parsedPrice(fields["价格"]?.first),
            lastWornAt: lastWornAt,
            uri: asset.uri,
            typeIdentifier: asset.typeIdentifier,
            createdAt: asset.createdAt
        )
    }

    private static func wearLog(from asset: MemoAsset) -> WardrobeWearLogInsight? {
        guard asset.kind == .wearLog else { return nil }
        let fields = fields(in: asset.summary)
        let wornAt = fields["日期"]?.first.flatMap { DateFormatters.wardrobeDay.date(from: $0) } ?? asset.createdAt
        return WardrobeWearLogInsight(
            id: asset.id,
            memoID: asset.memoID,
            title: asset.title,
            itemNames: fields["单品"] ?? [],
            scenes: fields["场景"] ?? [],
            weather: fields["天气"]?.joined(separator: "、"),
            note: fields["备注"]?.joined(separator: "、"),
            wornAt: wornAt,
            createdAt: asset.createdAt
        )
    }

    private static func laundryLog(from asset: MemoAsset) -> WardrobeLaundryLogInsight? {
        guard asset.kind == .laundryLog else { return nil }
        let fields = fields(in: asset.summary)
        let loggedAt = fields["日期"]?.first.flatMap { DateFormatters.wardrobeDay.date(from: $0) } ?? asset.createdAt
        guard let status = fields["状态"]?.first, !status.isEmpty else {
            return nil
        }
        return WardrobeLaundryLogInsight(
            id: asset.id,
            memoID: asset.memoID,
            title: asset.title,
            itemNames: fields["单品"] ?? [],
            status: status,
            note: fields["备注"]?.joined(separator: "、"),
            loggedAt: loggedAt,
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

    private static func wearStats(in wearLogs: [WardrobeWearLogInsight]) -> [String: (count: Int, lastWornAt: Date?)] {
        var stats: [String: (count: Int, lastWornAt: Date?)] = [:]
        for log in wearLogs {
            for name in Set(log.itemNames.map(wardrobeNormalizedName).filter { !$0.isEmpty }) {
                let current = stats[name]
                let lastWornAt: Date?
                if let existing = current?.lastWornAt {
                    lastWornAt = max(existing, log.wornAt)
                } else {
                    lastWornAt = log.wornAt
                }
                stats[name] = ((current?.count ?? 0) + 1, lastWornAt)
            }
        }
        return stats
    }

    private static func suggestions(
        items: [WardrobeItemInsight],
        outfits: [WardrobeOutfitInsight],
        wearLogs: [WardrobeWearLogInsight],
        unusedItems: [WardrobeItemInsight],
        unavailableNames: Set<String>,
        sceneStats: [WardrobeInsightMetric],
        seasonStats: [WardrobeInsightMetric]
    ) -> [WardrobeOutfitSuggestion] {
        guard !items.isEmpty else { return [] }

        var suggestions: [WardrobeOutfitSuggestion] = []
        let availableItems = items.filter { !unavailableNames.contains(wardrobeNormalizedName($0.name)) }

        if let weatherSuggestion = suggestionForWeather(from: wearLogs, items: availableItems) {
            suggestions.append(weatherSuggestion)
        }

        if let seed = unusedItems.first(where: { !unavailableNames.contains(wardrobeNormalizedName($0.name)) }) {
            let companions = companionItems(for: seed, in: availableItems)
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
           let sceneSuggestion = suggestionForScene(topScene.label, items: availableItems) {
            suggestions.append(sceneSuggestion)
        }

        if let topSeason = seasonStats.first,
           let seasonSuggestion = suggestionForSeason(topSeason.label, items: availableItems) {
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

        if outfits.isEmpty, let first = availableItems.first ?? items.first {
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

    private static func suggestionForWeather(
        from wearLogs: [WardrobeWearLogInsight],
        items: [WardrobeItemInsight]
    ) -> WardrobeOutfitSuggestion? {
        guard let weather = wearLogs.first(where: { $0.weather?.isEmpty == false })?.weather,
              !items.isEmpty else {
            return nil
        }
        let matchedItems = items
            .filter { item in weatherScore(item, weather: weather) > 0 }
            .sorted { lhs, rhs in
                let lhsScore = weatherScore(lhs, weather: weather)
                let rhsScore = weatherScore(rhs, weather: weather)
                if lhsScore == rhsScore {
                    return lhs.wearCount == rhs.wearCount ? lhs.name < rhs.name : lhs.wearCount < rhs.wearCount
                }
                return lhsScore > rhsScore
            }
        let draftItems = categoryBalancedItems(from: matchedItems.isEmpty ? items : matchedItems).map(\.name)
        guard !draftItems.isEmpty else { return nil }

        return WardrobeOutfitSuggestion(
            id: "weather-\(weather)",
            title: "\(weather) 天气穿搭",
            detail: "参考最近穿着天气，优先挑适合当前气候、且不在待洗待修里的单品。",
            systemImage: weatherSystemImage(for: weather),
            itemNames: draftItems,
            scenes: commonValues(matchedItems.flatMap(\.scenes)),
            seasons: commonValues(matchedItems.flatMap(\.seasons)),
            note: "由衣橱洞察生成：天气 \(weather)。"
        )
    }

    private static func packingSuggestions(
        items: [WardrobeItemInsight],
        outfits: [WardrobeOutfitInsight],
        wearLogs: [WardrobeWearLogInsight],
        unavailableNames: Set<String>,
        sceneStats: [WardrobeInsightMetric],
        seasonStats: [WardrobeInsightMetric]
    ) -> [WardrobePackingSuggestion] {
        let availableItems = items.filter { !unavailableNames.contains(wardrobeNormalizedName($0.name)) }
        guard !availableItems.isEmpty else { return [] }

        var suggestions: [WardrobePackingSuggestion] = []
        let weather = wearLogs.first(where: { $0.weather?.isEmpty == false })?.weather
        let season = seasonStats.first?.label
        let scene = sceneStats.first?.label ?? "旅行"
        let weatherItems = weather.map { weatherValue in
            availableItems
                .filter { weatherScore($0, weather: weatherValue) > 0 }
                .sorted { lhs, rhs in
                    let lhsScore = weatherScore(lhs, weather: weatherValue)
                    let rhsScore = weatherScore(rhs, weather: weatherValue)
                    if lhsScore == rhsScore { return lhs.wearCount < rhs.wearCount }
                    return lhsScore > rhsScore
                }
        } ?? []
        let baseItems = weatherItems.isEmpty
            ? availableItems.filter { item in
                (season.map { item.seasons.contains($0) } ?? false)
                    || item.scenes.contains(scene)
                    || item.scenes.contains("旅行")
            }
            : weatherItems
        let selectedItems = categoryBalancedItems(from: baseItems.isEmpty ? availableItems : baseItems).map(\.name)
        if !selectedItems.isEmpty {
            suggestions.append(
                WardrobePackingSuggestion(
                    id: "packing-weather",
                    title: "\(scene) 快速打包",
                    destination: nil,
                    weather: weather,
                    itemNames: selectedItems,
                    note: packingNote(weather: weather, season: season, scene: scene)
                )
            )
        }

        if let outfit = outfits.first(where: { !$0.itemNames.isEmpty }) {
            let outfitItems = outfit.itemNames.filter { !unavailableNames.contains(wardrobeNormalizedName($0)) }
            if !outfitItems.isEmpty {
                suggestions.append(
                    WardrobePackingSuggestion(
                        id: "packing-outfit-\(outfit.id.uuidString)",
                        title: "\(outfit.title) 打包",
                        destination: nil,
                        weather: weather,
                        itemNames: outfitItems,
                        note: "从最近穿搭生成，出门前检查鞋履、包包和饰品是否齐全。"
                    )
                )
            }
        }

        return Array(suggestions.uniquedByID().prefix(3))
    }

    private static func careReminders(in laundryLogs: [WardrobeLaundryLogInsight]) -> [WardrobeCareReminder] {
        var latestByItem: [String: WardrobeLaundryLogInsight] = [:]
        for log in laundryLogs {
            for name in log.itemNames {
                let key = wardrobeNormalizedName(name)
                guard !key.isEmpty else { continue }
                if let current = latestByItem[key], current.loggedAt >= log.loggedAt {
                    continue
                }
                latestByItem[key] = log
            }
        }

        return latestByItem
            .compactMap { entry -> WardrobeCareReminder? in
                let key = entry.key
                let log = entry.value
                guard isUnavailableLaundryStatus(log.status),
                      let itemName = log.itemNames.first(where: { wardrobeNormalizedName($0) == key }) else {
                    return nil
                }
                return WardrobeCareReminder(
                    id: "\(key)-\(log.status)",
                    itemName: itemName,
                    status: log.status,
                    detail: careDetail(for: log),
                    loggedAt: log.loggedAt
                )
            }
            .sorted { lhs, rhs in
                switch (lhs.loggedAt, rhs.loggedAt) {
                case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                    return lhsDate > rhsDate
                default:
                    return lhs.itemName < rhs.itemName
                }
            }
            .prefix(6)
            .map { $0 }
    }

    private static func unavailableItemNames(in laundryLogs: [WardrobeLaundryLogInsight]) -> Set<String> {
        Set(
            careReminders(in: laundryLogs)
                .map { wardrobeNormalizedName($0.itemName) }
                .filter { !$0.isEmpty }
        )
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
        if item.wearCount == 0 { score += 1 }
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

    private static func weatherScore(_ item: WardrobeItemInsight, weather: String) -> Int {
        let text = weather.lowercased()
        var score = 0
        if containsAny(text, ["雨", "阵雨", "rain"]) {
            if item.category == "鞋履" { score += 3 }
            if item.category == "外套" { score += 2 }
            if item.scenes.contains("旅行") { score += 1 }
        }
        if containsAny(text, ["冷", "寒", "雪", "低温", "wind", "snow"]) {
            if item.category == "外套" { score += 4 }
            if item.seasons.contains("冬") || item.seasons.contains("秋") { score += 3 }
        }
        if containsAny(text, ["热", "高温", "晴", "sun", "hot"]) {
            if item.seasons.contains("夏") { score += 3 }
            if item.category == "上装" || item.category == "连衣裙" { score += 1 }
        }
        if containsAny(text, ["多云", "阴", "cloud"]) {
            if item.seasons.contains("春") || item.seasons.contains("秋") { score += 2 }
            if item.category == "外套" { score += 1 }
        }
        if item.scenes.contains("通勤") { score += 1 }
        return score
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0.lowercased()) }
    }

    private static func weatherSystemImage(for weather: String) -> String {
        let text = weather.lowercased()
        if containsAny(text, ["雨", "rain"]) { return "cloud.rain" }
        if containsAny(text, ["雪", "snow"]) { return "snowflake" }
        if containsAny(text, ["晴", "sun", "热", "hot"]) { return "sun.max" }
        if containsAny(text, ["多云", "阴", "cloud"]) { return "cloud.sun" }
        return "thermometer.medium"
    }

    private static func packingNote(weather: String?, season: String?, scene: String) -> String {
        var parts = ["按 \(scene) 场景生成，已避开待洗待修单品。"]
        if let weather = weather, !weather.isEmpty {
            parts.append("天气参考：\(weather)。")
        }
        if let season = season, !season.isEmpty {
            parts.append("季节参考：\(season)。")
        }
        parts.append("出发前补充内搭、睡衣、充电器和证件。")
        return parts.joined(separator: " ")
    }

    private static func isUnavailableLaundryStatus(_ status: String) -> Bool {
        containsAny(status, ["待清洗", "送洗", "待熨烫", "待修补", "脏", "修", "熨"])
    }

    private static func careDetail(for log: WardrobeLaundryLogInsight) -> String {
        let dateText = DateFormatters.compactDay.string(from: log.loggedAt)
        if let note = log.note, !note.isEmpty {
            return "\(dateText) · \(note)"
        }
        return dateText
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

    private static func parsedPrice(_ text: String?) -> Double? {
        guard let text = text else { return nil }
        let normalized = text
            .replacingOccurrences(of: "￥", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "元", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(normalized)
    }

    private static func costPerWear(price: Double?, wearCount: Int) -> Double? {
        guard let price = price, wearCount > 0 else {
            return nil
        }

        return price / Double(wearCount)
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

private extension Array where Element == WardrobePackingSuggestion {
    func uniquedByID() -> [WardrobePackingSuggestion] {
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
