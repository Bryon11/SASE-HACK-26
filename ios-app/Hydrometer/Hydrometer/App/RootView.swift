import SwiftUI
import SwiftData
import UIKit

/// Routes between splash, sign-in, onboarding and the main app.
/// Signing in plays the "dive into the bottle" transition: the cap twists off,
/// the sign-in screen zooms into the bottle, water floods the screen, the next
/// screen is swapped in underneath, and the water drains away to reveal it.
struct RootView: View {
    @Environment(AuthService.self) private var auth

    /// What's on screen. Trails `auth.state` so the swap can hide under the water.
    @State private var shown: AuthService.State = .checking
    @State private var signInDiving = false
    @State private var waterVisible = false
    @State private var waterDrained = false

    var body: some View {
        ZStack {
            Group {
                switch shown {
                case .checking:
                    SplashView()
                case .signedOut:
                    SignInView(isDiving: signInDiving)
                case .signedIn(let userID):
                    SignedInRootView(userID: userID)
                        .id(userID) // fresh view tree per account
                }
            }
            .transition(.opacity)

            if waterVisible {
                WaterCurtainView(drained: waterDrained)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task { await auth.restoreSession() }
        .onChange(of: auth.state) { oldState, newState in
            Task { await transition(from: oldState, to: newState) }
        }
    }

    private func transition(from old: AuthService.State, to new: AuthService.State) async {
        switch (old, new) {
        case (.signedOut, .signedIn):
            await dive(into: new)
        case (.checking, .signedIn):
            await quickReveal(of: new)
        default:
            withAnimation(.easeInOut(duration: 0.35)) { shown = new }
        }
    }

    /// Full version, about 1.5 seconds, after tapping sign in or demo mode.
    private func dive(into state: AuthService.State) async {
        signInDiving = true // cap twists off, buttons fade, zoom starts
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        try? await Task.sleep(for: .seconds(0.6))

        withAnimation(.easeIn(duration: 0.35)) { waterVisible = true }
        try? await Task.sleep(for: .seconds(0.45))

        shown = state // swapped while the water covers everything
        signInDiving = false
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        try? await Task.sleep(for: .seconds(0.2))

        withAnimation(.easeIn(duration: 0.65)) { waterDrained = true }
        try? await Task.sleep(for: .seconds(0.7))
        waterVisible = false
        waterDrained = false
    }

    /// Short version on launch when you're already signed in.
    private func quickReveal(of state: AuthService.State) async {
        withAnimation(.easeIn(duration: 0.2)) { waterVisible = true }
        try? await Task.sleep(for: .seconds(0.22))
        shown = state
        try? await Task.sleep(for: .seconds(0.1))
        withAnimation(.easeIn(duration: 0.5)) { waterDrained = true }
        try? await Task.sleep(for: .seconds(0.55))
        waterVisible = false
        waterDrained = false
    }
}

/// Loads (or creates) the SwiftData profile for the signed-in Apple ID.
struct SignedInRootView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    private let userID: String

    init(userID: String) {
        self.userID = userID
        _profiles = Query(filter: #Predicate<UserProfile> { $0.appleUserID == userID })
    }

    var body: some View {
        Group {
            if let profile = profiles.first {
                if profile.hasCompletedOnboarding {
                    MainContainerView(profile: profile)
                } else {
                    OnboardingView(profile: profile)
                }
            } else {
                ProgressView()
            }
        }
        .task { ensureProfile() }
    }

    private func ensureProfile() {
        // Apple only sends name/email the FIRST time a user authorizes the app,
        // so capture them now or they're gone.
        let info = auth.consumeFreshSignInInfo()

        if let existing = profiles.first {
            if existing.displayName.isEmpty, let name = info?.displayName { existing.displayName = name }
            if existing.email == nil, let email = info?.email { existing.email = email }
            return
        }

        let profile = UserProfile(
            appleUserID: userID,
            displayName: info?.displayName ?? "",
            email: info?.email
        )
        context.insert(profile)
        try? context.save()
    }
}

/// Owns the DashboardViewModel so it's created exactly once per session.
/// (Creating it inside a view's init would re-create it on every parent redraw
/// and silently break the cap's onSip callback.)
struct MainContainerView: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var context
    @Environment(SmartCapManager.self) private var cap
    @State private var viewModel: DashboardViewModel?

    var body: some View {
        Group {
            if let viewModel {
                MainTabView(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = DashboardViewModel(context: context, profile: profile, cap: cap)
            }
            cap.startLive() // no-op in simulator mode
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.sipDeep.ignoresSafeArea()
            Image(systemName: "drop.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.sipAqua)
        }
    }
}
