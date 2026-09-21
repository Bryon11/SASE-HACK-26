import Foundation
import SwiftData
import Observation

/// Business logic for the dashboard: logging, today's totals, goal, streak,
/// the week strip, reminders, coins and the shop. Views stay dumb.
@MainActor
@Observable
final class DashboardViewModel {
    let profile: UserProfile
    let cap: SmartCapManager

    private(set) var todayLogs: [WaterLog] = []
    private(set) var weekDays: [WeekDayStatus] = []
    private(set) var insights = HydrationInsights()
    /// Every ounce ever logged — this is what grows the tree.
    private(set) var lifetimeOunces: Double = 0
    private(set) var friends: [Friend] = []
    private(set) var groupStreak = 0
    /// Increments each time the goal is crossed.
    private(set) var goalReachedTrigger = 0
    /// Set when coins are earned; the dashboard plays the coin animation, then clears it.
    private(set) var pendingReward: CoinReward?

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private var reminderTask: Task<Void, Never>?
    private let streakRecord: StreakRecord

    init(context: ModelContext, profile: UserProfile, cap: SmartCapManager) {
        self.context = context
        self.profile = profile
        self.cap = cap
        self.streakRecord = Self.fetchOrCreateStreak(ownerID: profile.appleUserID, in: context)

        cap.onSip = { [weak self] ounces, source in
            self?.logWater(ounces, source: source)
        }
        cap.onBottleLevel = { [weak self] ounces in
            self?.applyCapBottleLevel(ounces)
        }
        cap.setSimulatedCapacity(profile.bottleCapacityOz)
        refresh()
    }

    // MARK: Derived state

    var dailyGoal: Double { HydrationGoalCalculator.dailyGoal(for: profile) }
    var todayTotal: Double { todayLogs.reduce(0) { $0 + $1.amountOz } }
    /// Can exceed 1.0 — extra ounces become bonus mini bottles.
    var progress: Double { dailyGoal > 0 ? todayTotal / dailyGoal : 0 }
    var remaining: Double { max(dailyGoal - todayTotal, 0) }
    var goalMet: Bool { todayTotal >= dailyGoal }
    var currentStreak: Int { streakRecord.currentStreak }
    var longestStreak: Int { streakRecord.longestStreak }
    var coins: Int { profile.coins }

    var paceMessage: String {
        if goalMet { return "Every extra 8 oz fills a bonus bottle." }
        let expected = HydrationGoalCalculator.expectedIntake(by: .now, goal: dailyGoal)
        let behind = expected - todayTotal
        return behind <= 2 ? "You're on pace" : "\(behind.rounded().ozText) behind pace"
    }

    // MARK: Bottle level (simulated)

    var bottleCapacity: Double { max(profile.bottleCapacityOz, 1) }
    var bottleRemaining: Double { min(max(profile.bottleRemainingOz, 0), bottleCapacity) }
    var bottleLevel: Double { bottleRemaining / bottleCapacity }

    func refillBottle() {
        profile.bottleRemainingOz = profile.bottleCapacityOz
        save()
    }

    func setBottleCapacity(_ ounces: Double) {
        profile.bottleCapacityOz = ounces
        profile.bottleRemainingOz = min(profile.bottleRemainingOz, ounces)
        cap.setSimulatedCapacity(ounces)
        save()
    }

    /// True when the cap has sent a real reading recently.
    var bottleLevelIsLive: Bool {
        guard let last = cap.lastVolumeDate else { return false }
        return Date.now.timeIntervalSince(last) < 15 * 60
    }

    /// The float sensor's reading wins over our estimate.
    private func applyCapBottleLevel(_ ounces: Double) {
        let level = max(ounces, 0)
        if level > profile.bottleCapacityOz {
            // Bigger bottle than we thought — round up to the next 4 oz.
            profile.bottleCapacityOz = (level / 4).rounded(.up) * 4
        }
        profile.bottleRemainingOz = level
        save()
    }

    /// Takes a sip out of the bottle. Drinking more than is left means you
    /// refilled at some point, so the bottle starts over minus the overflow.
    private func drawFromBottle(_ ounces: Double) {
        let left = profile.bottleRemainingOz
        if ounces <= left {
            profile.bottleRemainingOz = left - ounces
        } else {
            let overflow = ounces - left
            profile.bottleRemainingOz = max(profile.bottleCapacityOz - overflow, 0)
        }
    }

    /// When you crossed the goal today, if you did.
    var todayGoalCrossingTime: Date? {
        var running = 0.0
        for log in todayLogs.sorted(by: { $0.timestamp < $1.timestamp }) {
            running += log.amountOz
            if running >= dailyGoal { return log.timestamp }
        }
        return nil
    }

    /// One line under the pace message comparing today with your usual day.
    var finishLineMessage: String? {
        let calendar = Calendar.current
        if goalMet {
            guard let crossed = todayGoalCrossingTime else { return nil }
            let time = crossed.formatted(date: .omitted, time: .shortened)
            guard let usual = insights.averageFinish else { return "finished at \(time)" }
            let minutes = calendar.component(.hour, from: crossed) * 60
                + calendar.component(.minute, from: crossed) - usual
            guard abs(minutes) >= 30 else { return "finished at \(time), about your usual time" }
            return "finished at \(time), \(durationText(abs(minutes))) \(minutes < 0 ? "faster" : "later") than usual"
        }
        if let projected = insights.projectedFinish {
            return "on pace to finish around \(projected.formatted(date: .omitted, time: .shortened))"
        }
        return nil
    }

    private func durationText(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let hours = Double(minutes) / 60
        return "\(hours.formatted(.number.precision(.fractionLength(0...1)))) hr"
    }

    var bottleStyle: BottleStyle {
        BottleStyle(
            cap: CosmeticCatalog.item(id: profile.equippedCapID),
            bottle: CosmeticCatalog.item(id: profile.equippedBottleID)
        )
    }

    var savingTarget: CosmeticItem? {
        ShopLogic.savingTarget(preferredID: profile.savingForItemID,
                               ownedIDs: profile.ownedItemIDs,
                               longestStreak: longestStreak)
    }

    // MARK: Logging

    func logWater(_ ounces: Double, source: LogSource = .manual) {
        guard ounces > 0 else { return }
        let wasBelowGoal = !goalMet
        let longestBefore = longestStreak
        context.insert(WaterLog(ownerID: profile.appleUserID, amountOz: ounces, source: source))
        // The cap reports the real level with every message, so only estimate
        // for sips typed in by hand.
        if source == .manual { drawFromBottle(ounces) }
        save()
        refresh()
        if wasBelowGoal && goalMet {
            goalReachedTrigger += 1
            awardCoinsIfNeeded(longestBefore: longestBefore)
        }
    }

    func delete(_ log: WaterLog) {
        // Put it back in the bottle too, so the level stays believable.
        profile.bottleRemainingOz = min(bottleCapacity, profile.bottleRemainingOz + log.amountOz)
        context.delete(log)
        save()
        refresh()
    }

    /// Call on appear, foreground, day change, and after settings edits.
    func refresh(now: Date = .now) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }
        let owner = profile.appleUserID

        let descriptor = FetchDescriptor<WaterLog>(
            predicate: #Predicate { $0.ownerID == owner && $0.timestamp >= start && $0.timestamp < end },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        todayLogs = (try? context.fetch(descriptor)) ?? []

        let updated = StreakEngine.evaluate(streakRecord.snapshot, todayTotal: todayTotal, goal: dailyGoal, now: now)
        if updated != streakRecord.snapshot {
            streakRecord.apply(updated)
            save()
        }

        cap.setSimulatedCapacity(profile.bottleCapacityOz)
        weekDays = computeWeek(now: now)
        insights = computeInsights(now: now)
        lifetimeOunces = computeLifetimeOunces()
        refreshFriends(now: now)
        rescheduleReminders(now: now)
    }

    // MARK: Coins

    /// One reward per day, the first time the goal is crossed.
    private func awardCoinsIfNeeded(longestBefore: Int, now: Date = .now) {
        let calendar = Calendar.current
        if let last = profile.lastRewardDay, calendar.isDate(last, inSameDayAs: now) { return }
        grantReward(longestBefore: longestBefore)
        profile.lastRewardDay = calendar.startOfDay(for: now)
        save()
    }

    private func grantReward(longestBefore: Int) {
        let base = CoinRewardCalculator.baseCoins
        let bonus = CoinRewardCalculator.bonusCoins(streak: currentStreak)
        let startingBalance = profile.coins
        profile.coins = startingBalance + base + bonus
        pendingReward = CoinReward(
            baseCoins: base,
            bonusCoins: bonus,
            startingBalance: startingBalance,
            newUnlocks: ShopLogic.newlyUnlocked(longestBefore: longestBefore, longestAfter: longestStreak),
            savingFor: savingTarget
        )
    }

    func dismissReward() {
        pendingReward = nil
    }

    // Demo helpers for the presentation drawer.
    func replayRewardForDemo() {
        grantReward(longestBefore: longestStreak)
        save()
    }

    /// Test control: log water by hand without the cap.
    func addTestWater(_ ounces: Double) {
        logWater(ounces, source: .manual)
    }

    /// Test control: pour straight into the tree. Dated well in the past so it
    /// grows the tree without touching today's total, streak or insights.
    func addTreeWaterForDemo(_ ounces: Double) {
        let calendar = Calendar.current
        guard let past = calendar.date(byAdding: .day, value: -60, to: .now) else { return }
        context.insert(WaterLog(ownerID: profile.appleUserID, amountOz: ounces,
                                timestamp: past, source: .manual))
        save()
        refresh()
    }

    func addDemoCoins(_ amount: Int) {
        profile.coins += amount
        save()
    }

    // MARK: Shop

    func isOwned(_ item: CosmeticItem) -> Bool {
        ShopLogic.isOwned(item, ownedIDs: profile.ownedItemIDs, longestStreak: longestStreak)
    }

    func isEquipped(_ item: CosmeticItem) -> Bool {
        switch item.slot {
        case .cap: profile.equippedCapID == item.id
        case .bottle: profile.equippedBottleID == item.id
        }
    }

    @discardableResult
    func purchase(_ item: CosmeticItem) -> Bool {
        guard !isOwned(item), item.streakRequirement == nil, profile.coins >= item.price else { return false }
        profile.coins -= item.price
        profile.ownedItemIDs.append(item.id)
        equip(item)
        return true
    }

    func equip(_ item: CosmeticItem) {
        guard isOwned(item) else { return }
        switch item.slot {
        case .cap: profile.equippedCapID = item.id
        case .bottle: profile.equippedBottleID = item.id
        }
        save()
    }

    func setSavingTarget(_ item: CosmeticItem) {
        guard item.streakRequirement == nil, !isOwned(item) else { return }
        profile.savingForItemID = item.id
        save()
    }

    // MARK: Week strip

    private func computeWeek(now: Date) -> [WeekDayStatus] {
        let calendar = Calendar.current
        var iso = Calendar(identifier: .iso8601) // weeks start on Monday
        iso.timeZone = calendar.timeZone
        guard let weekStart = iso.dateInterval(of: .weekOfYear, for: now)?.start,
              let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return [] }

        let owner = profile.appleUserID
        let descriptor = FetchDescriptor<WaterLog>(
            predicate: #Predicate { $0.ownerID == owner && $0.timestamp >= weekStart && $0.timestamp < weekEnd }
        )
        let logs = (try? context.fetch(descriptor)) ?? []
        var totals: [Date: Double] = [:]
        for log in logs {
            totals[calendar.startOfDay(for: log.timestamp), default: 0] += log.amountOz
        }

        let today = calendar.startOfDay(for: now)
        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        let goal = dailyGoal
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let dayStart = calendar.startOfDay(for: day)
            return WeekDayStatus(
                id: dayStart,
                letter: letters[offset],
                met: goal > 0 && (totals[dayStart] ?? 0) >= goal,
                isToday: dayStart == today,
                isFuture: dayStart > today
            )
        }
    }

    /// Total of every log this user has, used by the tree.
    private func computeLifetimeOunces() -> Double {
        let owner = profile.appleUserID
        let descriptor = FetchDescriptor<WaterLog>(predicate: #Predicate { $0.ownerID == owner })
        let logs = (try? context.fetch(descriptor)) ?? []
        return logs.reduce(0) { $0 + $1.amountOz }
    }

    // MARK: Friends & the group streak

    private var groupStore: GroupStreakStore { GroupStreakStore(ownerID: profile.appleUserID) }

    /// You plus your friends, best percentage first.
    var leaderboard: [LeaderboardEntry] {
        var entries = friends.map {
            LeaderboardEntry(id: $0.id.uuidString, name: $0.name, emoji: $0.emoji,
                             ounces: $0.todayOz, goal: $0.goalOz, streak: $0.streak, isMe: false)
        }
        entries.append(LeaderboardEntry(id: "me", name: profile.firstName ?? "You", emoji: "💧",
                                        ounces: todayTotal, goal: dailyGoal, streak: currentStreak, isMe: true))
        return entries.sorted {
            $0.progress == $1.progress ? $0.ounces > $1.ounces : $0.progress > $1.progress
        }
    }

    var groupSize: Int { leaderboard.count }
    var groupDoneToday: Int { leaderboard.filter(\.metGoal).count }
    var groupProgressToday: Double { groupSize > 0 ? Double(groupDoneToday) / Double(groupSize) : 0 }
    var myRank: Int { (leaderboard.firstIndex { $0.isMe } ?? 0) + 1 }

    var inviteCode: String {
        let key = "hydrometer.inviteCode.\(profile.appleUserID)"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let code = "HYDRO-" + String((0..<4).compactMap { _ in letters.randomElement() })
        UserDefaults.standard.set(code, forKey: key)
        return code
    }

    var inviteMessage: String {
        "Join my hydration group on Hydrometer — we keep a group streak going and it only counts when everyone hits their goal. My code: \(inviteCode)"
    }

    private static let demoFriends: [(name: String, emoji: String)] = [
        ("Maya", "🦊"), ("Roshaan", "🐧"), ("Dev", "🐙"),
        ("Sam", "🐝"), ("Priya", "🐢"), ("Leo", "🦁")
    ]

    func addDemoFriend() {
        let taken = Set(friends.map(\.name))
        guard let pick = Self.demoFriends.first(where: { !taken.contains($0.name) }) else { return }
        let goal = ((dailyGoal * Double.random(in: 0.85...1.15)) / 4).rounded() * 4
        let friend = Friend(ownerID: profile.appleUserID,
                            name: pick.name,
                            emoji: pick.emoji,
                            goalOz: goal,
                            todayOz: (goal * Double.random(in: 0.2...0.9) / 2).rounded() * 2,
                            streak: Int.random(in: 0...6))
        context.insert(friend)
        save()
        refreshFriends(now: .now)
    }

    func removeFriend(_ friend: Friend) {
        context.delete(friend)
        save()
        refreshFriends(now: .now)
    }

    /// Demo: a random friend who isn't finished takes a drink.
    func simulateFriendSip() {
        let thirsty = friends.filter { $0.todayOz < $0.goalOz }
        guard let friend = thirsty.randomElement() else { return }
        friend.todayOz += [4.0, 6, 8, 10].randomElement() ?? 8
        friend.lastUpdated = .now
        save()
        refreshFriends(now: .now)
    }

    private func refreshFriends(now: Date) {
        let owner = profile.appleUserID
        let descriptor = FetchDescriptor<Friend>(
            predicate: #Predicate { $0.ownerID == owner },
            sortBy: [SortDescriptor(\Friend.joinedAt)]
        )
        let fetched = (try? context.fetch(descriptor)) ?? []

        // Roll friends over to a new day the same way you roll over.
        let calendar = Calendar.current
        var changed = false
        for friend in fetched where !calendar.isDate(friend.lastUpdated, inSameDayAs: now) {
            friend.streak = friend.metGoal ? friend.streak + 1 : 0
            friend.todayOz = 0
            friend.lastUpdated = now
            changed = true
        }
        if changed { save() }

        friends = fetched
        let everyoneMet = !fetched.isEmpty && goalMet && fetched.allSatisfy(\.metGoal)
        groupStore.update(everyoneMet: everyoneMet, now: now)
        groupStreak = groupStore.current
    }

    // MARK: Insights

    /// Builds the patterns shown on the Insights screen from the last 30 days.
    private func computeInsights(now: Date) -> HydrationInsights {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -29, to: today),
              let end = calendar.date(byAdding: .day, value: 1, to: today) else { return HydrationInsights() }
        let owner = profile.appleUserID

        let descriptor = FetchDescriptor<WaterLog>(
            predicate: #Predicate { $0.ownerID == owner && $0.timestamp >= windowStart && $0.timestamp < end }
        )
        let logs = (try? context.fetch(descriptor)) ?? []
        return HydrationInsightsBuilder.build(logs: logs, goal: dailyGoal, now: now)
    }

    /// Demo helper: fills in two weeks of believable history so Insights has something to show.
    func seedDemoHistory(days: Int = 14) {
        let calendar = Calendar.current
        let owner = profile.appleUserID
        let goal = dailyGoal
        let sizes: [Double] = [4, 6, 8, 10, 12]

        for offset in 1...days {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: .now)) else { continue }
            let hitsGoal = Double.random(in: 0...1) < 0.6
            let target = goal * (hitsGoal ? Double.random(in: 1.0...1.25) : Double.random(in: 0.45...0.9))
            var poured = 0.0
            var hour = Double.random(in: 7...10.5)

            while poured < target && hour < 22 {
                let amount = sizes.randomElement() ?? 8
                guard let stamp = calendar.date(byAdding: .minute, value: Int(hour * 60), to: day) else { break }
                context.insert(WaterLog(ownerID: owner, amountOz: amount, timestamp: stamp,
                                        source: Double.random(in: 0...1) < 0.75 ? .smartCap : .manual))
                poured += amount
                hour += Double.random(in: 0.8...2.4)
            }
        }
        save()
        refresh()
    }

    // MARK: Reminders

    /// Rebuilds pending notifications from the latest numbers, so each reminder
    /// states exactly how much is left.
    private func rescheduleReminders(now: Date) {
        reminderTask?.cancel()
        guard profile.remindersEnabled else {
            ReminderScheduler.clearAll()
            return
        }
        let plan = ReminderPlanner.plan(
            reminderMinutes: profile.reminderMinutes,
            goal: dailyGoal,
            todayTotal: todayTotal,
            lastLogDate: todayLogs.first?.timestamp,
            now: now
        )
        reminderTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await ReminderScheduler.apply(plan)
        }
    }

    // MARK: Helpers

    private func save() {
        do { try context.save() } catch { print("SwiftData save failed: \(error)") }
    }

    private static func fetchOrCreateStreak(ownerID: String, in context: ModelContext) -> StreakRecord {
        let descriptor = FetchDescriptor<StreakRecord>(predicate: #Predicate { $0.ownerID == ownerID })
        if let existing = try? context.fetch(descriptor).first { return existing }
        let record = StreakRecord(ownerID: ownerID)
        context.insert(record)
        return record
    }
}
