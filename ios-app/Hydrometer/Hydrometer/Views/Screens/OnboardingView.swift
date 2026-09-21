import SwiftUI

/// Collects what the goal calculator needs. Edits write straight to the SwiftData model.
struct OnboardingView: View {
    @Bindable var profile: UserProfile

    private var goal: Double { HydrationGoalCalculator.recommendedGoal(for: profile) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 6) {
                        Text(goal.ozText)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.sipOcean)
                            .contentTransition(.numericText(value: goal))
                            .animation(.snappy, value: goal)
                        Text("Your daily goal")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section("About you") {
                    TextField("Name", text: $profile.displayName)
                        .textContentType(.name)
                    Stepper(value: $profile.weightLbs, in: 80...400, step: 5) {
                        LabeledContent("Weight", value: "\(Int(profile.weightLbs)) lb")
                    }
                }

                Section("Your day") {
                    Picker("Activity", selection: $profile.activityLevel) {
                        ForEach(ActivityLevel.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Climate", selection: $profile.climate) {
                        ForEach(Climate.allCases) { Text($0.label).tag($0) }
                    }
                }

                Section {
                    Button {
                        profile.hasCompletedOnboarding = true
                    } label: {
                        Text("Start tracking")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                } footer: {
                    Text("Based on about half your body weight in ounces, adjusted for activity and heat. You can change it anytime in Settings.")
                }
            }
            .navigationTitle("Set your goal")
        }
    }
}
