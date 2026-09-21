import SwiftUI

enum HydroTab: String, CaseIterable, Identifiable {
    case home, bottle, tree, insights, friends, shop
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .bottle: "Bottle"
        case .tree: "Tree"
        case .insights: "Insights"
        case .friends: "Friends"
        case .shop: "Shop"
        }
    }

    /// Same symbols the cards used before.
    var icon: String {
        switch self {
        case .home: "house.fill"
        case .bottle: "drop.fill"
        case .tree: "tree.fill"
        case .insights: "chart.line.uptrend.xyaxis"
        case .friends: "person.2.fill"
        case .shop: "bag.fill"
        }
    }
}

/// Bottom tab bar in the style of TikTok's: dark bar, icon over a small label,
/// white when selected and gray when not.
struct MainTabView: View {
    let viewModel: DashboardViewModel
    @State private var selection: HydroTab = .home

    /// Height of the bar's content; each screen reserves this much at the bottom.
    static let barHeight: CGFloat = 56

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selection {
                case .home:
                    DashboardView(viewModel: viewModel) { tab in selection = tab }
                case .bottle:
                    NavigationStack {
                        BottleView(viewModel: viewModel)
                            .tabBarRoom()
                    }
                case .tree:
                    NavigationStack {
                        GardenView(viewModel: viewModel)
                            .tabBarRoom()
                    }
                case .insights:
                    NavigationStack {
                        InsightsView(insights: viewModel.insights, goal: viewModel.dailyGoal)
                            .tabBarRoom()
                    }
                case .friends:
                    NavigationStack {
                        FriendsView(viewModel: viewModel)
                            .tabBarRoom()
                    }
                case .shop:
                    NavigationStack {
                        ShopView(viewModel: viewModel, showsDone: false)
                            .tabBarRoom()
                    }
                }
            }

            HydroTabBar(selection: $selection, coins: viewModel.coins)
        }
        .ignoresSafeArea(.keyboard)
        // Coins fly to the counter on the home screen, so go there for the reward.
        .onChange(of: viewModel.pendingReward?.id) { _, id in
            if id != nil { selection = .home }
        }
    }
}

struct HydroTabBar: View {
    @Binding var selection: HydroTab
    let coins: Int

    private let barColor = Color(red: 0.05, green: 0.06, blue: 0.08)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(HydroTab.allCases) { tab in
                Button {
                    guard selection != tab else { return }
                    selection = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 19, weight: .semibold))
                            .frame(height: 22)
                        Text(tab.title)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(selection == tab ? .white : Color.white.opacity(0.45))
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .overlay(alignment: .topTrailing) {
                        if tab == .shop && coins > 0 {
                            Text("\(coins)")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.sipGold, in: Capsule())
                                .offset(x: 10, y: -2)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 8)
        .background(barColor.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)
        }
        .animation(.snappy(duration: 0.2), value: selection)
    }
}

extension View {
    /// Keeps content clear of the custom tab bar. Applied inside each screen's
    /// navigation stack, because insets added outside one don't reach its scroll view.
    func tabBarRoom() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: MainTabView.barHeight)
        }
    }
}
