import Foundation

struct PlannedReminder: Equatable {
    let fireDate: Date
    let title: String
    let body: String
}

/// Decides WHEN reminders fire and WHAT they say. Pure logic — no notification APIs,
/// so it's easy to test.
///
/// Rules:
///  • Today's reminders state the exact amount left (they're rebuilt after every sip).
///  • Once today's goal is met, no more reminders today.
///  • A reminder is skipped if you drank within the last 20 minutes before it.
///  • Future days get a pace-based message, replaced with exact numbers once you open the app that day.
enum ReminderPlanner {
    /// iOS keeps at most 64 pending notifications per app.
    static let maxPending = 60
    static let maxTimesPerDay = 12
    /// 10 AM, 1 PM, 4 PM, 7 PM
    static let defaultTimes = [600, 780, 960, 1140]

    static func plan(
        reminderMinutes: [Int],
        goal: Double,
        todayTotal: Double,
        lastLogDate: Date?,
        now: Date = .now,
        daysAhead: Int = 7,
        quietPeriod: TimeInterval = 20 * 60,
        calendar: Calendar = .current
    ) -> [PlannedReminder] {
        let times = Array(Set(reminderMinutes)).filter { (0..<1440).contains($0) }.sorted()
        guard goal > 0, !times.isEmpty else { return [] }

        let today = calendar.startOfDay(for: now)
        var reminders: [PlannedReminder] = []

        for dayOffset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }

            for minutes in times {
                guard let fire = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day),
                      fire > now else { continue }

                let message: (title: String, body: String)
                if dayOffset == 0 {
                    if todayTotal >= goal { continue }
                    if let last = lastLogDate, fire.timeIntervalSince(last) < quietPeriod { continue }
                    message = todayMessage(todayTotal: todayTotal, goal: goal)
                } else {
                    message = futureMessage(at: fire, goal: goal, calendar: calendar)
                }

                reminders.append(PlannedReminder(fireDate: fire, title: message.title, body: message.body))
                if reminders.count >= maxPending { return reminders }
            }
        }
        return reminders
    }

    static func todayMessage(todayTotal: Double, goal: Double) -> (title: String, body: String) {
        let remaining = max(goal - todayTotal, 0)
        if remaining == 0 {
            return ("Goal reached 🎉", "You've hit your \(goal.ozText) goal. No more reminders today.")
        }
        if todayTotal == 0 {
            return ("Time for some water 💧", "You haven't logged any water yet. \(goal.ozText) to go today.")
        }
        let title = remaining <= goal * 0.25 ? "Almost there 💧" : "Time for some water 💧"
        return (title, "\(remaining.ozText) left to hit your \(goal.ozText) goal. You're at \(todayTotal.ozText) so far.")
    }

    private static func futureMessage(at date: Date, goal: Double, calendar: Calendar) -> (title: String, body: String) {
        let expected = HydrationGoalCalculator.expectedIntake(by: date, goal: goal, calendar: calendar).rounded()
        if expected < 4 {
            return ("Start with water 💧", "Kick off your day with a glass. Today's goal is \(goal.ozText).")
        }
        return ("Time for some water 💧",
                "Aim to be around \(expected.ozText) of your \(goal.ozText) goal by now. Open Hydrometer to see exactly what's left.")
    }
}
