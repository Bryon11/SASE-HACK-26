import Foundation
import SwiftData

/// A friend in your hydration group. For the hackathon these live on this device
/// and are simulated; swapping in a real backend later only changes where they load from.
@Model
final class Friend {
    var id: UUID
    var ownerID: String
    var name: String
    var emoji: String
    var goalOz: Double
    var todayOz: Double
    var streak: Int
    var lastUpdated: Date
    var joinedAt: Date

    init(ownerID: String, name: String, emoji: String, goalOz: Double,
         todayOz: Double = 0, streak: Int = 0) {
        self.id = UUID()
        self.ownerID = ownerID
        self.name = name
        self.emoji = emoji
        self.goalOz = goalOz
        self.todayOz = todayOz
        self.streak = streak
        self.lastUpdated = .now
        self.joinedAt = .now
    }

    var progress: Double { goalOz > 0 ? todayOz / goalOz : 0 }
    var metGoal: Bool { goalOz > 0 && todayOz >= goalOz }
}

/// One row of the standings — you or a friend.
struct LeaderboardEntry: Identifiable, Equatable {
    let id: String
    let name: String
    let emoji: String
    let ounces: Double
    let goal: Double
    let streak: Int
    let isMe: Bool

    var progress: Double { goal > 0 ? ounces / goal : 0 }
    var metGoal: Bool { goal > 0 && ounces >= goal }
}

/// The group streak: days where every single person hit their goal.
/// Kept in UserDefaults so adding friends never forces a database migration.
struct GroupStreakStore {
    private let streakKey: String
    private let dayKey: String

    init(ownerID: String) {
        streakKey = "hydrometer.group.streak.\(ownerID)"
        dayKey = "hydrometer.group.day.\(ownerID)"
    }

    var current: Int { UserDefaults.standard.integer(forKey: streakKey) }
    var lastCompletedDay: Date? { UserDefaults.standard.object(forKey: dayKey) as? Date }

    /// Same rules as your personal streak: credit today once, reset after a missed day,
    /// and take the credit back if someone's total drops below their goal again.
    func update(everyoneMet: Bool, now: Date = .now, calendar: Calendar = .current) {
        let defaults = UserDefaults.standard
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return }

        var streak = current
        let last = lastCompletedDay
        if let last, last < yesterday { streak = 0 }
        let countedToday = last.map { calendar.isDate($0, inSameDayAs: today) } ?? false

        if everyoneMet && !countedToday {
            let continues = last.map { calendar.isDate($0, inSameDayAs: yesterday) } ?? false
            streak = continues ? streak + 1 : 1
            defaults.set(today, forKey: dayKey)
        } else if !everyoneMet && countedToday {
            streak = max(streak - 1, 0)
            defaults.removeObject(forKey: dayKey)
        }
        defaults.set(streak, forKey: streakKey)
    }
}
