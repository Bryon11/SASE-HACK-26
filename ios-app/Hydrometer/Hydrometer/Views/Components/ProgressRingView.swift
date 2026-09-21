import SwiftUI

/// The app's hero element. Past 100% a mint second lap draws over the first.
struct ProgressRingView: View {
    let progress: Double
    var lineWidth: CGFloat = 24

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.sipAqua.opacity(0.15), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(progress, 1))
                .stroke(
                    AngularGradient(colors: [.sipOcean, .sipAqua], center: .center,
                                    startAngle: .degrees(0), endAngle: .degrees(360 * max(min(progress, 1), 0.01))),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if progress > 1 {
                Circle()
                    .trim(from: 0, to: min(progress - 1, 1))
                    .stroke(Color.sipMint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: .sipMint.opacity(0.5), radius: 6)
            }
        }
        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: progress)
        .accessibilityElement()
        .accessibilityLabel("Daily progress")
        .accessibilityValue("\(Int((progress * 100).rounded())) percent")
    }
}

/// Ring + numbers in the middle.
struct HydrationRingCard: View {
    let total: Double
    let goal: Double
    let progress: Double
    let paceMessage: String
    let isCapOpen: Bool

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                ProgressRingView(progress: progress)
                    .frame(width: 230, height: 230)

                VStack(spacing: 4) {
                    Image(systemName: isCapOpen ? "drop.degreesign.fill" : "drop.fill")
                        .font(.title2)
                        .foregroundStyle(Color.sipAqua)
                        .symbolEffect(.bounce, value: total)
                    Text(total.formatted(.number.precision(.fractionLength(0...1))))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .contentTransition(.numericText(value: total))
                        .animation(.snappy, value: total)
                    Text("of \(goal.ozText)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Text(paceMessage)
                .font(.callout.weight(.medium))
                .foregroundStyle(progress >= 1 ? Color.sipMint : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
