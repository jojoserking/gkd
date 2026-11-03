import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

const locales = ["de", "en"];

function pickLocale(request: NextRequest): string {
  const header = request.headers.get("accept-language") ?? "";
  // Erste Sprache im Browser, die wir anbieten, sonst Englisch
  for (const part of header.split(",")) {
    const code = part.split(";")[0].trim().slice(0, 2).toLowerCase();
    if (locales.includes(code)) return code;
  }
  return "en";
}

export function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const hasLocale = locales.some(
    (l) => pathname === `/${l}` || pathname.startsWith(`/${l}/`),
  );
  if (hasLocale) return;

  request.nextUrl.pathname = `/${pickLocale(request)}${pathname}`;
  return NextResponse.redirect(request.nextUrl);
}

export const config = {
  // Nicht für API, interne Next.js-Dateien und Dateien mit Endung
  matcher: ["/((?!api|_next|.*\\..*).*)"],
};
