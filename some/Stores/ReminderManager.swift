import Foundation
import UserNotifications

@MainActor
final class ReminderManager: ObservableObject {
    static let shared = ReminderManager()

    @Published private(set) var isEnabled: Bool
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var reminderDate: Date
    @Published private(set) var statusMessage: String?

    private static let isEnabledKey = "some.dailyReviewReminder.isEnabled"
    private static let hourKey = "some.dailyReviewReminder.hour"
    private static let minuteKey = "some.dailyReviewReminder.minute"
    private static let notificationIdentifier = "some.dailyReviewReminder"

    private let defaults: UserDefaults
    private let notificationCenter: UNUserNotificationCenter

    init(
        defaults: UserDefaults = .standard,
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.defaults = defaults
        self.notificationCenter = notificationCenter

        isEnabled = defaults.bool(forKey: Self.isEnabledKey)
        let hour = defaults.object(forKey: Self.hourKey) as? Int ?? 21
        let minute = defaults.object(forKey: Self.minuteKey) as? Int ?? 30
        reminderDate = Self.makeDate(hour: hour, minute: minute)
    }

    var timeText: String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderDate)
        return String(format: "%02d:%02d", components.hour ?? 21, components.minute ?? 30)
    }

    var authorizationText: String {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "通知权限已允许。"
        case .denied:
            return "通知权限已关闭，请在系统设置里允许通知。"
        case .notDetermined:
            return "开启时会请求通知权限。"
        @unknown default:
            return "通知权限状态未知。"
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await currentNotificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func setEnabled(_ enabled: Bool) async {
        guard enabled != isEnabled else { return }

        if enabled {
            let isAuthorized = await requestAuthorizationIfNeeded()
            guard isAuthorized else { return }

            isEnabled = true
            defaults.set(true, forKey: Self.isEnabledKey)
            await scheduleDailyReminder()
        } else {
            isEnabled = false
            defaults.set(false, forKey: Self.isEnabledKey)
            notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
            statusMessage = "每日回顾提醒已关闭。"
        }
    }

    func setReminderDate(_ date: Date) {
        reminderDate = date

        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        defaults.set(components.hour ?? 21, forKey: Self.hourKey)
        defaults.set(components.minute ?? 30, forKey: Self.minuteKey)

        guard isEnabled else {
            statusMessage = "提醒时间已设为 \(timeText)。"
            return
        }

        Task {
            await scheduleDailyReminder()
        }
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await currentNotificationSettings()
        authorizationStatus = settings.authorizationStatus

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            statusMessage = "通知权限已关闭，请在系统设置里允许通知。"
            return false
        case .notDetermined:
            do {
                let granted = try await requestNotificationAuthorization()
                await refreshAuthorizationStatus()
                statusMessage = granted ? nil : "没有通知权限，无法开启提醒。"
                return granted
            } catch {
                statusMessage = error.localizedDescription
                return false
            }
        @unknown default:
            statusMessage = "通知权限状态未知，无法开启提醒。"
            return false
        }
    }

    private func scheduleDailyReminder() async {
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderDate)

        var triggerComponents = DateComponents()
        triggerComponents.hour = components.hour
        triggerComponents.minute = components.minute

        let content = UNMutableNotificationContent()
        content.title = "回看一下今天"
        content.body = "打开 some，补一条闪念，或随机翻一条旧记录。"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier,
            content: content,
            trigger: trigger
        )

        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])

        do {
            try await addNotificationRequest(request)
            statusMessage = "每天 \(timeText) 提醒你回顾。"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func currentNotificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { (continuation: CheckedContinuation<UNNotificationSettings, Never>) in
            notificationCenter.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func requestNotificationAuthorization() async throws -> Bool {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func addNotificationRequest(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            notificationCenter.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func makeDate(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
    }
}
