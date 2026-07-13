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
          </div>
        </section>
      </main>
    </div>
  );
}
