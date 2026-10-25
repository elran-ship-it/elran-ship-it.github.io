import Foundation
import UserNotifications

/// Two kinds of local notifications:
///  1. A gentle repeating "nag" while you are still at home with pending items.
///  2. A burst of time-sensitive "you left without X" alarms after a geofence exit,
///     which keep firing until you confirm the items (or the burst runs out).
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let homeNagIdentifier = "home-nag"
    static let leaveAlarmPrefix = "leave-alarm-"
    static let alarmCategoryQuickConfirm = "LEAVE_ALARM_QUICK"
    static let alarmCategoryPhotoOnly = "LEAVE_ALARM_PHOTO"
    static let confirmAllAction = "CONFIRM_ALL"

    /// How many alarm notifications one exit schedules, and how far apart (seconds).
    static let alarmBurstCount = 20
    static let alarmBurstSpacing: TimeInterval = 45

    private let center = UNUserNotificationCenter.current()

    var onConfirmAll: (() -> Void)?
    var onOpenFromAlarm: (() -> Void)?

    func install() {
        center.delegate = self
        let confirmAll = UNNotificationAction(
            identifier: Self.confirmAllAction,
            title: "I have everything",
            options: [.authenticationRequired]
        )
        let quick = UNNotificationCategory(
            identifier: Self.alarmCategoryQuickConfirm,
            actions: [confirmAll],
            intentIdentifiers: [],
            options: []
        )
        let photoOnly = UNNotificationCategory(
            identifier: Self.alarmCategoryPhotoOnly,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([quick, photoOnly])
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - Home nag

    func scheduleHomeNag(titles: [String], everyMinutes minutes: Int) {
        clearHomeNag()
        guard !titles.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = "Don't forget"
        content.body = Self.summary(of: titles)
        content.sound = .default
        content.interruptionLevel = .active
        content.threadIdentifier = "home-nag"

        let interval = max(60, TimeInterval(minutes) * 60)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: true)
        let request = UNNotificationRequest(identifier: Self.homeNagIdentifier, content: content, trigger: trigger)
        center.add(request)
    }

    func clearHomeNag() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.homeNagIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.homeNagIdentifier])
    }

    // MARK: - Leave alarm

    func startLeaveAlarm(titles: [String], allowQuickConfirm: Bool, startingAfter initialDelay: TimeInterval = 1) {
        stopLeaveAlarm()
        guard !titles.isEmpty else { return }

        for index in 0..<Self.alarmBurstCount {
            let content = UNMutableNotificationContent()
            content.title = index == 0 ? "Wait! You're leaving without:" : "Still missing:"
            content.body = Self.summary(of: titles)
            content.sound = .defaultRingtone
            content.interruptionLevel = .timeSensitive
            content.categoryIdentifier = allowQuickConfirm ? Self.alarmCategoryQuickConfirm : Self.alarmCategoryPhotoOnly
            content.threadIdentifier = "leave-alarm"
            content.badge = NSNumber(value: titles.count)

            let delay = max(1, initialDelay + TimeInterval(index) * Self.alarmBurstSpacing)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let request = UNNotificationRequest(
                identifier: Self.leaveAlarmPrefix + String(index),
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    func stopLeaveAlarm() {
        let identifiers = (0..<Self.alarmBurstCount).map { Self.leaveAlarmPrefix + String($0) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        center.setBadgeCount(0)
    }

    // MARK: - Helpers

    private static func summary(of titles: [String]) -> String {
        if titles.count <= 3 {
            return titles.joined(separator: ", ")
        }
        let shown = titles.prefix(3).joined(separator: ", ")
        return "\(shown) and \(titles.count - 3) more"
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let isAlarm = response.notification.request.identifier.hasPrefix(Self.leaveAlarmPrefix)
        DispatchQueue.main.async { [weak self] in
            if response.actionIdentifier == Self.confirmAllAction {
                self?.onConfirmAll?()
            } else if isAlarm {
                self?.onOpenFromAlarm?()
            }
            completionHandler()
        }
    }
}
