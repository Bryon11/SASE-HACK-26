import Foundation
import SwiftData

/// One row per user. Updated by StreakEngine, never edited directly by views.
@Model
final class StreakRecord {
    @Attribute(.unique) var ownerID: String
    var currentStreak: Int
    var longestStreak: Int
    /// Start-of-day of the most recent day the goal was met.
    var lastCompletedDay: Date?
    /// Kept so today's credit can be undone if a log is deleted and today drops below goal.
    var previousCompletedDay: Date?
    var longestBeforeToday: Int

    init(ownerID: String) {
        self.ownerID = ownerID
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastCompletedDay = nil
        self.previousCompletedDay = nil
        self.longestBeforeToday = 0
    }
}

extension StreakRecord {
    var snapshot: StreakSnapshot {
        StreakSnapshot(
            current: currentStreak,
            longest: longestStreak,
            lastCompletedDay: lastCompletedDay,
            previousCompletedDay: previousCompletedDay,
            longestBeforeToday: longestBeforeToday
        )
    }

    func apply(_ s: StreakSnapshot) {
        currentStreak = s.current
        longestStreak = s.longest
        lastCompletedDay = s.lastCompletedDay
        previousCompletedDay = s.previousCompletedDay
        longestBeforeToday = s.longestBeforeToday
    }
}
