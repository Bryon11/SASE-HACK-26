import SwiftUI

struct StreakBadgeView: View {
    let current: Int
    let longest: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .foregroundStyle(current > 0 ? Color.sipEmber : .secondary)
                .symbolEffect(.bounce, value: current)
            Text("\(current)")
                .font(.headline.monospacedDigit())
                .contentTransition(.numericText(value: Double(current)))
            Text(current == 1 ? "day" : "days")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
        .animation(.snappy, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(current) day streak. Longest \(longest).")
    }
}
