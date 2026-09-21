import SwiftUI
import SwiftData
import Charts

struct HistoryView: View {
    let goal: Double
    @Query private var logs: [WaterLog]

    init(ownerID: String, goal: Double) {
        self.goal = goal
        _logs = Query(
            filter: #Predicate<WaterLog> { $0.ownerID == ownerID },
            sort: \WaterLog.timestamp,
            order: .reverse
        )
    }

    private struct DayGroup: Identifiable {
        let day: Date
        let logs: [WaterLog]
        var id: Date { day }
        var total: Double { logs.reduce(0) { $0 + $1.amountOz } }
    }

    private var days: [DayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: logs) { calendar.startOfDay(for: $0.timestamp) }
        return grouped.keys.sorted(by: >).map { DayGroup(day: $0, logs: grouped[$0] ?? []) }
    }

    private var lastSevenDays: [DayGroup] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let byDay = Dictionary(uniqueKeysWithValues: days.map { ($0.day, $0) })
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return byDay[day] ?? DayGroup(day: day, logs: [])
        }
    }

    var body: some View {
        List {
            if logs.isEmpty {
                ContentUnavailableView(
                    "No sips yet",
                    systemImage: "drop",
                    description: Text("Your daily totals will show up here.")
                )
            } else {
                Section("Last 7 days") {
                    Chart {
                        ForEach(lastSevenDays) { group in
                            BarMark(
                                x: .value("Day", group.day, unit: .day),
                                y: .value("Ounces", group.total)
                            )
                            .foregroundStyle(group.total >= goal ? Color.sipMint : Color.sipAqua)
                            .cornerRadius(6)
                        }
                        RuleMark(y: .value("Goal", goal))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(.secondary)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.weekday(.narrow))
                        }
                    }
                    .frame(height: 180)
                    .padding(.vertical, 8)
                }

                ForEach(days) { group in
                    Section {
                        ForEach(group.logs) { LogRowView(log: $0) }
                    } header: {
                        HStack {
                            Text(group.day, format: .dateTime.weekday(.wide).month().day())
                            Spacer()
                            Text(group.total.ozText)
                            Image(systemName: group.total >= goal ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(group.total >= goal ? Color.sipMint : .secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
    }
}
