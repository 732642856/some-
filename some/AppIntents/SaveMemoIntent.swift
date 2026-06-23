#if CI_DISABLE_APP_INTENTS
#else
import AppIntents
import Foundation

struct SaveMemoIntent: AppIntent {
    static var title: LocalizedStringResource = "存到 some"
    static var description = IntentDescription("保存一条新的随记。")
    static var openAppWhenRun = false

    @Parameter(
        title: "内容",
        inputOptions: String.IntentInputOptions(multiline: true),
        requestValueDialog: IntentDialog("想记录什么？")
    )
    var content: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = MemoStore()
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .result(dialog: IntentDialog("没有保存空内容。"))
        }

        guard store.addMemo(text: content) != nil else {
            return .result(dialog: IntentDialog("保存失败，请稍后再试。"))
        }

        return .result(dialog: IntentDialog("已保存到 some。"))
    }
}

protocol OpenSomeDestinationIntent: AppIntent {
    static var destination: MemoHomeMode { get }
    static var openedDialog: IntentDialog { get }
}

extension OpenSomeDestinationIntent {
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppShortcutRouteStore.request(Self.destination)
        return .result(dialog: Self.openedDialog)
    }
}

struct OpenZenIntent: OpenSomeDestinationIntent {
    static var title: LocalizedStringResource = "打开专注"
    static var description = IntentDescription("打开 some 的专注记录页。")
    static let destination: MemoHomeMode = .zen
    static let openedDialog = IntentDialog("已打开专注记录。")
}

struct OpenWorkLogIntent: OpenSomeDestinationIntent {
    static var title: LocalizedStringResource = "打开工作日志"
    static var description = IntentDescription("打开 some 的工作日志页。")
    static let destination: MemoHomeMode = .workLog
    static let openedDialog = IntentDialog("已打开工作日志。")
}

struct OpenWardrobeIntent: OpenSomeDestinationIntent {
    static var title: LocalizedStringResource = "打开衣橱"
    static var description = IntentDescription("打开 some 的衣橱和穿搭页。")
    static let destination: MemoHomeMode = .wardrobe
    static let openedDialog = IntentDialog("已打开衣橱。")
}

struct OpenAIWorkspaceIntent: OpenSomeDestinationIntent {
    static var title: LocalizedStringResource = "打开 AI 整理"
    static var description = IntentDescription("打开 some 的 AI 整理页。")
    static let destination: MemoHomeMode = .ai
    static let openedDialog = IntentDialog("已打开 AI 整理。")
}
#endif
