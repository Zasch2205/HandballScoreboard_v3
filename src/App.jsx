import { useEffect, useMemo, useState } from "react";
import "./App.css";

function formatClock(totalSeconds) {
  const minutes = Math.floor(totalSeconds / 60)
    .toString()
    .padStart(2, "0");
  const seconds = (totalSeconds % 60).toString().padStart(2, "0");
  return `${minutes}:${seconds}`;
}

function getMinuteLabel(totalSeconds) {
  const minute = Math.floor(totalSeconds / 60) + 1;
  return `${minute}'`;
}

function createGoalId() {
  return `goal-${Date.now()}-${Math.floor(Math.random() * 1000000)}`;
}

export default function App() {
  const [modalPlayerNumber, setModalPlayerNumber] = useState("");
  const [isGoalModalOpen, setIsGoalModalOpen] = useState(false);
  const [isEditScoreModalOpen, setIsEditScoreModalOpen] = useState(false);
  const [goals, setGoals] = useState([]);

  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const [isRunning, setIsRunning] = useState(false);

  useEffect(() => {
    if (!isRunning) return;

    const timer = setInterval(() => {
      setElapsedSeconds((prev) => prev + 1);
    }, 1000);

    return () => clearInterval(timer);
  }, [isRunning]);

  const clock = useMemo(() => formatClock(elapsedSeconds), [elapsedSeconds]);

  const homeScore = useMemo(
    () => goals.filter((goal) => goal.team === "home").length,
    [goals]
  );
  const awayScore = useMemo(
    () => goals.filter((goal) => goal.team === "away").length,
    [goals]
  );

  const homeScorersCount = useMemo(
    () => new Set(goals.filter((goal) => goal.team === "home").map((goal) => goal.player)).size,
    [goals]
  );

  const awayScorersCount = useMemo(
    () => new Set(goals.filter((goal) => goal.team === "away").map((goal) => goal.player)).size,
    [goals]
  );

  const homeDisplayScore = homeScore * homeScorersCount;
  const awayDisplayScore = awayScore * awayScorersCount;

  const homeGoals = useMemo(
    () => goals.filter((goal) => goal.team === "home"),
    [goals]
  );
  const awayGoals = useMemo(
    () => goals.filter((goal) => goal.team === "away"),
    [goals]
  );

  const pairedGoals = useMemo(() => {
    const maxLength = Math.max(homeGoals.length, awayGoals.length);
    return Array.from({ length: maxLength }, (_, index) => ({
      home: homeGoals[index] ?? null,
      away: awayGoals[index] ?? null,
    }));
  }, [homeGoals, awayGoals]);

  const openGoalModal = () => {
    setModalPlayerNumber("");
    setIsGoalModalOpen(true);
  };

  const closeGoalModal = () => {
    setModalPlayerNumber("");
    setIsGoalModalOpen(false);
  };

  const addGoalFromModal = (team) => {
    const trimmed = String(modalPlayerNumber ?? "").trim();

    if (!trimmed) {
      alert("Bitte Rückennummer eingeben.");
      return;
    }

    if (!/^\d{1,2}$/.test(trimmed)) {
      alert("Bitte eine gültige Rückennummer (1–2 Ziffern) eingeben.");
      return;
    }

    const entry = {
      id: createGoalId(),
      team,
      player: trimmed,
      minute: getMinuteLabel(elapsedSeconds),
      time: clock,
    };

    try {
      setGoals((prev) => [entry, ...prev]);
      closeGoalModal();
    } catch (error) {
      alert("Tor konnte nicht gespeichert werden. Bitte erneut versuchen.");
    }
  };

  const resetClock = () => {
    setIsRunning(false);
    setElapsedSeconds(0);
  };

  const resetMatch = () => {
    const confirmed = window.confirm(
      "Spiel wirklich zurücksetzen? Spielstand, Tore und Uhr werden gelöscht."
    );
    if (!confirmed) return;

    setGoals([]);
    setIsRunning(false);
    setElapsedSeconds(0);
    closeGoalModal();
    setIsEditScoreModalOpen(false);
  };

  const deleteGoal = (goalId) => {
    const goalToDelete = goals.find((goal) => goal.id === goalId);
    if (!goalToDelete) return;

    const confirmed = window.confirm(
      `Tor von ${goalToDelete.team === "home" ? "Heim" : "Gast"} (Spieler ${goalToDelete.player.padStart(2, "0")}, ${goalToDelete.time}) wirklich löschen?`
    );
    if (!confirmed) return;

    setGoals((prev) => prev.filter((goal) => goal.id !== goalId));
  };

  return (
    <div className="app">
      <div className="bg-glow bg-glow-left" />
      <div className="bg-glow bg-glow-right" />

      <main className="board">
        <header className="top-bar">
          <h1>Handball Scoreboard</h1>
          <div className="clock-chip">{clock}</div>
        </header>

        <section className="score-section">
          <div className="team-card">
            <p className="team-label">Heim</p>
            <p className="team-score-label">Spielstand</p>
            <p className="team-score">{homeDisplayScore}</p>
            <p className="team-score-actual-label">Tore</p>
            <p className="team-score-actual">{homeScore}</p>
          </div>

          <div className="score-separator">:</div>

          <div className="team-card">
            <p className="team-label">Gast</p>
            <p className="team-score-label">Spielstand</p>
            <p className="team-score">{awayDisplayScore}</p>
            <p className="team-score-actual-label">Tore</p>
            <p className="team-score-actual">{awayScore}</p>
          </div>
        </section>

        <section className="log-section">
          {goals.length === 0 ? (
            <div className="empty-log">noch keine Tore gefallen</div>
          ) : (
            <div className="goal-grid">
              {pairedGoals.map((row, index) => (
                <div key={`${row.home?.id ?? "h"}-${row.away?.id ?? "a"}-${index}`} className="goal-row">
                  <div className="goal-cell goal-cell-home">
                    {row.home ? (
                      <span className="goal-text">
                        Spieler {row.home.player.padStart(2, "0")} trifft in {row.home.time}
                      </span>
                    ) : null}
                  </div>
                  <div className="goal-cell goal-cell-away">
                    {row.away ? (
                      <span className="goal-text">
                        Spieler {row.away.player.padStart(2, "0")} trifft in {row.away.time}
                      </span>
                    ) : null}
                  </div>
                </div>
              ))}
            </div>
          )}
        </section>

        <div className="quick-goal-trigger-wrap">
          <button
            className="quick-goal-trigger"
            onClick={openGoalModal}
            aria-label="Tor erfassen"
            title="Tor erfassen"
          >
            🤾
          </button>
        </div>

        <section className="controls">
          <div className="clock-controls">
            <button
              className={`btn ${isRunning ? "btn-ghost" : "btn-start"}`}
              onClick={() => setIsRunning((prev) => !prev)}
            >
              {isRunning ? "Pause" : "Start"}
            </button>
            <button className="btn btn-ghost" onClick={resetClock}>
              Uhr Reset
            </button>
            <button className="btn btn-danger" onClick={resetMatch}>
              Spiel Reset
            </button>
            <button className="btn btn-ghost" onClick={() => setIsEditScoreModalOpen(true)}>
              Spielstand bearbeiten
            </button>
          </div>
        </section>
      </main>

      {isGoalModalOpen ? (
        <div className="goal-modal-backdrop" onClick={closeGoalModal}>
          <div className="goal-modal" onClick={(e) => e.stopPropagation()}>
            <div className="input-row">
              <label htmlFor="modalPlayerNumber">Rückennummer Torschütze</label>
              <input
                id="modalPlayerNumber"
                type="text"
                inputMode="numeric"
                maxLength={2}
                placeholder="z. B. 7"
                value={modalPlayerNumber}
                onChange={(e) =>
                  setModalPlayerNumber(e.target.value.replace(/[^\d]/g, ""))
                }
                autoFocus
              />
            </div>

            <div className="button-row">
              <button className="btn btn-home" type="button" onClick={() => addGoalFromModal("home")}>
                Tor Heim
              </button>
              <button className="btn btn-away" type="button" onClick={() => addGoalFromModal("away")}>
                Tor Gast
              </button>
            </div>

            <button className="btn btn-ghost" type="button" onClick={closeGoalModal}>
              Abbrechen
            </button>
          </div>
        </div>
      ) : null}

      {isEditScoreModalOpen ? (
        <div className="goal-modal-backdrop" onClick={() => setIsEditScoreModalOpen(false)}>
          <div className="goal-modal edit-score-modal" onClick={(e) => e.stopPropagation()}>
            <h3 className="edit-score-title">Spielstand bearbeiten</h3>

            {goals.length === 0 ? (
              <div className="empty-log">noch keine Tore vorhanden</div>
            ) : (
              <div className="edit-goal-list">
                {goals.map((goal) => (
                  <div key={goal.id} className="edit-goal-item">
                    <span className="edit-goal-text">
                      {goal.team === "home" ? "Heim" : "Gast"} · Spieler {goal.player.padStart(2, "0")} · {goal.time}
                    </span>
                    <button
                      className="delete-goal-btn"
                      onClick={() => deleteGoal(goal.id)}
                      aria-label="Tor löschen"
                      title="Tor löschen"
                    >
                      🗑️
                    </button>
                  </div>
                ))}
              </div>
            )}

            <button className="btn btn-ghost edit-modal-ok" onClick={() => setIsEditScoreModalOpen(false)}>
              OK
            </button>
          </div>
        </div>
      ) : null}
    </div>
  );
}
