import Foundation
import UserNotifications

enum NotificationManager {
    static func requestPermission(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

    static func scheduleWeeklyAuditReminder(enabled: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weekly_audit"])

        guard enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Audit Hour"
        content.body = "Time to review your subscriptions. Open SubRadar to check for zombies and optimize spending."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.weekday = 1
        dateComponents.hour = 10
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly_audit", content: content, trigger: trigger)
        center.add(request)
    }

    static func scheduleInactivityReminder(for subscriptionName: String, id: String) {
        let center = UNUserNotificationCenter.current()
        let identifier = "inactivity_\(id)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Subscription Check"
        content.body = "You haven't used \(subscriptionName) in a while. Time to audit its value?"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 7 * 24 * 3600, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    static func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
