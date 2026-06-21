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
