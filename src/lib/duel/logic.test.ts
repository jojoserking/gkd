import { test } from "node:test";
import assert from "node:assert/strict";
import {
  advance, canAnswer, isValidNickname, makeRoomCode, pointsFor, ranking,
  QUESTIONS_PER_DUEL, type RoomState,
} from "./logic.ts";

test("Punkte: falsch 0, sofort 1000, am Ende 500", () => {
  assert.equal(pointsFor(false, 0), 0);
  assert.equal(pointsFor(true, 0), 1000);
  assert.equal(pointsFor(true, 15000), 500);
  assert.equal(pointsFor(true, 7500), 750);
  assert.equal(pointsFor(true, 99999), 500);
});

test("Ablauf: Lobby, 10 Fragen mit Auflösung, dann Ende", () => {
  let s: RoomState = { status: "lobby", currentIndex: 0, questionStartedAt: null };
  s = advance(s, 1000);
  assert.deepEqual(s, { status: "question", currentIndex: 0, questionStartedAt: 1000 });
  for (let i = 0; i < QUESTIONS_PER_DUEL; i++) {
    assert.equal(s.status, "question");
    assert.equal(s.currentIndex, i);
    s = advance(s, 2000);
    assert.equal(s.status, "reveal");
    s = advance(s, 3000);
  }
  assert.equal(s.status, "finished");
  assert.deepEqual(advance(s, 4000), s);
});

test("Antworten nur während der 15 Sekunden", () => {
  const s: RoomState = { status: "question", currentIndex: 0, questionStartedAt: 0 };
  assert.equal(canAnswer(s, 14999), true);
  assert.equal(canAnswer(s, 15000), false);
  assert.equal(canAnswer({ ...s, status: "reveal" }, 100), false);
});

test("Raumcode hat 5 eindeutige Zeichen", () => {
  const code = makeRoomCode();
  assert.match(code, /^[A-HJ-NP-Z2-9]{5}$/);
});

test("Spitzname 2 bis 16 Zeichen", () => {
  assert.equal(isValidNickname("A"), false);
  assert.equal(isValidNickname("  Jo  "), true);
  assert.equal(isValidNickname("x".repeat(17)), false);
});

test("Rangliste sortiert nach Punkten", () => {
  const r = ranking([
    { playerId: "1", nickname: "Ben", score: 500 },
    { playerId: "2", nickname: "Ali", score: 900 },
    { playerId: "3", nickname: "Cem", score: 500 },
  ]);
  assert.deepEqual(r.map((p) => p.nickname), ["Ali", "Ben", "Cem"]);
});
