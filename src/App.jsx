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

export default function App() {
  const [homeScore, setHomeScore] = useState(0);
  const [awayScore, setAwayScore] = useState(0);

  const [playerNumber, setPlayerNumber] = useState("");
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

  const addGoal = (team) => {
    const trimmed = playerNumber.trim();

    if (!trimmed) {
      alert("Bitte Rückennummer eingeben.");
      return;
    }

    if (!/^\d{1,2}$/.test(trimmed)) {
      alert("Bitte eine gültige Rückennummer (1–2 Ziffern) eingeben.");
      return;
    }

    if (team === "home") {
      setHomeScore((prev) => prev + 1);
    } else {
      setAwayScore((prev) => prev + 1);
    }

    const entry = {
      id: crypto.randomUUID(),
      team,
      player: trimmed,
      minute: getMinuteLabel(elapsedSeconds),
      time: clock,
    };

    setGoals((prev) => [entry, ...prev]);
    setPlayerNumber("");
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

    setHomeScore(0);
    setAwayScore(0);
    setGoals([]);
    setPlayerNumber("");
    setIsRunning(false);
    setElapsedSeconds(0);
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
            <p className="team-score">{homeScore}</p>
          </div>

          <div className="score-separator">:</div>

          <div className="team-card">
            <p className="team-label">Gast</p>
            <p className="team-score">{awayScore}</p>
          </div>
        </section>

        <section className="controls">
          <div className="input-row">
            <label htmlFor="playerNumber">Rückennummer Torschütze</label>
            <input
              id="playerNumber"
              type="text"
              inputMode="numeric"
              maxLength={2}
              placeholder="z. B. 7"
              value={playerNumber}
              onChange={(e) =>
                setPlayerNumber(e.target.value.replace(/[^\d]/g, ""))
              }
              onKeyDown={(e) => {
                if (e.key === "Enter") {
                  addGoal("home");
                }
              }}
            />
          </div>

          <div className="button-row">
            <button className="btn btn-home" onClick={() => addGoal("home")}>
              Tor Heim
            </button>
            <button className="btn btn-away" onClick={() => addGoal("away")}>
              Tor Gast
            </button>
          </div>

          <div className="clock-controls">
            <button
              className="btn btn-ghost"
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
          </div>
        </section>

        <section className="log-section">
          <div className="log-header">
            <h2>Letzte Tore</h2>
            <span>{goals.length} Einträge</span>
          </div>

          {goals.length === 0 ? (
            <div className="empty-log">
              Noch keine Tore erfasst. Trage eine Rückennummer ein und buche ein Tor.
            </div>
          ) : (
            <ul className="goal-list">
              {goals.map((goal) => (
                <li key={goal.id} className="goal-item">
                  <span className={`pill ${goal.team === "home" ? "home" : "away"}`}>
                    {goal.team === "home" ? "Heim" : "Gast"}
                  </span>
                  <span className="goal-text">
                    # {goal.player} trifft in {goal.minute}
                  </span>
                  <span className="goal-time">{goal.time}</span>
                </li>
              ))}
            </ul>
          )}
        </section>
      </main>
    </div>
  );
}