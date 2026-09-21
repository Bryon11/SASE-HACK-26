import SwiftUI
import UserNotifications

struct ReminderSettingsView: View {
    let viewModel: DashboardViewModel
    @Bindable private var profile: UserProfile
    @State private var permission: UNAuthorizationStatus = .notDetermined
    @State private var testQueued = false
    @Environment(\.openURL) private var openURL

    init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
        _profile = Bindable(viewModel.profile)
    }

    private var preview: (title: String, body: String) {
        ReminderPlanner.todayMessage(todayTotal: viewModel.todayTotal, goal: viewModel.dailyGoal)
    }

    var body: some View {
        Form {
            Section {
                Toggle("Remind me to drink", isOn: Binding(
                    get: { profile.remindersEnabled },
                    set: { newValue in Task { await setEnabled(newValue) } }
                ))
            } footer: {
                Text("Each reminder tells you exactly how much is left. They stop for the day once you hit your goal, and skip if you drank in the last 20 minutes.")
            }

            if permission == .denied {
                Section {
                    Label("Notifications are turned off for Hydrometer.", systemImage: "bell.slash")
                    Button("Open iPhone Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
            }

            if profile.remindersEnabled {
                Section {
                    ForEach(profile.reminderMinutes.indices, id: \.self) { index in
                        DatePicker(selection: timeBinding(at: index), displayedComponents: .hourAndMinute) {
                            Label("Reminder \(index + 1)", systemImage: "bell")
                        }
                    }
                    .onDelete { offsets in
                        profile.reminderMinutes.remove(atOffsets: offsets)
                    }

                    if profile.reminderMinutes.count < ReminderPlanner.maxTimesPerDay {
                        Button("Add a time", systemImage: "plus.circle.fill", action: addTime)
                    }
                } header: {
                    Text("Times")
                } footer: {
                    Text("Swipe left on a time to delete it.")
                }

                Section("Quick setups") {
                    Button("4 times a day") {
                        profile.reminderMinutes = ReminderPlanner.defaultTimes
                    }
                    Button("Every 2 hours, 9 AM to 7 PM") {
                        profile.reminderMinutes = Array(stride(from: 9 * 60, through: 19 * 60, by: 120))
                    }
                    Button("Every hour, 9 AM to 8 PM") {
                        profile.reminderMinutes = Array(stride(from: 9 * 60, through: 20 * 60, by: 60))
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preview.title).font(.subheadline.weight(.semibold))
                        Text(preview.body).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    Button(testQueued ? "Arriving in 5 seconds…" : "Send a test notification") {
                        Task { await sendTest() }
                    }
                    .disabled(testQueued)
                } header: {
                    Text("A reminder right now would say")
                }
            }
        }
        .navigationTitle("Reminders")
        .task { permission = await ReminderScheduler.authorizationStatus() }
        .onDisappear {
            profile.reminderMinutes = Array(Set(profile.reminderMinutes)).sorted()
            viewModel.refresh() // reschedules with the new times
        }
    }

    // MARK: Actions

    private func setEnabled(_ enabled: Bool) async {
        if enabled {
            guard await ensurePermission() else {
                profile.remindersEnabled = false
                return
            }
            if profile.reminderMinutes.isEmpty {
                profile.reminderMinutes = ReminderPlanner.defaultTimes
            }
            profile.remindersEnabled = true
        } else {
            profile.remindersEnabled = false
            ReminderScheduler.clearAll()
        }
    }

    private func ensurePermission() async -> Bool {
        var status = await ReminderScheduler.authorizationStatus()
        if status == .notDetermined {
            _ = await ReminderScheduler.requestPermission()
            status = await ReminderScheduler.authorizationStatus()
        }
        permission = status
        return status == .authorized || status == .provisional || status == .ephemeral
    }

    private func sendTest() async {
        guard await ensurePermission() else { return }
        let message = preview
        await ReminderScheduler.sendTest(title: message.title, body: message.body)
        testQueued = true
        try? await Task.sleep(for: .seconds(6))
        testQueued = false
    }

    private func addTime() {
        let latest = profile.reminderMinutes.max() ?? (10 * 60)
        var candidate = min(latest + 120, 22 * 60)
        while profile.reminderMinutes.contains(candidate) && candidate < 23 * 60 + 45 {
            candidate += 15
        }
        profile.reminderMinutes.append(candidate)
    }

    private func timeBinding(at index: Int) -> Binding<Date> {
        Binding(
            get: {
                let minutes = profile.reminderMinutes.indices.contains(index) ? profile.reminderMinutes[index] : 12 * 60
                return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
            },
            set: { date in
                guard profile.reminderMinutes.indices.contains(index) else { return }
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                profile.reminderMinutes[index] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}
