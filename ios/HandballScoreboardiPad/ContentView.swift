import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = ScoreboardViewModel()

    @State private var isGoalSheetOpen = false
    @State private var isEditScoreSheetOpen = false
    @State private var showResetMatchConfirmation = false
    @State private var showRestorePrompt = false

    var body: some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets

            ZStack {
                backgroundLayer

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        topBar
                        scoreSection
                        goalLogSection
                        controlsSection
                    }
                    .padding(.top, insets.top + 20)
                    .padding(.leading, 20)
                    .padding(.trailing, max(24, insets.trailing + 92))
                    .padding(.bottom, 120)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                quickGoalButton
                    .padding(.trailing, insets.trailing + 120)
                    .padding(.bottom, insets.bottom + 40)
            }
        }
        .sheet(isPresented: $isGoalSheetOpen) {
            GoalEntrySheet { playerNumber, team in
                viewModel.addGoal(playerNumber: playerNumber, team: team)
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
        ZStack {
            Image("BackgroundPhoto")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .contrast(1.28)
                .saturation(0.88)
                .brightness(-0.28)

            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.03, blue: 0.06).opacity(0.9),
                    Color(red: 0.03, green: 0.05, blue: 0.1).opacity(0.83),
                    Color(red: 0.02, green: 0.03, blue: 0.06).opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 0.11, green: 0.19, blue: 0.37).opacity(0.22),
                    .clear
                ],
                center: .topLeading,
                startRadius: 40,
                endRadius: 640
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 0.0, green: 0.83, blue: 1.0).opacity(0.12),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 740
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(red: 0.16, green: 0.47, blue: 1.0).opacity(0.18))
                .frame(width: 420, height: 420)
                .blur(radius: 80)
                .offset(x: -220, y: -260)

            Circle()
                .fill(Color(red: 0.0, green: 0.9, blue: 1.0).opacity(0.14))
                .frame(width: 460, height: 460)
                .blur(radius: 86)
                .offset(x: 260, y: 290)
        }
    }

    private var topBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                Text("Handball Scoreboard")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .allowsTightening(true)

                Spacer(minLength: 8)
                clockChip
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 12) {
                Text("Handball Scoreboard")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .allowsTightening(true)

                HStack {
                    Spacer(minLength: 0)
                    clockChip
                }
            }
        }
    }

    private var clockChip: some View {
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
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)
    }

    private var scoreSection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                TeamScoreCard(
                    title: "Heim",
                    displayScore: viewModel.homeDisplayScore,
                    actualScore: viewModel.homeScore
                )

                Text(":")
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.52, green: 0.66, blue: 1.0))
                    .frame(width: 44)

                TeamScoreCard(
                    title: "Gast",
                    displayScore: viewModel.awayDisplayScore,
                    actualScore: viewModel.awayScore
                )
            }

            VStack(spacing: 12) {
                TeamScoreCard(
                    title: "Heim",
                    displayScore: viewModel.homeDisplayScore,
                    actualScore: viewModel.homeScore
                )

                Text(":")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.52, green: 0.66, blue: 1.0))

                TeamScoreCard(
                    title: "Gast",
                    displayScore: viewModel.awayDisplayScore,
                    actualScore: viewModel.awayScore
                )
            }
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
        ViewThatFits(in: .horizontal) {
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

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button(viewModel.isRunning ? "Pause" : "Start") {
                        viewModel.toggleRunning()
                    }
                    .buttonStyle(PrimaryActionButtonStyle(color: viewModel.isRunning ? Color(red: 0.1, green: 0.15, blue: 0.25) : Color.green))

                    Button("Uhr Reset") {
                        viewModel.resetClock()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }

                HStack(spacing: 12) {
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
    let onAddGoal: (_ playerNumber: String, _ team: Team) -> String?

    @Environment(\.dismiss) private var dismiss

    @State private var playerNumber = ""
    @State private var errorMessage: String?
    @FocusState private var isPlayerNumberFocused: Bool

    private var sanitizedPlayerNumber: String {
        String(playerNumber.filter { $0.isNumber }.prefix(2))
    }

    private var canSubmitGoal: Bool {
        !sanitizedPlayerNumber.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rückennummer Torschütze")
                        .font(.headline)
                    TextField("z. B. 7", text: $playerNumber)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .textFieldStyle(.roundedBorder)
                        .focused($isPlayerNumberFocused)
                        .onChange(of: playerNumber) { _, newValue in
                            playerNumber = String(newValue.filter { $0.isNumber }.prefix(2))
                        }
                }

                HStack(spacing: 12) {
                    Button("Tor Heim") {
                        addGoal(team: .home)
                    }
                    .buttonStyle(PrimaryActionButtonStyle(color: Color.blue))
                    .disabled(!canSubmitGoal)

                    Button("Tor Gast") {
                        addGoal(team: .away)
                    }
                    .buttonStyle(PrimaryActionButtonStyle(color: Color.cyan))
                    .disabled(!canSubmitGoal)
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
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPlayerNumberFocused = true
                }
            }
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
        playerNumber = sanitizedPlayerNumber

        if let message = onAddGoal(playerNumber, team) {
            errorMessage = message
            return
        }

        dismiss()
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
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .allowsTightening(true)
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
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .allowsTightening(true)
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
