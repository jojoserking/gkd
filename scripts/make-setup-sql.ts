// Erzeugt supabase/setup.sql: Tabellen (aus supabase/schema.sql) plus die Beispielfragen
// aus src/lib/questions.ts. Aufruf: npm run setup:sql
import { readFileSync, writeFileSync } from "node:fs";
import { questions } from "../src/lib/questions.ts";

const q = (s: string) => `'${s.replace(/'/g, "''")}'`;
const arr = (a: string[]) => `array[${a.map(q).join(", ")}]`;

const rows = questions.map(
  (x) =>
    `  (${q(x.id)}, ${q(x.category)}, ${q(x.de.text)}, ${arr(x.de.options)}, ${q(x.en.text)}, ${arr(x.en.options)}, ${x.answer})`,
);

const schema = readFileSync(new URL("../supabase/schema.sql", import.meta.url), "utf8");

const sql = `-- AUTOMATISCH ERZEUGT mit "npm run setup:sql". Nicht von Hand ändern,
-- sondern supabase/schema.sql oder src/lib/questions.ts ändern.
-- Kompletten Inhalt in den Supabase SQL-Editor kopieren und auf "Run" klicken.

${schema}
-- Beispielfragen
insert into questions (id, category, text_de, options_de, text_en, options_en, answer) values
${rows.join(",\n")}
on conflict (id) do update set
  category = excluded.category, text_de = excluded.text_de, options_de = excluded.options_de,
  text_en = excluded.text_en, options_en = excluded.options_en, answer = excluded.answer;
`;
writeFileSync(new URL("../supabase/setup.sql", import.meta.url), sql);
console.log(`${questions.length} Fragen nach supabase/setup.sql geschrieben`);
