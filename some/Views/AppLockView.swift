import LocalAuthentication
import SwiftUI

@MainActor
final class AppLockManager: ObservableObject {
    static let shared = AppLockManager()

    @Published private(set) var isEnabled: Bool
    @Published private(set) var isLocked: Bool
    @Published private(set) var statusMessage: String?

    private static let isEnabledKey = "some.appLock.isEnabled"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let enabled = defaults.bool(forKey: Self.isEnabledKey)
        isEnabled = enabled
        isLocked = enabled
    }

    var authenticationName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)

        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return "设备密码"
        }
    }

    func lockIfNeeded() {
        guard isEnabled else { return }
        isLocked = true
    }

    func unlock() async {
        await authenticate(reason: "解锁 some，查看你的记录。") {
            isLocked = false
            statusMessage = nil
        }
    }

    func setEnabled(_ enabled: Bool) async {
        guard enabled != isEnabled else { return }

        if enabled {
            await authenticate(reason: "开启隐私锁，用于保护你的本地记录。") {
                defaults.set(true, forKey: Self.isEnabledKey)
                isEnabled = true
                isLocked = false
                statusMessage = "隐私锁已开启。"
            }
        } else {
            await authenticate(reason: "关闭隐私锁。") {
                defaults.set(false, forKey: Self.isEnabledKey)
                isEnabled = false
                isLocked = false
                statusMessage = "隐私锁已关闭。"
            }
        }
    }

    private func authenticate(reason: String, onSuccess: @escaping () -> Void) async {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            statusMessage = error?.localizedDescription ?? "这台设备没有可用的解锁方式。"
            return
        }

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            if success {
                onSuccess()
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

struct AppLockView: View {
    @EnvironmentObject private var appLock: AppLockManager
    @State private var isAuthenticating = false
    @State private var didAttemptAutomaticUnlock = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(Color.accentGreen)

                    VStack(spacing: 8) {
                        Text("已锁定")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.primaryText)

                        Text("用 \(appLock.authenticationName) 解锁后继续记录。")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.secondaryText)
                    }
                }

                Button {
                    Task { await unlock() }
                } label: {
                    HStack(spacing: 8) {
                        if isAuthenticating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "faceid")
                        }

                        Text("解锁")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white)
                .background(Color.accentGreen)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .disabled(isAuthenticating)

                if let statusMessage = appLock.statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.secondaryText)
                }

                Spacer()
                Spacer()
            }
            .padding(28)
            .frame(maxWidth: 480)
        }
        .task {
            guard !didAttemptAutomaticUnlock else { return }
            didAttemptAutomaticUnlock = true
            await unlock()
        }
    }

    private func unlock() async {
        isAuthenticating = true
        await appLock.unlock()
        isAuthenticating = false
    }
}
