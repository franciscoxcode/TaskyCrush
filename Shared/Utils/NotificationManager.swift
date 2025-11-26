import Foundation
import UserNotifications

@MainActor
final class NotificationManager: NSObject, @preconcurrency UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private override init() { super.init() }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    func scheduleReminders(for task: TaskItem) {
        guard task.hasReminders, !task.isDone else { return }
        let now = Date()
        for reminder in task.reminders {
            guard let fireDate = reminder.resolvedDate(for: task), fireDate > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Reminder"
            content.body = task.title
            content.sound = .default

            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: identifier(for: task.id, reminderId: reminder.id), content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }
    }

    func cancelReminders(for task: TaskItem) {
        let identifiers = task.reminders.map { identifier(for: task.id, reminderId: $0.id) }
        guard !identifiers.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func identifier(for taskId: UUID, reminderId: UUID) -> String {
        "\(taskId.uuidString)::\(reminderId.uuidString)"
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}
