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
  "rounded-xl bg-indigo-600 px-6 py-3 font-semibold text-white hover:bg-indigo-500 disabled:opacity-50";
export const inputStyle =
  "rounded-xl border-2 border-current/20 bg-transparent px-4 py-3 text-lg focus:border-indigo-500 outline-none";
