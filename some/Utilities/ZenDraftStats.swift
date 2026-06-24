import Foundation

struct ZenDraftStats: Equatable {
    let characterCount: Int
    let lineCount: Int
    let tagCount: Int

    init(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        characterCount = trimmed.filter { !$0.isWhitespace }.count
        lineCount = trimmed
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .count
        tagCount = TagParser.extractTags(from: text).count
    }

    var canSave: Bool {
        characterCount > 0
    }

    var summaryText: String {
        guard canSave else {
            return "空白草稿"
        }

        return "\(characterCount) 字 · \(lineCount) 行 · \(tagCount) 个标签"
    }
}

enum ZenWritingPreference: String, CaseIterable, Identifiable {
    case calm
    case large
    case compact

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calm: return "舒适"
        case .large: return "大字"
        case .compact: return "紧凑"
        }
    }

    var fontSize: Double {
        switch self {
        case .calm: return 22
        case .large: return 28
        case .compact: return 18
        }
    }

    var lineSpacing: Double {
        switch self {
        case .calm: return 7
        case .large: return 10
        case .compact: return 4
        }
    }

    var placeholder: String {
        switch self {
        case .calm: return "只写这一条。"
        case .large: return "慢慢写。"
        case .compact: return "先记下来。"
        }
    }

    static func value(for rawValue: String) -> ZenWritingPreference {
        ZenWritingPreference(rawValue: rawValue) ?? .calm
    }
}

enum ZenWritingGoal: Int, CaseIterable, Identifiable {
    case none = 0
    case hundred = 100
    case threeHundred = 300
    case fiveHundred = 500
    case thousand = 1000

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none: return "无目标"
        case .hundred: return "100字"
        case .threeHundred: return "300字"
        case .fiveHundred: return "500字"
        case .thousand: return "1000字"
        }
    }

    var targetCount: Int? {
        rawValue > 0 ? rawValue : nil
    }

    func progressText(currentCount: Int) -> String {
        guard let targetCount = targetCount else {
            return "\(currentCount) 字"
        }

        return "\(currentCount)/\(targetCount) 字"
    }

    func progressFraction(currentCount: Int) -> Double {
        guard let targetCount = targetCount, targetCount > 0 else {
            return 0
        }

        return min(max(Double(currentCount) / Double(targetCount), 0), 1)
    }

    static func value(for rawValue: Int) -> ZenWritingGoal {
        ZenWritingGoal(rawValue: rawValue) ?? .none
    }
}
