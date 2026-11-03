import "server-only";
import { isSupabaseConfigured } from "@/lib/supabase/server";
import { DuelError } from "./server";

// Gemeinsame Hilfe für alle Duell-API-Routen: JSON lesen, Fehler sauber zurückgeben.
export async function readJson(request: Request): Promise<Record<string, unknown>> {
  try {
    const body = await request.json();
    return body && typeof body === "object" ? (body as Record<string, unknown>) : {};
  } catch {
    throw new DuelError("invalid_json");
  }
}

export async function handle(fn: () => Promise<unknown>): Promise<Response> {
  if (!isSupabaseConfigured()) return Response.json({ error: "not_configured" }, { status: 503 });
  try {
    return Response.json((await fn()) ?? { ok: true });
  } catch (e) {
    if (e instanceof DuelError) return Response.json({ error: e.code }, { status: e.status });
    console.error(e);
    return Response.json({ error: "server_error" }, { status: 500 });
  }
}
