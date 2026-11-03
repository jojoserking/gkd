import { notFound } from "next/navigation";
import { getDictionary, hasLocale } from "@/lib/dictionaries";
import DuelStart from "@/components/duel/DuelStart";

export default async function DuelPage({ params }: PageProps<"/[lang]/duel">) {
  const { lang } = await params;
  if (!hasLocale(lang)) notFound();
  const t = await getDictionary(lang);

  return (
    <main className="w-full max-w-md flex flex-col gap-6 animate-pop">
      <div className="text-center">
        <span className="text-5xl">⚔️</span>
        <h1 className="mt-2 text-4xl font-black">{t.duelTitle}</h1>
        <p className="mt-3 opacity-75">{t.duelIntro}</p>
      </div>
      <div className="rounded-3xl bg-card p-6 shadow-lg ring-1 ring-indigo-500/15 backdrop-blur">
        <DuelStart lang={lang} t={t} />
      </div>
    </main>
  );
}
