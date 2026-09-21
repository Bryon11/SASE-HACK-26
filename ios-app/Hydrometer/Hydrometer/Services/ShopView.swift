import SwiftUI
import UIKit

/// Spend coins on caps, straps and bottles. Tapping an item tries it on the preview bottle.
struct ShopView: View {
    let viewModel: DashboardViewModel
    /// The sheet version keeps a Done button; the tab version doesn't need one.
    var showsDone: Bool = true
    @Environment(\.dismiss) private var dismiss
    @State private var slot: CosmeticSlot = .cap
    @State private var previewIDs: [CosmeticSlot: String]
    @State private var flash: String?
    @State private var twisting = false

    init(viewModel: DashboardViewModel, showsDone: Bool = true) {
        self.viewModel = viewModel
        self.showsDone = showsDone
        _previewIDs = State(initialValue: [
            .cap: viewModel.profile.equippedCapID,
            .strap: viewModel.profile.equippedStrapID,
            .bottle: viewModel.profile.equippedBottleID
        ])
    }

    private func previewItem(_ slot: CosmeticSlot) -> CosmeticItem? {
        previewIDs[slot].flatMap { CosmeticCatalog.item(id: $0) }
    }

    private var selected: CosmeticItem? { previewItem(slot) }

    private var previewStyle: BottleStyle {
        BottleStyle(cap: previewItem(.cap), strap: previewItem(.strap), bottle: previewItem(.bottle))
    }

    private var previewLabel: String {
        [previewItem(.cap), previewItem(.strap), previewItem(.bottle)]
            .compactMap { $0?.displayName }
            .joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    previewCard
                    savingCard
                    Picker("Category", selection: $slot) {
                        ForEach(CosmeticSlot.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(CosmeticCatalog.items(for: slot)) { item in
                            tile(item)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) { actionBar }
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        CoinView(size: 18)
                        Text("\(viewModel.coins)")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(Color.sipGoldText)
                            .contentTransition(.numericText(value: Double(viewModel.coins)))
                    }
                    .animation(.snappy, value: viewModel.coins)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(viewModel.coins) coins")
                }
                if showsDone {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }

    // MARK: Sections

    private var previewCard: some View {
        VStack(spacing: 10) {
            WaterBottleView(progress: 0.72, isCapOpen: twisting, style: previewStyle, width: 92, height: 180)
                .padding(.top, 24) // room for the cap to lift
            Text(previewLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.sipAqua.opacity(0.14), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var savingCard: some View {
        let target = viewModel.savingTarget
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(target.map { "Saving for: \($0.displayName)" } ?? "You own everything")
                    .font(.subheadline.weight(.bold))
                Spacer()
                if let target {
                    Text("\(min(viewModel.coins, target.price)) / \(target.price)")
                        .font(.subheadline.weight(.heavy).monospacedDigit())
                        .foregroundStyle(Color.sipGoldText)
                }
            }
            ProgressView(value: target.map { min(Double(viewModel.coins) / Double(max($0.price, 1)), 1) } ?? 1)
                .tint(Color.sipGold)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(.easeOut, value: viewModel.coins)
    }

    private func tile(_ item: CosmeticItem) -> some View {
        let owned = viewModel.isOwned(item)
        let equipped = viewModel.isEquipped(item)
        let locked = item.streakRequirement != nil && !owned
        let isSelected = previewIDs[slot] == item.id
        let statusColor: Color = equipped ? Color.sipOcean : ((owned || locked) ? Color.secondary : Color.sipGoldText)

        return Button {
            withAnimation(.snappy) {
                previewIDs[slot] = item.id
                flash = nil
            }
            if !owned && !locked { viewModel.setSavingTarget(item) }
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(item.color)
                    .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 1))
                    .frame(width: 40, height: 40)
                    .opacity(locked ? 0.45 : 1)
                Text(item.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                HStack(spacing: 4) {
                    if locked {
                        Image(systemName: "lock.fill")
                        Text("\(item.streakRequirement ?? 0)-day streak")
                    } else if equipped {
                        Text("Equipped")
                    } else if owned {
                        Text("Owned")
                    } else {
                        CoinView(size: 11)
                        Text("\(item.price)")
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 104)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.sipOcean : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.displayName), \(locked ? "locked" : equipped ? "equipped" : owned ? "owned" : "\(item.price) coins")")
    }

    private var actionBar: some View {
        VStack(spacing: 8) {
            if let flash {
                Text(flash)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.sipGoldText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.sipGold.opacity(0.22), in: Capsule())
                    .transition(.scale.combined(with: .opacity))
            }
            Button(action: performAction) {
                Text(action.label)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.sipOcean)
            .disabled(action.disabled)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
        .animation(.snappy, value: flash)
    }

    // MARK: Actions

    private var action: (label: String, disabled: Bool) {
        guard let item = selected else { return ("Pick something", true) }
        let owned = viewModel.isOwned(item)
        if let required = item.streakRequirement, !owned {
            return ("Unlocks with a \(required)-day streak", true)
        }
        if viewModel.isEquipped(item) { return ("Equipped", true) }
        if owned { return ("Equip \(item.displayName)", false) }
        if viewModel.coins >= item.price { return ("Buy for \(item.price) coins", false) }
        return ("\(item.price - viewModel.coins) more coins needed", true)
    }

    private func performAction() {
        guard let item = selected else { return }
        if viewModel.isOwned(item) {
            viewModel.equip(item)
            twistOn()
            return
        }
        if viewModel.purchase(item) {
            flash = "\(item.displayName.capitalized) unlocked"
            twistOn()
            CoinSoundPlayer.shared.ding(step: 5, final: true)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    /// Unscrews and screws the preview cap back on, like putting the new one on.
    private func twistOn() {
        twisting = true
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            twisting = false
        }
    }
}
