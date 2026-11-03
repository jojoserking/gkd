import Link from "next/link";
import { notFound } from "next/navigation";
import { getDictionary, hasLocale } from "@/lib/dictionaries";

export default async function Home({ params }: PageProps<"/[lang]">) {
  const { lang } = await params;
  if (!hasLocale(lang)) notFound();
  const t = await getDictionary(lang);
  const other = lang === "de" ? "en" : "de";

  return (
    <main className="w-full max-w-md flex flex-col gap-8 text-center">
      <div className="flex justify-end text-sm">
        <Link href={`/${other}`} className="underline opacity-70 hover:opacity-100">
          {other.toUpperCase()}
        </Link>
      </div>
      <div>
        <h1 className="text-5xl font-bold tracking-tight">GKD</h1>
        <p className="mt-1 text-sm uppercase tracking-widest opacity-60">General Knowledge Duel</p>
        <p className="mt-6 text-lg">{t.tagline}</p>
      </div>
      <div className="flex flex-col gap-3">
        <Link
          href={`/${lang}/daily`}
          className="rounded-xl bg-indigo-600 px-6 py-4 text-lg font-semibold text-white hover:bg-indigo-500"
        >
          {t.playDaily}
        </Link>
        <Link
          href={`/${lang}/duel`}
          className="rounded-xl border-2 border-indigo-600 px-6 py-4 text-lg font-semibold hover:bg-indigo-600/10"
        >
          {t.liveDuel}
        </Link>
      </div>
    </main>
  );
}
