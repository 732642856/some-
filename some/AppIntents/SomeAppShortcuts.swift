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
    }
}
#endif
