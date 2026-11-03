import { Suspense } from "react";
import { connection } from "next/server";
import { notFound } from "next/navigation";
import { getDictionary, hasLocale, type Locale } from "@/lib/dictionaries";
import { publicDailyQuestions, todayKey } from "@/lib/daily";
import DailyQuiz from "@/components/DailyQuiz";

// Die Fragen hängen vom heutigen Datum ab, deshalb erst beim Aufruf berechnen.
async function TodaysQuiz({ lang }: { lang: Locale }) {
  await connection();
  const t = await getDictionary(lang);
  const date = todayKey();
  return <DailyQuiz lang={lang} date={date} questions={publicDailyQuestions(date, lang)} t={t} />;
}

export default async function DailyPage({ params }: PageProps<"/[lang]/daily">) {
  const { lang } = await params;
  if (!hasLocale(lang)) notFound();

  return (
    <main className="w-full max-w-md">
      <Suspense fallback={<p className="text-center opacity-60">…</p>}>
        <TodaysQuiz lang={lang} />
      </Suspense>
    </main>
  );
}
