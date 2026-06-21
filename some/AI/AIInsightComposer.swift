import Foundation

enum AIInsightMode: String, CaseIterable, Identifiable {
    case weeklyReview
    case stuckBreaker
    case selfAwareness
    case topicResearch
    case writingSpark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weeklyReview: return "周期复盘"
        case .stuckBreaker: return "困惑破局"
        case .selfAwareness: return "自我觉察"
        case .topicResearch: return "主题研究"
        case .writingSpark: return "写作灵感"
        }
    }

    var systemImage: String {
        switch self {
        case .weeklyReview: return "calendar.badge.clock"
        case .stuckBreaker: return "lightbulb.max"
        case .selfAwareness: return "person.crop.circle.badge.questionmark"
        case .topicResearch: return "scope"
        case .writingSpark: return "text.quote"
        }
    }

    var instruction: String {
        switch self {
        case .weeklyReview:
            return "用于周期复盘。找出这组笔记里反复出现的主题、情绪和行动线索，帮用户看到一段时间内真正关心的事。"
        case .stuckBreaker:
            return "用于困惑破局。识别用户卡住的根因、隐含假设、可验证的小实验，并提出能推动下一步的问题。"
        case .selfAwareness:
            return "用于自我觉察。观察用户的偏好、价值观、能量来源、回避模式和矛盾点，表达要克制，不要诊断。"
        case .topicResearch:
            return "用于主题研究。围绕笔记里的一个或多个主题归纳观点、证据、待补材料和可延展的问题。"
        case .writingSpark:
            return "用于写作灵感。把零散笔记转成可写作的角度、标题、论点、素材组合和开头草稿。"
        }
    }
}

enum AIInsightRange: String, CaseIterable, Identifiable {
    case today
    case lastSevenDays
    case lastThirtyDays
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "今天"
        case .lastSevenDays: return "7 天"
        case .lastThirtyDays: return "30 天"
        case .all: return "全部"
        }
    }

    func filter(_ memos: [Memo], calendar: Calendar = .current) -> [Memo] {
        let activeMemos = memos.filter { !$0.isArchived }

        switch self {
        case .today:
            return activeMemos.filter { calendar.isDateInToday($0.createdAt) }
        case .lastSevenDays:
            return activeMemosSince(days: 7, memos: activeMemos, calendar: calendar)
        case .lastThirtyDays:
            return activeMemosSince(days: 30, memos: activeMemos, calendar: calendar)
        case .all:
            return activeMemos
        }
    }

    private func activeMemosSince(days: Int, memos: [Memo], calendar: Calendar) -> [Memo] {
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: Date())) else {
            return memos
        }
        return memos.filter { $0.createdAt >= start }
    }
}

enum AIInsightComposer {
    static func prompt(
        mode: AIInsightMode,
        memos: [Memo],
        focus: String,
        maxMemoCount: Int = 80
    ) -> String {
        let selectedMemos = memos
            .sorted { $0.createdAt < $1.createdAt }
            .suffix(maxMemoCount)

        let memoText = selectedMemos.map { memo in
            let tags = memo.tags.map { "#\($0)" }.joined(separator: " ")
            return """
            - 时间：\(DateFormatters.export.string(from: memo.createdAt))
              标签：\(tags.isEmpty ? "无" : tags)
              内容：\(memo.text)
            """
        }
        .joined(separator: "\n")

        let trimmedFocus = focus.trimmingCharacters(in: .whitespacesAndNewlines)
        let focusText = trimmedFocus.isEmpty ? "无，直接从笔记中提炼。" : trimmedFocus

        return """
        你是一个中文个人知识管理助理，任务是做 AI 洞察，而不是总结流水账。
        请只基于用户提供的笔记，不要编造事实，不要做医学、法律、财务诊断。

        洞察类型：\(mode.title)
        分析目标：\(mode.instruction)
        用户关注点：\(focusText)

        输出格式请严格使用 Markdown，并包含这些小节：
        ## 核心主题
        用 3-5 条概括反复出现的主题。

        ## 关键洞察
        给出 3-5 条有解释力的观察，每条都要引用或贴近原始笔记里的具体内容。

        ## 盲点与矛盾
        指出可能被忽略的假设、矛盾、缺失信息或重复模式。语气要温和，不要武断。

        ## 深层问题
        提出 5 个能帮助继续思考的问题。

        ## 下一步
        给出 3 个很小、今天或本周能执行的动作。

        如果材料很少，也要诚实说明证据不足，并输出简短洞察。

        笔记材料：
        \(memoText)
        """
    }
}
