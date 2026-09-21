import Foundation
import SwiftData

@Model
final class UserProfile {
    /// Stable, app-scoped identifier from Sign in with Apple (credential.user).
    @Attribute(.unique) var appleUserID: String
    var displayName: String
    var email: String?

    var weightLbs: Double
    var activityLevelRaw: String
    var climateRaw: String
    /// When set, overrides the calculated goal.
    var customGoalOz: Double?

    var hasCompletedOnboarding: Bool
    var createdAt: Date

    // Reminders. Default values let SwiftData migrate existing installs automatically.
    var remindersEnabled: Bool = false
    /// Minutes after midnight, e.g. 600 = 10:00 AM.
    var reminderMinutes: [Int] = []

    // Coins & shop. Defaults let SwiftData migrate existing installs automatically.
    var coins: Int = 0
    var ownedItemIDs: [String] = []
    var equippedCapID: String = "cap.stone"
    var equippedStrapID: String = "strap.red"
    var equippedBottleID: String = "bottle.clear"
    var savingForItemID: String = "cap.gold"
    /// Start of the last day coins were awarded — one reward per day.
    var lastRewardDay: Date? = nil

    // The physical bottle, simulated: capacity and what's left in it right now.
    var bottleCapacityOz: Double = 24
    var bottleRemainingOz: Double = 24

    // Enums are stored as raw strings: simplest, migration-friendly, predicate-safe.
    var activityLevel: ActivityLevel {
        get { ActivityLevel(rawValue: activityLevelRaw) ?? .moderate }
        set { activityLevelRaw = newValue.rawValue }
    }

    var climate: Climate {
        get { Climate(rawValue: climateRaw) ?? .temperate }
        set { climateRaw = newValue.rawValue }
    }

    var firstName: String? {
        displayName.split(separator: " ").first.map(String.init)
    }

    init(
        appleUserID: String,
        displayName: String = "",
        email: String? = nil,
        weightLbs: Double = 160,
        activityLevel: ActivityLevel = .moderate,
        climate: Climate = .temperate
    ) {
        self.appleUserID = appleUserID
        self.displayName = displayName
        self.email = email
        self.weightLbs = weightLbs
        self.activityLevelRaw = activityLevel.rawValue
        self.climateRaw = climate.rawValue
        self.customGoalOz = nil
        self.hasCompletedOnboarding = false
        self.createdAt = .now
    }
}

enum ActivityLevel: String, CaseIterable, Identifiable, Codable {
    case sedentary, light, moderate, intense
    var id: String { rawValue }

    var label: String {
        switch self {
        case .sedentary: "Mostly sitting"
        case .light: "Light activity"
        case .moderate: "Moderate exercise"
        case .intense: "Intense training"
        }
    }
}

enum Climate: String, CaseIterable, Identifiable, Codable {
    case temperate, warm, hot
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}
