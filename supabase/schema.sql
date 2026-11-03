-- GKD Datenbank. Einmal komplett im Supabase SQL-Editor ausführen.
-- Man kann es auch mehrmals ausführen, es geht dabei nichts kaputt.

-- Fragen. Nur der Server darf sie lesen, damit die Lösung nie im Browser landet.
create table if not exists questions (
  id          text primary key,
  category    text not null,
  text_de     text not null,
  options_de  text[] not null check (array_length(options_de, 1) = 4),
  text_en     text not null,
  options_en  text[] not null check (array_length(options_en, 1) = 4),
  answer      smallint not null check (answer between 0 and 3),
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

-- Ein Duell-Raum, erkennbar am 5-stelligen Code
create table if not exists rooms (
  code                 text primary key,
  host_player_id       uuid,
  status               text not null default 'lobby'
                       check (status in ('lobby', 'question', 'reveal', 'finished')),
  current_index        smallint not null default 0,
  question_started_at  timestamptz,
  question_ids         text[] not null,
  created_at           timestamptz not null default now()
);

-- Mitspieler in einem Raum (ohne Konto, nur mit Spitznamen)
create table if not exists room_players (
  id                 uuid primary key default gen_random_uuid(),
  room_code          text not null references rooms(code) on delete cascade,
  nickname           text not null,
  score              integer not null default 0,
  last_answer_index  smallint not null default -1, -- bei welcher Frage zuletzt geantwortet
  joined_at          timestamptz not null default now(),
  unique (room_code, nickname)
);
create index if not exists room_players_room_idx on room_players(room_code);

-- Geheimer Schlüssel pro Spieler. So kann niemand für andere antworten.
create table if not exists player_secrets (
  player_id  uuid primary key references room_players(id) on delete cascade,
  token      text not null
);

-- Jede abgegebene Antwort. Pro Spieler und Frage nur eine.
create table if not exists room_answers (
  room_code       text not null references rooms(code) on delete cascade,
  player_id       uuid not null references room_players(id) on delete cascade,
  question_index  smallint not null,
  choice          smallint not null,
  correct         boolean not null,
  points          integer not null,
  answered_at     timestamptz not null default now(),
  primary key (room_code, player_id, question_index)
);

-- Antwort speichern und Punkte gutschreiben in einem Schritt
create or replace function record_answer(
  p_room text, p_player uuid, p_index smallint, p_choice smallint, p_correct boolean, p_points integer
) returns boolean language plpgsql security definer set search_path = public as $$
begin
  insert into room_answers (room_code, player_id, question_index, choice, correct, points)
  values (p_room, p_player, p_index, p_choice, p_correct, p_points);
  update room_players
     set score = score + p_points, last_answer_index = p_index
   where id = p_player and room_code = p_room;
  return true;
exception when unique_violation then
  return false; -- hat schon geantwortet
end $$;
revoke execute on function record_answer from public, anon, authenticated;
grant execute on function record_answer to service_role;

-- Sicherheit (Row Level Security): Browser dürfen nur Räume und Spieler LESEN.
-- Alles Schreiben läuft über unseren Server mit dem service_role-Schlüssel.
alter table questions      enable row level security;
alter table rooms          enable row level security;
alter table room_players   enable row level security;
alter table player_secrets enable row level security;
alter table room_answers   enable row level security;

drop policy if exists "rooms lesbar" on rooms;
create policy "rooms lesbar" on rooms for select to anon, authenticated using (true);
drop policy if exists "spieler lesbar" on room_players;
create policy "spieler lesbar" on room_players for select to anon, authenticated using (true);
-- questions, player_secrets, room_answers: keine Policy = für Browser gesperrt.

-- Rechte ausdrücklich setzen (falls neue Tabellen nicht automatisch freigegeben werden)
grant select on rooms, room_players to anon, authenticated;
revoke all on questions, player_secrets, room_answers from anon, authenticated;
grant all on questions, rooms, room_players, player_secrets, room_answers to service_role;

-- Live-Updates (Realtime) für Räume und Spieler einschalten
do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and tablename = 'rooms') then
    alter publication supabase_realtime add table rooms;
  end if;
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and tablename = 'room_players') then
    alter publication supabase_realtime add table room_players;
  end if;
end $$;
