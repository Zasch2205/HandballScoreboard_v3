import Combine
@preconcurrency import Foundation

// Definiert die beiden möglichen Mannschaftsseiten.
enum Team: String, CaseIterable, Codable {
    case home
    case away

    var label: String {
        switch self {
        case .home:
            return "Heim"
        case .away:
            return "Gast"
        }
    }
}

// Einzelnes Tor-Ereignis für Timeline, Anzeige und Persistenz.
struct GoalEntry: Identifiable, Equatable, Codable {
    let id: UUID
    let team: Team
    let player: String
    let minute: String
    let time: String

    init(id: UUID = UUID(), team: Team, player: String, minute: String, time: String) {
        self.id = id
        self.team = team
        self.player = player
        self.minute = minute
        self.time = time
    }
}

// Typ einer disziplinarischen Aktion.
enum DisciplineType: String, Codable, CaseIterable {
    case yellowCard
    case twoMinutes
}

// Einzelnes Karten-/Strafen-Ereignis.
// Bei 2 Minuten speichern wir zusätzlich die Startsekunde für den Countdown.
struct DisciplineEntry: Identifiable, Equatable, Codable {
    let id: UUID
    let team: Team
    let player: String
    let minute: String
    let time: String
    let type: DisciplineType
    let startSecond: Int?

    init(
        id: UUID = UUID(),
        team: Team,
        player: String,
        minute: String,
        time: String,
        type: DisciplineType,
        startSecond: Int? = nil
    ) {
        self.id = id
        self.team = team
        self.player = player
        self.minute = minute
        self.time = time
        self.type = type
        self.startSecond = startSecond
    }
}

// Validierungsfehler rund um Rückennummern.
enum GoalValidationError: LocalizedError {
    case missingPlayerNumber
    case invalidPlayerNumber

    var errorDescription: String? {
        switch self {
        case .missingPlayerNumber:
            return "Bitte Rückennummer eingeben."
        case .invalidPlayerNumber:
            return "Bitte eine gültige Rückennummer (1–2 Ziffern) eingeben."
        }
    }
}

// Validierungsfehler beim Umbenennen von Mannschaften.
enum TeamRenameValidationError: LocalizedError {
    case invalidTeamName

    var errorDescription: String? {
        switch self {
        case .invalidTeamName:
            return "Bitte einen gültigen Teamnamen eingeben."
        }
    }
}

@MainActor
/// Zentrale Zustands- und Logikschicht für das Scoreboard.
///
/// Das ViewModel kapselt:
/// - Spielzustand (Tore, Karten, Uhr, Teamnamen)
/// - abgeleitete Darstellungen für die UI
/// - Persistenz und Wiederherstellung
final class ScoreboardViewModel: ObservableObject {
    // MARK: - Published State

    @Published var goals: [GoalEntry] = [] {
        didSet {
            recalculateDerivedState()
        }
    }
    @Published var disciplineEntries: [DisciplineEntry] = [] {
        didSet {
            recalculateDerivedState()
        }
    }
    @Published var elapsedSeconds = 0
    @Published var isRunning = false
    @Published private(set) var homeTeamName = Team.home.label
    @Published private(set) var awayTeamName = Team.away.label
    @Published private(set) var shouldShowRestorePrompt = false

    // MARK: - Supporting Types

    // Historischer Typ für die frühere zweispaltige Tor-Ansicht.
    typealias GoalPair = (home: GoalEntry?, away: GoalEntry?)

    // Laufende 2-Minuten-Strafe inkl. verbleibender Zeit.
    struct ActiveTwoMinutePenalty: Identifiable, Equatable {
        let id: UUID
        let team: Team
        let player: String
        let remainingSeconds: Int

        var remainingClock: String {
            let safeSeconds = max(0, remainingSeconds)
            let minutes = String(format: "%02d", safeSeconds / 60)
            let seconds = String(format: "%02d", safeSeconds % 60)
            return "\(minutes):\(seconds)"
        }
    }

    // Einheitliches Ereignismodell für das zentrale Match-Log (UI-Timeline).
    struct MatchLogEntry: Identifiable, Equatable {
        enum Kind: Equatable {
            case goal
            case yellowCard
            case twoMinutes
        }

        let id: UUID
        let team: Team
        let player: String
        let minute: String
        let time: String
        let kind: Kind
    }

    // Persistiertes Datenformat in UserDefaults.
    // `decodeIfPresent` sorgt für Abwärtskompatibilität bei älteren Speicherständen.
    private struct PersistedState: Codable {
        let goals: [GoalEntry]
        let disciplineEntries: [DisciplineEntry]
        let elapsedSeconds: Int
        let isRunning: Bool
        let homeTeamName: String
        let awayTeamName: String

        private enum CodingKeys: String, CodingKey {
            case goals
            case disciplineEntries
            case elapsedSeconds
            case isRunning
            case homeTeamName
            case awayTeamName
        }

        init(
            goals: [GoalEntry],
            disciplineEntries: [DisciplineEntry],
            elapsedSeconds: Int,
            isRunning: Bool,
            homeTeamName: String,
            awayTeamName: String
        ) {
            self.goals = goals
            self.disciplineEntries = disciplineEntries
            self.elapsedSeconds = elapsedSeconds
            self.isRunning = isRunning
            self.homeTeamName = homeTeamName
            self.awayTeamName = awayTeamName
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            goals = try container.decode([GoalEntry].self, forKey: .goals)
            disciplineEntries = try container.decodeIfPresent([DisciplineEntry].self, forKey: .disciplineEntries) ?? []
            elapsedSeconds = try container.decode(Int.self, forKey: .elapsedSeconds)
            isRunning = try container.decode(Bool.self, forKey: .isRunning)
            homeTeamName = try container.decodeIfPresent(String.self, forKey: .homeTeamName) ?? Team.home.label
            awayTeamName = try container.decodeIfPresent(String.self, forKey: .awayTeamName) ?? Team.away.label
        }
    }

    // Vorgecachter Zustand für UI-Anzeigen, die aus Rohdaten berechnet werden.
    // So müssen wir nicht bei jedem Render teuer neu rechnen.
    private struct DerivedState {
        let homeScore: Int
        let awayScore: Int
        let homeDisplayScore: Int
        let awayDisplayScore: Int
        let pairedGoals: [GoalPair]
        let matchLogEntries: [MatchLogEntry]
        let homeYellowCards: Int
        let awayYellowCards: Int
        let homeTwoMinutePenalties: Int
        let awayTwoMinutePenalties: Int

        static let empty = DerivedState(
            homeScore: 0,
            awayScore: 0,
            homeDisplayScore: 0,
            awayDisplayScore: 0,
            pairedGoals: [],
            matchLogEntries: [],
            homeYellowCards: 0,
            awayYellowCards: 0,
            homeTwoMinutePenalties: 0,
            awayTwoMinutePenalties: 0
        )
    }

    // MARK: - Configuration

    // Schutzgrenzen für Speichergröße, Eingaben und Zeitbereiche.
    private static let persistedStateKey = "handballscoreboard.ipad.state.v1"
    private static let maxStoredGoals = 500
    private static let maxStoredDisciplineEntries = 500
    private static let maxPersistedDataBytes = 2_000_000
    private static let maxElapsedSeconds = 86_399
    private static let maxMinuteLabel = (maxElapsedSeconds / 60) + 1
    private static let maxTeamNameLength = 24
    private static let penaltyDurationSeconds = 120

    private let userDefaults: UserDefaults
    private let persistenceQueue = DispatchQueue(label: "com.handballscoreboard.persistence", qos: .utility)
    private var timerCancellable: AnyCancellable?
    private var derivedState = DerivedState.empty

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        restoreState()
        recalculateDerivedState()

        // 1s-Timer für die Spieluhr.
        // Persistenz nur periodisch, um Schreiblast niedrig zu halten.
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                guard isRunning else { return }

                let nextElapsedSeconds = min(elapsedSeconds + 1, Self.maxElapsedSeconds)
                elapsedSeconds = nextElapsedSeconds

                if nextElapsedSeconds >= Self.maxElapsedSeconds {
                    isRunning = false
                    persistNow()
                    return
                }

                if nextElapsedSeconds.isMultiple(of: 15) {
                    persistNow()
                }
            }
    }

    // MARK: - Derived Public State

    var clock: String {
        Self.formatClock(elapsedSeconds)
    }

    var homeScore: Int {
        derivedState.homeScore
    }

    var awayScore: Int {
        derivedState.awayScore
    }

    var homeDisplayScore: Int {
        derivedState.homeDisplayScore
    }

    var awayDisplayScore: Int {
        derivedState.awayDisplayScore
    }

    var pairedGoals: [GoalPair] {
        derivedState.pairedGoals
    }

    var matchLogEntries: [MatchLogEntry] {
        derivedState.matchLogEntries
    }

    var homeYellowCards: Int {
        derivedState.homeYellowCards
    }

    var awayYellowCards: Int {
        derivedState.awayYellowCards
    }

    var homeTwoMinutePenalties: Int {
        derivedState.homeTwoMinutePenalties
    }

    var awayTwoMinutePenalties: Int {
        derivedState.awayTwoMinutePenalties
    }

    // Liefert nur aktive (noch nicht abgelaufene) 2-Minuten-Strafen.
    // Sortierung: zuerst die Strafe, die als Nächstes endet.
    var activeTwoMinutePenalties: [ActiveTwoMinutePenalty] {
        disciplineEntries
            .compactMap { entry -> ActiveTwoMinutePenalty? in
                guard entry.type == .twoMinutes, let startSecond = entry.startSecond else {
                    return nil
                }

                let elapsed = max(0, elapsedSeconds - startSecond)
                let remainingSeconds = Self.penaltyDurationSeconds - elapsed

                guard remainingSeconds > 0 else {
                    return nil
                }

                return ActiveTwoMinutePenalty(
                    id: entry.id,
                    team: entry.team,
                    player: entry.player,
                    remainingSeconds: remainingSeconds
                )
            }
            .sorted { lhs, rhs in
                lhs.remainingSeconds < rhs.remainingSeconds
            }
    }

    // MARK: - Public Actions

    func teamName(for team: Team) -> String {
        switch team {
        case .home:
            return homeTeamName
        case .away:
            return awayTeamName
        }
    }

    // Spieluhr pausieren/fortsetzen.
    func toggleRunning() {
        isRunning.toggle()
        persistNow()
    }

    // Nur Uhr zurücksetzen; Tore/Karten bleiben erhalten.
    func resetClock() {
        isRunning = false
        elapsedSeconds = 0
        persistNow()
    }

    // Vollständiger Spiel-Reset.
    func resetMatch() {
        goals = []
        disciplineEntries = []
        isRunning = false
        elapsedSeconds = 0
        persistNow()
    }

    // Neues Tor validieren, anlegen und vorne in die Liste einfügen.
    func addGoal(playerNumber: String, team: Team) -> String? {
        let trimmed = playerNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return GoalValidationError.missingPlayerNumber.localizedDescription
        }

        guard Self.isValidPlayerNumber(trimmed) else {
            return GoalValidationError.invalidPlayerNumber.localizedDescription
        }

        let entry = GoalEntry(
            team: team,
            player: trimmed,
            minute: Self.minuteLabel(elapsedSeconds),
            time: clock
        )

        goals.insert(entry, at: 0)

        if goals.count > Self.maxStoredGoals {
            goals.removeLast(goals.count - Self.maxStoredGoals)
        }

        persistNow()
        return nil
    }

    func addYellowCard(playerNumber: String, team: Team) -> String? {
        addDiscipline(playerNumber: playerNumber, team: team, type: .yellowCard)
    }

    func addTwoMinutePenalty(playerNumber: String, team: Team) -> String? {
        addDiscipline(playerNumber: playerNumber, team: team, type: .twoMinutes)
    }

    func deleteGoal(goalID: UUID) {
        goals.removeAll { $0.id == goalID }
        persistNow()
    }

    func deleteDisciplineEntry(entryID: UUID) {
        disciplineEntries.removeAll { $0.id == entryID }
        persistNow()
    }

    // Teamnamen werden vor dem Speichern bereinigt.
    func renameTeam(_ team: Team, to newName: String) -> String? {
        guard let sanitizedName = Self.sanitizeTeamName(newName) else {
            return TeamRenameValidationError.invalidTeamName.localizedDescription
        }

        switch team {
        case .home:
            guard homeTeamName != sanitizedName else { return nil }
            homeTeamName = sanitizedName
        case .away:
            guard awayTeamName != sanitizedName else { return nil }
            awayTeamName = sanitizedName
        }

        persistNow()
        return nil
    }

    func resetTeamNames() {
        let defaultHomeName = Team.home.label
        let defaultAwayName = Team.away.label

        guard homeTeamName != defaultHomeName || awayTeamName != defaultAwayName else {
            return
        }

        homeTeamName = defaultHomeName
        awayTeamName = defaultAwayName
        persistNow()
    }

    func goalDeleteConfirmationText(_ goal: GoalEntry) -> String {
        "Tor von \(teamName(for: goal.team)) (Spieler \(goal.player.paddedPlayerNumber), \(goal.time)) wirklich löschen?"
    }

    func disciplineDeleteConfirmationText(_ entry: DisciplineEntry) -> String {
        let entryTypeLabel: String

        switch entry.type {
        case .yellowCard:
            entryTypeLabel = "Gelbe Karte"
        case .twoMinutes:
            entryTypeLabel = "2 Minuten"
        }

        return "\(entryTypeLabel) von \(teamName(for: entry.team)) (Spieler \(entry.player.paddedPlayerNumber), \(entry.time)) wirklich löschen?"
    }

    // Persistiert den aktuellen Zustand sofort.
    func persistNow() {
        saveState(
            goals: goals,
            disciplineEntries: disciplineEntries,
            elapsedSeconds: elapsedSeconds,
            isRunning: isRunning,
            homeTeamName: homeTeamName,
            awayTeamName: awayTeamName
        )
    }

    // Restore-Dialog: bestehendes Spiel fortsetzen.
    func continueRecoveredSession() {
        shouldShowRestorePrompt = false
    }

    // Restore-Dialog: gespeicherten Stand verwerfen und neu starten.
    func startNewSessionFromRestorePrompt() {
        resetMatch()
        shouldShowRestorePrompt = false
        persistNow()
    }

    // MARK: - Internal State Updates

    // Gemeinsame Logik für gelbe Karten und 2-Minuten-Strafen.
    private func addDiscipline(playerNumber: String, team: Team, type: DisciplineType) -> String? {
        let trimmed = playerNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return GoalValidationError.missingPlayerNumber.localizedDescription
        }

        guard Self.isValidPlayerNumber(trimmed) else {
            return GoalValidationError.invalidPlayerNumber.localizedDescription
        }

        let entry = DisciplineEntry(
            team: team,
            player: trimmed,
            minute: Self.minuteLabel(elapsedSeconds),
            time: clock,
            type: type,
            startSecond: type == .twoMinutes ? elapsedSeconds : nil
        )

        disciplineEntries.insert(entry, at: 0)

        if disciplineEntries.count > Self.maxStoredDisciplineEntries {
            disciplineEntries.removeLast(disciplineEntries.count - Self.maxStoredDisciplineEntries)
        }

        persistNow()
        return nil
    }

    // Berechnet alle abgeleiteten Anzeigen (Scores, Zähler, Timeline) neu.
    // Wird automatisch ausgelöst, sobald `goals` oder `disciplineEntries` geändert werden.
    private func recalculateDerivedState() {
        var homeGoals: [GoalEntry] = []
        homeGoals.reserveCapacity(goals.count)

        var awayGoals: [GoalEntry] = []
        awayGoals.reserveCapacity(goals.count)

        var homeScorers = Set<String>()
        var awayScorers = Set<String>()

        for goal in goals {
            switch goal.team {
            case .home:
                homeGoals.append(goal)
                homeScorers.insert(goal.player)
            case .away:
                awayGoals.append(goal)
                awayScorers.insert(goal.player)
            }
        }

        var homeYellowCards = 0
        var awayYellowCards = 0
        var homeTwoMinutePenalties = 0
        var awayTwoMinutePenalties = 0

        for entry in disciplineEntries {
            switch (entry.team, entry.type) {
            case (.home, .yellowCard):
                homeYellowCards += 1
            case (.away, .yellowCard):
                awayYellowCards += 1
            case (.home, .twoMinutes):
                homeTwoMinutePenalties += 1
            case (.away, .twoMinutes):
                awayTwoMinutePenalties += 1
            }
        }

        let homeScore = homeGoals.count
        let awayScore = awayGoals.count

        var goalPairs: [GoalPair] = []
        goalPairs.reserveCapacity(max(homeGoals.count, awayGoals.count))

        for index in 0..<max(homeGoals.count, awayGoals.count) {
            goalPairs.append((
                home: index < homeGoals.count ? homeGoals[index] : nil,
                away: index < awayGoals.count ? awayGoals[index] : nil
            ))
        }

        let matchLogEntries = Self.buildMatchLogEntries(goals: goals, disciplineEntries: disciplineEntries)

        derivedState = DerivedState(
            homeScore: homeScore,
            awayScore: awayScore,
            homeDisplayScore: homeScore * homeScorers.count,
            awayDisplayScore: awayScore * awayScorers.count,
            pairedGoals: goalPairs,
            matchLogEntries: matchLogEntries,
            homeYellowCards: homeYellowCards,
            awayYellowCards: awayYellowCards,
            homeTwoMinutePenalties: homeTwoMinutePenalties,
            awayTwoMinutePenalties: awayTwoMinutePenalties
        )
    }

    // MARK: - Persistence

    // Lädt den gespeicherten Zustand, validiert ihn und entscheidet,
    // ob ein Wiederherstellen-Dialog angezeigt werden soll.
    private func restoreState() {
        guard let data = userDefaults.data(forKey: Self.persistedStateKey) else {
            return
        }

        guard data.count <= Self.maxPersistedDataBytes else {
            userDefaults.removeObject(forKey: Self.persistedStateKey)
            return
        }

        let decoder = JSONDecoder()

        guard let state = try? decoder.decode(PersistedState.self, from: data) else {
            userDefaults.removeObject(forKey: Self.persistedStateKey)
            return
        }

        let sanitizedGoals = sanitizeGoals(state.goals)
        let sanitizedDisciplineEntries = sanitizeDisciplineEntries(state.disciplineEntries)
        let sanitizedElapsedSeconds = Self.clampElapsedSeconds(state.elapsedSeconds)
        let sanitizedIsRunning = state.isRunning

        homeTeamName = Self.sanitizeTeamName(state.homeTeamName) ?? Team.home.label
        awayTeamName = Self.sanitizeTeamName(state.awayTeamName) ?? Team.away.label

        let hasMeaningfulSavedSession =
            !sanitizedGoals.isEmpty ||
            !sanitizedDisciplineEntries.isEmpty ||
            sanitizedElapsedSeconds > 0 ||
            sanitizedIsRunning

        guard hasMeaningfulSavedSession else {
            return
        }

        goals = sanitizedGoals
        disciplineEntries = sanitizedDisciplineEntries
        elapsedSeconds = sanitizedElapsedSeconds
        isRunning = sanitizedIsRunning
        shouldShowRestorePrompt = true
    }

    // Serialisiert den Zustand im Hintergrund und schreibt ihn atomar in UserDefaults.
    private func saveState(
        goals: [GoalEntry],
        disciplineEntries: [DisciplineEntry],
        elapsedSeconds: Int,
        isRunning: Bool,
        homeTeamName: String,
        awayTeamName: String
    ) {
        let persistedStateKey = Self.persistedStateKey
        let maxPersistedDataBytes = Self.maxPersistedDataBytes

        let state = PersistedState(
            goals: Array(goals.prefix(Self.maxStoredGoals)),
            disciplineEntries: Array(disciplineEntries.prefix(Self.maxStoredDisciplineEntries)),
            elapsedSeconds: Self.clampElapsedSeconds(elapsedSeconds),
            isRunning: isRunning,
            homeTeamName: homeTeamName,
            awayTeamName: awayTeamName
        )

        let userDefaults = self.userDefaults

        persistenceQueue.async {
            let encoder = JSONEncoder()

            guard let data = try? encoder.encode(state), data.count <= maxPersistedDataBytes else {
                return
            }

            userDefaults.set(data, forKey: persistedStateKey)
        }
    }

    // MARK: - Sanitizing

    // Defensives Filtern geladener Tore (z. B. nach App-Updates oder Datenkorruption).
    private func sanitizeGoals(_ rawGoals: [GoalEntry]) -> [GoalEntry] {
        var sanitizedGoals: [GoalEntry] = []
        sanitizedGoals.reserveCapacity(min(rawGoals.count, Self.maxStoredGoals))

        for goal in rawGoals {
            guard
                Self.isValidPlayerNumber(goal.player),
                Self.isValidMinuteLabel(goal.minute),
                Self.isValidClock(goal.time)
            else {
                continue
            }

            sanitizedGoals.append(goal)

            if sanitizedGoals.count >= Self.maxStoredGoals {
                break
            }
        }

        return sanitizedGoals
    }

    // Defensives Filtern geladener Karten-/Straf-Einträge.
    private func sanitizeDisciplineEntries(_ rawEntries: [DisciplineEntry]) -> [DisciplineEntry] {
        var sanitizedEntries: [DisciplineEntry] = []
        sanitizedEntries.reserveCapacity(min(rawEntries.count, Self.maxStoredDisciplineEntries))

        for entry in rawEntries {
            guard
                Self.isValidPlayerNumber(entry.player),
                Self.isValidMinuteLabel(entry.minute),
                Self.isValidClock(entry.time)
            else {
                continue
            }

            switch entry.type {
            case .yellowCard:
                sanitizedEntries.append(
                    DisciplineEntry(
                        id: entry.id,
                        team: entry.team,
                        player: entry.player,
                        minute: entry.minute,
                        time: entry.time,
                        type: .yellowCard,
                        startSecond: nil
                    )
                )
            case .twoMinutes:
                guard let startSecond = entry.startSecond, (0...Self.maxElapsedSeconds).contains(startSecond) else {
                    continue
                }

                sanitizedEntries.append(
                    DisciplineEntry(
                        id: entry.id,
                        team: entry.team,
                        player: entry.player,
                        minute: entry.minute,
                        time: entry.time,
                        type: .twoMinutes,
                        startSecond: startSecond
                    )
                )
            }

            if sanitizedEntries.count >= Self.maxStoredDisciplineEntries {
                break
            }
        }

        return sanitizedEntries
    }

    private static func clampElapsedSeconds(_ seconds: Int) -> Int {
        min(max(0, seconds), maxElapsedSeconds)
    }

    // Vereinheitlicht Teamnamen: Steuerzeichen raus, Whitespaces normalisieren, Länge begrenzen.
    private static func sanitizeTeamName(_ rawName: String) -> String? {
        let filteredScalars = rawName.unicodeScalars.filter { scalar in
            !CharacterSet.controlCharacters.contains(scalar) || scalar.value == 32
        }

        let filtered = String(String.UnicodeScalarView(filteredScalars))

        let collapsedWhitespace = filtered
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let limited = String(collapsedWhitespace.prefix(maxTeamNameLength))

        guard !limited.isEmpty else {
            return nil
        }

        return limited
    }

    // MARK: - Timeline Building

    // Baut die kombinierte Timeline aus Toren + Disziplinarereignissen.
    // Sortierung: neueste Spielzeit zuerst; bei gleicher Zeit stabile Reihenfolge über Quellindex.
    private static func buildMatchLogEntries(goals: [GoalEntry], disciplineEntries: [DisciplineEntry]) -> [MatchLogEntry] {
        struct SortableMatchLogEntry {
            let entry: MatchLogEntry
            let sourceIndex: Int
            let timeInSeconds: Int
        }

        var sortableEntries: [SortableMatchLogEntry] = []
        sortableEntries.reserveCapacity(goals.count + disciplineEntries.count)

        for (index, goal) in goals.enumerated() {
            sortableEntries.append(
                SortableMatchLogEntry(
                    entry: MatchLogEntry(
                        id: goal.id,
                        team: goal.team,
                        player: goal.player,
                        minute: goal.minute,
                        time: goal.time,
                        kind: .goal
                    ),
                    sourceIndex: index,
                    timeInSeconds: parseClockToSeconds(goal.time)
                )
            )
        }

        for (index, disciplineEntry) in disciplineEntries.enumerated() {
            sortableEntries.append(
                SortableMatchLogEntry(
                    entry: MatchLogEntry(
                        id: disciplineEntry.id,
                        team: disciplineEntry.team,
                        player: disciplineEntry.player,
                        minute: disciplineEntry.minute,
                        time: disciplineEntry.time,
                        kind: disciplineEntry.type == .yellowCard ? .yellowCard : .twoMinutes
                    ),
                    sourceIndex: index,
                    timeInSeconds: parseClockToSeconds(disciplineEntry.time)
                )
            )
        }

        return sortableEntries
            .sorted { lhs, rhs in
                if lhs.timeInSeconds != rhs.timeInSeconds {
                    return lhs.timeInSeconds > rhs.timeInSeconds
                }

                if lhs.sourceIndex != rhs.sourceIndex {
                    return lhs.sourceIndex < rhs.sourceIndex
                }

                return lhs.entry.id.uuidString > rhs.entry.id.uuidString
            }
            .map(\.entry)
    }

    // Wandelt die Anzeige "MM:SS" in Sekunden um (für Sortierung/Logik).
    private static func parseClockToSeconds(_ clock: String) -> Int {
        let components = clock.split(separator: ":", omittingEmptySubsequences: false)

        guard
            components.count == 2,
            let minutes = Int(components[0]),
            let seconds = Int(components[1]),
            (0...59).contains(seconds)
        else {
            return 0
        }

        return (minutes * 60) + seconds
    }

    // MARK: - Validation & Formatting

    // Zulässig sind 1-2 Ziffern.
    private static func isValidPlayerNumber(_ number: String) -> Bool {
        let digitCount = number.count
        return (1...2).contains(digitCount) && number.allSatisfy(\.isNumber)
    }

    // Erwartet Format MM:SS (min. 2 Stellen für Minuten, exakt 2 für Sekunden).
    private static func isValidClock(_ clock: String) -> Bool {
        let components = clock.split(separator: ":", omittingEmptySubsequences: false)

        guard components.count == 2 else {
            return false
        }

        let minutesPart = String(components[0])
        let secondsPart = String(components[1])

        guard
            (2...4).contains(minutesPart.count),
            minutesPart.allSatisfy(\.isNumber),
            secondsPart.count == 2,
            secondsPart.allSatisfy(\.isNumber),
            let seconds = Int(secondsPart),
            (0...59).contains(seconds)
        else {
            return false
        }

        return true
    }

    // Erwartet Minutenlabel wie "1'", "12'" usw.
    private static func isValidMinuteLabel(_ label: String) -> Bool {
        guard label.hasSuffix("'") else {
            return false
        }

        let digits = String(label.dropLast())

        guard
            (1...4).contains(digits.count),
            digits.allSatisfy(\.isNumber),
            let minute = Int(digits),
            (1...maxMinuteLabel).contains(minute)
        else {
            return false
        }

        return true
    }

    // Formatiert rohe Sekunden als Anzeigeuhr.
    private static func formatClock(_ totalSeconds: Int) -> String {
        let safeSeconds = clampElapsedSeconds(totalSeconds)
        let minutes = String(format: "%02d", safeSeconds / 60)
        let seconds = String(format: "%02d", safeSeconds % 60)
        return "\(minutes):\(seconds)"
    }

    // Im Handball beginnt die Minute bei 1' statt 0'.
    private static func minuteLabel(_ totalSeconds: Int) -> String {
        "\((clampElapsedSeconds(totalSeconds) / 60) + 1)'"
    }
}

// MARK: - Utilities

private extension String {
    // Für Anzeigezwecke aus "3" -> "03".
    var paddedPlayerNumber: String {
        count == 1 ? "0\(self)" : self
    }
}
