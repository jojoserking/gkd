import "server-only";
import { cacheLife } from "next/cache";
import { questions as localQuestions, type Category, type Question } from "./questions";
import { isSupabaseConfigured, supabaseAdmin } from "./supabase/server";

type Row = {
  id: string;
  category: string;
  text_de: string;
  options_de: string[];
  text_en: string;
  options_en: string[];
  answer: number;
  active: boolean;
};

function fromRow(r: Row): Question {
  return {
    id: r.id,
    category: r.category as Category,
    de: { text: r.text_de, options: r.options_de as Question["de"]["options"] },
    en: { text: r.text_en, options: r.options_en as Question["en"]["options"] },
    answer: r.answer as Question["answer"],
  };
}

async function loadFromSupabase(): Promise<Row[]> {
  "use cache";
  cacheLife("minutes");
  const { data, error } = await supabaseAdmin()
    .from("questions")
    .select("id, category, text_de, options_de, text_en, options_en, answer, active")
    .order("id");
  if (error) throw new Error(`Fragen konnten nicht geladen werden: ${error.message}`);
  return data as Row[];
}

// Fragen aus Supabase plus alle Fragen aus dem Code, die dort noch fehlen.
// So sind neue Fragen sofort im Spiel, ohne dass jemand SQL ausführen muss.
// Eine Frage, die in Supabase auf active = false steht, bleibt ausgeschaltet.
function merge(rows: Row[]): Question[] {
  const known = new Set(rows.map((r) => r.id));
  const fromDb = rows.filter((r) => r.active).map(fromRow);
  return [...fromDb, ...localQuestions.filter((q) => !known.has(q.id))];
}

// Alle Fragen. Kommen aus Supabase (plus neue aus dem Code), sobald es eingerichtet ist.
// Bis dahin (oder bei einem Fehler) nehmen wir nur die Fragen aus questions.ts,
// damit die Website nie kaputtgeht.
export async function getQuestionPool(): Promise<Question[]> {
  if (!isSupabaseConfigured()) return localQuestions;
  try {
    const pool = merge(await loadFromSupabase());
    return pool.length > 0 ? pool : localQuestions;
  } catch (e) {
    console.error(e);
    return localQuestions;
  }
}

export async function getQuestionsByIds(ids: string[]): Promise<Map<string, Question>> {
  const pool = await getQuestionPool();
  const wanted = new Set(ids);
  return new Map(pool.filter((q) => wanted.has(q.id)).map((q) => [q.id, q]));
}
