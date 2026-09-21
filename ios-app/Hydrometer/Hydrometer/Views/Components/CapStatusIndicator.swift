import SwiftUI

struct CapStatusIndicator: View {
    let cap: SmartCapManager

    var body: some View {
        Button {
            if cap.connectionState == .idle { cap.scan() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .symbolEffect(.pulse, isActive: isSearching)
                VStack(alignment: .leading, spacing: 1) {
                    Text(cap.connectionState.label)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if let battery = cap.batteryPercent {
                        Label("\(battery)%", systemImage: batteryIcon(battery))
                            .font(.caption2)
                            .foregroundStyle(battery <= 20 ? .red : .secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Smart cap: \(cap.connectionState.label)")
    }

    private var isSearching: Bool {
        cap.connectionState == .scanning || cap.connectionState == .connecting
    }

    private var icon: String {
        switch cap.connectionState {
        case .connected: "sensor.fill"
        case .simulated: "wand.and.stars"
        case .scanning, .connecting: "antenna.radiowaves.left.and.right"
        default: "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch cap.connectionState {
        case .connected: .green
        case .simulated: .purple
        case .scanning, .connecting: .sipAqua
        case .idle: .secondary
        default: .orange
        }
    }

    private func batteryIcon(_ p: Int) -> String {
        switch p {
        case 76...: "battery.100"
        case 51...75: "battery.75"
        case 26...50: "battery.50"
        case 11...25: "battery.25"
        default: "battery.0"
        }
    }
}
