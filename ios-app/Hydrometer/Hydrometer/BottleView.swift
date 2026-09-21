import SwiftUI

/// The bottle in your hand: what's left, the float sensor, and today's sips.
struct BottleView: View {
    let viewModel: DashboardViewModel

    private static let sizes: [Double] = [12, 16, 20, 24, 32, 40, 64]

    private var level: Double {
        viewModel.bottleCapacity > 0 ? viewModel.bottleRemaining / viewModel.bottleCapacity : 0
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    WaterBottleView(progress: level,
                                    isCapOpen: viewModel.cap.isCapOpen,
                                    style: viewModel.bottleStyle,
                                    width: 130,
                                    height: 260,
                                    showsFloat: true)

                    VStack(spacing: 4) {
                        Text("\(viewModel.bottleRemaining.formatted(.number.precision(.fractionLength(0...1)))) oz left")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .contentTransition(.numericText(value: viewModel.bottleRemaining))
                        Text("of a \(viewModel.bottleCapacity.ozText) bottle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Label(viewModel.bottleLevelIsLive ? "Live from the cap's float sensor" : "Estimated from your sips",
                              systemImage: viewModel.bottleLevelIsLive ? "sensor.fill" : "function")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background((viewModel.bottleLevelIsLive ? Color.sipMint : Color.gray).opacity(0.2), in: Capsule())
                            .foregroundStyle(viewModel.bottleLevelIsLive ? Color.sipOcean : .secondary)
                    }

                    if level <= 0.2 {
                        Label("Almost empty — refill soon", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                    }

                    Button {
                        withAnimation(.snappy) { viewModel.refillBottle() }
                    } label: {
                        Label("Refill to full", systemImage: "drop.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.sipOcean)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
            }

            Section("Today's sips") {
                if viewModel.todayLogs.isEmpty {
                    Text("Nothing yet today. Twist the cap to log a drink.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.todayLogs) { log in
                        LogRowView(log: log)
                    }
                    .onDelete { offsets in
                        for index in offsets where viewModel.todayLogs.indices.contains(index) {
                            withAnimation { viewModel.delete(viewModel.todayLogs[index]) }
                        }
                    }
                }
            }

            Section("Bottle size") {
                Picker("Ounces", selection: Binding(
                    get: { viewModel.bottleCapacity },
                    set: { viewModel.setBottleCapacity($0) }
                )) {
                    ForEach(Self.sizes, id: \.self) { size in
                        Text("\(Int(size))").tag(size)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Cap") {
                LabeledContent("Connection", value: viewModel.cap.connectionState.label)
                LabeledContent("Position", value: viewModel.cap.isTilted ? "Tilted (readings paused)" : "Upright")
                if let battery = viewModel.cap.batteryPercent {
                    LabeledContent("Battery", value: "\(battery)%")
                }
                if let last = viewModel.cap.lastVolumeDate {
                    LabeledContent("Last reading", value: last.formatted(date: .omitted, time: .shortened))
                }
                NavigationLink {
                    HistoryView(ownerID: viewModel.profile.appleUserID, goal: viewModel.dailyGoal)
                } label: {
                    Label("Full history", systemImage: "calendar")
                }
            }
        }
        .navigationTitle("In your bottle")
        .animation(.snappy, value: viewModel.todayLogs.count)
    }
}
