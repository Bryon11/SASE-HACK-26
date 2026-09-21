import SwiftUI

struct LogRowView: View {
    let log: WaterLog

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: log.source.systemImage)
                .font(.body)
                .foregroundStyle(Color.sipOcean)
                .frame(width: 36, height: 36)
                .background(Color.sipAqua.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(log.amountOz.ozText).font(.body.weight(.semibold))
                Text(log.source.label).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(log.timestamp, format: .dateTime.hour().minute())
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
