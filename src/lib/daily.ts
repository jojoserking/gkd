import "server-only";
import { questions, type Question } from "./questions";
import type { Locale } from "./dictionaries";

export const QUESTIONS_PER_DAY = 10;

// Heutiges Datum in deutscher Zeit, z. B. "2026-11-03". Um Mitternacht gibt es neue Fragen.
export function todayKey(): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Berlin" }).format(new Date());
}

// Einfacher Zufallsgenerator mit Startwert: gleiches Datum = gleiche Fragen für alle.
function seededRandom(seed: string) {
  let h = 2166136261;
  for (const ch of seed) h = Math.imul(h ^ ch.charCodeAt(0), 16777619);
  return () => {
    h += 0x6d2b79f5;
    let t = h;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function dailyQuestions(date: string): Question[] {
  const rand = seededRandom(date);
  const pool = [...questions];
  for (let i = pool.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [pool[i], pool[j]] = [pool[j], pool[i]];
  }
  return pool.slice(0, QUESTIONS_PER_DAY);
}

// Was der Browser sehen darf: Frage und Antworten, aber nicht die Lösung.
export type PublicQuestion = { id: string; category: string; text: string; options: string[] };

export function publicDailyQuestions(date: string, lang: Locale): PublicQuestion[] {
  return dailyQuestions(date).map((q) => ({
    id: q.id,
    category: q.category,
    text: q[lang].text,
    options: q[lang].options,
  }));
}
