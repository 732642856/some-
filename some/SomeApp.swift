import SwiftUI

@main
struct SomeApp: App {
    @StateObject private var store = MemoStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onOpenURL { url in
                    store.addMemo(from: url)
                }
        }
    }
}
