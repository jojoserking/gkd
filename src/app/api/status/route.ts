import { connection } from "next/server";
import { isSupabaseConfigured, supabaseAdmin } from "@/lib/supabase/server";
import { getQuestionPool } from "@/lib/questionStore";

// Diagnoseseite: /api/status zeigt, ob das Live-Duell richtig eingerichtet ist.
// Es werden nur Ja/Nein und Fehlermeldungen gezeigt, niemals Schlüssel.
export async function GET() {
  await connection();
  const env = {
    NEXT_PUBLIC_SUPABASE_URL: Boolean(process.env.NEXT_PUBLIC_SUPABASE_URL),
    NEXT_PUBLIC_SUPABASE_ANON_KEY: Boolean(process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY),
    SUPABASE_SERVICE_ROLE_KEY: Boolean(process.env.SUPABASE_SERVICE_ROLE_KEY),
  };
  const checks: Record<string, string> = {};
  if (isSupabaseConfigured()) {
    const db = supabaseAdmin();
    for (const table of ["questions", "rooms", "room_players", "player_secrets", "room_answers"]) {
      const { count, error } = await db.from(table).select("*", { count: "exact", head: true });
      checks[`table ${table}`] = error ? `FEHLER: ${error.message || error.code}` : `ok (${count ?? 0} Zeilen)`;
    }
  }
  const allEnv = Object.values(env).every(Boolean);
  const allChecks = Object.values(checks).every((v) => v.startsWith("ok"));
  return Response.json(
    {
      liveDuelReady: allEnv && allChecks,
      env,
      checks,
      questionsAvailable: (await getQuestionPool()).length,
      hint: !allEnv
        ? "Mindestens eine Umgebungsvariable fehlt. In Vercel eintragen und danach neu deployen (Redeploy)."
        : !allChecks
          ? "Supabase antwortet mit einem Fehler. Wurde supabase/setup.sql komplett ausgeführt? Ist der geheime Schlüssel richtig?"
          : "Alles bereit.",
    },
    { headers: { "Cache-Control": "no-store" } },
  );
}
