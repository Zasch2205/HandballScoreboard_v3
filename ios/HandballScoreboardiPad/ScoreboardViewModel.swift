import Combine
import Foundation

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

@MainActor
final class ScoreboardViewModel: ObservableObject {
    @Published var goals: [GoalEntry] = []
    @Published var elapsedSeconds = 0
    @Published var isRunning = false
    @Published private(set) var shouldShowRestorePrompt = false

    private struct PersistedState: Codable {
        let goals: [GoalEntry]
        let elapsedSeconds: Int
        let isRunning: Bool
    }

    private static let persistedStateKey = "handballscoreboard.ipad.state.v1"

    private let userDefaults: UserDefaults
    private var timerCancellable: AnyCancellable?
    private var persistenceCancellable: AnyCancellable?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        restoreState()

        persistenceCancellable = Publishers.CombineLatest3(
            $goals.removeDuplicates(),
            $elapsedSeconds.removeDuplicates(),
            $isRunning.removeDuplicates()
        )
        .dropFirst()
        .sink { [weak self] goals, elapsedSeconds, isRunning in
            self?.saveState(goals: goals, elapsedSeconds: elapsedSeconds, isRunning: isRunning)
        }

        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if isRunning {
                    elapsedSeconds += 1
                }
            }
    }

    var clock: String {
        Self.formatClock(elapsedSeconds)
    }

    var homeScore: Int {
        goals.filter { $0.team == .home }.count
    }

    var awayScore: Int {
        goals.filter { $0.team == .away }.count
    }

    var homeScorersCount: Int {
        Set(goals.filter { $0.team == .home }.map { $0.player }).count
    }

    var awayScorersCount: Int {
        Set(goals.filter { $0.team == .away }.map { $0.player }).count
    }

    var homeDisplayScore: Int {
        homeScore * homeScorersCount
    }

    var awayDisplayScore: Int {
        awayScore * awayScorersCount
    }

    var pairedGoals: [(home: GoalEntry?, away: GoalEntry?)] {
        let homeGoals = goals.filter { $0.team == .home }
        let awayGoals = goals.filter { $0.team == .away }

        return (0..<max(homeGoals.count, awayGoals.count)).map { index in
            (
                home: index < homeGoals.count ? homeGoals[index] : nil,
                away: index < awayGoals.count ? awayGoals[index] : nil
            )
        }
    }

    func toggleRunning() {
        isRunning.toggle()
    }

    func resetClock() {
        isRunning = false
        elapsedSeconds = 0
    }

    func resetMatch() {
        goals = []
        isRunning = false
        elapsedSeconds = 0
    }

    func addGoal(playerNumber: String, team: Team) throws {
        let trimmed = playerNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw GoalValidationError.missingPlayerNumber
        }

        let numberRegex = try NSRegularExpression(pattern: "^\\\\d{1,2}$")
        let range = NSRange(location: 0, length: trimmed.utf16.count)

        guard numberRegex.firstMatch(in: trimmed, options: [], range: range) != nil else {
            throw GoalValidationError.invalidPlayerNumber
        }

        let entry = GoalEntry(
            team: team,
            player: trimmed,
            minute: Self.minuteLabel(elapsedSeconds),
            time: clock
        )

        goals.insert(entry, at: 0)
    }

    func deleteGoal(goalID: UUID) {
        goals.removeAll { $0.id == goalID }
    }

    func goalDeleteConfirmationText(_ goal: GoalEntry) -> String {
        "Tor von \(goal.team.label) (Spieler \(goal.player.paddedPlayerNumber), \(goal.time)) wirklich löschen?"
    }

    func persistNow() {
        saveState(goals: goals, elapsedSeconds: elapsedSeconds, isRunning: isRunning)
    }

    func continueRecoveredSession() {
        shouldShowRestorePrompt = false
    }

    func startNewSessionFromRestorePrompt() {
        resetMatch()
        shouldShowRestorePrompt = false
        persistNow()
    }

    private func restoreState() {
        guard let data = userDefaults.data(forKey: Self.persistedStateKey) else {
            return
        }

        let decoder = JSONDecoder()

        guard let state = try? decoder.decode(PersistedState.self, from: data) else {
            return
        }

        let hasMeaningfulSavedSession = !state.goals.isEmpty || state.elapsedSeconds > 0 || state.isRunning

        guard hasMeaningfulSavedSession else {
            return
        }

        goals = state.goals
        elapsedSeconds = max(0, state.elapsedSeconds)
        isRunning = state.isRunning
        shouldShowRestorePrompt = true
    }

    private func saveState(goals: [GoalEntry], elapsedSeconds: Int, isRunning: Bool) {
        let state = PersistedState(
            goals: goals,
            elapsedSeconds: max(0, elapsedSeconds),
            isRunning: isRunning
        )

        let encoder = JSONEncoder()

        guard let data = try? encoder.encode(state) else {
            return
        }

        userDefaults.set(data, forKey: Self.persistedStateKey)
    }

    private static func formatClock(_ totalSeconds: Int) -> String {
        let minutes = String(format: "%02d", totalSeconds / 60)
        let seconds = String(format: "%02d", totalSeconds % 60)
        return "\(minutes):\(seconds)"
    }

    private static func minuteLabel(_ totalSeconds: Int) -> String {
        "\((totalSeconds / 60) + 1)'"
    }
}

private extension String {
    var paddedPlayerNumber: String {
        count == 1 ? "0\(self)" : self
    }
}
