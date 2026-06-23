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
