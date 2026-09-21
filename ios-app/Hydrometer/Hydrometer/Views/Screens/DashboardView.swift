import SwiftUI
import Combine

struct DashboardView: View {
    let viewModel: DashboardViewModel
    /// Lets the home screen jump to another tab.
    var onSelectTab: (HydroTab) -> Void = { _ in }

    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings = false
    @State private var showDemoDrawer = false
    @State private var dismissedAlertID: String?

    // Coin animation plumbing
    @State private var capFrame: CGRect = .zero
    @State private var counterFrame: CGRect = .zero
    @State private var rewardCapOpen = false
    @State private var counterOverride: Int?
    @State private var counterBump = 0

    /// During the reward the counter counts up coin by coin instead of jumping.
    private var displayedCoins: Int {
        counterOverride ?? viewModel.pendingReward?.startingBalance ?? viewModel.coins
    }

    private var showsReward: Bool {
        viewModel.pendingReward != nil && scenePhase == .active && !showSettings
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header

                    if let alert = viewModel.cap.health.alert, dismissedAlertID != alert.id {
                        CapHealthBanner(alert: alert) {
                            withAnimation(.snappy) { dismissedAlertID = alert.id }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    HydrationBottleCard(
                        total: viewModel.todayTotal,
                        goal: viewModel.dailyGoal,
                        progress: viewModel.progress,
                        paceMessage: viewModel.paceMessage,
                        finishLine: viewModel.finishLineMessage,
                        isCapOpen: viewModel.cap.isCapOpen || rewardCapOpen,
                        style: viewModel.bottleStyle
                    )

                    statTiles

                    DayTimelineCard(logs: viewModel.todayLogs)

                    FriendsStripCard(
                        groupStreak: viewModel.groupStreak,
                        entries: viewModel.leaderboard,
                        done: viewModel.groupDoneToday,
                        total: viewModel.groupSize,
                        rank: viewModel.myRank,
                        hasFriends: !viewModel.friends.isEmpty
                    ) {
                        onSelectTab(.friends)
                    }

                    SavingForCard(coins: displayedCoins, target: viewModel.savingTarget) {
                        onSelectTab(.shop)
                    }
                }
                .padding()
            }
            .tabBarRoom()
            .onPreferenceChange(CapFrameKey.self) { capFrame = $0 }
            .onPreferenceChange(CoinCounterFrameKey.self) { counterFrame = $0 }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        HistoryView(ownerID: viewModel.profile.appleUserID, goal: viewModel.dailyGoal)
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel("History")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if viewModel.cap.mode == .simulator {
                        Button { showDemoDrawer = true } label: {
                            Image(systemName: "wand.and.stars")
                        }
                        .accessibilityLabel("Demo controls")
                    }
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings, onDismiss: { viewModel.refresh() }) {
                SettingsView(viewModel: viewModel)
            }
            .sheet(isPresented: $showDemoDrawer) {
                demoDrawer
            }
            .sensoryFeedback(.impact(weight: .light), trigger: viewModel.todayLogs.count)
            .animation(.snappy, value: viewModel.cap.health)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { viewModel.refresh() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
                viewModel.refresh() // midnight rollover: new day, streak re-evaluated
            }
        }
        .overlay {
            if let reward = viewModel.pendingReward, showsReward {
                CoinRewardView(
                    reward: reward,
                    capFrame: capFrame,
                    counterFrame: counterFrame,
                    onCapOpen: { open in rewardCapOpen = open },
                    onCoinLanded: { amount in
                        counterOverride = (counterOverride ?? reward.startingBalance) + amount
                        counterBump += 1
                    },
                    onOpenShop: {
                        finishReward()
                        onSelectTab(.shop)
                    },
                    onFinish: { finishReward() }
                )
                .id(reward.id)
                .onAppear { counterOverride = nil }
                .onDisappear { rewardCapOpen = false }
                .transition(.opacity)
            }
        }
    }

    private func finishReward() {
        counterOverride = nil
        rewardCapOpen = false
        viewModel.dismissReward()
    }

    // MARK: Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting).font(.title3.weight(.semibold))
                    Text(Date.now, format: .dateTime.weekday(.wide).month().day())
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                StreakBadgeView(current: viewModel.currentStreak, longest: viewModel.longestStreak)
                CoinCounterView(coins: displayedCoins, bumpTrigger: counterBump) {
                    onSelectTab(.shop)
                }
            }

            WeekStripView(days: viewModel.weekDays)

            CapStatusIndicator(cap: viewModel.cap)
                // Hidden shortcut: long-press the cap status to open the demo controls.
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.6).onEnded { _ in
                        if viewModel.cap.mode == .simulator { showDemoDrawer = true }
                    }
                )
        }
    }

    private var statTiles: some View {
        HStack(spacing: 10) {
            StatTile(value: viewModel.bottleRemaining.ozText,
                     label: "in bottle",
                     tint: viewModel.bottleRemaining < 4 ? .orange : .primary)
            StatTile(value: "\(viewModel.todayLogs.count)", label: "sips today")
            StatTile(value: lastSipText, label: "last sip")
        }
    }

    private var lastSipText: String {
        guard let last = viewModel.todayLogs.first?.timestamp else { return "—" }
        return last.formatted(date: .omitted, time: .shortened)
    }

    /// Simulator controls in a half-height drawer; the bottle stays visible above it.
    private var demoDrawer: some View {
        ScrollView {
            VStack(spacing: 14) {
                SimulatorPanelView(cap: viewModel.cap)

                VStack(alignment: .leading, spacing: 12) {
                    Label("Rewards", systemImage: "dollarsign.circle")
                        .font(.headline)
                    HStack {
                        Button("Replay coin reward") { viewModel.replayRewardForDemo() }
                        Button("+20 coins") { viewModel.addDemoCoins(20) }
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)

                    Button("Seed 2 weeks of history") { viewModel.seedDemoHistory() }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
            }
            .padding()
        }
        .presentationDetents([.fraction(0.42), .large])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.42)))
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let part = hour < 12 ? "Good morning" : (hour < 18 ? "Good afternoon" : "Good evening")
        if let name = viewModel.profile.firstName { return "\(part), \(name)" }
        return part
    }
}
