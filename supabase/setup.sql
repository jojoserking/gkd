-- AUTOMATISCH ERZEUGT mit "npm run setup:sql". Nicht von Hand ändern,
-- sondern supabase/schema.sql oder src/lib/questions.ts ändern.
-- Kompletten Inhalt in den Supabase SQL-Editor kopieren und auf "Run" klicken.

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

-- Beispielfragen
insert into questions (id, category, text_de, options_de, text_en, options_en, answer) values
  ('geo-001', 'geography', 'Was ist die Hauptstadt von Australien?', array['Sydney', 'Canberra', 'Melbourne', 'Perth'], 'What is the capital of Australia?', array['Sydney', 'Canberra', 'Melbourne', 'Perth'], 1),
  ('geo-002', 'geography', 'Welcher ist der längste Fluss Deutschlands?', array['Elbe', 'Donau', 'Rhein', 'Main'], 'Which river flows the longest distance within Germany?', array['Elbe', 'Danube', 'Rhine', 'Main'], 2),
  ('geo-003', 'geography', 'Auf welchem Kontinent liegt Ägypten?', array['Asien', 'Afrika', 'Europa', 'Südamerika'], 'On which continent is Egypt?', array['Asia', 'Africa', 'Europe', 'South America'], 1),
  ('geo-004', 'geography', 'Welcher ist der höchste Berg der Erde?', array['K2', 'Mont Blanc', 'Kilimandscharo', 'Mount Everest'], 'What is the highest mountain on Earth?', array['K2', 'Mont Blanc', 'Kilimanjaro', 'Mount Everest'], 3),
  ('geo-005', 'geography', 'Welches Land hat die meisten Einwohner?', array['Indien', 'USA', 'China', 'Indonesien'], 'Which country has the largest population?', array['India', 'USA', 'China', 'Indonesia'], 0),
  ('geo-006', 'geography', 'Welcher Ozean ist der größte?', array['Atlantik', 'Indischer Ozean', 'Pazifik', 'Arktischer Ozean'], 'Which ocean is the largest?', array['Atlantic', 'Indian Ocean', 'Pacific', 'Arctic Ocean'], 2),
  ('his-001', 'history', 'In welchem Jahr fiel die Berliner Mauer?', array['1987', '1989', '1990', '1991'], 'In which year did the Berlin Wall fall?', array['1987', '1989', '1990', '1991'], 1),
  ('his-002', 'history', 'Wer war der erste Mensch auf dem Mond?', array['Buzz Aldrin', 'Juri Gagarin', 'Neil Armstrong', 'Michael Collins'], 'Who was the first person to walk on the Moon?', array['Buzz Aldrin', 'Yuri Gagarin', 'Neil Armstrong', 'Michael Collins'], 2),
  ('his-003', 'history', 'In welchem Jahr begann der Erste Weltkrieg?', array['1912', '1914', '1916', '1918'], 'In which year did World War I begin?', array['1912', '1914', '1916', '1918'], 1),
  ('his-004', 'history', 'Welches Volk baute die Pyramiden von Gizeh?', array['Die Römer', 'Die Griechen', 'Die alten Ägypter', 'Die Maya'], 'Which people built the pyramids of Giza?', array['The Romans', 'The Greeks', 'The ancient Egyptians', 'The Maya'], 2),
  ('his-005', 'history', 'Wer erfand den Buchdruck mit beweglichen Lettern in Europa?', array['Johannes Gutenberg', 'Martin Luther', 'Leonardo da Vinci', 'Galileo Galilei'], 'Who invented printing with movable type in Europe?', array['Johannes Gutenberg', 'Martin Luther', 'Leonardo da Vinci', 'Galileo Galilei'], 0),
  ('sci-001', 'science', 'Welches chemische Symbol hat Gold?', array['Go', 'Gd', 'Au', 'Ag'], 'What is the chemical symbol for gold?', array['Go', 'Gd', 'Au', 'Ag'], 2),
  ('sci-002', 'science', 'Welcher Planet ist der Sonne am nächsten?', array['Venus', 'Merkur', 'Mars', 'Erde'], 'Which planet is closest to the Sun?', array['Venus', 'Mercury', 'Mars', 'Earth'], 1),
  ('sci-003', 'science', 'Bei wie viel Grad Celsius kocht Wasser auf Meereshöhe?', array['90 °C', '100 °C', '110 °C', '120 °C'], 'At what temperature does water boil at sea level?', array['90 °C', '100 °C', '110 °C', '120 °C'], 1),
  ('sci-004', 'science', 'Wie viele Knochen hat ein erwachsener Mensch ungefähr?', array['106', '156', '206', '306'], 'About how many bones does an adult human have?', array['106', '156', '206', '306'], 2),
  ('sci-005', 'science', 'Welches Gas brauchen Pflanzen für die Fotosynthese?', array['Sauerstoff', 'Stickstoff', 'Kohlendioxid', 'Helium'], 'Which gas do plants need for photosynthesis?', array['Oxygen', 'Nitrogen', 'Carbon dioxide', 'Helium'], 2),
  ('sci-006', 'science', 'Wie viele Planeten hat unser Sonnensystem?', array['7', '8', '9', '10'], 'How many planets are in our solar system?', array['7', '8', '9', '10'], 1),
  ('cul-001', 'culture', 'Wer malte die Mona Lisa?', array['Michelangelo', 'Raffael', 'Leonardo da Vinci', 'Vincent van Gogh'], 'Who painted the Mona Lisa?', array['Michelangelo', 'Raphael', 'Leonardo da Vinci', 'Vincent van Gogh'], 2),
  ('cul-002', 'culture', 'Wer schrieb „Romeo und Julia“?', array['Goethe', 'William Shakespeare', 'Charles Dickens', 'Friedrich Schiller'], 'Who wrote “Romeo and Juliet”?', array['Goethe', 'William Shakespeare', 'Charles Dickens', 'Friedrich Schiller'], 1),
  ('cul-003', 'culture', 'Aus welchem Land stammt die Band ABBA?', array['Norwegen', 'Dänemark', 'Schweden', 'Finnland'], 'Which country is the band ABBA from?', array['Norway', 'Denmark', 'Sweden', 'Finland'], 2),
  ('cul-004', 'culture', 'Welcher Komponist wurde in Bonn geboren?', array['Mozart', 'Ludwig van Beethoven', 'Johann Sebastian Bach', 'Richard Wagner'], 'Which composer was born in Bonn?', array['Mozart', 'Ludwig van Beethoven', 'Johann Sebastian Bach', 'Richard Wagner'], 1),
  ('cul-005', 'culture', 'In welcher Stadt steht der Eiffelturm?', array['Lyon', 'Brüssel', 'Paris', 'Marseille'], 'In which city is the Eiffel Tower?', array['Lyon', 'Brussels', 'Paris', 'Marseille'], 2),
  ('spo-001', 'sport', 'Wie viele Spieler hat eine Fußballmannschaft auf dem Feld?', array['9', '10', '11', '12'], 'How many players does a football (soccer) team have on the field?', array['9', '10', '11', '12'], 2),
  ('spo-002', 'sport', 'Wie oft wurde Deutschland (inkl. BRD) bis 2022 Fußball-Weltmeister der Männer?', array['2-mal', '3-mal', '4-mal', '5-mal'], 'How many men''s FIFA World Cups had Germany (incl. West Germany) won by 2022?', array['2', '3', '4', '5'], 2),
  ('spo-003', 'sport', 'Wie viele Ringe hat das olympische Symbol?', array['4', '5', '6', '7'], 'How many rings are in the Olympic symbol?', array['4', '5', '6', '7'], 1),
  ('spo-004', 'sport', 'In welcher Sportart gibt es einen „Slam Dunk“?', array['Volleyball', 'Tennis', 'Basketball', 'Handball'], 'In which sport is there a “slam dunk”?', array['Volleyball', 'Tennis', 'Basketball', 'Handball'], 2),
  ('nat-001', 'nature', 'Welches ist das größte Säugetier der Welt?', array['Afrikanischer Elefant', 'Blauwal', 'Giraffe', 'Pottwal'], 'What is the largest mammal in the world?', array['African elephant', 'Blue whale', 'Giraffe', 'Sperm whale'], 1),
  ('nat-002', 'nature', 'Wie viele Beine hat eine Spinne?', array['6', '8', '10', '12'], 'How many legs does a spider have?', array['6', '8', '10', '12'], 1),
  ('nat-003', 'nature', 'Welches Tier ist das schnellste an Land?', array['Löwe', 'Gepard', 'Pferd', 'Antilope'], 'Which is the fastest land animal?', array['Lion', 'Cheetah', 'Horse', 'Antelope'], 1),
  ('nat-004', 'nature', 'Wovon ernähren sich Pandas hauptsächlich?', array['Fisch', 'Bambus', 'Früchte', 'Insekten'], 'What do pandas mainly eat?', array['Fish', 'Bamboo', 'Fruit', 'Insects'], 1)
on conflict (id) do update set
  category = excluded.category, text_de = excluded.text_de, options_de = excluded.options_de,
  text_en = excluded.text_en, options_en = excluded.options_en, answer = excluded.answer;
