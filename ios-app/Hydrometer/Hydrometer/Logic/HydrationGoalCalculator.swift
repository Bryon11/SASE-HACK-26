import Foundation

/// Pure functions — no state, trivially unit-testable.
/// Heuristic only (≈ half body weight in oz + adjustments). Not medical advice.
enum HydrationGoalCalculator {
    static let minimumOz: Double = 48
    static let maximumOz: Double = 160

    static func recommendedGoal(weightLbs: Double, activity: ActivityLevel, climate: Climate) -> Double {
        let base = weightLbs * 0.5
        let raw = base + activityBonus(activity) + climateBonus(climate)
        let clamped = min(max(raw, minimumOz), maximumOz)
        return (clamped / 4).rounded() * 4 // round to a friendly multiple of 4 oz
    }

    static func recommendedGoal(for profile: UserProfile) -> Double {
        recommendedGoal(weightLbs: profile.weightLbs, activity: profile.activityLevel, climate: profile.climate)
    }

    /// The goal actually in effect: custom override wins.
    static func dailyGoal(for profile: UserProfile) -> Double {
        profile.customGoalOz ?? recommendedGoal(for: profile)
    }

    /// How much the user "should" have had by `date`, spreading the goal evenly
    /// across waking hours. Powers the "on pace / behind pace" message.
    static func expectedIntake(
        by date: Date,
        goal: Double,
        wakeHour: Int = 8,
        sleepHour: Int = 22,
        calendar: Calendar = .current
    ) -> Double {
        let start = calendar.startOfDay(for: date)
        guard let wake = calendar.date(byAdding: .hour, value: wakeHour, to: start),
              let sleep = calendar.date(byAdding: .hour, value: sleepHour, to: start) else { return 0 }
        let fraction = date.timeIntervalSince(wake) / sleep.timeIntervalSince(wake)
        return goal * min(max(fraction, 0), 1)
    }

    private static func activityBonus(_ level: ActivityLevel) -> Double {
        switch level {
        case .sedentary: 0
        case .light: 8
        case .moderate: 16
        case .intense: 32
        }
    }

    private static func climateBonus(_ climate: Climate) -> Double {
        switch climate {
        case .temperate: 0
        case .warm: 8
        case .hot: 16
        }
    }
}
