import SwiftUI

struct SettingsView: View {
    let viewModel: DashboardViewModel
    @Bindable private var profile: UserProfile
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
        _profile = Bindable(viewModel.profile)
    }

    private var cap: SmartCapManager { viewModel.cap }
    private var recommended: Double { HydrationGoalCalculator.recommendedGoal(for: profile) }

    private var reminderSummary: String {
        guard profile.remindersEnabled else { return "Off" }
        let count = Set(profile.reminderMinutes).count
        return count == 1 ? "1 a day" : "\(count) a day"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $profile.displayName)
                    Stepper(value: $profile.weightLbs, in: 80...400, step: 5) {
                        LabeledContent("Weight", value: "\(Int(profile.weightLbs)) lb")
                    }
                    Picker("Activity", selection: $profile.activityLevel) {
                        ForEach(ActivityLevel.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Climate", selection: $profile.climate) {
                        ForEach(Climate.allCases) { Text($0.label).tag($0) }
                    }
                }

                Section {
                    LabeledContent("Recommended", value: recommended.ozText)
                    Toggle("Set my own goal", isOn: Binding(
                        get: { profile.customGoalOz != nil },
                        set: { profile.customGoalOz = $0 ? recommended : nil }
                    ))
                    if let custom = profile.customGoalOz {
                        Stepper(value: Binding(get: { custom }, set: { profile.customGoalOz = $0 }),
                                in: 32...200, step: 4) {
                            LabeledContent("Daily goal", value: custom.ozText)
                        }
                    }
                } header: {
                    Text("Daily goal")
                } footer: {
                    Text("Changing your goal affects today and future days. Days already counted toward your streak stay counted.")
                }

                Section("Reminders") {
                    NavigationLink {
                        ReminderSettingsView(viewModel: viewModel)
                    } label: {
                        LabeledContent {
                            Text(reminderSummary)
                        } label: {
                            Label("Hydration reminders", systemImage: "bell.badge")
                        }
                    }
                }

                Section("Smart cap") {
                    Picker("Source", selection: Binding(get: { cap.mode }, set: { cap.setMode($0) })) {
                        ForEach(SmartCapManager.Mode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    LabeledContent("Status", value: cap.connectionState.label)
                    if cap.mode == .live {
                        Button("Forget this cap and search again") { cap.forgetDevice() }
                    }
                }

                Section {
                    Button("Sign out", role: .destructive) {
                        cap.stopAutoDemo()
                        ReminderScheduler.clearAll()
                        dismiss()
                        auth.signOut()
                    }
                } footer: {
                    if let email = profile.email { Text("Signed in as \(email)") }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
