import Link from "next/link";
import { notFound } from "next/navigation";
import { getDictionary, hasLocale } from "@/lib/dictionaries";
import DuelStart from "@/components/duel/DuelStart";

export default async function DuelPage({ params }: PageProps<"/[lang]/duel">) {
  const { lang } = await params;
  if (!hasLocale(lang)) notFound();
  const t = await getDictionary(lang);

  return (
    <main className="w-full max-w-md flex flex-col gap-6">
      <Link href={`/${lang}`} className="text-sm opacity-70">← GKD</Link>
      <h1 className="text-3xl font-bold">{t.duelTitle}</h1>
      <p className="opacity-80">{t.duelIntro}</p>
      <DuelStart lang={lang} t={t} />
    </main>
  );
}
