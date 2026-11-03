"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

// Umschalter DE | EN oben rechts. Bleibt auf derselben Seite, nur die Sprache wechselt.
// staticPath: Ersatz beim Vorab-Rendern, verlinkt nur auf die Startseite.
export default function LanguageSwitch({ lang, staticPath }: { lang: string; staticPath?: boolean }) {
  return staticPath ? <Switch lang={lang} rest="" /> : <CurrentPathSwitch lang={lang} />;
}

function CurrentPathSwitch({ lang }: { lang: string }) {
  const pathname = usePathname() ?? `/${lang}`;
  const rest = pathname.replace(/^\/(de|en)(?=\/|$)/, "");
  return <Switch lang={lang} rest={rest} />;
}

function Switch({ lang, rest }: { lang: string; rest: string }) {
  return (
    <div className="flex rounded-full bg-card p-1 text-sm font-semibold shadow-sm ring-1 ring-indigo-500/20 backdrop-blur">
      {(["de", "en"] as const).map((l) => (
        <Link
          key={l}
          href={`/${l}${rest}`}
          aria-current={l === lang ? "true" : undefined}
          className={`rounded-full px-3 py-1 transition ${
            l === lang ? "bg-indigo-600 text-white" : "opacity-60 hover:opacity-100"
          }`}
        >
          {l.toUpperCase()}
        </Link>
      ))}
    </div>
  );
}
