import Foundation

struct WeekdayAverage: Identifiable, Equatable {
    let id: Int        // 1 = Sunday
    let name: String
    let average: Double
}

/// Everything the Insights screen shows. Pure data, computed from logs.
struct HydrationInsights: Equatable {
    var daysWithData = 0
    var goalDays = 0
    var averageDailyOunces: Double = 0

    // Share of all water logged in each part of the day.
    var shareMorning: Double = 0     // before noon
    var shareAfternoon: Double = 0   // noon–6 PM
    var shareEvening: Double = 0     // after 6 PM

    /// Minutes after midnight, averaged across past days.
    var averageFirstSip: Int?
    var earlyStartDays = 0
    var earlyStartHitRate: Double?
    var lateStartDays = 0
    var lateStartHitRate: Double?

    var weekdayAverages: [WeekdayAverage] = []
    /// When you usually cross your goal, on days you did.
    var averageFinish: Int?
    /// When today's pace would get you there.
    var projectedFinish: Date?
    var goalAlreadyMet = false

    var averageSipOunces: Double = 0
    var sipsPerDay: Double = 0
    var capShare: Double = 0

    var goalHitRate: Double { daysWithData > 0 ? Double(goalDays) / Double(daysWithData) : 0 }
    var hasEnoughData: Bool { daysWithData >= 2 }

    var bestWeekday: WeekdayAverage? { weekdayAverages.max { $0.average < $1.average } }
    var toughestWeekday: WeekdayAverage? { weekdayAverages.min { $0.average < $1.average } }
}

enum HydrationInsightsBuilder {
    /// Pass the last ~30 days of logs.
    static func build(logs: [WaterLog], goal: Double, now: Date = .now, calendar: Calendar = .current) -> HydrationInsights {
        var insights = HydrationInsights()
        guard !logs.isEmpty, goal > 0 else { return insights }

        let today = calendar.startOfDay(for: now)
        var byDay: [Date: [WaterLog]] = [:]
        for log in logs {
            byDay[calendar.startOfDay(for: log.timestamp), default: []].append(log)
        }
        let dayTotals = byDay.mapValues { $0.reduce(0) { $0 + $1.amountOz } }

        insights.daysWithData = byDay.count
        insights.goalDays = dayTotals.values.filter { $0 >= goal }.count
        insights.averageDailyOunces = dayTotals.values.reduce(0, +) / Double(max(byDay.count, 1))

        // When you drink
        var morning = 0.0, afternoon = 0.0, evening = 0.0
        for log in logs {
            let hour = calendar.component(.hour, from: log.timestamp)
            if hour < 12 { morning += log.amountOz }
            else if hour < 18 { afternoon += log.amountOz }
            else { evening += log.amountOz }
        }
        let everything = morning + afternoon + evening
        if everything > 0 {
            insights.shareMorning = morning / everything
            insights.shareAfternoon = afternoon / everything
            insights.shareEvening = evening / everything
        }

        // First sip, start-time effect, and finish times (today is still in progress, so skip it)
        var firstSips: [Int] = []
        var finishes: [Int] = []
        var earlyDays = 0, earlyMet = 0, lateDays = 0, lateMet = 0
        for (day, dayLogs) in byDay where day != today {
            guard let first = dayLogs.map(\.timestamp).min() else { continue }
            let minutes = calendar.component(.hour, from: first) * 60 + calendar.component(.minute, from: first)
            firstSips.append(minutes)

            let met = (dayTotals[day] ?? 0) >= goal
            if minutes < 9 * 60 {
                earlyDays += 1
                if met { earlyMet += 1 }
            } else {
                lateDays += 1
                if met { lateMet += 1 }
            }
            if met, let crossed = crossingTime(dayLogs, goal: goal) {
                finishes.append(calendar.component(.hour, from: crossed) * 60 + calendar.component(.minute, from: crossed))
            }
        }
        if !firstSips.isEmpty { insights.averageFirstSip = firstSips.reduce(0, +) / firstSips.count }
        if !finishes.isEmpty { insights.averageFinish = finishes.reduce(0, +) / finishes.count }
        insights.earlyStartDays = earlyDays
        insights.lateStartDays = lateDays
        if earlyDays > 0 { insights.earlyStartHitRate = Double(earlyMet) / Double(earlyDays) }
        if lateDays > 0 { insights.lateStartHitRate = Double(lateMet) / Double(lateDays) }

        // Weekday averages
        var weekdayTotals: [Int: [Double]] = [:]
        for (day, total) in dayTotals {
            weekdayTotals[calendar.component(.weekday, from: day), default: []].append(total)
        }
        let symbols = calendar.shortWeekdaySymbols // index 0 = Sunday
        insights.weekdayAverages = (1...7).compactMap { weekday in
            guard let totals = weekdayTotals[weekday], !totals.isEmpty else { return nil }
            return WeekdayAverage(id: weekday,
                                  name: symbols[weekday - 1],
                                  average: totals.reduce(0, +) / Double(totals.count))
        }

        // Today's finish forecast
        let todayLogs = byDay[today] ?? []
        let todayTotal = dayTotals[today] ?? 0
        if todayTotal >= goal {
            insights.goalAlreadyMet = true
        } else if let first = todayLogs.map(\.timestamp).min() {
            let hours = now.timeIntervalSince(first) / 3600
            let rate = hours > 0.5 ? todayTotal / hours : 0
            if rate > 0 {
                let hoursLeft = (goal - todayTotal) / rate
                if hoursLeft < 24 { insights.projectedFinish = now.addingTimeInterval(hoursLeft * 3600) }
            }
        }

        // How you log
        insights.averageSipOunces = logs.reduce(0) { $0 + $1.amountOz } / Double(logs.count)
        insights.sipsPerDay = Double(logs.count) / Double(max(byDay.count, 1))
        insights.capShare = Double(logs.filter { $0.source != .manual }.count) / Double(logs.count)

        return insights
    }

    /// The moment a day's running total first reached the goal.
    private static func crossingTime(_ logs: [WaterLog], goal: Double) -> Date? {
        var running = 0.0
        for log in logs.sorted(by: { $0.timestamp < $1.timestamp }) {
            running += log.amountOz
            if running >= goal { return log.timestamp }
        }
        return nil
    }
}
