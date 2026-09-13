import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = ScoreboardViewModel()

    @State private var isGoalSheetOpen = false
    @State private var isEditScoreSheetOpen = false
    @State private var showResetMatchConfirmation = false
    @State private var showRestorePrompt = false

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 20) {
                topBar
                scoreSection
                goalLogSection
                controlsSection
            }
            .padding(24)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    quickGoalButton
                }
            }
            .padding(.trailing, 28)
            .padding(.bottom, 28)
        }
        .sheet(isPresented: $isGoalSheetOpen) {
            GoalEntrySheet { playerNumber, team in
                do {
                    try viewModel.addGoal(playerNumber: playerNumber, team: team)
                    isGoalSheetOpen = false
                } catch {
                    throw error
                }
            }
        }
        .sheet(isPresented: $isEditScoreSheetOpen) {
            EditScoreSheet(
                goals: viewModel.goals,
                deleteConfirmationText: viewModel.goalDeleteConfirmationText(_:),
                onDelete: { goal in
                    viewModel.deleteGoal(goalID: goal.id)
                }
            )
        }
        .confirmationDialog(
            "Spiel wirklich zurücksetzen? Spielstand, Tore und Uhr werden gelöscht.",
            isPresented: $showResetMatchConfirmation,
            titleVisibility: .visible
        ) {
            Button("Spiel zurücksetzen", role: .destructive) {
                viewModel.resetMatch()
                isGoalSheetOpen = false
                isEditScoreSheetOpen = false
            }
            Button("Abbrechen", role: .cancel) {}
        }
        .alert("Gespeichertes Spiel gefunden", isPresented: $showRestorePrompt) {
            Button("Spiel fortsetzen") {
                viewModel.continueRecoveredSession()
            }
            Button("Neues Spiel", role: .destructive) {
                viewModel.startNewSessionFromRestorePrompt()
            }
        } message: {
            Text("Möchtest du das zuletzt gespeicherte Spiel fortsetzen oder ein neues Spiel starten?")
        }
        .onAppear {
            showRestorePrompt = viewModel.shouldShowRestorePrompt
        }
        .onChange(of: viewModel.shouldShowRestorePrompt) { _, newValue in
            showRestorePrompt = newValue
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                viewModel.persistNow()
            }
        }
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [Color(red: 0.04, green: 0.07, blue: 0.14), Color(red: 0.07, green: 0.11, blue: 0.20)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            Text("Handball Scoreboard")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Text(viewModel.clock)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
                )
                .foregroundStyle(Color(red: 0.55, green: 0.91, blue: 1.0))
        }
    }

    private var scoreSection: some View {
        HStack(alignment: .center, spacing: 16) {
            TeamScoreCard(
                title: "Heim",
                displayScore: viewModel.homeDisplayScore,
                actualScore: viewModel.homeScore
            )

            Text(":")
                .font(.system(size: 72, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 0.52, green: 0.66, blue: 1.0))
                .frame(maxWidth: 50)

            TeamScoreCard(
                title: "Gast",
                displayScore: viewModel.awayDisplayScore,
                actualScore: viewModel.awayScore
            )
        }
    }

    private var goalLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.goals.isEmpty {
                Text("noch keine Tore gefallen")
                    .font(.headline)
                    .foregroundStyle(Color.white.opacity(0.75))
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(viewModel.pairedGoals.enumerated()), id: \.offset) { _, row in
                            HStack(spacing: 10) {
                                GoalCell(goal: row.home)
                                GoalCell(goal: row.away)
                            }
                        }
                    }
                    .padding(14)
                }
                .frame(maxHeight: 280)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var controlsSection: some View {
        HStack(spacing: 12) {
            Button(viewModel.isRunning ? "Pause" : "Start") {
                viewModel.toggleRunning()
            }
            .buttonStyle(PrimaryActionButtonStyle(color: viewModel.isRunning ? Color(red: 0.1, green: 0.15, blue: 0.25) : Color.green))

            Button("Uhr Reset") {
                viewModel.resetClock()
            }
            .buttonStyle(SecondaryActionButtonStyle())

            Button("Spiel Reset") {
                showResetMatchConfirmation = true
            }
            .buttonStyle(PrimaryActionButtonStyle(color: Color.red))

            Button("Spielstand bearbeiten") {
                isEditScoreSheetOpen = true
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
    }

    private var quickGoalButton: some View {
        Button {
            isGoalSheetOpen = true
        } label: {
            Text("🤾")
                .font(.system(size: 34))
                .frame(width: 88, height: 88)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.19, green: 0.51, blue: 1.0), Color(red: 0.08, green: 0.34, blue: 0.88)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                .shadow(color: Color.blue.opacity(0.45), radius: 12, x: 0, y: 6)
        }
        .accessibilityLabel("Tor erfassen")
    }
}

private struct TeamScoreCard: View {
    let title: String
    let displayScore: Int
    let actualScore: Int

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Spielstand")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(Color.yellow)

            Text("\(displayScore)")
                .font(.system(size: 72, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.yellow)

            Text("Tore")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(Color.red.opacity(0.9))

            Text("\(actualScore)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.red.opacity(0.95))
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct GoalCell: View {
    let goal: GoalEntry?

    var body: some View {
        VStack(alignment: .leading) {
            if let goal {
                Text("Spieler \(goal.player.paddedPlayerNumber) trifft in \(goal.time)")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
            } else {
                Text(" ")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct GoalEntrySheet: View {
    let onAddGoal: (_ playerNumber: String, _ team: Team) throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var playerNumber = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rückennummer Torschütze")
                        .font(.headline)
                    TextField("z. B. 7", text: $playerNumber)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: playerNumber) { _, newValue in
                            playerNumber = String(newValue.filter { $0.isNumber }.prefix(2))
                        }
                }

                HStack(spacing: 12) {
                    Button("Tor Heim") {
                        addGoal(team: .home)
                    }
                    .buttonStyle(PrimaryActionButtonStyle(color: Color.blue))

                    Button("Tor Gast") {
                        addGoal(team: .away)
                    }
                    .buttonStyle(PrimaryActionButtonStyle(color: Color.cyan))
                }

                Button("Abbrechen") {
                    dismiss()
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Spacer()
            }
            .padding(20)
            .navigationTitle("Tor erfassen")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Hinweis", isPresented: Binding(
                get: { errorMessage != nil },
                set: { _ in errorMessage = nil }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.medium])
    }

    private func addGoal(team: Team) {
        do {
            try onAddGoal(playerNumber, team)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct EditScoreSheet: View {
    let goals: [GoalEntry]
    let deleteConfirmationText: (GoalEntry) -> String
    let onDelete: (GoalEntry) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var pendingDeleteGoal: GoalEntry?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                if goals.isEmpty {
                    Text("noch keine Tore vorhanden")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundStyle(.secondary)
                } else {
                    List(goals) { goal in
                        HStack {
                            Text("\(goal.team.label) · Spieler \(goal.player.paddedPlayerNumber) · \(goal.time)")
                                .font(.body)
                            Spacer()
                            Button {
                                pendingDeleteGoal = goal
                            } label: {
                                Image(systemName: "trash")
                                    .font(.title3)
                            }
                            .buttonStyle(.borderless)
                            .tint(.red)
                        }
                    }
                    .listStyle(.plain)
                }

                Button("OK") {
                    dismiss()
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Spielstand bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                pendingDeleteGoal.map(deleteConfirmationText) ?? "",
                isPresented: Binding(
                    get: { pendingDeleteGoal != nil },
                    set: { shouldShow in
                        if !shouldShow {
                            pendingDeleteGoal = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button("Tor löschen", role: .destructive) {
                    if let pendingDeleteGoal {
                        onDelete(pendingDeleteGoal)
                    }
                    pendingDeleteGoal = nil
                }
                Button("Abbrechen", role: .cancel) {
                    pendingDeleteGoal = nil
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(configuration.isPressed ? 0.8 : 1.0))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(red: 0.1, green: 0.15, blue: 0.25).opacity(configuration.isPressed ? 0.8 : 1.0))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
    }
}

private extension String {
    var paddedPlayerNumber: String {
        count == 1 ? "0\(self)" : self
    }
}

#Preview {
    ContentView()
}
