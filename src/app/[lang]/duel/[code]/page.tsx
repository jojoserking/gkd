import { Suspense } from "react";
import { notFound } from "next/navigation";
import { getDictionary, hasLocale, type Locale } from "@/lib/dictionaries";
import DuelRoom from "@/components/duel/DuelRoom";

async function Room({ params }: { params: PageProps<"/[lang]/duel/[code]">["params"] }) {
  const { lang, code } = await params;
  if (!hasLocale(lang) || !/^[A-Za-z0-9]{5}$/.test(code)) notFound();
  const t = await getDictionary(lang as Locale);
  return <DuelRoom lang={lang} code={code.toUpperCase()} t={t} />;
}

export default function DuelRoomPage({ params }: PageProps<"/[lang]/duel/[code]">) {
  return (
    <main className="w-full max-w-md">
      <Suspense fallback={<p className="text-center opacity-60">…</p>}>
        <Room params={params} />
      </Suspense>
    </main>
  );
}
