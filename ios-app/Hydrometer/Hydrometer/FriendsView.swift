import SwiftUI

/// The competition page: group streak, today's standings, and invites.
struct FriendsView: View {
    let viewModel: DashboardViewModel
    @State private var toast: String?

    var body: some View {
        List {
            Section {
                groupCard
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
            }

            Section("Today's standings") {
                ForEach(Array(viewModel.leaderboard.enumerated()), id: \.element.id) { index, entry in
                    row(rank: index + 1, entry: entry)
                        .swipeActions(edge: .trailing) {
                            if !entry.isMe, let friend = friend(for: entry) {
                                Button(role: .destructive) {
                                    viewModel.removeFriend(friend)
                                } label: {
                                    Label("Remove", systemImage: "person.badge.minus")
                                }
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if !entry.isMe && !entry.metGoal {
                                Button {
                                    show("Nudged \(entry.name) 💧")
                                } label: {
                                    Label("Nudge", systemImage: "hand.wave.fill")
                                }
                                .tint(Color.sipOcean)
                            }
                        }
                }
            }

            Section {
                ShareLink(item: viewModel.inviteMessage) {
                    Label("Invite a friend", systemImage: "square.and.arrow.up")
                }
                Button {
                    viewModel.addDemoFriend()
                    show("A friend joined your group")
                } label: {
                    Label("Add a demo friend", systemImage: "person.badge.plus")
                }
                LabeledContent("Your group code", value: viewModel.inviteCode)
                    .font(.subheadline.monospaced())
            } header: {
                Text("Invite")
            } footer: {
                Text("For this build, friends are simulated on your device and drink on their own while you watch. Real invites need a shared server, which is the next step.")
            }
        }
        .navigationTitle("Friends")
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(radius: 8, y: 4)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: toast)
        .task {
            // Friends keep drinking while the page is open, so the standings move live.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(6))
                guard !Task.isCancelled else { return }
                viewModel.simulateFriendSip()
            }
        }
    }

    // MARK: Pieces

    private var groupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(LinearGradient(colors: [.yellow, Color.sipEmber],
                                                    startPoint: .top, endPoint: .bottom))
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.groupStreak == 1 ? "1-day group streak" : "\(viewModel.groupStreak)-day group streak")
                        .font(.title3.weight(.heavy))
                    Text("It only counts when everyone hits their goal.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                ForEach(viewModel.leaderboard) { entry in
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .fill(entry.metGoal ? Color.sipMint.opacity(0.25) : Color.gray.opacity(0.15))
                            .frame(width: 38, height: 38)
                            .overlay(Text(entry.emoji).font(.system(size: 18)))
                        if entry.metGoal {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.sipMint)
                                .background(Circle().fill(Color(.systemBackground)))
                        }
                    }
                }
                Spacer(minLength: 0)
            }

            ProgressView(value: viewModel.groupProgressToday)
                .tint(Color.sipMint)
            Text("\(viewModel.groupDoneToday) of \(viewModel.groupSize) done today · you're #\(viewModel.myRank)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func row(rank: Int, entry: LeaderboardEntry) -> some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.subheadline.weight(.heavy).monospacedDigit())
                .foregroundStyle(rank == 1 ? Color.sipGold : .secondary)
                .frame(width: 30, alignment: .leading)

            Text(entry.emoji).font(.system(size: 22))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(entry.isMe ? "\(entry.name) (you)" : entry.name)
                        .font(.subheadline.weight(.semibold))
                    if entry.metGoal {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.sipMint)
                    }
                    Spacer(minLength: 0)
                    if entry.streak > 0 {
                        Label("\(entry.streak)", systemImage: "flame.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.sipEmber)
                    }
                }
                ProgressView(value: min(entry.progress, 1))
                    .tint(entry.isMe ? Color.sipOcean : Color.sipAqua)
                Text("\(entry.ounces.ozText) of \(entry.goal.ozText) · \(Int((entry.progress * 100).rounded()))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(entry.isMe ? Color.sipAqua.opacity(0.12) : nil)
    }

    private func friend(for entry: LeaderboardEntry) -> Friend? {
        viewModel.friends.first { $0.id.uuidString == entry.id }
    }

    private func show(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            toast = nil
        }
    }
}
