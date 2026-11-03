"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import type { PublicQuestion } from "@/lib/daily";
import type { Dictionary } from "@/lib/dictionaries";

type Props = { lang: string; date: string; questions: PublicQuestion[]; t: Dictionary };
type Answer = { choice: number; correctIndex: number; correct: boolean };

const storageKey = (date: string) => `gkd-daily-${date}`;

export default function DailyQuiz({ lang, date, questions, t }: Props) {
  const [index, setIndex] = useState(0);
  const [answers, setAnswers] = useState<Answer[]>([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(false);
  const [finished, setFinished] = useState(false);
  const [copied, setCopied] = useState(false);

  // Wer heute schon gespielt hat, sieht direkt sein Ergebnis.
  useEffect(() => {
    try {
      const saved = localStorage.getItem(storageKey(date));
      if (saved) {
        // localStorage gibt es nur im Browser, deshalb erst nach dem Laden lesen.
        // eslint-disable-next-line react-hooks/set-state-in-effect
        setAnswers(JSON.parse(saved));
        setFinished(true);
      }
    } catch {}
  }, [date]);

  const question = questions[index];
  const current = answers[index];
  const score = answers.filter((a) => a.correct).length;

  async function choose(choice: number) {
    if (current || busy) return;
    setBusy(true);
    setError(false);
    try {
      const res = await fetch("/api/daily/answer", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ questionId: question.id, choice }),
      });
      if (!res.ok) throw new Error();
      const data = await res.json();
      setAnswers((prev) => [...prev, { choice, correctIndex: data.correctIndex, correct: data.correct }]);
    } catch {
      setError(true);
    } finally {
      setBusy(false);
    }
  }

  function next() {
    if (index + 1 < questions.length) {
      setIndex(index + 1);
    } else {
      setFinished(true);
      try {
        localStorage.setItem(storageKey(date), JSON.stringify(answers));
      } catch {}
    }
  }

  async function share() {
    const squares = answers.map((a) => (a.correct ? "🟩" : "🟥")).join("");
    const text = `GKD ${date}: ${score}/${questions.length}\n${squares}\n${window.location.origin}/${lang}/daily`;
    try {
      if (navigator.share) await navigator.share({ text });
      else {
        await navigator.clipboard.writeText(text);
        setCopied(true);
      }
    } catch {}
  }

  if (finished) {
    return (
      <div className="flex flex-col items-center gap-6 text-center">
        <h1 className="text-2xl font-bold">{t.resultTitle}</h1>
        <p className="text-6xl font-bold">
          {score}/{questions.length}
        </p>
        <p className="text-2xl tracking-widest">
          {answers.map((a, i) => (
            <span key={i}>{a.correct ? "🟩" : "🟥"}</span>
          ))}
        </p>
        <button
          onClick={share}
          className="rounded-xl bg-indigo-600 px-6 py-3 font-semibold text-white hover:bg-indigo-500"
        >
          {copied ? t.copied : t.share}
        </button>
        <p className="opacity-70">{t.comeBack}</p>
        <Link href={`/${lang}`} className="underline opacity-70">
          {t.back}
        </Link>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between text-sm opacity-70">
        <Link href={`/${lang}`}>← GKD</Link>
        <span>
          {t.question} {index + 1} {t.of} {questions.length}
        </span>
      </div>
      <div className="h-2 w-full rounded-full bg-current/10">
        <div
          className="h-2 rounded-full bg-indigo-600 transition-all"
          style={{ width: `${((index + (current ? 1 : 0)) / questions.length) * 100}%` }}
        />
      </div>
      <h1 className="text-2xl font-semibold leading-snug">{question.text}</h1>
      <div className="flex flex-col gap-3">
        {question.options.map((option, i) => {
          let style = "border-current/20 hover:border-indigo-500";
          if (current) {
            if (i === current.correctIndex) style = "border-green-600 bg-green-600/15";
            else if (i === current.choice) style = "border-red-600 bg-red-600/15";
            else style = "border-current/10 opacity-60";
          }
          return (
            <button
              key={i}
              onClick={() => choose(i)}
              disabled={!!current || busy}
              className={`rounded-xl border-2 px-5 py-4 text-left text-lg transition ${style}`}
            >
              {option}
            </button>
          );
        })}
      </div>
      {error && <p className="text-red-600">{t.error}</p>}
      {current && (
        <div className="flex items-center justify-between">
          <p className={`font-semibold ${current.correct ? "text-green-600" : "text-red-600"}`}>
            {current.correct ? t.correct : t.wrong}
          </p>
          <button
            onClick={next}
            className="rounded-xl bg-indigo-600 px-6 py-3 font-semibold text-white hover:bg-indigo-500"
          >
            {index + 1 < questions.length ? t.next : t.showResult}
          </button>
        </div>
      )}
    </div>
  );
}
