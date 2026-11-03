"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import type { Dictionary } from "@/lib/dictionaries";
import { buttonPrimary, errorText, inputStyle, postJson, saveCredentials } from "./shared";

// Startseite des Duells: Raum erstellen oder mit Code beitreten
export default function DuelStart({ lang, t }: { lang: string; t: Dictionary }) {
  const router = useRouter();
  const [nickname, setNickname] = useState("");
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function run(url: string) {
    setBusy(true);
    setError(null);
    try {
      const data = await postJson(url, { nickname });
      const roomCode = String(data.code);
      saveCredentials(roomCode, { playerId: String(data.playerId), token: String(data.token) });
      router.push(`/${lang}/duel/${roomCode}`);
    } catch (e) {
      setError(errorText(t, (e as Error).message));
      setBusy(false);
    }
  }

  const cleanCode = code.trim().toUpperCase();

  return (
    <div className="flex flex-col gap-4">
      <input
        className={inputStyle}
        placeholder={t.nickname}
        value={nickname}
        maxLength={16}
        onChange={(e) => setNickname(e.target.value)}
      />
      <button className={buttonPrimary} disabled={busy} onClick={() => run("/api/duel/create")}>
        {t.createRoom}
      </button>
      <p className="text-center text-sm opacity-60">{t.or}</p>
      <div className="flex gap-2">
        <input
          className={`${inputStyle} min-w-0 flex-1 uppercase tracking-widest`}
          placeholder={t.roomCode}
          value={code}
          maxLength={5}
          onChange={(e) => setCode(e.target.value)}
        />
        <button
          className={buttonPrimary}
          disabled={busy || cleanCode.length !== 5}
          onClick={() => run(`/api/duel/${cleanCode}/join`)}
        >
          {t.join}
        </button>
      </div>
      {error && <p className="text-red-600">{error}</p>}
    </div>
  );
}
