import SwiftUI
import Charts

/// Turns the raw logs into things you couldn't know on your own: when you fall
/// behind, what your start time does to your odds, and where today is heading.
struct InsightsView: View {
    let insights: HydrationInsights
    let goal: Double

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if insights.hasEnoughData {
                    consistencyCard
                    whenYouDrinkCard
                    if insights.averageFirstSip != nil { firstSipCard }
                    finishCard
                    loggingCard
                } else {
                    ContentUnavailableView(
                        "Not enough data yet",
                        systemImage: "chart.bar",
                        description: Text("Log water for a couple of days and your patterns will show up here.")
                    )
                    .padding(.top, 60)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: Cards

    private var consistencyCard: some View {
        card {
            Text("Consistency")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Int((insights.goalHitRate * 100).rounded()))%")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text("of days hit")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("\(insights.goalDays) of your last \(insights.daysWithData) days, averaging \(insights.averageDailyOunces.rounded().ozText) a day.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if insights.weekdayAverages.count > 1 {
                Chart {
                    ForEach(insights.weekdayAverages) { day in
                        BarMark(x: .value("Day", day.name), y: .value("Average", day.average))
                            .foregroundStyle(day.average >= goal ? Color.sipMint : Color.sipAqua)
                            .cornerRadius(5)
                    }
                    RuleMark(y: .value("Goal", goal))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 140)
                .padding(.top, 4)

                if let best = insights.bestWeekday, let worst = insights.toughestWeekday, best.id != worst.id {
                    takeaway("\(best.name) is your strongest day; \(worst.name) is where you slip.")
                }
            }
        }
    }

    private var whenYouDrinkCard: some View {
        card {
            Text("When you drink")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            shareRow("Morning", insights.shareMorning)
            shareRow("Afternoon", insights.shareAfternoon)
            shareRow("Evening", insights.shareEvening)
            takeaway(whenTakeaway)
        }
    }

    private var firstSipCard: some View {
        card {
            Text("Your first sip")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if let minutes = insights.averageFirstSip {
                Text(timeText(minutes))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("is when you usually start drinking.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let early = insights.earlyStartHitRate, let late = insights.lateStartHitRate,
               insights.earlyStartDays >= 2, insights.lateStartDays >= 2 {
                takeaway("Starting before 9 AM, you hit your goal \(percent(early)) of the time. Starting later, \(percent(late)).")
            } else {
                takeaway("A few more days of data will show what your start time does to your odds.")
            }
        }
    }

    private var finishCard: some View {
        card {
            Text("Today's finish line")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if insights.goalAlreadyMet {
                Text("Done for today")
                    .font(.title2.weight(.bold))
                if let usual = insights.averageFinish {
                    takeaway("You usually cross the line around \(timeText(usual)).")
                }
            } else if let projected = insights.projectedFinish {
                Text(projected, format: .dateTime.hour().minute())
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("is when today's pace gets you there.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let usual = insights.averageFinish {
                    let projectedMinutes = Calendar.current.component(.hour, from: projected) * 60
                        + Calendar.current.component(.minute, from: projected)
                    let difference = projectedMinutes - usual
                    takeaway(abs(difference) < 30
                             ? "That's right about your usual finish time."
                             : difference > 0
                               ? "That's \(minutesText(difference)) later than usual — worth a refill soon."
                               : "That's \(minutesText(-difference)) earlier than usual. Nice pace.")
                }
            } else {
                Text("Not enough sips today")
                    .font(.title3.weight(.semibold))
                takeaway("Log a couple of sips and I can predict when you'll finish.")
            }
        }
    }

    private var loggingCard: some View {
        card {
            Text("How you log")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 24) {
                stat(percent(insights.capShare), "from the cap")
                stat(insights.averageSipOunces.ozText, "average sip")
                stat(String(format: "%.0f", insights.sipsPerDay), "sips a day")
            }
            takeaway(insights.capShare > 0.7
                     ? "The cap is doing most of the work, so your numbers are close to real life."
                     : "Most sips are typed in by hand, so the cap may be missing drinks.")
        }
    }

    // MARK: Pieces

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func takeaway(_ text: String) -> some View {
        Label(text, systemImage: "lightbulb.fill")
            .font(.footnote)
            .foregroundStyle(Color.sipOcean)
            .padding(.top, 2)
    }

    private func shareRow(_ label: String, _ share: Double) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .frame(width: 84, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.sipAqua.opacity(0.18))
                    Capsule().fill(Color.sipWater).frame(width: max(geo.size.width * share, 4))
                }
            }
            .frame(height: 14)
            Text(percent(share))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .frame(width: 44, alignment: .trailing)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.weight(.bold))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var whenTakeaway: String {
        let parts = [("morning", insights.shareMorning), ("afternoon", insights.shareAfternoon), ("evening", insights.shareEvening)]
        guard let biggest = parts.max(by: { $0.1 < $1.1 }), let smallest = parts.min(by: { $0.1 < $1.1 }) else { return "" }
        return "Most of your water lands in the \(biggest.0). The \(smallest.0) is your gap — that's where a reminder helps most."
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func timeText(_ minutes: Int) -> String {
        let date = Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        return date.formatted(.dateTime.hour().minute())
    }

    private func minutesText(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let hours = Double(minutes) / 60
        return "\(hours.formatted(.number.precision(.fractionLength(0...1)))) hr"
    }
}
