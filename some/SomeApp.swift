import SwiftUI

@main
struct SomeApp: App {
    @StateObject private var store = MemoStore()
    @StateObject private var appLock = AppLockManager.shared
    @StateObject private var reminders = ReminderManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if CI_DISABLE_APP_INTENTS
        #else
        SomeAppShortcuts.updateAppShortcutParameters()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(store)
                    .environmentObject(appLock)
                    .environmentObject(reminders)

                if appLock.isLocked {
                    AppLockView()
                        .environmentObject(appLock)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: appLock.isLocked)
                .task {
                    await reminders.refreshAuthorizationStatus()
                }
                .onOpenURL { url in
                    store.addMemo(from: url)
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        store.reloadFromStorage()
                        Task { await reminders.refreshAuthorizationStatus() }
                    } else {
                        appLock.lockIfNeeded()
                    }
                }
        }
    }
}
