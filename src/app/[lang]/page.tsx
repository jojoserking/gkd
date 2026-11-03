import Link from "next/link";
import { notFound } from "next/navigation";
import { getDictionary, hasLocale } from "@/lib/dictionaries";
import { questions } from "@/lib/questions";

export default async function Home({ params }: PageProps<"/[lang]">) {
  const { lang } = await params;
  if (!hasLocale(lang)) notFound();
  const t = await getDictionary(lang);
  const questionCount = Math.floor(questions.length / 10) * 10;

  return (
    <main className="flex w-full max-w-xl flex-col gap-10 text-center animate-pop">
      <div className="pt-6">
        <h1 className="bg-gradient-to-br from-indigo-600 to-fuchsia-500 bg-clip-text text-7xl font-black tracking-tight text-transparent">
          GKD
        </h1>
        <p className="mt-2 text-xs font-semibold uppercase tracking-[0.35em] opacity-60">General Knowledge Duel</p>
        <p className="mx-auto mt-6 max-w-sm text-xl leading-relaxed">{t.tagline}</p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <Link
          href={`/${lang}/daily`}
          className="group rounded-3xl bg-gradient-to-br from-indigo-600 to-violet-600 p-6 text-left text-white shadow-lg shadow-indigo-600/30 transition hover:-translate-y-1 hover:shadow-xl"
        >
          <span className="text-4xl">📅</span>
          <h2 className="mt-3 text-2xl font-bold">{t.playDaily}</h2>
          <p className="mt-1 text-sm opacity-85">{t.dailyDesc}</p>
          <span className="mt-4 inline-block text-xl transition group-hover:translate-x-1">→</span>
        </Link>
        <Link
          href={`/${lang}/duel`}
          className="group rounded-3xl bg-card p-6 text-left shadow-lg ring-1 ring-indigo-500/20 backdrop-blur transition hover:-translate-y-1 hover:shadow-xl"
        >
          <span className="text-4xl">⚔️</span>
          <h2 className="mt-3 text-2xl font-bold">{t.liveDuel}</h2>
          <p className="mt-1 text-sm opacity-70">{t.duelDesc}</p>
          <span className="mt-4 inline-block text-xl text-indigo-600 transition group-hover:translate-x-1">→</span>
        </Link>
      </div>

      <div className="grid grid-cols-3 gap-3 text-sm">
        {[
          [`${questionCount}+`, t.statQuestions],
          ["6", t.statCategories],
          ["2", t.statLanguages],
        ].map(([n, label]) => (
          <div key={label} className="rounded-2xl bg-card py-4 ring-1 ring-indigo-500/10 backdrop-blur">
            <p className="text-2xl font-black text-indigo-600">{n}</p>
            <p className="opacity-60">{label}</p>
          </div>
        ))}
      </div>
    </main>
  );
}
