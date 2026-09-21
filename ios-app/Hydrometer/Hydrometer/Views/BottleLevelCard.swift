import SwiftUI

/// "How much is left in the bottle right now" — simulated by subtracting each
/// sip from the bottle's capacity, and topped back up when you refill.
/// (If the hardware later gains a level sensor, only the numbers change.)
struct BottleLevelCard: View {
    let remaining: Double
    let capacity: Double
    let style: BottleStyle
    var isLive: Bool = false
    let onRefill: () -> Void
    let onCapacityChange: (Double) -> Void

    private static let capacityOptions: [Double] = [12, 16, 20, 24, 32, 40, 64]

    private var level: Double { capacity > 0 ? min(max(remaining / capacity, 0), 1) : 0 }
    private var isEmpty: Bool { remaining < 0.5 }
    private var isLow: Bool { !isEmpty && level <= 0.2 }

    private var statusText: String {
        if isEmpty { return "Empty — time for a refill" }
        if isLow { return "Almost empty" }
        let glasses = Int((remaining / 8).rounded(.down))
        return glasses >= 1 ? "About \(glasses) more glass\(glasses == 1 ? "" : "es")" : "Less than a glass left"
    }

    var body: some View {
        HStack(spacing: 18) {
            WaterBottleView(progress: level, isCapOpen: false, style: style, width: 58, height: 112, showsFloat: true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("In your bottle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Label(isLive ? "Live" : "Estimated", systemImage: isLive ? "sensor.fill" : "function")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((isLive ? Color.sipMint : Color.gray).opacity(0.2), in: Capsule())
                        .foregroundStyle(isLive ? Color.sipOcean : .secondary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(remaining.formatted(.number.precision(.fractionLength(0...1))))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .contentTransition(.numericText(value: remaining))
                    Menu {
                        Picker("Bottle size", selection: Binding(
                            get: { capacity },
                            set: { onCapacityChange($0) }
                        )) {
                            ForEach(Self.capacityOptions, id: \.self) { size in
                                Text(size.ozText).tag(size)
                            }
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Text("of \(capacity.ozText)")
                            Image(systemName: "chevron.up.chevron.down").font(.caption2)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.sipAqua.opacity(0.18))
                        Capsule()
                            .fill(isEmpty || isLow ? Color.orange : Color.sipWater)
                            .frame(width: max(geo.size.width * level, level > 0 ? 6 : 0))
                    }
                }
                .frame(height: 10)

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(isEmpty || isLow ? Color.orange : .secondary)
            }

            Button(action: onRefill) {
                VStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                    Text(isLive ? "Full" : "Refill").font(.caption.weight(.semibold))
                }
                .frame(width: 58, height: 58)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.sipOcean)
            .accessibilityLabel("Refill bottle")
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .animation(.snappy, value: remaining)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bottle has \(remaining.ozText) of \(capacity.ozText) left")
    }
}
