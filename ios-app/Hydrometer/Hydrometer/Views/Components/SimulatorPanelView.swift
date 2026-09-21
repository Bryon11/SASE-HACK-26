import SwiftUI

/// Presentation control deck. Every button sends real byte packets through
/// SmartCapManager's parser — the same path live BLE data takes.
struct SimulatorPanelView: View {
    let cap: SmartCapManager
    @State private var customOunces: Double = 6
    @State private var isTwisting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Cap simulator", systemImage: "wand.and.stars")
                    .font(.headline)
                Spacer()
                if cap.isTilted {
                    Text("Tilted")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.gray.opacity(0.25), in: Capsule())
                        .foregroundStyle(.secondary)
                }
                if cap.isCapOpen {
                    Text("Cap open")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.sipEmber.opacity(0.2), in: Capsule())
                        .foregroundStyle(Color.sipEmber)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.snappy, value: cap.isCapOpen)

            HStack(spacing: 10) {
                ForEach([2.0, 4, 8], id: \.self) { oz in
                    Button { twist(oz) } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                            Text("Twist \(oz.ozText)").font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.bordered)
                    .tint(.purple)
                }
            }
            .disabled(isTwisting)

            HStack {
                Slider(value: $customOunces, in: 0.5...20, step: 0.5)
                Button("Twist \(customOunces.ozText)") { twist(customOunces) }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(isTwisting)
            }

            Toggle(isOn: Binding(get: { cap.isAutoDemoRunning }, set: { _ in cap.toggleAutoDemo() })) {
                Label("Auto-sip every few seconds", systemImage: "play.circle")
            }
            .tint(.purple)

            VStack(alignment: .leading, spacing: 8) {
                Text("Cap health tests")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack {
                    Button("20%") { cap.simulateBattery(20) }
                    Button("10%") { cap.simulateBattery(10) }
                    Button("0% (dead)") { cap.simulateBattery(0) }
                    Button("Charged") { cap.simulateBattery(100) }
                }
                HStack {
                    Button("Cap goes quiet") { cap.simulateSilentCap() }
                    Button("Bad JSON") { cap.simulateMalformedPacket() }
                }
                HStack {
                    Button("Refill bottle") { cap.simulateRefill() }
                    Button(cap.isTilted ? "Set upright" : "Tilt bottle") { cap.simulateTilt(!cap.isTilted) }
                }
            }
            .font(.caption)
            .buttonStyle(.bordered)

            if !cap.eventLog.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(cap.eventLog.prefix(5), id: \.self) { line in
                        Text(line).lineLimit(1)
                    }
                }
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func twist(_ oz: Double) {
        isTwisting = true
        Task {
            await cap.simulateTwist(ounces: oz)
            isTwisting = false
        }
    }
}
