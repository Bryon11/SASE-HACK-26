import Foundation

/// Coins for hitting your goal: 5 base + 1 per streak day (max +5).
/// Day 1 = 6, day 2 = 7, day 3 = 8 → a 20-coin gold cap on day 3.
enum CoinRewardCalculator {
    static let baseCoins = 5
    static let maxStreakBonus = 5

    static func bonusCoins(streak: Int) -> Int {
        min(max(streak, 0), maxStreakBonus)
    }
}

enum ShopLogic {
    static func isOwned(_ item: CosmeticItem, ownedIDs: [String], longestStreak: Int) -> Bool {
        if item.isStarter { return true }
        if let required = item.streakRequirement { return longestStreak >= required }
        return ownedIDs.contains(item.id)
    }

    /// What the progress bar tracks: the item you picked, or else the cheapest thing you don't own.
    static func savingTarget(preferredID: String, ownedIDs: [String], longestStreak: Int) -> CosmeticItem? {
        let buyable = CosmeticCatalog.all.filter {
            $0.streakRequirement == nil && !isOwned($0, ownedIDs: ownedIDs, longestStreak: longestStreak)
        }
        if let preferred = buyable.first(where: { $0.id == preferredID }) { return preferred }
        return buyable.min { $0.price < $1.price }
    }

    /// Streak items that unlocked because the longest streak just grew.
    static func newlyUnlocked(longestBefore: Int, longestAfter: Int) -> [CosmeticItem] {
        CosmeticCatalog.all.filter { item in
            guard let required = item.streakRequirement else { return false }
            return longestBefore < required && longestAfter >= required
        }
    }
}

/// Everything the coin animation needs to play one reward.
struct CoinReward: Identifiable, Equatable {
    let id = UUID()
    let baseCoins: Int
    let bonusCoins: Int
    let startingBalance: Int
    let newUnlocks: [CosmeticItem]
    let savingFor: CosmeticItem?

    var totalCoins: Int { baseCoins + bonusCoins }
    var endingBalance: Int { startingBalance + totalCoins }
}
