import SwiftUI
import SwiftData
import UserNotifications

@main
struct HydrometerApp: App {
    // App-lifetime services. Both are @Observable and injected via the environment.
    @State private var auth = AuthService()
    @State private var cap = SmartCapManager()

    init() {
        // Without this, iOS hides notifications while the app is open.
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(cap)
        }
        .modelContainer(for: [UserProfile.self, WaterLog.self, StreakRecord.self, Friend.self])
    }
}
