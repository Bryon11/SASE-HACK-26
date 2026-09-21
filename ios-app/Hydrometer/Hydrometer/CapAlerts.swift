import Foundation
import UserNotifications

/// Notifications about the cap itself: battery getting low, battery dead, or
/// the cap going quiet. Each alert fires once, and the battery alerts reset
/// after you charge it back up.
@MainActor
enum CapAlerts {
    /// The lowest battery level we've already warned about (100 = nothing yet).
    private static let batteryKey = "hydrometer.lastBatteryAlert"
    private static let quietKey = "hydrometer.lastQuietAlert"

    static func batteryChanged(to percent: Int) {
        let defaults = UserDefaults.standard
        let alreadyWarned = defaults.object(forKey: batteryKey) as? Int ?? 100

        // Charged back up — arm the warnings again.
        if percent >= 30 {
            if alreadyWarned < 100 { defaults.set(100, forKey: batteryKey) }
            return
        }

        if percent <= 0, alreadyWarned > 0 {
            defaults.set(0, forKey: batteryKey)
            send(id: "cap-battery-dead",
                 title: "Your cap is out of battery",
                 body: "Sips won't log until you charge it. Add water by hand in the meantime.")
        } else if percent <= 10, alreadyWarned > 10 {
            defaults.set(10, forKey: batteryKey)
            send(id: "cap-battery-10",
                 title: "Cap battery at \(percent)%",
                 body: "Charge your cap soon or it'll stop logging your sips.")
        } else if percent <= 20, alreadyWarned > 20 {
            defaults.set(20, forKey: batteryKey)
            send(id: "cap-battery-20",
                 title: "Cap battery at \(percent)%",
                 body: "Still counting, but your cap needs a charge in the next day or so.")
        }
    }

    /// Connected but silent for hours — the cap may be off, out of range, or broken.
    static func capWentQuiet(lastSeen: Date) {
        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: quietKey) as? Date,
           Date.now.timeIntervalSince(last) < 6 * 3600 { return } // at most one of these every 6 hours
        defaults.set(Date.now, forKey: quietKey)

        let time = lastSeen.formatted(date: .omitted, time: .shortened)
        send(id: "cap-quiet",
             title: "Haven't heard from your cap",
             body: "No sips since \(time). Check its battery, or log by hand for now.")
    }

    private static func send(id: String, title: String, body: String) {
        Task {
            let center = UNUserNotificationCenter.current()
            let status = await center.notificationSettings().authorizationStatus
            if status == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
            }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.threadIdentifier = "cap-health"

            // 1 second so it lands as a banner rather than being swallowed.
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }
}
