import Foundation
import UserNotifications

/// Thin wrapper around UNUserNotificationCenter. All decisions live in ReminderPlanner.
enum ReminderScheduler {
    private static let idPrefix = "hydration-reminder-"
    private static var allIDs: [String] { (0..<64).map { "\(idPrefix)\($0)" } }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    static func clearAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: allIDs)
    }

    /// Replaces every pending hydration reminder with the given plan.
    static func apply(_ plan: [PlannedReminder]) async {
        clearAll()
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current

        for (index, reminder) in plan.prefix(64).enumerated() {
            if Task.isCancelled { return } // a newer plan is on its way
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            content.threadIdentifier = "hydration"

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: "\(idPrefix)\(index)", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    /// Fires once, 5 seconds from now. Great for demos.
    static func sendTest(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "hydration-test", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }
}

/// Lets reminders appear as banners even while Hydrometer is open on screen.
@MainActor
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
