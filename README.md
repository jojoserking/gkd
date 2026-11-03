# GKD · General Knowledge Duel

Allgemeinwissen-Quiz: jeden Tag 10 neue Fragen, bald auch live gegen Freunde. Auf Deutsch und Englisch.

## Stand

- Tagesquiz mit 10 Fragen pro Tag, für alle gleich (wechselt um Mitternacht deutscher Zeit)
- Antworten werden auf dem Server geprüft, die Lösung kommt nie in den Browser
- Ergebnis teilen (z. B. per WhatsApp), Ergebnis bleibt nach dem Neuladen erhalten
- Deutsch (`/de`) und Englisch (`/en`), die Sprache wird aus dem Browser erkannt
- 30 Beispielfragen in `src/lib/questions.ts`

## Lokal starten

Du brauchst [Node.js](https://nodejs.org) (Version 20 oder neuer).

```bash
npm install
npm run dev
```

Dann im Browser http://localhost:3000 öffnen.

## Wichtige Dateien

| Datei | Was drin ist |
| --- | --- |
| `src/lib/questions.ts` | Der Fragenpool (später in Supabase) |
| `src/lib/daily.ts` | Wählt jeden Tag 10 Fragen aus |
| `src/app/api/daily/answer/route.ts` | Prüft Antworten auf dem Server |
| `src/components/DailyQuiz.tsx` | Das Quiz, das man im Browser sieht |
| `src/dictionaries/de.json`, `en.json` | Alle Texte der Seite pro Sprache |

## Nächste Schritte

1. Online stellen mit Vercel
2. Fragen in die Datenbank (Supabase) verschieben und auf 500 ausbauen
3. Live-Duell mit Supabase Realtime
