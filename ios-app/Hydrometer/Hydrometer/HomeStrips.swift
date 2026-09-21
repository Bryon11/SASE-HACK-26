import SwiftUI

// MARK: - Quick stats

struct StatTile: View {
    let value: String
    let label: String
    var tint: Color = .primary

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Your day

/// A 6 AM–10 PM line with one dot per sip, sized by how much you drank.
/// The gaps are the point: they show when you stop drinking.
struct DayTimelineCard: View {
    let logs: [WaterLog]
    var startHour = 6
    var endHour = 22

    private var sorted: [WaterLog] { logs.sorted { $0.timestamp < $1.timestamp } }

    private var caption: String {
        guard let last = sorted.last?.timestamp else { return "No sips yet today" }
        let minutes = Int(Date.now.timeIntervalSince(last) / 60)
        if minutes < 60 { return "\(max(minutes, 1)) min since your last sip" }
        let hours = Double(minutes) / 60
        return "\(hours.formatted(.number.precision(.fractionLength(0...1)))) hr since your last sip"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Your day")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.18))
                    .frame(width: geo.size.width, height: 4)
                    .offset(y: 15)

                    if let nowX = position(for: .now, width: geo.size.width) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.45))
                            .frame(width: 2, height: 22)
                            .offset(x: nowX - 1, y: 6)
                    }

                    ForEach(sorted) { log in
                        if let x = position(for: log.timestamp, width: geo.size.width) {
                            let size = dotSize(for: log.amountOz)
                            Circle()
                                .fill(Color.sipWater)
                                .frame(width: size, height: size)
                                .offset(x: x - size / 2, y: 17 - size / 2)
                        }
                    }
                }
            }
            .frame(height: 34)

            HStack {
                Text("6a")
                Spacer()
                Text("2p")
                Spacer()
                Text("10p")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's sips over time. \(caption)")
    }

    private func position(for date: Date, width: CGFloat) -> CGFloat? {
        let calendar = Calendar.current
        let minutes = Double(calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date))
        let start = Double(startHour * 60)
        let span = Double((endHour - startHour) * 60)
        guard span > 0 else { return nil }
        let fraction = min(max((minutes - start) / span, 0), 1)
        return width * fraction
    }

    private func dotSize(for ounces: Double) -> CGFloat {
        let clamped = min(max(ounces, 2), 16)
        return 6 + (clamped - 2) / 14 * 8 // 6…14 points
    }
}

// MARK: - Friends strip

struct FriendsStripCard: View {
    let groupStreak: Int
    let entries: [LeaderboardEntry]
    let done: Int
    let total: Int
    let rank: Int
    let hasFriends: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundStyle(Color.sipEmber)
                    Text(headline)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                if hasFriends {
                    HStack(spacing: 8) {
                        ForEach(entries.prefix(5)) { entry in
                            Text(entry.emoji)
                                .font(.system(size: 16))
                                .frame(width: 30, height: 30)
                                .background((entry.metGoal ? Color.sipMint : Color.gray).opacity(0.22), in: Circle())
                        }
                        Spacer(minLength: 0)
                        Text("\(done) of \(total) done")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Invite someone and keep a group streak going.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private var headline: String {
        guard hasFriends else { return "Friends" }
        let streakPart = groupStreak > 0 ? "Group streak \(groupStreak)" : "No group streak yet"
        return "\(streakPart) · you're #\(rank)"
    }
}

// MARK: - Saving for

struct SavingForCard: View {
    let coins: Int
    let target: CosmeticItem?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                CoinView(size: 22)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    if let target {
                        ProgressView(value: min(Double(coins) / Double(max(target.price, 1)), 1))
                            .tint(Color.sipGold)
                    }
                }

                if let target {
                    Text("\(min(coins, target.price))/\(target.price)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(Color.sipGoldText)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private var title: String {
        guard let target else { return "You own everything in the shop" }
        return coins >= target.price
            ? "You can buy the \(target.displayName)"
            : "Saving for \(target.displayName)"
    }
}
