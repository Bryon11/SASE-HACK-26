import SwiftUI

/// What the cap's condition looks like to the rest of the app.
enum CapHealth: Equatable {
    case unknown
    case ok
    case lowBattery(Int)       // 20% or less
    case criticalBattery(Int)  // 10% or less
    case batteryDead           // 0%
    case silent(since: Date)   // connected, but nothing for hours
}

struct CapAlertInfo: Equatable, Identifiable {
    let id: String
    let title: String
    let message: String
    let systemImage: String
    let tint: Color
}

extension CapHealth {
    /// nil when there's nothing worth interrupting anyone about.
    var alert: CapAlertInfo? {
        switch self {
        case .unknown, .ok:
            nil
        case .lowBattery(let percent):
            CapAlertInfo(
                id: "low",
                title: "Cap battery at \(percent)%",
                message: "Charge it in the next day or so. Logging still works for now.",
                systemImage: "battery.25",
                tint: .orange
            )
        case .criticalBattery(let percent):
            CapAlertInfo(
                id: "critical",
                title: "Cap battery at \(percent)%",
                message: "Charge it now, or sips will stop logging on their own.",
                systemImage: "battery.0",
                tint: .red
            )
        case .batteryDead:
            CapAlertInfo(
                id: "dead",
                title: "Your cap is out of battery",
                message: "Nothing is being logged automatically. Use the + buttons until it's charged.",
                systemImage: "exclamationmark.triangle.fill",
                tint: .red
            )
        case .silent(let since):
            CapAlertInfo(
                id: "quiet",
                title: "Cap hasn't reported since \(since.formatted(date: .omitted, time: .shortened))",
                message: "It may be off, out of range, or broken. Log by hand for now.",
                systemImage: "wifi.exclamationmark",
                tint: .orange
            )
        }
    }
}

struct CapHealthBanner: View {
    let alert: CapAlertInfo
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: alert.systemImage)
                .font(.title3)
                .foregroundStyle(alert.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(alert.title)
                    .font(.subheadline.weight(.bold))
                Text(alert.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(14)
        .background(alert.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(alert.tint.opacity(0.35), lineWidth: 1)
        )
    }
}
