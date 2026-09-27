import SwiftUI

/// Hauptansicht der iPad-App.
///
/// Verantwortlich für:
/// - Darstellung von Uhr, Spielstand und Ereignis-Log
/// - Öffnen der Eingabe-/Bearbeitungsdialoge
/// - Weitergabe aller Nutzeraktionen an das `ScoreboardViewModel`
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = ScoreboardViewModel()

    @State private var isGoalSheetOpen = false
    @State private var isEditScoreSheetOpen = false
    @State private var showResetMatchConfirmation = false
    @State private var showRestorePrompt = false

    // MARK: - Layout Root

    // `GeometryReader` erlaubt uns, Safe-Area-Abstände dynamisch zu berücksichtigen.
    // Dadurch bleibt das Layout auf allen iPad-Größen stabil.
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
            GoalEntrySheet(
                homeTeamName: viewModel.homeTeamName,
                awayTeamName: viewModel.awayTeamName,
                onAddGoal: { playerNumber, team in
                    viewModel.addGoal(playerNumber: playerNumber, team: team)
                },
                onAddYellowCard: { playerNumber, team in
                    viewModel.addYellowCard(playerNumber: playerNumber, team: team)
                },
                onAddTwoMinutePenalty: { playerNumber, team in
                    viewModel.addTwoMinutePenalty(playerNumber: playerNumber, team: team)
                }
            )
        }
        .sheet(isPresented: $isEditScoreSheetOpen) {
            EditScoreSheet(
                goals: viewModel.goals,
                disciplineEntries: viewModel.disciplineEntries,
                homeTeamName: viewModel.homeTeamName,
                awayTeamName: viewModel.awayTeamName,
                teamName: viewModel.teamName(for:),
                deleteGoalConfirmationText: viewModel.goalDeleteConfirmationText(_:),
                deleteDisciplineConfirmationText: viewModel.disciplineDeleteConfirmationText(_:),
                onDeleteGoal: { goal in
                    viewModel.deleteGoal(goalID: goal.id)
                },
                onDeleteDiscipline: { entry in
                    viewModel.deleteDisciplineEntry(entryID: entry.id)
                },
                onRenameTeam: { team, name in
                    viewModel.renameTeam(team, to: name)
                },
                onResetTeamNames: {
                    viewModel.resetTeamNames()
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

    // MARK: - Main Sections

    // Hintergrund im "Glas/Licht"-Look: Bild + dunkle Overlays + zwei weiche Lichtkreise.
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

    // Kopfzeile mit Titel und Uhr. `ViewThatFits` wechselt automatisch in ein
    // vertikales Layout, falls horizontal nicht genug Platz vorhanden ist.
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

    // Uhr-Container oben rechts.
    // Zeigt immer die Hauptspielzeit und optional die aktuell laufende 2-Minuten-Strafe.
    private var clockChip: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(viewModel.clock)
                .font(.system(size: 42, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 0.55, green: 0.91, blue: 1.0))

            if let activePenalty = viewModel.activeTwoMinutePenalties.first {
                Text("2 Min \(viewModel.teamName(for: activePenalty.team)) #\(activePenalty.player.paddedPlayerNumber): \(activePenalty.remainingClock)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.orange.opacity(0.95))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if viewModel.activeTwoMinutePenalties.count > 1 {
                    Text("+\(viewModel.activeTwoMinutePenalties.count - 1) weitere")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.75))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
        )
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
    }

    // Die beiden Team-Karten mit aktuellem Stand.
    // Auch hier sorgt `ViewThatFits` für einen sauberen Fallback bei weniger Platz.
    private var scoreSection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                TeamScoreCard(
                    title: viewModel.homeTeamName,
                    displayScore: viewModel.homeDisplayScore,
                    actualScore: viewModel.homeScore
                )

                Text(":")
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.52, green: 0.66, blue: 1.0))
                    .frame(width: 44)

                TeamScoreCard(
                    title: viewModel.awayTeamName,
                    displayScore: viewModel.awayDisplayScore,
                    actualScore: viewModel.awayScore
                )
            }

            VStack(spacing: 12) {
                TeamScoreCard(
                    title: viewModel.homeTeamName,
                    displayScore: viewModel.homeDisplayScore,
                    actualScore: viewModel.homeScore
                )

                Text(":")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.52, green: 0.66, blue: 1.0))

                TeamScoreCard(
                    title: viewModel.awayTeamName,
                    displayScore: viewModel.awayDisplayScore,
                    actualScore: viewModel.awayScore
                )
            }
        }
    }

    // Zentrales Ereignisfeld unter dem Spielstand:
    // Tore, gelbe Karten und 2-Minuten-Strafen in einer gemeinsamen Timeline.
    private var goalLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.matchLogEntries.isEmpty {
                Text("noch keine Ereignisse")
                    .font(.headline)
                    .foregroundStyle(Color.white.opacity(0.75))
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.matchLogEntries) { event in
                            MatchLogRow(
                                event: event,
                                teamName: viewModel.teamName(for:)
                            )
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

    // Primäre Steuerung für Uhr/Reset/Bearbeitung.
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

                Button("Bearbeiten") {
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

                    Button("Bearbeiten") {
                        isEditScoreSheetOpen = true
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
    }

    // Floating Action Button zum schnellen Öffnen der Eingabemaske.
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

// MARK: - Reusable Subviews

// Kompakte Anzeige einer Mannschaft im oberen Spielstand.
private struct TeamScoreCard: View {
    let title: String
    let displayScore: Int
    let actualScore: Int

    // MARK: - UI

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .allowsTightening(true)

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

// Einzelne Zeile im mittleren Ereignis-Log.
// Heim-Ereignisse werden links, Gast-Ereignisse rechts angeordnet.
private struct MatchLogRow: View {
    let event: ScoreboardViewModel.MatchLogEntry
    let teamName: (Team) -> String

    // MARK: - Derived State

    private var isHomeEvent: Bool {
        event.team == .home
    }

    private var accentColor: Color {
        switch event.kind {
        case .goal:
            return Color(red: 0.22, green: 0.7, blue: 1.0)
        case .yellowCard:
            return Color.yellow.opacity(0.95)
        case .twoMinutes:
            return Color.orange.opacity(0.95)
        }
    }

    private var iconName: String {
        switch event.kind {
        case .goal:
            return "soccerball"
        case .yellowCard:
            return "rectangle.portrait.fill"
        case .twoMinutes:
            return "timer"
        }
    }

    private var headline: String {
        switch event.kind {
        case .goal:
            return "Spieler \(event.player.paddedPlayerNumber) hat ein Tor erzielt"
        case .yellowCard:
            return "Spieler \(event.player.paddedPlayerNumber) hat eine gelbe Karte bekommen"
        case .twoMinutes:
            return "Spieler \(event.player.paddedPlayerNumber) hat eine 2-Minuten-Strafe bekommen"
        }
    }

    // MARK: - Helper Views

    private var eventIcon: some View {
        Image(systemName: iconName)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(accentColor)
            .frame(width: 20, height: 20)
    }

    private var eventText: some View {
        VStack(alignment: isHomeEvent ? .leading : .trailing, spacing: 4) {
            Text(headline)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .multilineTextAlignment(isHomeEvent ? .leading : .trailing)

            Text("\(teamName(event.team)) · \(event.minute) · \(event.time)")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.72))
                .multilineTextAlignment(isHomeEvent ? .leading : .trailing)
        }
    }

    // MARK: - UI

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isHomeEvent {
                eventIcon
                eventText
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                eventText
                eventIcon
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// Eingabedialog für Tore, gelbe Karten und 2-Minuten-Strafen.
private struct GoalEntrySheet: View {
    let homeTeamName: String
    let awayTeamName: String
    let onAddGoal: (_ playerNumber: String, _ team: Team) -> String?
    let onAddYellowCard: (_ playerNumber: String, _ team: Team) -> String?
    let onAddTwoMinutePenalty: (_ playerNumber: String, _ team: Team) -> String?

    @Environment(\.dismiss) private var dismiss

    @State private var playerNumber = ""
    @State private var errorMessage: String?
    @State private var pendingDisciplineType: DisciplineType?
    @FocusState private var isPlayerNumberFocused: Bool

    // MARK: - Derived State

    private var sanitizedPlayerNumber: String {
        // Nur Ziffern zulassen und auf zwei Zeichen begrenzen.
        String(playerNumber.filter { $0.isNumber }.prefix(2))
    }

    private var canSubmitEntry: Bool {
        !sanitizedPlayerNumber.isEmpty
    }

    // MARK: - UI

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

                    HStack {
                        Button("OK") {
                            isPlayerNumberFocused = false
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.1, green: 0.15, blue: 0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Spacer(minLength: 0)
                    }
                }

                HStack(spacing: 12) {
                    Button("Tor \(homeTeamName)") {
                        addGoal(team: .home)
                    }
                    .buttonStyle(PrimaryActionButtonStyle(color: Color.blue))
                    .disabled(!canSubmitEntry)

                    Button("Tor \(awayTeamName)") {
                        addGoal(team: .away)
                    }
                    .buttonStyle(PrimaryActionButtonStyle(color: Color.cyan))
                    .disabled(!canSubmitEntry)
                }

                HStack(spacing: 12) {
                    Button("Gelbe Karte") {
                        requestDiscipline(type: .yellowCard)
                    }
                    .buttonStyle(PrimaryActionButtonStyle(color: Color.yellow.opacity(0.9)))
                    .disabled(!canSubmitEntry)

                    Button("2 Minuten") {
                        requestDiscipline(type: .twoMinutes)
                    }
                    .buttonStyle(PrimaryActionButtonStyle(color: Color.orange))
                    .disabled(!canSubmitEntry)
                }

                HStack(spacing: 12) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Tor erfassen")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                DispatchQueue.main.async {
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
            .confirmationDialog(
                "Für welches Team?",
                isPresented: Binding(
                    get: { pendingDisciplineType != nil },
                    set: { shouldShow in
                        if !shouldShow {
                            pendingDisciplineType = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button(homeTeamName) {
                    submitDiscipline(team: .home)
                }
                Button(awayTeamName) {
                    submitDiscipline(team: .away)
                }
                Button("Abbrechen", role: .cancel) {
                    pendingDisciplineType = nil
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func addGoal(team: Team) {
        // Vor dem Absenden nochmals die sanitierte Nummer verwenden,
        // damit auch bei manuell eingefügten Zeichen nur gültige Daten ankommen.
        playerNumber = sanitizedPlayerNumber

        if let message = onAddGoal(playerNumber, team) {
            errorMessage = message
            return
        }

        dismiss()
    }

    private func requestDiscipline(type: DisciplineType) {
        // Zuerst Nummer fixieren, dann Teamauswahl-Dialog öffnen.
        playerNumber = sanitizedPlayerNumber
        isPlayerNumberFocused = false
        pendingDisciplineType = type
    }

    private func submitDiscipline(team: Team) {
        guard let pendingDisciplineType else {
            return
        }

        playerNumber = sanitizedPlayerNumber

        let message: String?

        // Je nach gewählter Disziplin den passenden ViewModel-Aufruf verwenden.
        switch pendingDisciplineType {
        case .yellowCard:
            message = onAddYellowCard(playerNumber, team)
        case .twoMinutes:
            message = onAddTwoMinutePenalty(playerNumber, team)
        }

        self.pendingDisciplineType = nil

        if let message {
            errorMessage = message
            return
        }

        dismiss()
    }
}

// Dialog zum nachträglichen Bearbeiten:
// Einträge löschen, Teamnamen ändern, Teamnamen zurücksetzen.
private struct EditScoreSheet: View {
    let goals: [GoalEntry]
    let disciplineEntries: [DisciplineEntry]
    let homeTeamName: String
    let awayTeamName: String
    let teamName: (Team) -> String
    let deleteGoalConfirmationText: (GoalEntry) -> String
    let deleteDisciplineConfirmationText: (DisciplineEntry) -> String
    let onDeleteGoal: (GoalEntry) -> Void
    let onDeleteDiscipline: (DisciplineEntry) -> Void
    let onRenameTeam: (_ team: Team, _ name: String) -> String?
    let onResetTeamNames: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var pendingDeleteItem: PendingDeleteItem?
    @State private var renameTargetTeam: Team?
    @State private var pendingTeamName = ""
    @State private var renameErrorMessage: String?

    private enum PendingDeleteItem {
        case goal(GoalEntry)
        case discipline(DisciplineEntry)
    }

    // MARK: - Derived State

    private var hasAnyEntries: Bool {
        !goals.isEmpty || !disciplineEntries.isEmpty
    }

    private var pendingDeleteText: String {
        // Einheitliche Löschabfrage unabhängig vom Eintragstyp.
        guard let pendingDeleteItem else {
            return ""
        }

        switch pendingDeleteItem {
        case .goal(let goal):
            return deleteGoalConfirmationText(goal)
        case .discipline(let entry):
            return deleteDisciplineConfirmationText(entry)
        }
    }

    private var renameAlertTitle: String {
        switch renameTargetTeam {
        case .home:
            return "Heim umbenennen"
        case .away:
            return "Gast umbenennen"
        case nil:
            return "Team umbenennen"
        }
    }

    // MARK: - UI

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                if !hasAnyEntries {
                    Text("noch keine Einträge vorhanden")
                        .frame(maxWidth: .infinity, minHeight: 220)
                        .foregroundStyle(.secondary)
                } else {
                    List {
                        if !goals.isEmpty {
                            Section("Tore") {
                                ForEach(goals) { goal in
                                    HStack {
                                        Text("\(teamName(goal.team)) · Spieler \(goal.player.paddedPlayerNumber) · \(goal.time)")
                                            .font(.body)
                                        Spacer()
                                        Button {
                                            pendingDeleteItem = .goal(goal)
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.title3)
                                        }
                                        .buttonStyle(.borderless)
                                        .tint(.red)
                                    }
                                }
                            }
                        }

                        if !disciplineEntries.isEmpty {
                            Section("Karten / Strafen") {
                                ForEach(disciplineEntries) { entry in
                                    HStack {
                                        Text("\(teamName(entry.team)) · \(disciplineTypeLabel(entry.type)) · Spieler \(entry.player.paddedPlayerNumber) · \(entry.time)")
                                            .font(.body)
                                        Spacer()
                                        Button {
                                            pendingDeleteItem = .discipline(entry)
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.title3)
                                        }
                                        .buttonStyle(.borderless)
                                        .tint(.red)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .frame(minHeight: 220)
                }

                HStack(spacing: 12) {
                    renameTeamCard(title: "Heim", currentName: homeTeamName, team: .home)
                    renameTeamCard(title: "Gast", currentName: awayTeamName, team: .away)
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)

                Button("Teamnamen zurücksetzen") {
                    onResetTeamNames()
                }
                .buttonStyle(SecondaryActionButtonStyle())

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
                pendingDeleteText,
                isPresented: Binding(
                    get: { pendingDeleteItem != nil },
                    set: { shouldShow in
                        if !shouldShow {
                            pendingDeleteItem = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button("Eintrag löschen", role: .destructive) {
                    applyDelete()
                }
                Button("Abbrechen", role: .cancel) {
                    pendingDeleteItem = nil
                }
            }
            .alert(renameAlertTitle, isPresented: Binding(
                get: { renameTargetTeam != nil },
                set: { shouldShow in
                    if !shouldShow {
                        cancelTeamRename()
                    }
                }
            )) {
                TextField("Vereinsname", text: $pendingTeamName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)

                Button("Umbenennen") {
                    applyTeamRename()
                }

                Button("Abbrechen", role: .cancel) {
                    cancelTeamRename()
                }
            } message: {
                Text("Bitte den neuen Vereinsnamen eingeben.")
            }
            .alert("Hinweis", isPresented: Binding(
                get: { renameErrorMessage != nil },
                set: { _ in renameErrorMessage = nil }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(renameErrorMessage ?? "")
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Actions

    private func applyTeamRename() {
        guard let renameTargetTeam else {
            return
        }

        if let message = onRenameTeam(renameTargetTeam, pendingTeamName) {
            renameErrorMessage = message
            return
        }

        cancelTeamRename()
    }

    private func cancelTeamRename() {
        renameTargetTeam = nil
        pendingTeamName = ""
    }

    private func applyDelete() {
        guard let pendingDeleteItem else {
            return
        }

        switch pendingDeleteItem {
        case .goal(let goal):
            onDeleteGoal(goal)
        case .discipline(let entry):
            onDeleteDiscipline(entry)
        }

        self.pendingDeleteItem = nil
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func renameTeamCard(title: String, currentName: String, team: Team) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            Text(currentName)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Button("Umbenennen") {
                renameTargetTeam = team
                pendingTeamName = currentName
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func disciplineTypeLabel(_ type: DisciplineType) -> String {
        switch type {
        case .yellowCard:
            return "Gelbe Karte"
        case .twoMinutes:
            return "2 Minuten"
        }
    }
}

// MARK: - Button Styles

// Primärer, farbiger Aktionsbutton (Start, Reset etc.).
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

// Sekundärer Button-Stil für neutrale Aktionen.
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

// MARK: - Utilities

private extension String {
    // Vereinheitlichte Darstellung der Rückennummer als 2-stellige Anzeige.
    var paddedPlayerNumber: String {
        count == 1 ? "0\(self)" : self
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
