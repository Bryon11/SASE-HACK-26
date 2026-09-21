import Foundation

/// Value-type mirror of StreakRecord so the rules can be tested without SwiftData.
struct StreakSnapshot: Equatable {
    var current: Int
    var longest: Int
    var lastCompletedDay: Date?
    var previousCompletedDay: Date?
    var longestBeforeToday: Int

    static let empty = StreakSnapshot(
        current: 0, longest: 0, lastCompletedDay: nil, previousCompletedDay: nil, longestBeforeToday: 0
    )
}

/// Streak rules:
///  1. Meeting the goal today credits today once (+1 if yesterday was credited, else restart at 1).
///  2. A streak stays alive through today even if today isn't done yet.
///  3. If the last credited day is older than yesterday, the streak resets to 0.
///  4. If a deleted log drops today back below goal, today's credit is undone.
/// Safe to call as often as you like — evaluation is idempotent.
enum StreakEngine {
    static func evaluate(
        _ snapshot: StreakSnapshot,
        todayTotal: Double,
        goal: Double,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> StreakSnapshot {
        var s = snapshot
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return s }

        // Rule 3: a full day was missed.
        if let last = s.lastCompletedDay, last < yesterday {
            s.current = 0
        }

        let metToday = goal > 0 && todayTotal >= goal
        let creditedToday = s.lastCompletedDay.map { calendar.isDate($0, inSameDayAs: today) } ?? false

        if metToday && !creditedToday {
            // Rule 1
            let continuesStreak = s.lastCompletedDay.map { calendar.isDate($0, inSameDayAs: yesterday) } ?? false
            s.current = continuesStreak ? s.current + 1 : 1
            s.previousCompletedDay = s.lastCompletedDay
            s.lastCompletedDay = today
            s.longestBeforeToday = s.longest
            s.longest = max(s.longest, s.current)
        } else if !metToday && creditedToday {
            // Rule 4
            s.current = max(0, s.current - 1)
            s.lastCompletedDay = s.previousCompletedDay
            s.previousCompletedDay = nil
            s.longest = s.longestBeforeToday
        }
        return s
    }
}
