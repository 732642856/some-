#if CI_DISABLE_APP_INTENTS
#else
import AppIntents

struct SomeAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveMemoIntent(),
            phrases: [
                "存到 \(.applicationName)",
                "用 \(.applicationName) 记一条",
                "在 \(.applicationName) 里记录",
                "Save a memo in \(.applicationName)"
            ],
            shortTitle: "新建随记",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: OpenZenIntent(),
            phrases: [
                "打开 \(.applicationName) 专注",
                "在 \(.applicationName) 专注记录"
            ],
            shortTitle: "打开专注",
            systemImageName: "moon.stars"
        )
        AppShortcut(
            intent: OpenWorkLogIntent(),
            phrases: [
                "打开 \(.applicationName) 工作日志",
                "在 \(.applicationName) 写工作日志"
            ],
            shortTitle: "打开日志",
            systemImageName: "doc.text"
        )
        AppShortcut(
            intent: OpenWardrobeIntent(),
            phrases: [
                "打开 \(.applicationName) 衣橱",
                "在 \(.applicationName) 看穿搭"
            ],
            shortTitle: "打开衣橱",
            systemImageName: "tshirt"
        )
        AppShortcut(
            intent: OpenAIWorkspaceIntent(),
            phrases: [
                "打开 \(.applicationName) AI",
                "在 \(.applicationName) 做 AI 整理"
            ],
            shortTitle: "打开 AI",
            systemImageName: "sparkles.rectangle.stack"
        )
    }
}
#endif
