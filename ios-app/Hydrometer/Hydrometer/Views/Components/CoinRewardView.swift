import SwiftUI
import UIKit

// MARK: - Coin graphic & counter

struct CoinView: View {
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            Circle().fill(Color.sipGold)
            Circle().stroke(Color.sipGoldDark, lineWidth: size * 0.07)
            Circle()
                .stroke(Color.sipGoldDark.opacity(0.7), lineWidth: size * 0.05)
                .padding(size * 0.2)
            Circle()
                .fill(Color.white.opacity(0.45))
                .frame(width: size * 0.18, height: size * 0.18)
                .offset(x: -size * 0.2, y: -size * 0.2)
        }
        .frame(width: size, height: size)
    }
}

/// Reports where the coin counter is, so flying coins know where to land.
struct CoinCounterFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

/// Coin balance pill. Bumps each time `bumpTrigger` changes. Tap opens the shop.
struct CoinCounterView: View {
    let coins: Int
    let bumpTrigger: Int
    let action: () -> Void
    @State private var bumped = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                CoinView(size: 18)
                Text("\(coins)")
                    .font(.subheadline.weight(.heavy).monospacedDigit())
                    .foregroundStyle(Color.sipGoldText)
                    .contentTransition(.numericText(value: Double(coins)))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.sipGold.opacity(0.22), in: Capsule())
            .scaleEffect(bumped ? 1.18 : 1)
        }
        .buttonStyle(.plain)
        .background {
            GeometryReader { geo in
                Color.clear.preference(key: CoinCounterFrameKey.self, value: geo.frame(in: .global))
            }
        }
        .animation(.snappy, value: coins)
        .onChange(of: bumpTrigger) { _, _ in
            withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { bumped = true }
            Task {
                try? await Task.sleep(for: .milliseconds(150))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { bumped = false }
            }
        }
        .accessibilityLabel("\(coins) coins")
        .accessibilityHint("Opens the shop")
    }
}

// MARK: - Reward sequence

/// The goal reward, in about 2 seconds:
///  1. the cap pops and a coin shoots up out of the bottle, spinning
///  2. streak bonus coins follow, each ding a note higher
///  3. coins arc into the counter, which bumps as each lands
///  4. a card shows your savings progress or a new unlock
/// Tap anywhere to skip.
struct CoinRewardView: View {
    let reward: CoinReward
    let capFrame: CGRect
    let counterFrame: CGRect
    let onCapOpen: (Bool) -> Void
    let onCoinLanded: (Int) -> Void
    let onOpenShop: () -> Void
    let onFinish: () -> Void

    @State private var start: Date?
    @State private var showCard = false
    @State private var barProgress: Double = 0
    @State private var finished = false

    private let rise: Double = 0.45
    private let fly: Double = 0.6
    private let gap: Double = 0.22

    private struct FlyingCoin: Identifiable {
        let id: Int
        let amount: Int
        let label: String
        let delay: Double
        let spread: CGFloat
        let size: CGFloat
    }

    private var coins: [FlyingCoin] {
        var list = [FlyingCoin(id: 0, amount: reward.baseCoins, label: "+\(reward.baseCoins)",
                               delay: 0, spread: 0, size: 40)]
        for i in 0..<reward.bonusCoins {
            let side: CGFloat = i % 2 == 0 ? 1 : -1
            let spread: CGFloat = side * CGFloat(20 + (i / 2) * 18)
            list.append(FlyingCoin(id: i + 1, amount: 1, label: "+1",
                                   delay: 0.3 + Double(i) * gap, spread: spread, size: 28))
        }
        return list
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                    .opacity(showCard ? 0.2 : 0.001)
                    .contentShape(Rectangle())
                    .onTapGesture { finish() }

                if let start {
                    TimelineView(.animation) { context in
                        let t = context.date.timeIntervalSince(start)
                        ZStack {
                            ForEach(coins) { coin in
                                coinView(coin, t: t, screen: geo.size)
                            }
                        }
                    }
                    .allowsHitTesting(false)
                }

                if showCard {
                    progressCard
                        .frame(maxWidth: min(geo.size.width - 40, 380))
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.44)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { barProgress = barFrom }
        .task { await run() }
    }

    // MARK: Sequence

    private func run() async {
        onCapOpen(true)
        try? await Task.sleep(for: .seconds(0.4))
        guard !finished, !Task.isCancelled else { return }

        let began = Date.now
        start = began
        let list = coins
        for (index, coin) in list.enumerated() {
            let landAt = coin.delay + rise + fly
            let wait = landAt - Date.now.timeIntervalSince(began)
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard !finished, !Task.isCancelled else { return }
            let isLast = index == list.count - 1
            onCoinLanded(coin.amount)
            CoinSoundPlayer.shared.ding(step: index, final: isLast)
            UIImpactFeedbackGenerator(style: isLast ? .heavy : .light).impactOccurred()
        }

        onCapOpen(false)
        try? await Task.sleep(for: .seconds(0.25))
        guard !finished, !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { showCard = true }

        try? await Task.sleep(for: .seconds(0.35))
        guard !finished, !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.9)) { barProgress = barTarget }
        if !reward.newUnlocks.isEmpty || isReadyToBuy {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }

        try? await Task.sleep(for: .seconds(3.2))
        guard !Task.isCancelled else { return }
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onCapOpen(false)
        onFinish()
    }

    // MARK: Coins

    @ViewBuilder
    private func coinView(_ coin: FlyingCoin, t: Double, screen: CGSize) -> some View {
        let local = t - coin.delay
        if local >= 0 && local < rise + fly {
            let rising = local < rise
            let scale: CGFloat = rising
                ? CGFloat(0.5 + 0.5 * easeOut(local / rise))
                : CGFloat(1 - 0.35 * ((local - rise) / fly))
            CoinView(size: coin.size)
                .rotation3DEffect(.degrees(local * 900), axis: (x: 0, y: 1, z: 0))
                .overlay(alignment: .top) {
                    if local < rise + 0.15 {
                        Text(coin.label)
                            .font(.system(size: coin.size * 0.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.sipGoldDark)
                            .fixedSize()
                            .offset(y: -coin.size * 0.8)
                    }
                }
                .scaleEffect(scale)
                .position(position(for: coin, local: local, screen: screen))
        }
    }

    private func position(for coin: FlyingCoin, local: Double, screen: CGSize) -> CGPoint {
        let origin = capFrame == .zero
            ? CGPoint(x: screen.width / 2, y: screen.height * 0.35)
            : CGPoint(x: capFrame.midX, y: capFrame.midY)
        let end = counterFrame == .zero
            ? CGPoint(x: screen.width - 50, y: 80)
            : CGPoint(x: counterFrame.midX, y: counterFrame.midY)
        let peak = CGPoint(x: origin.x + coin.spread, y: origin.y - 120)

        if local < rise {
            let u = CGFloat(easeOut(local / rise))
            return CGPoint(x: origin.x + (peak.x - origin.x) * u,
                           y: origin.y + (peak.y - origin.y) * u)
        }
        let u = CGFloat(easeInOut((local - rise) / fly))
        let control = CGPoint(x: (peak.x + end.x) / 2, y: min(peak.y, end.y) - 70)
        let a = (1 - u) * (1 - u)
        let b = 2 * (1 - u) * u
        let c = u * u
        return CGPoint(x: a * peak.x + b * control.x + c * end.x,
                       y: a * peak.y + b * control.y + c * end.y)
    }

    private func easeOut(_ x: Double) -> Double {
        1 - pow(1 - min(max(x, 0), 1), 3)
    }

    private func easeInOut(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }

    // MARK: Card

    private var barFrom: Double {
        guard let target = reward.savingFor, target.price > 0 else { return 1 }
        return min(Double(reward.startingBalance) / Double(target.price), 1)
    }

    private var barTarget: Double {
        guard let target = reward.savingFor, target.price > 0 else { return 1 }
        return min(Double(reward.endingBalance) / Double(target.price), 1)
    }

    private var isReadyToBuy: Bool {
        guard let target = reward.savingFor else { return false }
        return reward.endingBalance >= target.price
    }

    private var breakdown: String {
        reward.bonusCoins > 0
            ? "\(reward.baseCoins) for today's goal + \(reward.bonusCoins) streak bonus"
            : "\(reward.baseCoins) for today's goal"
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let unlock = reward.newUnlocks.first {
                HStack(spacing: 14) {
                    Circle()
                        .fill(unlock.color)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 1))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New unlock!")
                            .font(.title3.weight(.heavy))
                        Text("\(unlock.displayName.capitalized), earned with a \(unlock.streakRequirement ?? 0)-day streak")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Button("Try it on") { onOpenShop() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.sipOcean)
            } else if let target = reward.savingFor {
                HStack(alignment: .firstTextBaseline) {
                    Text(isReadyToBuy ? "Ready to buy!" : "+\(reward.totalCoins) coins")
                        .font(.title3.weight(.heavy))
                    Spacer()
                    Text("\(min(reward.endingBalance, target.price)) / \(target.price)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(Color.sipGoldText)
                }
                Text(isReadyToBuy
                     ? "You have enough for the \(target.displayName)."
                     : "Saving for: \(target.displayName.capitalized)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProgressView(value: barProgress)
                    .tint(Color.sipGold)
                    .scaleEffect(x: 1, y: 1.6, anchor: .center)
                Text(breakdown)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if isReadyToBuy {
                    Button("Open shop") { onOpenShop() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.sipOcean)
                }
            } else {
                Text("+\(reward.totalCoins) coins")
                    .font(.title3.weight(.heavy))
                Text("You own every item in the shop.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 16, y: 6)
    }
}
