// Reine Spiellogik fürs Live-Duell, ohne Datenbank. Dadurch gut testbar.

export const QUESTIONS_PER_DUEL = 10;
export const SECONDS_PER_QUESTION = 15;
export const MAX_PLAYERS = 8;
export const MAX_POINTS = 1000;

export type RoomStatus = "lobby" | "question" | "reveal" | "finished";

export type RoomState = {
  status: RoomStatus;
  currentIndex: number; // welche Frage gerade dran ist (0 bis 9)
  questionStartedAt: number | null; // Zeitpunkt in Millisekunden
};

// Raumcode aus 5 Zeichen ohne verwechselbare Buchstaben (kein O/0, I/1)
const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
export function makeRoomCode(random: () => number = Math.random): string {
  let code = "";
  for (let i = 0; i < 5; i++) code += CODE_CHARS[Math.floor(random() * CODE_CHARS.length)];
  return code;
}

export function isValidNickname(name: string): boolean {
  const trimmed = name.trim();
  return trimmed.length >= 2 && trimmed.length <= 16;
}

// Richtig und schnell = mehr Punkte. Richtig in letzter Sekunde = 500, sofort = 1000.
export function pointsFor(correct: boolean, answeredAfterMs: number): number {
  if (!correct) return 0;
  const limit = SECONDS_PER_QUESTION * 1000;
  const remaining = Math.max(0, Math.min(limit, limit - answeredAfterMs));
  return Math.round(MAX_POINTS / 2 + (MAX_POINTS / 2) * (remaining / limit));
}

export function isTimeUp(state: RoomState, now: number): boolean {
  if (state.status !== "question" || state.questionStartedAt === null) return false;
  return now - state.questionStartedAt >= SECONDS_PER_QUESTION * 1000;
}

export function canAnswer(state: RoomState, now: number): boolean {
  return state.status === "question" && !isTimeUp(state, now);
}

// Nächster Zustand, wenn der Gastgeber auf "Start" bzw. "Weiter" drückt
export function advance(state: RoomState, now: number): RoomState {
  switch (state.status) {
    case "lobby":
      return { status: "question", currentIndex: 0, questionStartedAt: now };
    case "question":
      return { ...state, status: "reveal" };
    case "reveal":
      if (state.currentIndex + 1 >= QUESTIONS_PER_DUEL) {
        return { ...state, status: "finished", questionStartedAt: null };
      }
      return { status: "question", currentIndex: state.currentIndex + 1, questionStartedAt: now };
    case "finished":
      return state;
  }
}

export type Standing = { playerId: string; nickname: string; score: number };

// Rangliste: meiste Punkte zuerst, bei Gleichstand alphabetisch
export function ranking(players: Standing[]): Standing[] {
  return [...players].sort((a, b) => b.score - a.score || a.nickname.localeCompare(b.nickname));
}
