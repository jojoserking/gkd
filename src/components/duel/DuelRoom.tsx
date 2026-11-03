"use client";

import Link from "next/link";
import { useCallback, useEffect, useRef, useState } from "react";
import type { Dictionary } from "@/lib/dictionaries";
import { supabaseBrowser } from "@/lib/supabase/browser";
import { ranking, SECONDS_PER_QUESTION, type RoomStatus } from "@/lib/duel/logic";
import {
  buttonPrimary, errorText, inputStyle, loadCredentials, postJson, saveCredentials, type Credentials,
} from "./shared";

type Room = {
  code: string;
  host_player_id: string | null;
  status: RoomStatus;
  current_index: number;
};
type Player = { id: string; nickname: string; score: number; last_answer_index: number };
type QuestionInfo = {
  index: number;
  total: number;
  question: { text: string; options: string[] };
  correctIndex: number | null;
  deadline: number; // Zeitpunkt (Browser-Uhr), an dem die Zeit abläuft
};

type Props = { lang: string; code: string; t: Dictionary };

export default function DuelRoom({ lang, code, t }: Props) {
  const [creds, setCreds] = useState<Credentials | null | undefined>(undefined);
  const [room, setRoom] = useState<Room | null>(null);
  const [players, setPlayers] = useState<Player[]>([]);
  const [question, setQuestion] = useState<QuestionInfo | null>(null);
  const [myChoices, setMyChoices] = useState<Record<number, number>>({});
  const [now, setNow] = useState(() => Date.now());
  const [error, setError] = useState<string | null>(null);
  const [notFoundRoom, setNotFoundRoom] = useState(false);
  const [copied, setCopied] = useState(false);
  const supabase = supabaseBrowser();

  // Gespeicherte Zugangsdaten erst im Browser lesen
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setCreds(loadCredentials(code));
  }, [code]);

  // Raum und Mitspieler aus Supabase laden
  const refresh = useCallback(async () => {
    if (!supabase) return;
    const [roomRes, playersRes] = await Promise.all([
      supabase.from("rooms").select("code, host_player_id, status, current_index").eq("code", code).maybeSingle(),
      supabase.from("room_players").select("id, nickname, score, last_answer_index").eq("room_code", code),
    ]);
    if (roomRes.data) setRoom(roomRes.data as Room);
    else if (!roomRes.error) setNotFoundRoom(true);
    if (playersRes.data) setPlayers(playersRes.data as Player[]);
  }, [supabase, code]);

  // Live-Updates: Sobald sich Raum oder Spieler ändern, neu laden.
  // Zusätzlich alle 5 Sekunden, falls die Live-Verbindung mal abreißt.
  useEffect(() => {
    if (!supabase) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect
    refresh();
    const channel = supabase
      .channel(`room-${code}`)
      .on("postgres_changes", { event: "*", schema: "public", table: "rooms", filter: `code=eq.${code}` }, refresh)
      .on("postgres_changes", { event: "*", schema: "public", table: "room_players", filter: `room_code=eq.${code}` }, refresh)
      .subscribe();
    const poll = setInterval(refresh, 5000);
    return () => {
      clearInterval(poll);
      supabase.removeChannel(channel);
    };
  }, [supabase, code, refresh]);

  // Aktuelle Frage vom Server holen, wenn sich Status oder Fragennummer ändern
  const status = room?.status;
  const currentIndex = room?.current_index;
  useEffect(() => {
    if (status !== "question" && status !== "reveal") return;
    let cancelled = false;
    (async () => {
      try {
        const res = await fetch(`/api/duel/${code}/question?lang=${lang}`, { cache: "no-store" });
        const data = await res.json();
        if (cancelled || !res.ok || !data.question) return;
        setQuestion({
          index: data.index,
          total: data.total,
          question: data.question,
          correctIndex: data.correctIndex,
          deadline: Date.now() + data.remainingMs,
        });
      } catch {}
    })();
    return () => {
      cancelled = true;
    };
  }, [code, lang, status, currentIndex]);

  // Uhr für den Countdown
  useEffect(() => {
    if (status !== "question") return;
    const timer = setInterval(() => setNow(Date.now()), 250);
    return () => clearInterval(timer);
  }, [status]);

  const isHost = !!creds && room?.host_player_id === creds.playerId;
  const showQuestion = question && question.index === currentIndex ? question : null;
  const secondsLeft = showQuestion ? Math.max(0, Math.ceil((showQuestion.deadline - now) / 1000)) : 0;
  const everyoneAnswered =
    players.length > 0 && currentIndex !== undefined && players.every((p) => p.last_answer_index >= currentIndex);

  const advance = useCallback(async () => {
    if (!creds) return;
    try {
      await postJson(`/api/duel/${code}/advance`, creds);
      refresh();
    } catch (e) {
      setError(errorText(t, (e as Error).message));
    }
  }, [code, creds, refresh, t]);

  // Frage automatisch auflösen, wenn die Zeit um ist oder alle geantwortet haben
  const autoAdvanced = useRef<string>("");
  useEffect(() => {
    if (status !== "question" || !showQuestion || !creds) return;
    const timeUp = showQuestion.deadline - now <= -500; // kleiner Puffer für Uhr-Unterschiede
    const key = `${currentIndex}`;
    if ((timeUp || (isHost && everyoneAnswered)) && autoAdvanced.current !== key) {
      autoAdvanced.current = key;
      advance();
    }
  }, [status, showQuestion, now, creds, isHost, everyoneAnswered, currentIndex, advance]);

  async function answer(choice: number) {
    if (!creds || currentIndex === undefined || myChoices[currentIndex] !== undefined) return;
    setMyChoices((prev) => ({ ...prev, [currentIndex]: choice }));
    setError(null);
    try {
      await postJson(`/api/duel/${code}/answer`, { ...creds, choice });
    } catch (e) {
      setError(errorText(t, (e as Error).message));
    }
  }

  async function copyLink() {
    try {
      await navigator.clipboard.writeText(window.location.href);
      setCopied(true);
    } catch {}
  }

  if (!supabase) return <Message text={t.notConfigured} lang={lang} t={t} />;
  if (notFoundRoom) return <Message text={t.errors.room_not_found} lang={lang} t={t} />;
  if (creds === undefined || !room) return <p className="text-center opacity-60">{t.loading}</p>;

  if (!creds) {
    return <JoinForm code={code} lang={lang} t={t} canJoin={room.status === "lobby"} onJoined={setCreds} />;
  }

  const standings = ranking(players.map((p) => ({ playerId: p.id, nickname: p.nickname, score: p.score })));

  // Warteraum
  if (room.status === "lobby") {
    return (
      <div className="flex flex-col gap-6">
        <Header lang={lang} title={t.lobby} />
        <div className="rounded-xl border-2 border-current/10 p-4 text-center">
          <p className="text-sm opacity-70">{t.inviteFriends}</p>
          <p className="my-2 text-4xl font-bold tracking-[0.3em]">{code}</p>
          <button onClick={copyLink} className="text-sm underline opacity-80">
            {copied ? t.copied : t.copyLink}
          </button>
        </div>
        <div>
          <h2 className="mb-2 font-semibold">
            {t.players} ({players.length}/8)
          </h2>
          <ul className="flex flex-col gap-1">
            {players.map((p) => (
              <li key={p.id} className="rounded-lg bg-current/5 px-3 py-2">
                {p.nickname}
                {p.id === room.host_player_id && <span className="opacity-60"> · {t.host}</span>}
                {p.id === creds.playerId && <span className="opacity-60"> ({t.you})</span>}
              </li>
            ))}
          </ul>
        </div>
        {isHost ? (
          <button className={buttonPrimary} onClick={advance}>
            {t.start}
          </button>
        ) : (
          <p className="text-center opacity-70">{t.waitingForHost}</p>
        )}
        {error && <p className="text-red-600">{error}</p>}
      </div>
    );
  }

  // Endergebnis
  if (room.status === "finished") {
    return (
      <div className="flex flex-col gap-6 text-center">
        <h1 className="text-3xl font-bold">{t.finalRanking}</h1>
        {standings[0] && (
          <p className="text-xl">
            🏆 {t.winner}: <strong>{standings[0].nickname}</strong>
          </p>
        )}
        <Standings standings={standings} me={creds.playerId} t={t} />
        <Link href={`/${lang}/duel`} className={buttonPrimary}>
          {t.newDuel}
        </Link>
        <Link href={`/${lang}`} className="underline opacity-70">
          {t.back}
        </Link>
      </div>
    );
  }

  // Frage läuft oder wird aufgelöst
  if (!showQuestion) return <p className="text-center opacity-60">{t.loading}</p>;
  const myChoice = myChoices[showQuestion.index];
  const revealed = room.status === "reveal" && showQuestion.correctIndex !== null;
  const answeredCount = players.filter((p) => p.last_answer_index >= showQuestion.index).length;

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between text-sm opacity-70">
        <span>
          {t.question} {showQuestion.index + 1} {t.of} {showQuestion.total}
        </span>
        <span>{room.status === "question" ? `${secondsLeft} ${t.secondsLeft}` : t.timeUp}</span>
      </div>
      <div className="h-2 w-full rounded-full bg-current/10">
        <div
          className="h-2 rounded-full bg-indigo-600 transition-all duration-300"
          style={{ width: `${room.status === "question" ? (secondsLeft / SECONDS_PER_QUESTION) * 100 : 0}%` }}
        />
      </div>
      <h1 className="text-2xl font-semibold leading-snug">{showQuestion.question.text}</h1>
      <div className="flex flex-col gap-3">
        {showQuestion.question.options.map((option, i) => {
          let style = "border-current/20 hover:border-indigo-500";
          if (revealed) {
            if (i === showQuestion.correctIndex) style = "border-green-600 bg-green-600/15";
            else if (i === myChoice) style = "border-red-600 bg-red-600/15";
            else style = "border-current/10 opacity-60";
          } else if (myChoice !== undefined) {
            style = i === myChoice ? "border-indigo-600 bg-indigo-600/15" : "border-current/10 opacity-60";
          }
          return (
            <button
              key={i}
              onClick={() => answer(i)}
              disabled={myChoice !== undefined || room.status !== "question" || secondsLeft === 0}
              className={`rounded-xl border-2 px-5 py-4 text-left text-lg transition ${style}`}
            >
              {option}
            </button>
          );
        })}
      </div>
      {room.status === "question" && (
        <p className="text-center text-sm opacity-70">
          {myChoice !== undefined ? `${t.waitingForOthers} ` : ""}
          {answeredCount}/{players.length} {t.answered}
        </p>
      )}
      {revealed && (
        <>
          <p
            className={`text-center font-semibold ${myChoice === showQuestion.correctIndex ? "text-green-600" : "text-red-600"}`}
          >
            {myChoice === showQuestion.correctIndex ? t.correct : myChoice === undefined ? t.timeUp : t.wrong}
          </p>
          <div>
            <h2 className="mb-2 font-semibold">{t.standings}</h2>
            <Standings standings={standings} me={creds.playerId} t={t} />
          </div>
          {isHost ? (
            <button className={buttonPrimary} onClick={advance}>
              {showQuestion.index + 1 < showQuestion.total ? t.next : t.showResult}
            </button>
          ) : (
            <p className="text-center opacity-70">{t.waitingForHost}</p>
          )}
        </>
      )}
      {error && <p className="text-red-600">{error}</p>}
    </div>
  );
}

function Header({ lang, title }: { lang: string; title: string }) {
  return (
    <div className="flex items-center justify-between">
      <Link href={`/${lang}`} className="text-sm opacity-70">
        ← GKD
      </Link>
      <h1 className="text-xl font-bold">{title}</h1>
      <span />
    </div>
  );
}

function Message({ text, lang, t }: { text: string; lang: string; t: Dictionary }) {
  return (
    <div className="flex flex-col items-center gap-4 text-center">
      <p>{text}</p>
      <Link href={`/${lang}/duel`} className="underline opacity-70">
        {t.duelTitle}
      </Link>
    </div>
  );
}

function Standings({
  standings,
  me,
  t,
}: {
  standings: { playerId: string; nickname: string; score: number }[];
  me: string;
  t: Dictionary;
}) {
  return (
    <ol className="flex flex-col gap-1 text-left">
      {standings.map((s, i) => (
        <li
          key={s.playerId}
          className={`flex justify-between rounded-lg px-3 py-2 ${s.playerId === me ? "bg-indigo-600/15" : "bg-current/5"}`}
        >
          <span>
            {i + 1}. {s.nickname}
            {s.playerId === me && <span className="opacity-60"> ({t.you})</span>}
          </span>
          <span className="font-semibold">
            {s.score} {t.points}
          </span>
        </li>
      ))}
    </ol>
  );
}

// Wer über einen Einladungslink kommt, gibt hier seinen Spitznamen ein
function JoinForm({
  code,
  lang,
  t,
  canJoin,
  onJoined,
}: {
  code: string;
  lang: string;
  t: Dictionary;
  canJoin: boolean;
  onJoined: (c: Credentials) => void;
}) {
  const [nickname, setNickname] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!canJoin) return <Message text={t.errors.already_started} lang={lang} t={t} />;

  async function join() {
    setBusy(true);
    setError(null);
    try {
      const data = await postJson(`/api/duel/${code}/join`, { nickname });
      const creds = { playerId: String(data.playerId), token: String(data.token) };
      saveCredentials(code, creds);
      onJoined(creds);
    } catch (e) {
      setError(errorText(t, (e as Error).message));
      setBusy(false);
    }
  }

  return (
    <div className="flex flex-col gap-4">
      <Header lang={lang} title={t.duelTitle} />
      <p className="text-center text-4xl font-bold tracking-[0.3em]">{code}</p>
      <input
        className={inputStyle}
        placeholder={t.nickname}
        value={nickname}
        maxLength={16}
        onChange={(e) => setNickname(e.target.value)}
      />
      <button className={buttonPrimary} disabled={busy} onClick={join}>
        {t.join}
      </button>
      {error && <p className="text-red-600">{error}</p>}
    </div>
  );
}
