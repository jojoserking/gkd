# Supabase einrichten (einmalig, ca. 5 Minuten)

1. In Supabase dein Projekt öffnen, links auf **SQL Editor** klicken, dann **New query**.
2. Den kompletten Inhalt von [`setup.sql`](./setup.sql) hineinkopieren und auf **Run** klicken.
   Es sollte „Success“ erscheinen. Damit gibt es die Tabellen, die Sicherheitsregeln,
   die Live-Updates und 30 Beispielfragen.
3. Bei Vercel (Projekt → Settings → Environment Variables) diese drei Variablen anlegen:
   - `NEXT_PUBLIC_SUPABASE_URL` = Project URL (Supabase → Project Settings → Data API)
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY` = publishable bzw. anon-Schlüssel (Project Settings → API Keys)
   - `SUPABASE_SERVICE_ROLE_KEY` = secret bzw. service_role-Schlüssel (Project Settings → API Keys)
4. Bei Vercel unter **Deployments** das neueste Deployment neu bauen lassen („Redeploy“),
   damit die Variablen wirken.

Ohne diese Schritte läuft das Tagesquiz trotzdem (mit den Beispielfragen aus dem Code),
und das Live-Duell zeigt „noch nicht eingerichtet“.

## Neue Fragen hinzufügen

Am einfachsten im Supabase **Table Editor**, Tabelle `questions`, „Insert row“.
`answer` ist die Position der richtigen Antwort: 0 = erste, 1 = zweite, 2 = dritte, 3 = vierte.
Mit `active = false` wird eine Frage ausgeblendet. Änderungen erscheinen nach wenigen Minuten.
