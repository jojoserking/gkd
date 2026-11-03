"use client";

import type { Dictionary } from "@/lib/dictionaries";

// Zugangsdaten eines Spielers für einen Raum, im Browser gespeichert
export type Credentials = { playerId: string; token: string };

const key = (code: string) => `gkd-duel-${code}`;

export function loadCredentials(code: string): Credentials | null {
  try {
    const raw = localStorage.getItem(key(code));
    return raw ? (JSON.parse(raw) as Credentials) : null;
  } catch {
    return null;
  }
}

export function saveCredentials(code: string, creds: Credentials) {
  try {
    localStorage.setItem(key(code), JSON.stringify(creds));
  } catch {}
}

export async function postJson(url: string, body: unknown): Promise<Record<string, unknown>> {
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(typeof data.error === "string" ? data.error : "server_error");
  return data;
}

export function errorText(t: Dictionary, code: string): string {
  if (code === "not_configured") return t.notConfigured;
  return (t.errors as Record<string, string>)[code] ?? t.error;
}

export const buttonPrimary =
  "rounded-2xl bg-gradient-to-br from-indigo-600 to-violet-600 px-6 py-3 text-center font-semibold text-white shadow-md shadow-indigo-600/30 transition hover:brightness-110 active:scale-[0.98] disabled:opacity-50";
export const inputStyle =
  "rounded-2xl border-2 border-indigo-500/20 bg-card px-4 py-3 text-lg outline-none transition focus:border-indigo-500";
export const cardStyle = "rounded-3xl bg-card p-6 shadow-lg ring-1 ring-indigo-500/15 backdrop-blur";
