import SwiftUI

/// The tree full screen: every ounce you drink pours into it.
struct GardenView: View {
    let viewModel: DashboardViewModel

    private var lifetime: Double { viewModel.lifetimeOunces }
    private var growth: Double { TreeGrowth.growth(for: lifetime) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                GrowingTreeView(growth: growth, waterAmount: viewModel.todayTotal,
                                pourOnAppear: true, bottleStyle: viewModel.bottleStyle)
                    .frame(height: 320)
                    .background(
                        LinearGradient(colors: [Color(hex: "#D9F0FB"), Color(hex: "#EFF8E8")],
                                       startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                    )

                VStack(spacing: 6) {
                    Text(TreeGrowth.stageName(for: lifetime))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("\(lifetime.rounded().ozText) poured in so far")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                card {
                    if let next = TreeGrowth.nextStage(for: lifetime),
                       let remaining = TreeGrowth.ouncesToNextStage(for: lifetime) {
                        HStack {
                            Text("Next: \(next.name)")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(remaining.rounded().ozText)
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(Color(hex: "#3E9B4F"))
                        }
                        ProgressView(value: TreeGrowth.progressToNextStage(for: lifetime))
                            .tint(Color(hex: "#4CAE58"))
                        Text("At your usual pace, about \(daysToNextStage(remaining)) more days of hitting your goal.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Fully grown")
                            .font(.subheadline.weight(.semibold))
                        Text("Your tree is done growing, but it keeps its fruit as long as you keep drinking.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                card {
                    Text("Today")
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 10) {
                        StatTile(value: viewModel.todayTotal.rounded().ozText, label: "poured today")
                        StatTile(value: "\(viewModel.currentStreak)", label: "day streak")
                        StatTile(value: "\(TreeGrowth.stageIndex(for: lifetime) + 1)/\(TreeGrowth.stages.count)", label: "stage")
                    }
                    Text("Every sip the cap logs waters the tree. Miss a day and it just stops growing — it never dies.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Your tree")
    }

    private func daysToNextStage(_ remaining: Double) -> Int {
        let perDay = max(viewModel.dailyGoal, 1)
        return max(Int((remaining / perDay).rounded(.up)), 1)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
