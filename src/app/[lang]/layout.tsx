import type { Metadata } from "next";
import { notFound } from "next/navigation";
import Link from "next/link";
import { Suspense } from "react";
import { Geist } from "next/font/google";
import LanguageSwitch from "@/components/LanguageSwitch";
import { hasLocale, locales } from "@/lib/dictionaries";
import "../globals.css";

const geist = Geist({ variable: "--font-geist-sans", subsets: ["latin"] });

export const metadata: Metadata = {
  title: "GKD · General Knowledge Duel",
  description: "Daily general knowledge quiz and live duels with friends.",
};

export async function generateStaticParams() {
  return locales.map((lang) => ({ lang }));
}

export default async function RootLayout({ children, params }: LayoutProps<"/[lang]">) {
  const { lang } = await params;
  if (!hasLocale(lang)) notFound();

  return (
    <html lang={lang} className={`${geist.variable} h-full antialiased`}>
      <body className="min-h-full flex flex-col items-center px-4 pb-12 font-sans">
        <header className="flex w-full max-w-xl items-center justify-between py-5">
          <Link href={`/${lang}`} className="flex items-center gap-2 text-lg font-black tracking-tight">
            <span className="grid h-9 w-9 place-items-center rounded-xl bg-gradient-to-br from-indigo-500 to-fuchsia-500 text-white shadow-md">
              ?
            </span>
            GKD
          </Link>
          <Suspense fallback={<LanguageSwitch lang={lang} staticPath />}>
            <LanguageSwitch lang={lang} />
          </Suspense>
        </header>
        <div className="flex w-full flex-1 flex-col items-center pt-4">{children}</div>
      </body>
    </html>
  );
}
