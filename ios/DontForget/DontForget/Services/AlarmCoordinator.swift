import AudioToolbox
import CoreLocation
import Foundation
import Observation
import SwiftData
import UIKit

/// Glue between the data store, the geofence and notifications.
///
/// - At home with pending items  → repeating gentle reminder.
/// - Leave home with pending items → alarm notifications + full-screen in-app alarm.
/// - Confirm every item (photo)   → everything goes quiet.
/// - Come back home               → recurring items reset, reminders resume.
@MainActor
@Observable
final class AlarmCoordinator {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    let location = LocationService()
    let notifications = NotificationService()
    let settings = AppSettings()

    var isAlarming = false
    private(set) var alarmStartedAt: Date?
    private var soundTimer: Timer?

    init(container: ModelContainer) {
        self.container = container
    }

    // MARK: - Lifecycle

    func start() {
        notifications.install()
        notifications.onConfirmAll = { [weak self] in
            self?.confirmAllPending(photo: nil)
        }
        notifications.onOpenFromAlarm = { [weak self] in
            guard let self else { return }
            if !self.pendingItems().isEmpty, self.location.isAtHome != true {
                self.isAlarming = true
                self.startInAppSoundIfForeground()
            }
        }
        location.onExitHome = { [weak self] in
            Task { @MainActor in self?.handleExitHome() }
        }
        location.onEnterHome = { [weak self] in
            Task { @MainActor in self?.handleEnterHome() }
        }
        applyHomeMonitoring()
    }

    /// Call when the app comes to the foreground.
    func appBecameActive() {
        location.refreshHomeState()
        refreshHomeNag()
        if isAlarming {
            startInAppSoundIfForeground()
        }
    }

    func appWentToBackground() {
        stopInAppSound()
    }

    func requestPermissionsIfNeeded() async {
        await notifications.requestAuthorization()
        if location.authorization == .notDetermined {
            location.requestWhenInUseAuthorization()
        }
    }

    // MARK: - Home

    func setHome(_ coordinate: CLLocationCoordinate2D) {
        settings.homeCoordinate = coordinate
        applyHomeMonitoring()
        location.requestAlwaysAuthorization()
    }

    func clearHome() {
        settings.homeCoordinate = nil
        location.stopMonitoringHome()
        notifications.clearHomeNag()
        stopAlarm()
    }

    func applyHomeMonitoring() {
        guard let home = settings.homeCoordinate else {
            location.stopMonitoringHome()
            return
        }
        location.monitorHome(center: home, radius: settings.homeRadius)
    }

    // MARK: - Queries

    func pendingItems() -> [ReminderItem] {
        let descriptor = FetchDescriptor<ReminderItem>(
            predicate: #Predicate { $0.isConfirmed == false && $0.isArchived == false },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Geofence events

    func handleExitHome() {
        let pending = pendingItems()
        guard settings.alarmEnabled, !pending.isEmpty else {
            notifications.clearHomeNag()
            return
        }
        isAlarming = true
        alarmStartedAt = .now
        notifications.clearHomeNag()
        notifications.startLeaveAlarm(
            titles: pending.map(\.displayTitle),
            allowQuickConfirm: settings.allowConfirmWithoutPhoto
        )
        startInAppSoundIfForeground()
    }

    func handleEnterHome() {
        stopAlarm()
        resetRecurringItems()
        refreshHomeNag()
    }

    // MARK: - Alarm control

    func stopAlarm() {
        isAlarming = false
        alarmStartedAt = nil
        notifications.stopLeaveAlarm()
        stopInAppSound()
    }

    /// Quiet for a few minutes, then the alarm notifications come back if items are still pending.
    func snooze(minutes: Int) {
        let pending = pendingItems()
        isAlarming = false
        stopInAppSound()
        notifications.startLeaveAlarm(
            titles: pending.map(\.displayTitle),
            allowQuickConfirm: settings.allowConfirmWithoutPhoto,
            startingAfter: TimeInterval(minutes) * 60
        )
    }

    /// Lets you feel what the alarm is like without leaving the house.
    func triggerTestAlarm() {
        let pending = pendingItems()
        let titles = pending.isEmpty ? ["Lunch box (test)"] : pending.map(\.displayTitle)
        isAlarming = true
        alarmStartedAt = .now
        notifications.startLeaveAlarm(titles: titles, allowQuickConfirm: settings.allowConfirmWithoutPhoto)
        startInAppSoundIfForeground()
    }

    // MARK: - Items

    func itemsChanged() {
        if pendingItems().isEmpty {
            stopAlarm()
        }
        refreshHomeNag()
    }

    func confirm(_ item: ReminderItem, photo: Data?) {
        item.isConfirmed = true
        item.confirmedAt = .now
        item.confirmationPhotoData = photo
        save()
        itemsChanged()
    }

    func confirmAllPending(photo: Data?) {
        for item in pendingItems() {
            item.isConfirmed = true
            item.confirmedAt = .now
            item.confirmationPhotoData = photo
        }
        save()
        itemsChanged()
    }

    func unconfirm(_ item: ReminderItem) {
        item.isConfirmed = false
        item.confirmedAt = nil
        item.confirmationPhotoData = nil
        save()
        itemsChanged()
    }

    func delete(_ item: ReminderItem) {
        context.delete(item)
        save()
        itemsChanged()
    }

    func archiveConfirmed() {
        let descriptor = FetchDescriptor<ReminderItem>(
            predicate: #Predicate { $0.isConfirmed == true && $0.isArchived == false && $0.isRecurring == false }
        )
        for item in (try? context.fetch(descriptor)) ?? [] {
            item.isArchived = true
        }
        save()
    }

    private func resetRecurringItems() {
        let descriptor = FetchDescriptor<ReminderItem>(
            predicate: #Predicate { $0.isRecurring == true && $0.isConfirmed == true && $0.isArchived == false }
        )
        for item in (try? context.fetch(descriptor)) ?? [] {
            item.isConfirmed = false
            item.confirmedAt = nil
            item.confirmationPhotoData = nil
        }
        save()
    }

    func refreshHomeNag() {
        let pending = pendingItems()
        if pending.isEmpty || location.isAtHome == false || settings.homeCoordinate == nil {
            notifications.clearHomeNag()
        } else {
            notifications.scheduleHomeNag(
                titles: pending.map(\.displayTitle),
                everyMinutes: settings.nagIntervalMinutes
            )
        }
    }

    private func save() {
        do {
            try context.save()
        } catch {
            assertionFailure("Save failed: \(error)")
        }
    }

    // MARK: - In-app alarm sound

    private func startInAppSoundIfForeground() {
        guard UIApplication.shared.applicationState == .active, soundTimer == nil else { return }
        playAlarmTone()
        soundTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.playAlarmTone() }
        }
    }

    private func stopInAppSound() {
        soundTimer?.invalidate()
        soundTimer = nil
    }

    private func playAlarmTone() {
        // 1304 is the system "alarm" tone; AlertSound also vibrates on iPhone.
        AudioServicesPlayAlertSound(1304)
    }
}
