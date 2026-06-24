import Foundation

enum MemoContentFilter: String, CaseIterable, Hashable {
    case link
    case attachment
    case task
    case openTask = "open-task"
    case completedTask = "completed-task"
    case reference
    case referenceNote = "reference-note"
    case backlink
    case webClip = "web-clip"
    case clipFragment = "clip-fragment"
    case imageEdit = "image-edit"
    case screenshot
    case ocrReview = "ocr-review"
    case scrapbook
    case audio
    case video
    case wardrobe
    case outfit
    case wearLog = "wear-log"
    case laundryLog = "laundry-log"
    case packingList = "packing-list"
    case workLog = "work-log"
}

enum MemoDateField: String, Hashable {
    case created
    case updated
}

enum MemoDateOperator: String, Hashable {
    case on
    case before
    case onOrBefore
    case after
    case onOrAfter
}

struct MemoDateFilter: Equatable, Hashable {
    let field: MemoDateField
    let operation: MemoDateOperator
    let start: Date
    let end: Date
}

struct MemoSearchQuery: Equatable {
    let rawText: String
    let textTerms: [String]
    let tagFilters: [String]
    let requiredContentFilters: [MemoContentFilter]
    let excludedContentFilters: [MemoContentFilter]
    let dateFilters: [MemoDateFilter]
    let isPinned: Bool?
    let isArchived: Bool?

    var text: String {
        textTerms.joined(separator: " ")
    }

    var hasTextTerms: Bool {
        !textTerms.isEmpty
    }

    var hasContentFilters: Bool {
        !requiredContentFilters.isEmpty || !excludedContentFilters.isEmpty
    }

    var hasDateFilters: Bool {
        !dateFilters.isEmpty
    }
}

enum MemoSearchQueryParser {
    static func parse(_ rawText: String) -> MemoSearchQuery {
        var textTerms: [String] = []
        var tagFilters: [String] = []
        var requiredContentFilters: [MemoContentFilter] = []
        var excludedContentFilters: [MemoContentFilter] = []
        var dateFilters: [MemoDateFilter] = []
        var isPinned: Bool?
        var isArchived: Bool?

        for token in tokenize(rawText) {
            let lowercased = token.lowercased()

            if token.hasPrefix("#") {
                let tag = String(token.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                if !tag.isEmpty {
                    tagFilters.append(tag)
                }
            } else if lowercased == "is:pinned" || lowercased == "is:pin" || token == "is:置顶" {
                isPinned = true
            } else if lowercased == "is:unpinned" || lowercased == "is:unpin" || token == "is:未置顶" {
                isPinned = false
            } else if lowercased == "is:archived" || lowercased == "is:archive" || token == "is:归档" {
                isArchived = true
            } else if lowercased == "is:active" || lowercased == "is:inbox" || token == "is:记录" {
                isArchived = false
            } else if lowercased.hasPrefix("tag:") {
                let tag = String(token.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !tag.isEmpty {
                    tagFilters.append(tag)
                }
            } else if let filter = contentFilter(in: token, prefix: "has:") {
                requiredContentFilters.append(filter)
            } else if let filter = contentFilter(in: token, prefix: "-has:") {
                excludedContentFilters.append(filter)
            } else if let filter = contentFilter(in: token, prefix: "no:") {
                excludedContentFilters.append(filter)
            } else if let filter = contentFilter(in: token, prefix: "without:") {
                excludedContentFilters.append(filter)
            } else if let filter = dateFilter(in: token) {
                dateFilters.append(filter)
            } else {
                textTerms.append(token)
            }
        }

        return MemoSearchQuery(
            rawText: rawText,
            textTerms: textTerms,
            tagFilters: Array(Set(tagFilters)).sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            },
            requiredContentFilters: uniqueContentFilters(requiredContentFilters),
            excludedContentFilters: uniqueContentFilters(excludedContentFilters),
            dateFilters: uniqueDateFilters(dateFilters),
            isPinned: isPinned,
            isArchived: isArchived
        )
    }

    private static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var isInsideQuotes = false

        for character in text {
            if character == "\"" {
                isInsideQuotes.toggle()
                continue
            }

            if character.isWhitespace && !isInsideQuotes {
                appendToken(current, to: &tokens)
                current = ""
            } else {
                current.append(character)
            }
        }

        appendToken(current, to: &tokens)
        return tokens
    }

    private static func appendToken(_ token: String, to tokens: inout [String]) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            tokens.append(trimmed)
        }
    }

    private static func contentFilter(in token: String, prefix: String) -> MemoContentFilter? {
        let lowercased = token.lowercased()
        guard lowercased.hasPrefix(prefix) else {
            return nil
        }

        let value = String(token.dropFirst(prefix.count))
        return contentFilter(from: value)
    }

    private static func contentFilter(from value: String) -> MemoContentFilter? {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")

        switch normalized {
        case "link", "links", "url", "urls", "链接", "网址":
            return .link
        case "attachment", "attachments", "file", "files", "resource", "resources", "附件", "文件":
            return .attachment
        case "task", "tasks", "todo", "todos", "checkbox", "checkboxes", "任务", "待办":
            return .task
        case "open-task", "open-tasks", "unchecked", "incomplete-task", "incomplete-tasks", "未完成":
            return .openTask
        case "done-task", "done-tasks", "completed-task", "completed-tasks", "checked", "已完成":
            return .completedTask
        case "reference", "references", "ref", "refs", "引用":
            return .reference
        case "reference-note", "reference-notes", "ref-note", "ref-notes", "引用批注", "引用备注":
            return .referenceNote
        case "backlink", "backlinks", "incoming-reference", "incoming-references", "被引用", "反向引用":
            return .backlink
        case "web", "webclip", "web-clip", "article", "articles", "网页", "网页摘录":
            return .webClip
        case "clip", "clips", "clip-fragment", "clipfragment", "excerpt", "excerpts", "snippet", "snippets", "摘录", "摘录片段", "片段", "关键片段", "摘录卡片":
            return .clipFragment
        case "image-edit", "imageedit", "edited-image", "photo-edit", "photoedit", "image-work", "图片编辑", "照片编辑", "图片作品", "滤镜", "边框", "裁剪":
            return .imageEdit
        case "ocr", "image-text", "screenshot", "screenshots", "scan", "scan-text", "图片文字", "截图", "截图文字", "识别文字":
            return .screenshot
        case "ocr-review", "ocrreview", "ocr-low-confidence", "low-confidence-ocr", "needs-ocr-review", "review-ocr", "ocr-proofread", "ocr-proofreading", "proofread-ocr", "待校对", "ocr待校对", "识别待校对", "图片文字待校对", "低置信度", "低置信度ocr":
            return .ocrReview
        case "scrapbook", "journal", "journaling", "handbook", "layout", "layouts", "collage", "collages", "page", "pages", "手帐", "手帳", "电子手帐", "拼贴", "拼贴页", "页面", "排版":
            return .scrapbook
        case "audio", "audios", "voice", "voices", "recording", "recordings", "录音", "音频", "语音":
            return .audio
        case "video", "videos", "movie", "movies", "clip-video", "视频", "录像", "影片":
            return .video
        case "wardrobe", "closet", "clothing", "clothes", "衣橱", "衣柜", "衣物", "单品":
            return .wardrobe
        case "outfit", "outfits", "look", "looks", "穿搭", "搭配", "造型":
            return .outfit
        case "wear", "wears", "worn", "wear-log", "wearlog", "wear-record", "wearrecord", "穿着", "穿着记录", "穿搭记录", "穿着日历", "成本每次":
            return .wearLog
        case "laundry", "laundry-log", "laundrylog", "care", "care-log", "carelog", "wash", "washing", "洗护", "洗护记录", "护理", "护理记录", "清洗":
            return .laundryLog
        case "packing", "packing-list", "packinglist", "pack", "travel-pack", "travel-packing", "travel-list", "打包", "打包清单", "旅行打包", "旅行清单", "行李", "行李清单":
            return .packingList
        case "worklog", "work-log", "worklogs", "daily-report", "weekly-report", "project-report", "retro", "retrospective", "report", "reports", "log", "logs", "工作日志", "工作记录", "日报", "周报", "项目汇报", "项目日志", "复盘日志", "汇总":
            return .workLog
        default:
            return nil
        }
    }

    private static func uniqueContentFilters(_ filters: [MemoContentFilter]) -> [MemoContentFilter] {
        Array(Set(filters)).sorted { $0.rawValue < $1.rawValue }
    }

    private static func dateFilter(in token: String) -> MemoDateFilter? {
        let lowercased = token.lowercased()
        let field: MemoDateField
        let valueStartIndex: String.Index

        if lowercased.hasPrefix("created:") {
            field = .created
            valueStartIndex = token.index(token.startIndex, offsetBy: "created:".count)
        } else if lowercased.hasPrefix("date:") {
            field = .created
            valueStartIndex = token.index(token.startIndex, offsetBy: "date:".count)
        } else if lowercased.hasPrefix("updated:") {
            field = .updated
            valueStartIndex = token.index(token.startIndex, offsetBy: "updated:".count)
        } else {
            return nil
        }

        return dateFilter(field: field, rawValue: String(token[valueStartIndex...]))
    }

    private static func dateFilter(field: MemoDateField, rawValue: String) -> MemoDateFilter? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let operation: MemoDateOperator
        let dateText: String

        if trimmed.hasPrefix(">=") {
            operation = .onOrAfter
            dateText = String(trimmed.dropFirst(2))
        } else if trimmed.hasPrefix("<=") {
            operation = .onOrBefore
            dateText = String(trimmed.dropFirst(2))
        } else if trimmed.hasPrefix(">") {
            operation = .after
            dateText = String(trimmed.dropFirst())
        } else if trimmed.hasPrefix("<") {
            operation = .before
            dateText = String(trimmed.dropFirst())
        } else {
            operation = .on
            dateText = trimmed
        }

        guard let range = dateRange(from: dateText) else {
            return nil
        }

        return MemoDateFilter(
            field: field,
            operation: operation,
            start: range.start,
            end: range.end
        )
    }

    private static func dateRange(from rawText: String) -> (start: Date, end: Date)? {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count) else {
            return nil
        }

        guard let year = Int(parts[0]), (1...9999).contains(year) else {
            return nil
        }

        let calendar = localGregorianCalendar()
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = TimeZone.current
        components.year = year

        if parts.count >= 2 {
            guard let month = Int(parts[1]), (1...12).contains(month) else {
                return nil
            }
            components.month = month
        } else {
            components.month = 1
        }

        if parts.count == 3 {
            guard let day = Int(parts[2]), (1...31).contains(day) else {
                return nil
            }
            components.day = day
        } else {
            components.day = 1
        }

        guard let start = calendar.date(from: components) else {
            return nil
        }
        let resolved = calendar.dateComponents([.year, .month, .day], from: start)
        guard resolved.year == components.year,
              resolved.month == components.month,
              resolved.day == components.day else {
            return nil
        }

        let step: Calendar.Component = parts.count == 1 ? .year : parts.count == 2 ? .month : .day
        guard let end = calendar.date(byAdding: step, value: 1, to: start) else {
            return nil
        }

        return (start, end)
    }

    private static func localGregorianCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        return calendar
    }

    private static func uniqueDateFilters(_ filters: [MemoDateFilter]) -> [MemoDateFilter] {
        Array(Set(filters)).sorted {
            if $0.field != $1.field {
                return $0.field.rawValue < $1.field.rawValue
            }
            if $0.start != $1.start {
                return $0.start < $1.start
            }
            return $0.operation.rawValue < $1.operation.rawValue
        }
    }
}
