import "server-only";
import { randomBytes, randomUUID, timingSafeEqual } from "node:crypto";
import { supabaseAdmin } from "@/lib/supabase/server";
import { getQuestionPool, getQuestionsByIds } from "@/lib/questionStore";
import {
  advance, canAnswer, isTimeUp, isValidNickname, makeRoomCode, pointsFor,
  MAX_PLAYERS, QUESTIONS_PER_DUEL, SECONDS_PER_QUESTION, type RoomState, type RoomStatus,
} from "./logic";

// Alles, was im Live-Duell in die Datenbank schreibt, läuft hier über den Server.

export class DuelError extends Error {
  constructor(public code: string, public status = 400) {
    super(code);
  }
}

type RoomRow = {
  code: string;
  host_player_id: string | null;
  status: RoomStatus;
  current_index: number;
  question_started_at: string | null;
  question_ids: string[];
};

const ROOM_COLUMNS = "code, host_player_id, status, current_index, question_started_at, question_ids";

export function normalizeCode(code: string): string {
  return code.trim().toUpperCase();
}

function toState(room: RoomRow): RoomState {
  return {
    status: room.status,
    currentIndex: room.current_index,
    questionStartedAt: room.question_started_at ? Date.parse(room.question_started_at) : null,
  };
}

async function getRoom(code: string): Promise<RoomRow> {
  const { data, error } = await supabaseAdmin()
    .from("rooms").select(ROOM_COLUMNS).eq("code", normalizeCode(code)).maybeSingle();
  if (error) throw error;
  if (!data) throw new DuelError("room_not_found", 404);
  return data as RoomRow;
}

function shuffle<T>(list: T[]): T[] {
  const a = [...list];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

async function addPlayer(code: string, nickname: string) {
  const db = supabaseAdmin();
  const id = randomUUID();
  const token = randomBytes(24).toString("base64url");
  const { error } = await db.from("room_players").insert({ id, room_code: code, nickname });
  if (error) {
    if (error.code === "23505") throw new DuelError("nickname_taken", 409);
    throw error;
  }
  const { error: secretError } = await db.from("player_secrets").insert({ player_id: id, token });
  if (secretError) throw secretError;
  return { playerId: id, token };
}

export async function createRoom(nicknameRaw: string) {
  const nickname = nicknameRaw.trim();
  if (!isValidNickname(nickname)) throw new DuelError("invalid_nickname");
  const db = supabaseAdmin();
  const questionIds = shuffle(await getQuestionPool()).slice(0, QUESTIONS_PER_DUEL).map((q) => q.id);
  if (questionIds.length < QUESTIONS_PER_DUEL) throw new DuelError("not_enough_questions", 500);

  // Falls ein Code zufällig schon vergeben ist, einfach einen neuen probieren
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = makeRoomCode();
    const { error } = await db.from("rooms").insert({ code, question_ids: questionIds });
    if (error?.code === "23505") continue;
    if (error) throw error;
    const player = await addPlayer(code, nickname);
    const { error: hostError } = await db.from("rooms").update({ host_player_id: player.playerId }).eq("code", code);
    if (hostError) throw hostError;
    return { code, ...player };
  }
  throw new DuelError("no_free_code", 500);
}

export async function joinRoom(codeRaw: string, nicknameRaw: string) {
  const nickname = nicknameRaw.trim();
  if (!isValidNickname(nickname)) throw new DuelError("invalid_nickname");
  const room = await getRoom(codeRaw);
  if (room.status !== "lobby") throw new DuelError("already_started", 409);
  const { count, error } = await supabaseAdmin()
    .from("room_players").select("id", { count: "exact", head: true }).eq("room_code", room.code);
  if (error) throw error;
  if ((count ?? 0) >= MAX_PLAYERS) throw new DuelError("room_full", 409);
  return { code: room.code, ...(await addPlayer(room.code, nickname)) };
}

async function checkPlayer(code: string, playerId: unknown, token: unknown) {
  if (typeof playerId !== "string" || typeof token !== "string") throw new DuelError("unauthorized", 401);
  const { data, error } = await supabaseAdmin()
    .from("room_players").select("id, room_code, player_secrets(token)")
    .eq("id", playerId).eq("room_code", code).maybeSingle();
  if (error) throw error;
  const secrets = data?.player_secrets as unknown as { token: string } | { token: string }[] | null;
  const stored = Array.isArray(secrets) ? secrets[0]?.token : secrets?.token;
  const a = Buffer.from(stored ?? "");
  const b = Buffer.from(token);
  if (!stored || a.length !== b.length || !timingSafeEqual(a, b)) throw new DuelError("unauthorized", 401);
}

// Weiter zum nächsten Schritt. Start/Weiter darf nur der Gastgeber.
// Die Auflösung einer Frage darf jeder auslösen, sobald die Zeit um ist.
export async function advanceRoom(codeRaw: string, playerId: unknown, token: unknown) {
  const room = await getRoom(codeRaw);
  await checkPlayer(room.code, playerId, token);
  const now = Date.now();
  const state = toState(room);
  const isHost = room.host_player_id === playerId;
  if (!isHost && !(state.status === "question" && isTimeUp(state, now))) {
    throw new DuelError("only_host", 403);
  }
  const next = advance(state, now);
  if (next.status === state.status && next.currentIndex === state.currentIndex) return;

  // Nur ändern, wenn sich der Raum inzwischen nicht schon geändert hat (z. B. Doppelklick)
  const { error } = await supabaseAdmin()
    .from("rooms")
    .update({
      status: next.status,
      current_index: next.currentIndex,
      question_started_at: next.questionStartedAt ? new Date(next.questionStartedAt).toISOString() : null,
    })
    .eq("code", room.code).eq("status", room.status).eq("current_index", room.current_index);
  if (error) throw error;
}

export async function submitAnswer(codeRaw: string, playerId: unknown, token: unknown, choice: unknown) {
  if (typeof choice !== "number" || !Number.isInteger(choice) || choice < 0 || choice > 3) {
    throw new DuelError("invalid_choice");
  }
  const room = await getRoom(codeRaw);
  await checkPlayer(room.code, playerId, token);
  const now = Date.now();
  const state = toState(room);
  if (!canAnswer(state, now)) throw new DuelError("too_late", 409);

  const questionId = room.question_ids[room.current_index];
  const question = (await getQuestionsByIds([questionId])).get(questionId);
  if (!question) throw new DuelError("question_missing", 500);

  const correct = choice === question.answer;
  const points = pointsFor(correct, now - (state.questionStartedAt ?? now));
  const { data, error } = await supabaseAdmin().rpc("record_answer", {
    p_room: room.code, p_player: playerId, p_index: room.current_index,
    p_choice: choice, p_correct: correct, p_points: points,
  });
  if (error) throw error;
  if (data === false) throw new DuelError("already_answered", 409);
  return { accepted: true };
}

// Die aktuelle Frage für den Browser. Die Lösung gibt es erst, wenn die Frage aufgelöst ist.
export async function currentQuestion(codeRaw: string, lang: "de" | "en") {
  const room = await getRoom(codeRaw);
  const state = toState(room);
  if (state.status === "lobby" || state.status === "finished") {
    return { status: state.status, index: state.currentIndex, question: null };
  }
  const questionId = room.question_ids[room.current_index];
  const question = (await getQuestionsByIds([questionId])).get(questionId);
  if (!question) throw new DuelError("question_missing", 500);
  const elapsed = Date.now() - (state.questionStartedAt ?? Date.now());
  return {
    status: state.status,
    index: state.currentIndex,
    total: room.question_ids.length,
    question: { text: question[lang].text, options: question[lang].options, category: question.category },
    remainingMs: Math.max(0, SECONDS_PER_QUESTION * 1000 - elapsed),
    correctIndex: state.status === "reveal" ? question.answer : null,
  };
}
