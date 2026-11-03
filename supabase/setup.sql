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
  ('nat-004', 'nature', 'Wovon ernähren sich Pandas hauptsächlich?', array['Fisch', 'Bambus', 'Früchte', 'Insekten'], 'What do pandas mainly eat?', array['Fish', 'Bamboo', 'Fruit', 'Insects'], 1),
  ('geo-007', 'geography', 'Was ist die Hauptstadt von Kanada?', array['Montreal', 'Toronto', 'Vancouver', 'Ottawa'], 'What is the capital of Canada?', array['Montreal', 'Toronto', 'Vancouver', 'Ottawa'], 3),
  ('geo-008', 'geography', 'Welche ist die größte heiße Wüste der Erde?', array['Gobi', 'Atacama', 'Kalahari', 'Sahara'], 'What is the largest hot desert on Earth?', array['Gobi', 'Atacama', 'Kalahari', 'Sahara'], 3),
  ('geo-009', 'geography', 'Wie viele Bundesländer hat Deutschland?', array['12', '14', '16', '18'], 'How many federal states does Germany have?', array['12', '14', '16', '18'], 2),
  ('geo-010', 'geography', 'Was ist die Hauptstadt von Japan?', array['Osaka', 'Nagoya', 'Kyoto', 'Tokio'], 'What is the capital of Japan?', array['Osaka', 'Nagoya', 'Kyoto', 'Tokyo'], 3),
  ('geo-011', 'geography', 'Welches Land hat ungefähr die Form eines Stiefels?', array['Italien', 'Griechenland', 'Spanien', 'Portugal'], 'Which country is roughly shaped like a boot?', array['Italy', 'Greece', 'Spain', 'Portugal'], 0),
  ('geo-012', 'geography', 'Welches ist das flächenmäßig größte Land der Welt?', array['Russland', 'Kanada', 'USA', 'China'], 'Which is the largest country in the world by area?', array['Russia', 'Canada', 'USA', 'China'], 0),
  ('geo-013', 'geography', 'Welches Meer liegt zwischen Europa und Afrika?', array['Mittelmeer', 'Ostsee', 'Schwarzes Meer', 'Nordsee'], 'Which sea lies between Europe and Africa?', array['Mediterranean Sea', 'Baltic Sea', 'Black Sea', 'North Sea'], 0),
  ('geo-014', 'geography', 'Was ist die Hauptstadt von Spanien?', array['Sevilla', 'Barcelona', 'Valencia', 'Madrid'], 'What is the capital of Spain?', array['Seville', 'Barcelona', 'Valencia', 'Madrid'], 3),
  ('geo-015', 'geography', 'In welchem Land liegt Machu Picchu?', array['Mexiko', 'Chile', 'Peru', 'Bolivien'], 'In which country is Machu Picchu?', array['Mexico', 'Chile', 'Peru', 'Bolivia'], 2),
  ('geo-016', 'geography', 'Was ist die Hauptstadt der Türkei?', array['Istanbul', 'Antalya', 'Ankara', 'Izmir'], 'What is the capital of Turkey?', array['Istanbul', 'Antalya', 'Ankara', 'Izmir'], 2),
  ('geo-017', 'geography', 'Wie heißt der höchste Berg Deutschlands?', array['Brocken', 'Watzmann', 'Zugspitze', 'Feldberg'], 'What is the highest mountain in Germany?', array['Brocken', 'Watzmann', 'Zugspitze', 'Feldberg'], 2),
  ('geo-018', 'geography', 'Welcher Kontinent ist der kleinste?', array['Südamerika', 'Antarktis', 'Europa', 'Australien/Ozeanien'], 'Which is the smallest continent?', array['South America', 'Antarctica', 'Europe', 'Australia/Oceania'], 3),
  ('geo-019', 'geography', 'Durch welche Stadt fließt die Themse?', array['Edinburgh', 'Dublin', 'London', 'Manchester'], 'Which city does the River Thames flow through?', array['Edinburgh', 'Dublin', 'London', 'Manchester'], 2),
  ('geo-020', 'geography', 'Was ist die Hauptstadt von Brasilien?', array['Salvador', 'São Paulo', 'Rio de Janeiro', 'Brasília'], 'What is the capital of Brazil?', array['Salvador', 'São Paulo', 'Rio de Janeiro', 'Brasília'], 3),
  ('geo-021', 'geography', 'Welches dieser Länder grenzt an Deutschland?', array['Ungarn', 'Dänemark', 'Slowenien', 'Italien'], 'Which of these countries borders Germany?', array['Hungary', 'Denmark', 'Slovenia', 'Italy'], 1),
  ('geo-022', 'geography', 'Was ist die Hauptstadt von Norwegen?', array['Oslo', 'Helsinki', 'Bergen', 'Stockholm'], 'What is the capital of Norway?', array['Oslo', 'Helsinki', 'Bergen', 'Stockholm'], 0),
  ('geo-023', 'geography', 'Welcher Fluss fließt durch Wien?', array['Moldau', 'Elbe', 'Donau', 'Rhein'], 'Which river flows through Vienna?', array['Vltava', 'Elbe', 'Danube', 'Rhine'], 2),
  ('geo-024', 'geography', 'Auf welcher Insel liegt der Vulkan Ätna?', array['Sardinien', 'Kreta', 'Korsika', 'Sizilien'], 'On which island is the volcano Mount Etna?', array['Sardinia', 'Crete', 'Corsica', 'Sicily'], 3),
  ('geo-025', 'geography', 'In welcher Stadt sitzt die Schweizer Regierung?', array['Zürich', 'Genf', 'Bern', 'Basel'], 'In which city is the Swiss government based?', array['Zurich', 'Geneva', 'Bern', 'Basel'], 2),
  ('geo-026', 'geography', 'Welches Land hat die Hauptstadt Nairobi?', array['Kenia', 'Tansania', 'Äthiopien', 'Uganda'], 'Which country''s capital is Nairobi?', array['Kenya', 'Tanzania', 'Ethiopia', 'Uganda'], 0),
  ('geo-027', 'geography', 'Welcher ist der größte See Afrikas?', array['Victoriasee', 'Malawisee', 'Tschadsee', 'Tanganjikasee'], 'What is the largest lake in Africa?', array['Lake Victoria', 'Lake Malawi', 'Lake Chad', 'Lake Tanganyika'], 0),
  ('geo-028', 'geography', 'In welchem Land steht die Freiheitsstatue?', array['Frankreich', 'Kanada', 'England', 'USA'], 'In which country is the Statue of Liberty?', array['France', 'Canada', 'England', 'USA'], 3),
  ('geo-029', 'geography', 'Welche Stadt hat den Spitznamen „Big Apple“?', array['Los Angeles', 'Chicago', 'New York City', 'Boston'], 'Which city is nicknamed “the Big Apple”?', array['Los Angeles', 'Chicago', 'New York City', 'Boston'], 2),
  ('geo-030', 'geography', 'Was ist die Hauptstadt von Argentinien?', array['Santiago de Chile', 'Lima', 'Buenos Aires', 'Montevideo'], 'What is the capital of Argentina?', array['Santiago de Chile', 'Lima', 'Buenos Aires', 'Montevideo'], 2),
  ('geo-031', 'geography', 'Welche Meerenge trennt bei Istanbul Europa und Asien?', array['Straße von Gibraltar', 'Ärmelkanal', 'Beringstraße', 'Bosporus'], 'Which strait separates Europe and Asia at Istanbul?', array['Strait of Gibraltar', 'English Channel', 'Bering Strait', 'Bosphorus'], 3),
  ('geo-032', 'geography', 'Welches ist das flächenmäßig größte Land Südamerikas?', array['Brasilien', 'Kolumbien', 'Peru', 'Argentinien'], 'Which is the largest country in South America by area?', array['Brazil', 'Colombia', 'Peru', 'Argentina'], 0),
  ('geo-033', 'geography', 'Welche ist die größte Insel der Welt?', array['Borneo', 'Neuguinea', 'Grönland', 'Madagaskar'], 'What is the largest island in the world?', array['Borneo', 'New Guinea', 'Greenland', 'Madagascar'], 2),
  ('geo-034', 'geography', 'Was ist die Hauptstadt von Polen?', array['Danzig', 'Warschau', 'Krakau', 'Breslau'], 'What is the capital of Poland?', array['Gdańsk', 'Warsaw', 'Kraków', 'Wrocław'], 1),
  ('geo-035', 'geography', 'In welchem Ozean liegt Hawaii?', array['Arktischer Ozean', 'Indischer Ozean', 'Atlantik', 'Pazifik'], 'In which ocean is Hawaii?', array['Arctic Ocean', 'Indian Ocean', 'Atlantic Ocean', 'Pacific Ocean'], 3),
  ('geo-036', 'geography', 'Welches Land hat ein Ahornblatt auf der Flagge?', array['Kanada', 'Schweiz', 'Neuseeland', 'Schweden'], 'Which country has a maple leaf on its flag?', array['Canada', 'Switzerland', 'New Zealand', 'Sweden'], 0),
  ('his-006', 'history', 'In welchem Jahr erreichte Kolumbus Amerika?', array['1492', '1607', '1453', '1513'], 'In which year did Columbus reach the Americas?', array['1492', '1607', '1453', '1513'], 0),
  ('his-007', 'history', 'Wer war der erste Bundeskanzler der Bundesrepublik Deutschland?', array['Konrad Adenauer', 'Ludwig Erhard', 'Helmut Schmidt', 'Willy Brandt'], 'Who was the first Chancellor of West Germany?', array['Konrad Adenauer', 'Ludwig Erhard', 'Helmut Schmidt', 'Willy Brandt'], 0),
  ('his-008', 'history', 'In welchem Jahr wurde Deutschland wiedervereinigt?', array['1993', '1989', '1991', '1990'], 'In which year was Germany reunified?', array['1993', '1989', '1991', '1990'], 3),
  ('his-009', 'history', 'Welcher Herrscher wurde im Jahr 800 zum Kaiser gekrönt?', array['Karl der Große', 'Otto der Große', 'Friedrich Barbarossa', 'Ludwig der Fromme'], 'Which ruler was crowned emperor in the year 800?', array['Charlemagne', 'Otto the Great', 'Frederick Barbarossa', 'Louis the Pious'], 0),
  ('his-010', 'history', 'In welchem Jahr endete der Zweite Weltkrieg?', array['1944', '1943', '1945', '1946'], 'In which year did World War II end?', array['1944', '1943', '1945', '1946'], 2),
  ('his-011', 'history', 'Welches Schiff sank 1912 nach dem Zusammenstoß mit einem Eisberg?', array['Lusitania', 'Bismarck', 'Britannic', 'Titanic'], 'Which ship sank in 1912 after hitting an iceberg?', array['Lusitania', 'Bismarck', 'Britannic', 'Titanic'], 3),
  ('his-012', 'history', 'Wer war der erste Präsident der USA?', array['Abraham Lincoln', 'John Adams', 'George Washington', 'Thomas Jefferson'], 'Who was the first President of the United States?', array['Abraham Lincoln', 'John Adams', 'George Washington', 'Thomas Jefferson'], 2),
  ('his-013', 'history', 'Welche Stadt wurde 79 n. Chr. beim Ausbruch des Vesuvs verschüttet?', array['Athen', 'Rom', 'Pompeji', 'Neapel'], 'Which city was buried by the eruption of Mount Vesuvius in AD 79?', array['Athens', 'Rome', 'Pompeii', 'Naples'], 2),
  ('his-014', 'history', 'In welcher Schlacht wurde Napoleon 1815 endgültig besiegt?', array['Austerlitz', 'Leipzig', 'Waterloo', 'Trafalgar'], 'At which battle was Napoleon finally defeated in 1815?', array['Austerlitz', 'Leipzig', 'Waterloo', 'Trafalgar'], 2),
  ('his-015', 'history', 'Welche Revolution begann im Jahr 1789?', array['Industrielle Revolution', 'Russische Revolution', 'Amerikanische Revolution', 'Französische Revolution'], 'Which revolution began in 1789?', array['Industrial Revolution', 'Russian Revolution', 'American Revolution', 'French Revolution'], 3),
  ('his-016', 'history', 'Wer veröffentlichte 1517 die 95 Thesen?', array['Erasmus von Rotterdam', 'Martin Luther', 'Jan Hus', 'Johannes Calvin'], 'Who published the 95 Theses in 1517?', array['Erasmus of Rotterdam', 'Martin Luther', 'Jan Hus', 'John Calvin'], 1),
  ('his-017', 'history', 'Welches Volk baute Machu Picchu?', array['Olmeken', 'Inka', 'Maya', 'Azteken'], 'Which civilization built Machu Picchu?', array['Olmecs', 'Inca', 'Maya', 'Aztecs'], 1),
  ('his-018', 'history', 'Wer war die erste Frau, die einen Nobelpreis bekam?', array['Rosalind Franklin', 'Bertha von Suttner', 'Marie Curie', 'Lise Meitner'], 'Who was the first woman to win a Nobel Prize?', array['Rosalind Franklin', 'Bertha von Suttner', 'Marie Curie', 'Lise Meitner'], 2),
  ('his-019', 'history', 'Welches Land schenkte den USA die Freiheitsstatue?', array['Frankreich', 'Spanien', 'Niederlande', 'England'], 'Which country gave the Statue of Liberty to the USA?', array['France', 'Spain', 'Netherlands', 'England'], 0),
  ('his-020', 'history', 'In welchem Jahr wurde die Berliner Mauer gebaut?', array['1961', '1953', '1968', '1949'], 'In which year was the Berlin Wall built?', array['1961', '1953', '1968', '1949'], 0),
  ('his-021', 'history', 'Wer flog 1961 als erster Mensch ins Weltall?', array['Juri Gagarin', 'Alan Shepard', 'Neil Armstrong', 'John Glenn'], 'Who became the first person in space in 1961?', array['Yuri Gagarin', 'Alan Shepard', 'Neil Armstrong', 'John Glenn'], 0),
  ('his-022', 'history', 'In welcher Stadt wurde John F. Kennedy 1963 ermordet?', array['Washington', 'New York', 'Dallas', 'Chicago'], 'In which city was John F. Kennedy assassinated in 1963?', array['Washington, D.C.', 'New York', 'Dallas', 'Chicago'], 2),
  ('his-023', 'history', 'Welcher Pharao wurde durch sein 1922 entdecktes Grab berühmt?', array['Echnaton', 'Ramses II.', 'Cheops', 'Tutanchamun'], 'Which pharaoh became famous for his tomb discovered in 1922?', array['Akhenaten', 'Ramesses II', 'Khufu', 'Tutankhamun'], 3),
  ('his-024', 'history', 'Wer war die erste Bundeskanzlerin Deutschlands?', array['Ursula von der Leyen', 'Annegret Kramp-Karrenbauer', 'Andrea Nahles', 'Angela Merkel'], 'Who was Germany''s first female Chancellor?', array['Ursula von der Leyen', 'Annegret Kramp-Karrenbauer', 'Andrea Nahles', 'Angela Merkel'], 3),
  ('his-025', 'history', 'In welchem Jahr landete Apollo 11 auf dem Mond?', array['1972', '1969', '1961', '1965'], 'In which year did Apollo 11 land on the Moon?', array['1972', '1969', '1961', '1965'], 1),
  ('his-026', 'history', 'Wer war bei der Wiedervereinigung 1990 Bundeskanzler?', array['Gerhard Schröder', 'Helmut Schmidt', 'Helmut Kohl', 'Willy Brandt'], 'Who was German Chancellor at reunification in 1990?', array['Gerhard Schröder', 'Helmut Schmidt', 'Helmut Kohl', 'Willy Brandt'], 2),
  ('his-027', 'history', 'Welche Stadt war vor Berlin die Hauptstadt der Bundesrepublik?', array['Köln', 'Frankfurt am Main', 'München', 'Bonn'], 'Which city was West Germany''s capital before Berlin?', array['Cologne', 'Frankfurt', 'Munich', 'Bonn'], 3),
  ('his-028', 'history', 'Welcher Krieg dauerte von 1618 bis 1648?', array['Siebenjähriger Krieg', 'Hundertjähriger Krieg', 'Spanischer Erbfolgekrieg', 'Dreißigjähriger Krieg'], 'Which war lasted from 1618 to 1648?', array['Seven Years'' War', 'Hundred Years'' War', 'War of the Spanish Succession', 'Thirty Years'' War'], 3),
  ('his-029', 'history', 'Von welchem Land war Nelson Mandela Präsident?', array['Südafrika', 'Simbabwe', 'Kenia', 'Nigeria'], 'Which country did Nelson Mandela lead as president?', array['South Africa', 'Zimbabwe', 'Kenya', 'Nigeria'], 0),
  ('his-030', 'history', 'Wer leitete die Expedition der ersten Weltumsegelung (Start 1519)?', array['Vasco da Gama', 'Ferdinand Magellan', 'Christoph Kolumbus', 'James Cook'], 'Who led the expedition of the first circumnavigation of the globe (started 1519)?', array['Vasco da Gama', 'Ferdinand Magellan', 'Christopher Columbus', 'James Cook'], 1),
  ('his-031', 'history', 'In welchem Jahr kam der Euro als Bargeld in Umlauf?', array['2005', '1999', '2002', '1995'], 'In which year were euro notes and coins introduced?', array['2005', '1999', '2002', '1995'], 2),
  ('his-032', 'history', 'Wer krönte sich 1804 zum Kaiser der Franzosen?', array['Ludwig XVI.', 'Ludwig XIV.', 'Karl X.', 'Napoleon Bonaparte'], 'Who crowned himself Emperor of the French in 1804?', array['Louis XVI', 'Louis XIV', 'Charles X', 'Napoleon Bonaparte'], 3),
  ('his-033', 'history', 'Welche Stadt wurde laut Sage mit dem hölzernen Pferd erobert?', array['Troja', 'Sparta', 'Athen', 'Karthago'], 'According to legend, which city was captured with a wooden horse?', array['Troy', 'Sparta', 'Athens', 'Carthage'], 0),
  ('his-034', 'history', 'Welcher König wurde „Sonnenkönig“ genannt?', array['Ludwig XIV.', 'Ludwig XVI.', 'Friedrich der Große', 'Heinrich VIII.'], 'Which king was called the “Sun King”?', array['Louis XIV', 'Louis XVI', 'Frederick the Great', 'Henry VIII'], 0),
  ('his-035', 'history', 'In welchem Jahr wurden die Vereinten Nationen (UNO) gegründet?', array['1945', '1939', '1950', '1919'], 'In which year was the United Nations founded?', array['1945', '1939', '1950', '1919'], 0),
  ('sci-007', 'science', 'Wie lautet die chemische Formel von Wasser?', array['H₂O', 'O₂', 'H₂O₂', 'CO₂'], 'What is the chemical formula of water?', array['H₂O', 'O₂', 'H₂O₂', 'CO₂'], 0),
  ('sci-008', 'science', 'Welcher Planet wird „Roter Planet“ genannt?', array['Venus', 'Jupiter', 'Merkur', 'Mars'], 'Which planet is called the “Red Planet”?', array['Venus', 'Jupiter', 'Mercury', 'Mars'], 3),
  ('sci-009', 'science', 'Welches ist das größte Organ des Menschen?', array['Haut', 'Lunge', 'Leber', 'Gehirn'], 'What is the largest organ of the human body?', array['Skin', 'Lungs', 'Liver', 'Brain'], 0),
  ('sci-010', 'science', 'Welche Blutgruppe gilt als Universalspender?', array['0 negativ', 'AB positiv', 'B positiv', 'A negativ'], 'Which blood type is known as the universal donor?', array['O negative', 'AB positive', 'B positive', 'A negative'], 0),
  ('sci-011', 'science', 'Wie schnell ist Licht ungefähr?', array['3.000.000 km/s', '300.000 km/s', '30.000 km/s', '3.000 km/s'], 'Roughly how fast is light?', array['3,000,000 km/s', '300,000 km/s', '30,000 km/s', '3,000 km/s'], 1),
  ('sci-012', 'science', 'Wer entwickelte die Relativitätstheorie?', array['Niels Bohr', 'Max Planck', 'Isaac Newton', 'Albert Einstein'], 'Who developed the theory of relativity?', array['Niels Bohr', 'Max Planck', 'Isaac Newton', 'Albert Einstein'], 3),
  ('sci-013', 'science', 'Was misst man in Hertz?', array['Frequenz', 'Spannung', 'Temperatur', 'Druck'], 'What is measured in hertz?', array['Frequency', 'Voltage', 'Temperature', 'Pressure'], 0),
  ('sci-014', 'science', 'Welches Element hat das Symbol O?', array['Wasserstoff', 'Kohlenstoff', 'Sauerstoff', 'Stickstoff'], 'Which element has the symbol O?', array['Hydrogen', 'Carbon', 'Oxygen', 'Nitrogen'], 2),
  ('sci-015', 'science', 'Welches Gas macht den größten Teil der Luft aus?', array['Argon', 'Stickstoff', 'Kohlendioxid', 'Sauerstoff'], 'Which gas makes up most of the air?', array['Argon', 'Nitrogen', 'Carbon dioxide', 'Oxygen'], 1),
  ('sci-016', 'science', 'Welcher ist der größte Planet unseres Sonnensystems?', array['Saturn', 'Neptun', 'Erde', 'Jupiter'], 'What is the largest planet in our solar system?', array['Saturn', 'Neptune', 'Earth', 'Jupiter'], 3),
  ('sci-017', 'science', 'Wer formulierte das Gravitationsgesetz?', array['Galileo Galilei', 'Johannes Kepler', 'Isaac Newton', 'Albert Einstein'], 'Who formulated the law of universal gravitation?', array['Galileo Galilei', 'Johannes Kepler', 'Isaac Newton', 'Albert Einstein'], 2),
  ('sci-018', 'science', 'Wie viele Chromosomen hat ein Mensch normalerweise?', array['46', '23', '48', '44'], 'How many chromosomes does a human normally have?', array['46', '23', '48', '44'], 0),
  ('sci-019', 'science', 'Bei wie viel Grad Celsius gefriert Wasser?', array['0 °C', '32 °C', '4 °C', '-10 °C'], 'At what temperature in Celsius does water freeze?', array['0 °C', '32 °C', '4 °C', '-10 °C'], 0),
  ('sci-020', 'science', 'Welches Metall ist bei Zimmertemperatur flüssig?', array['Quecksilber', 'Blei', 'Zinn', 'Aluminium'], 'Which metal is liquid at room temperature?', array['Mercury', 'Lead', 'Tin', 'Aluminium'], 0),
  ('sci-021', 'science', 'Wie lange braucht das Licht der Sonne ungefähr bis zur Erde?', array['etwa 1 Tag', 'etwa 1 Stunde', 'etwa 8 Sekunden', 'etwa 8 Minuten'], 'About how long does sunlight take to reach Earth?', array['about 1 day', 'about 1 hour', 'about 8 seconds', 'about 8 minutes'], 3),
  ('sci-022', 'science', 'In welcher Einheit misst man elektrische Spannung?', array['Ohm', 'Watt', 'Volt', 'Ampere'], 'In which unit is electrical voltage measured?', array['Ohm', 'Watt', 'Volt', 'Ampere'], 2),
  ('sci-023', 'science', 'Welches Vitamin bildet der Körper mit Hilfe von Sonnenlicht?', array['Vitamin C', 'Vitamin B12', 'Vitamin D', 'Vitamin A'], 'Which vitamin does the body make with the help of sunlight?', array['Vitamin C', 'Vitamin B12', 'Vitamin D', 'Vitamin A'], 2),
  ('sci-024', 'science', 'Wer entdeckte das Penicillin?', array['Alexander Fleming', 'Louis Pasteur', 'Robert Koch', 'Marie Curie'], 'Who discovered penicillin?', array['Alexander Fleming', 'Louis Pasteur', 'Robert Koch', 'Marie Curie'], 0),
  ('sci-025', 'science', 'Was ist die Quadratwurzel aus 144?', array['11', '16', '14', '12'], 'What is the square root of 144?', array['11', '16', '14', '12'], 3),
  ('sci-026', 'science', 'Woraus besteht die Sonne hauptsächlich?', array['Kohlenstoff', 'Sauerstoff', 'Wasserstoff', 'Helium'], 'What is the Sun mainly made of?', array['Carbon', 'Oxygen', 'Hydrogen', 'Helium'], 2),
  ('sci-027', 'science', 'Welche dieser Zahlen ist eine Primzahl?', array['21', '17', '33', '27'], 'Which of these numbers is a prime number?', array['21', '17', '33', '27'], 1),
  ('sci-028', 'science', 'Wo in der Zelle liegt der Großteil der Erbinformation (DNA)?', array['In der Zellmembran', 'In den Ribosomen', 'In der Vakuole', 'Im Zellkern'], 'Where in the cell is most of the genetic information (DNA) stored?', array['In the cell membrane', 'In the ribosomes', 'In the vacuole', 'In the nucleus'], 3),
  ('sci-029', 'science', 'Welchen Wert hat die Kreiszahl Pi ungefähr?', array['3,14', '1,62', '2,72', '3,41'], 'What is the approximate value of pi?', array['3.14', '1.62', '2.72', '3.41'], 0),
  ('sci-030', 'science', 'Welcher Planet ist für seine großen Ringe berühmt?', array['Venus', 'Saturn', 'Mars', 'Merkur'], 'Which planet is famous for its large rings?', array['Venus', 'Saturn', 'Mars', 'Mercury'], 1),
  ('sci-031', 'science', 'Welches chemische Symbol hat Natrium?', array['N', 'Nt', 'So', 'Na'], 'What is the chemical symbol for sodium?', array['N', 'Sd', 'So', 'Na'], 3),
  ('sci-032', 'science', 'Wie groß ist die Winkelsumme in einem Dreieck?', array['180°', '90°', '360°', '270°'], 'What do the angles in a triangle add up to?', array['180°', '90°', '360°', '270°'], 0),
  ('sci-033', 'science', 'Wer stellte 1869 das Periodensystem der Elemente vor?', array['Dmitri Mendelejew', 'John Dalton', 'Robert Boyle', 'Antoine Lavoisier'], 'Who presented the periodic table of elements in 1869?', array['Dmitri Mendeleev', 'John Dalton', 'Robert Boyle', 'Antoine Lavoisier'], 0),
  ('sci-034', 'science', 'Wofür bekam Alexander Graham Bell 1876 ein Patent?', array['Fernseher', 'Glühbirne', 'Radio', 'Telefon'], 'What did Alexander Graham Bell patent in 1876?', array['Television', 'Light bulb', 'Radio', 'Telephone'], 3),
  ('sci-035', 'science', 'Welcher Planet ist am weitesten von der Sonne entfernt?', array['Uranus', 'Neptun', 'Saturn', 'Jupiter'], 'Which planet is farthest from the Sun?', array['Uranus', 'Neptune', 'Saturn', 'Jupiter'], 1),
  ('sci-036', 'science', 'Wie viel ist 7 mal 8?', array['64', '48', '56', '54'], 'What is 7 times 8?', array['64', '48', '56', '54'], 2),
  ('cul-006', 'culture', 'Wer schrieb „Faust“?', array['Johann Wolfgang von Goethe', 'Heinrich Heine', 'Friedrich Schiller', 'Thomas Mann'], 'Who wrote “Faust”?', array['Johann Wolfgang von Goethe', 'Heinrich Heine', 'Friedrich Schiller', 'Thomas Mann'], 0),
  ('cul-007', 'culture', 'Wer komponierte „Die Zauberflöte“?', array['Richard Wagner', 'Johann Sebastian Bach', 'Wolfgang Amadeus Mozart', 'Ludwig van Beethoven'], 'Who composed “The Magic Flute”?', array['Richard Wagner', 'Johann Sebastian Bach', 'Wolfgang Amadeus Mozart', 'Ludwig van Beethoven'], 2),
  ('cul-008', 'culture', 'Wer malte „Die Sternennacht“?', array['Pablo Picasso', 'Paul Cézanne', 'Claude Monet', 'Vincent van Gogh'], 'Who painted “The Starry Night”?', array['Pablo Picasso', 'Paul Cézanne', 'Claude Monet', 'Vincent van Gogh'], 3),
  ('cul-009', 'culture', 'Aus welchem Land kommt Sushi?', array['Japan', 'China', 'Korea', 'Thailand'], 'Which country does sushi come from?', array['Japan', 'China', 'Korea', 'Thailand'], 0),
  ('cul-010', 'culture', 'Wie heißt der junge Zauberer in den Büchern von J. K. Rowling?', array['Harry Potter', 'Frodo Beutlin', 'Percy Jackson', 'Luke Skywalker'], 'What is the name of the young wizard in J. K. Rowling''s books?', array['Harry Potter', 'Frodo Baggins', 'Percy Jackson', 'Luke Skywalker'], 0),
  ('cul-011', 'culture', 'Wer schrieb „Der kleine Prinz“?', array['Victor Hugo', 'Albert Camus', 'Jules Verne', 'Antoine de Saint-Exupéry'], 'Who wrote “The Little Prince”?', array['Victor Hugo', 'Albert Camus', 'Jules Verne', 'Antoine de Saint-Exupéry'], 3),
  ('cul-012', 'culture', 'Welches Instrument hat normalerweise 88 Tasten?', array['Trompete', 'Harfe', 'Klavier', 'Geige'], 'Which instrument usually has 88 keys?', array['Trumpet', 'Harp', 'Piano', 'Violin'], 2),
  ('cul-013', 'culture', 'Aus welcher Stadt stammen die Beatles?', array['London', 'Birmingham', 'Liverpool', 'Manchester'], 'Which city are the Beatles from?', array['London', 'Birmingham', 'Liverpool', 'Manchester'], 2),
  ('cul-014', 'culture', 'Welche Sprache spricht man hauptsächlich in Brasilien?', array['Portugiesisch', 'Spanisch', 'Englisch', 'Französisch'], 'What is the main language spoken in Brazil?', array['Portuguese', 'Spanish', 'English', 'French'], 0),
  ('cul-015', 'culture', 'Wer malte die Decke der Sixtinischen Kapelle?', array['Leonardo da Vinci', 'Botticelli', 'Raffael', 'Michelangelo'], 'Who painted the ceiling of the Sistine Chapel?', array['Leonardo da Vinci', 'Botticelli', 'Raphael', 'Michelangelo'], 3),
  ('cul-016', 'culture', 'In welcher Stadt findet das Oktoberfest statt?', array['München', 'Hamburg', 'Wien', 'Berlin'], 'In which city does Oktoberfest take place?', array['Munich', 'Hamburg', 'Vienna', 'Berlin'], 0),
  ('cul-017', 'culture', 'Wie viele Saiten hat eine normale Gitarre?', array['6', '4', '8', '5'], 'How many strings does a standard guitar have?', array['6', '4', '8', '5'], 0),
  ('cul-018', 'culture', 'Wer schrieb „Die Verwandlung“?', array['Stefan Zweig', 'Franz Kafka', 'Hermann Hesse', 'Bertolt Brecht'], 'Who wrote “The Metamorphosis”?', array['Stefan Zweig', 'Franz Kafka', 'Hermann Hesse', 'Bertolt Brecht'], 1),
  ('cul-019', 'culture', 'Aus welchem Land stammt die Pizza?', array['USA', 'Frankreich', 'Italien', 'Griechenland'], 'Which country does pizza come from?', array['USA', 'France', 'Italy', 'Greece'], 2),
  ('cul-020', 'culture', 'Welcher Superheld wird „Der Dunkle Ritter“ genannt?', array['Iron Man', 'Batman', 'Spider-Man', 'Superman'], 'Which superhero is called “The Dark Knight”?', array['Iron Man', 'Batman', 'Spider-Man', 'Superman'], 1),
  ('cul-021', 'culture', 'Wer sang das Album „Thriller“ (1982)?', array['Michael Jackson', 'Prince', 'Lionel Richie', 'Stevie Wonder'], 'Who released the album “Thriller” (1982)?', array['Michael Jackson', 'Prince', 'Lionel Richie', 'Stevie Wonder'], 0),
  ('cul-022', 'culture', 'In welcher Stadt steht das Kolosseum?', array['Istanbul', 'Rom', 'Athen', 'Neapel'], 'In which city is the Colosseum?', array['Istanbul', 'Rome', 'Athens', 'Naples'], 1),
  ('cul-023', 'culture', 'Wer trägt in „Der Herr der Ringe“ den Ring nach Mordor?', array['Gandalf', 'Aragorn', 'Legolas', 'Frodo'], 'In “The Lord of the Rings”, who carries the Ring to Mordor?', array['Gandalf', 'Aragorn', 'Legolas', 'Frodo'], 3),
  ('cul-024', 'culture', 'Wer komponierte die 9. Sinfonie mit der „Ode an die Freude“?', array['Joseph Haydn', 'Franz Schubert', 'Ludwig van Beethoven', 'Wolfgang Amadeus Mozart'], 'Who composed the 9th Symphony with the “Ode to Joy”?', array['Joseph Haydn', 'Franz Schubert', 'Ludwig van Beethoven', 'Wolfgang Amadeus Mozart'], 2),
  ('cul-025', 'culture', 'Wer erfand die Detektivfigur Sherlock Holmes?', array['Charles Dickens', 'Arthur Conan Doyle', 'Agatha Christie', 'Edgar Allan Poe'], 'Who created the detective Sherlock Holmes?', array['Charles Dickens', 'Arthur Conan Doyle', 'Agatha Christie', 'Edgar Allan Poe'], 1),
  ('cul-026', 'culture', 'In welchem Land steht das Taj Mahal?', array['Indien', 'Pakistan', 'Iran', 'Bangladesch'], 'In which country is the Taj Mahal?', array['India', 'Pakistan', 'Iran', 'Bangladesh'], 0),
  ('cul-027', 'culture', 'Welche Farbe entsteht, wenn man blaue und gelbe Malfarbe mischt?', array['Braun', 'Orange', 'Lila', 'Grün'], 'What colour do you get when you mix blue and yellow paint?', array['Brown', 'Orange', 'Purple', 'Green'], 3),
  ('cul-028', 'culture', 'Welche Maus ist die bekannteste Figur von Disney?', array['Speedy Gonzales', 'Stuart Little', 'Jerry', 'Micky Maus'], 'Which mouse is Disney''s most famous character?', array['Speedy Gonzales', 'Stuart Little', 'Jerry', 'Mickey Mouse'], 3),
  ('cul-029', 'culture', 'Wie viele Felder hat ein Schachbrett?', array['64', '81', '48', '100'], 'How many squares does a chessboard have?', array['64', '81', '48', '100'], 0),
  ('cul-030', 'culture', 'Wer schrieb das Drama „Die Räuber“?', array['Johann Wolfgang von Goethe', 'Gotthold Ephraim Lessing', 'Heinrich von Kleist', 'Friedrich Schiller'], 'Who wrote the play “The Robbers” (Die Räuber)?', array['Johann Wolfgang von Goethe', 'Gotthold Ephraim Lessing', 'Heinrich von Kleist', 'Friedrich Schiller'], 3),
  ('cul-031', 'culture', 'Welche Sprache haben die meisten Menschen als Muttersprache?', array['Englisch', 'Spanisch', 'Mandarin-Chinesisch', 'Hindi'], 'Which language has the most native speakers?', array['English', 'Spanish', 'Mandarin Chinese', 'Hindi'], 2),
  ('cul-032', 'culture', 'Wer malte das Bild „Guernica“?', array['Francisco de Goya', 'Salvador Dalí', 'Pablo Picasso', 'Joan Miró'], 'Who painted “Guernica”?', array['Francisco de Goya', 'Salvador Dalí', 'Pablo Picasso', 'Joan Miró'], 2),
  ('cul-033', 'culture', 'Welches Fest feiert man am 31. Oktober mit Kostümen und Kürbissen?', array['Silvester', 'Halloween', 'Ostern', 'Thanksgiving'], 'Which festival on 31 October is celebrated with costumes and pumpkins?', array['New Year''s Eve', 'Halloween', 'Easter', 'Thanksgiving'], 1),
  ('cul-034', 'culture', 'Wie heißt die Währung von Japan?', array['Ringgit', 'Won', 'Yuan', 'Yen'], 'What is the currency of Japan?', array['Ringgit', 'Won', 'Yuan', 'Yen'], 3),
  ('cul-035', 'culture', 'Aus welchem Land kommt die Band Rammstein?', array['Deutschland', 'Schweiz', 'Österreich', 'Niederlande'], 'Which country is the band Rammstein from?', array['Germany', 'Switzerland', 'Austria', 'Netherlands'], 0),
  ('spo-005', 'sport', 'Wie lange dauert ein Fußballspiel regulär (ohne Nachspielzeit)?', array['90 Minuten', '120 Minuten', '100 Minuten', '80 Minuten'], 'How long is a regular football match (without stoppage time)?', array['90 minutes', '120 minutes', '100 minutes', '80 minutes'], 0),
  ('spo-006', 'sport', 'Alle wie viele Jahre finden die Olympischen Sommerspiele statt?', array['4', '2', '3', '5'], 'How often (every how many years) are the Summer Olympics held?', array['4', '2', '3', '5'], 0),
  ('spo-007', 'sport', 'Wie viele Spieler hat ein Basketballteam gleichzeitig auf dem Feld?', array['6', '7', '4', '5'], 'How many players does a basketball team have on the court at once?', array['6', '7', '4', '5'], 3),
  ('spo-008', 'sport', 'In welcher Sportart ist Wimbledon ein berühmtes Turnier?', array['Golf', 'Squash', 'Tennis', 'Badminton'], 'In which sport is Wimbledon a famous tournament?', array['Golf', 'Squash', 'Tennis', 'Badminton'], 2),
  ('spo-009', 'sport', 'Wie lang ist ein Marathon?', array['42,195 km', '45 km', '21,1 km', '40 km'], 'How long is a marathon?', array['42.195 km', '45 km', '21.1 km', '40 km'], 0),
  ('spo-010', 'sport', 'Wo fanden 1896 die ersten Olympischen Spiele der Neuzeit statt?', array['Athen', 'London', 'Paris', 'St. Louis'], 'Where were the first modern Olympic Games held in 1896?', array['Athens', 'London', 'Paris', 'St. Louis'], 0),
  ('spo-011', 'sport', 'Wie viele Punkte zählt ein Touchdown im American Football?', array['3', '2', '7', '6'], 'How many points is a touchdown worth in American football?', array['3', '2', '7', '6'], 3),
  ('spo-012', 'sport', 'Welche Farbe hat das Trikot des Gesamtführenden der Tour de France?', array['Weiß', 'Gelb', 'Rot', 'Grün'], 'What colour jersey does the overall leader of the Tour de France wear?', array['White', 'Yellow', 'Red', 'Green'], 1),
  ('spo-013', 'sport', 'Wie viele Löcher hat eine normale Golfrunde?', array['9', '18', '24', '12'], 'How many holes are in a standard round of golf?', array['9', '18', '24', '12'], 1),
  ('spo-014', 'sport', 'Wer hält den Weltrekord über 100 Meter der Männer (9,58 s)?', array['Usain Bolt', 'Tyson Gay', 'Carl Lewis', 'Yohan Blake'], 'Who holds the men''s 100 m world record (9.58 s)?', array['Usain Bolt', 'Tyson Gay', 'Carl Lewis', 'Yohan Blake'], 0),
  ('spo-015', 'sport', 'Welches Land wurde 2014 Fußball-Weltmeister der Männer?', array['Brasilien', 'Argentinien', 'Spanien', 'Deutschland'], 'Which country won the 2014 men''s FIFA World Cup?', array['Brazil', 'Argentina', 'Spain', 'Germany'], 3),
  ('spo-016', 'sport', 'Welches Land wurde 2022 Fußball-Weltmeister der Männer?', array['Kroatien', 'Argentinien', 'Brasilien', 'Frankreich'], 'Which country won the 2022 men''s FIFA World Cup?', array['Croatia', 'Argentina', 'Brazil', 'France'], 1),
  ('spo-017', 'sport', 'In welcher Sportart gibt es „Strike“ und „Spare“?', array['Bowling', 'Golf', 'Tennis', 'Curling'], 'In which sport are there “strikes” and “spares”?', array['Bowling', 'Golf', 'Tennis', 'Curling'], 0),
  ('spo-018', 'sport', 'Wie viele Spieler stehen beim Hallenvolleyball pro Team auf dem Feld?', array['6', '5', '4', '7'], 'How many players per team are on the court in indoor volleyball?', array['6', '5', '4', '7'], 0),
  ('spo-019', 'sport', 'Wie heißt die höchste Fußballliga in Deutschland?', array['Serie A', 'Premier League', 'La Liga', 'Bundesliga'], 'What is the top football league in Germany called?', array['Serie A', 'Premier League', 'La Liga', 'Bundesliga'], 3),
  ('spo-020', 'sport', 'Wer gewann bis einschließlich 2025 die meisten Wimbledon-Einzeltitel der Männer?', array['Pete Sampras', 'Novak Djokovic', 'Björn Borg', 'Roger Federer'], 'Up to and including 2025, who won the most men''s singles titles at Wimbledon?', array['Pete Sampras', 'Novak Djokovic', 'Björn Borg', 'Roger Federer'], 3),
  ('spo-021', 'sport', 'Wo fanden die Olympischen Sommerspiele 2024 statt?', array['Paris', 'Tokio', 'Los Angeles', 'London'], 'Where were the 2024 Summer Olympics held?', array['Paris', 'Tokyo', 'Los Angeles', 'London'], 0),
  ('spo-022', 'sport', 'In welcher Sportart spielt man mit einem Puck?', array['Eishockey', 'Curling', 'Polo', 'Lacrosse'], 'In which sport is a puck used?', array['Ice hockey', 'Curling', 'Polo', 'Lacrosse'], 0),
  ('spo-023', 'sport', 'Was ist die höchste Punktzahl mit drei Pfeilen beim Darts?', array['200', '171', '150', '180'], 'What is the highest score with three darts?', array['200', '171', '150', '180'], 3),
  ('spo-024', 'sport', 'Wie lange dauert ein Handballspiel bei Erwachsenen (ohne Pausen)?', array['90 Minuten', '70 Minuten', '80 Minuten', '60 Minuten'], 'How long is an adult handball match (without breaks)?', array['90 minutes', '70 minutes', '80 minutes', '60 minutes'], 3),
  ('spo-025', 'sport', 'Welches Land hat bis einschließlich 2022 die meisten Fußball-WM-Titel der Männer?', array['Italien', 'Brasilien', 'Deutschland', 'Argentinien'], 'Up to and including 2022, which country has won the most men''s World Cups?', array['Italy', 'Brazil', 'Germany', 'Argentina'], 1),
  ('spo-026', 'sport', 'In welcher Disziplin springt man mit einem langen Stab?', array['Hochsprung', 'Stabhochsprung', 'Weitsprung', 'Dreisprung'], 'In which event do athletes jump using a long pole?', array['High jump', 'Pole vault', 'Long jump', 'Triple jump'], 1),
  ('spo-027', 'sport', 'Wie viele Spieler hat ein Eishockeyteam gleichzeitig auf dem Eis (mit Torwart)?', array['11', '6', '7', '5'], 'How many players does an ice hockey team have on the ice at once (including the goalie)?', array['11', '6', '7', '5'], 1),
  ('spo-028', 'sport', 'Welcher Boxer nannte sich selbst „The Greatest“?', array['George Foreman', 'Joe Frazier', 'Mike Tyson', 'Muhammad Ali'], 'Which boxer called himself “The Greatest”?', array['George Foreman', 'Joe Frazier', 'Mike Tyson', 'Muhammad Ali'], 3),
  ('spo-029', 'sport', 'In welchem Motorsport wurde Michael Schumacher siebenmal Weltmeister?', array['Rallye', 'MotoGP', 'Formel 1', 'DTM'], 'In which motorsport did Michael Schumacher become world champion seven times?', array['Rally', 'MotoGP', 'Formula 1', 'DTM'], 2),
  ('spo-030', 'sport', 'Aus welchem Land stammt das Sumo-Ringen?', array['Korea', 'China', 'Japan', 'Mongolei'], 'Which country does sumo wrestling come from?', array['Korea', 'China', 'Japan', 'Mongolia'], 2),
  ('spo-031', 'sport', 'Wie hoch hängt ein Basketballkorb?', array['3,50 m', '3,05 m', '2,80 m', '2,50 m'], 'How high is a basketball hoop?', array['3.50 m', '3.05 m', '2.80 m', '2.50 m'], 1),
  ('spo-032', 'sport', 'Welcher Verein hat die meisten deutschen Meistertitel im Fußball?', array['FC Schalke 04', '1. FC Nürnberg', 'Borussia Dortmund', 'FC Bayern München'], 'Which club has won the most German football championships?', array['Schalke 04', '1. FC Nürnberg', 'Borussia Dortmund', 'Bayern Munich'], 3),
  ('spo-033', 'sport', 'Welche Schwimmart ist normalerweise die schnellste?', array['Kraul (Freistil)', 'Brust', 'Schmetterling', 'Rücken'], 'Which swimming stroke is usually the fastest?', array['Front crawl (freestyle)', 'Breaststroke', 'Butterfly', 'Backstroke'], 0),
  ('spo-034', 'sport', 'Wer hat die meisten olympischen Goldmedaillen aller Zeiten?', array['Usain Bolt', 'Carl Lewis', 'Michael Phelps', 'Larissa Latynina'], 'Who has won the most Olympic gold medals of all time?', array['Usain Bolt', 'Carl Lewis', 'Michael Phelps', 'Larissa Latynina'], 2),
  ('nat-005', 'nature', 'Wie viele Beine hat ein Insekt?', array['4', '10', '8', '6'], 'How many legs does an insect have?', array['4', '10', '8', '6'], 3),
  ('nat-006', 'nature', 'Welches ist das größte Landtier?', array['Flusspferd', 'Nashorn', 'Afrikanischer Elefant', 'Giraffe'], 'What is the largest land animal?', array['Hippopotamus', 'Rhinoceros', 'African elephant', 'Giraffe'], 2),
  ('nat-007', 'nature', 'Wie nennt man ein junges Pferd?', array['Kalb', 'Fohlen', 'Ferkel', 'Lamm'], 'What is a young horse called?', array['Calf', 'Foal', 'Piglet', 'Lamb'], 1),
  ('nat-008', 'nature', 'Welcher Vogel kann rückwärts fliegen?', array['Adler', 'Spatz', 'Kolibri', 'Taube'], 'Which bird can fly backwards?', array['Eagle', 'Sparrow', 'Hummingbird', 'Pigeon'], 2),
  ('nat-009', 'nature', 'Welches Tier hat den längsten Hals?', array['Kamel', 'Strauß', 'Giraffe', 'Lama'], 'Which animal has the longest neck?', array['Camel', 'Ostrich', 'Giraffe', 'Llama'], 2),
  ('nat-010', 'nature', 'Wie viele Herzen hat ein Oktopus?', array['1', '2', '4', '3'], 'How many hearts does an octopus have?', array['1', '2', '4', '3'], 3),
  ('nat-011', 'nature', 'Welches dieser Säugetiere kann wirklich fliegen?', array['Igel', 'Fledermaus', 'Maulwurf', 'Biber'], 'Which of these mammals can truly fly?', array['Hedgehog', 'Bat', 'Mole', 'Beaver'], 1),
  ('nat-012', 'nature', 'Zu welcher Tiergruppe gehört der Wal?', array['Amphibien', 'Säugetiere', 'Fische', 'Reptilien'], 'Which animal group do whales belong to?', array['Amphibians', 'Mammals', 'Fish', 'Reptiles'], 1),
  ('nat-013', 'nature', 'An welchem Baum wachsen Eicheln?', array['Ahorn', 'Eiche', 'Birke', 'Buche'], 'Which tree do acorns grow on?', array['Maple', 'Oak', 'Birch', 'Beech'], 1),
  ('nat-014', 'nature', 'Welches Tier trägt sein Junges in einem Beutel?', array['Gürteltier', 'Ameisenbär', 'Faultier', 'Känguru'], 'Which animal carries its young in a pouch?', array['Armadillo', 'Anteater', 'Sloth', 'Kangaroo'], 3),
  ('nat-015', 'nature', 'Was wird aus einer Raupe?', array['Ein Schmetterling', 'Ein Käfer', 'Eine Libelle', 'Eine Biene'], 'What does a caterpillar turn into?', array['A butterfly', 'A beetle', 'A dragonfly', 'A bee'], 0),
  ('nat-016', 'nature', 'Welches ist der größte Fisch der Welt?', array['Mantarochen', 'Walhai', 'Weißer Hai', 'Mondfisch'], 'What is the largest fish in the world?', array['Manta ray', 'Whale shark', 'Great white shark', 'Ocean sunfish'], 1),
  ('nat-017', 'nature', 'Welcher Stoff macht Blätter grün?', array['Keratin', 'Chlorophyll', 'Hämoglobin', 'Melanin'], 'Which substance makes leaves green?', array['Keratin', 'Chlorophyll', 'Haemoglobin', 'Melanin'], 1),
  ('nat-018', 'nature', 'Wie lange ist ein Elefant ungefähr schwanger?', array['etwa 22 Monate', 'etwa 9 Monate', 'etwa 12 Monate', 'etwa 36 Monate'], 'Roughly how long is an elephant pregnant?', array['about 22 months', 'about 9 months', 'about 12 months', 'about 36 months'], 0),
  ('nat-019', 'nature', 'Was frisst ein Koala hauptsächlich?', array['Gras', 'Insekten', 'Bambus', 'Eukalyptusblätter'], 'What does a koala mainly eat?', array['Grass', 'Insects', 'Bamboo', 'Eucalyptus leaves'], 3),
  ('nat-020', 'nature', 'Welches dieser Tiere hält Winterschlaf?', array['Reh', 'Wildschwein', 'Fuchs', 'Igel'], 'Which of these animals hibernates?', array['Deer', 'Wild boar', 'Fox', 'Hedgehog'], 3),
  ('nat-021', 'nature', 'Welcher ist der größte Vogel der Welt?', array['Emu', 'Kondor', 'Strauß', 'Albatros'], 'What is the largest bird in the world?', array['Emu', 'Condor', 'Ostrich', 'Albatross'], 2),
  ('nat-022', 'nature', 'Wie viele Arme hat ein Seestern meistens?', array['8', '4', '5', '6'], 'How many arms does a starfish usually have?', array['8', '4', '5', '6'], 2),
  ('nat-023', 'nature', 'Wie sieht der Hut eines Fliegenpilzes aus?', array['Gelb', 'Rot mit weißen Punkten', 'Blau mit weißen Punkten', 'Braun'], 'What does the cap of a fly agaric mushroom look like?', array['Yellow', 'Red with white spots', 'Blue with white spots', 'Brown'], 1),
  ('nat-024', 'nature', 'Welches Tier ist dafür bekannt, seine Farbe zu wechseln?', array['Leguan', 'Krokodil', 'Schildkröte', 'Chamäleon'], 'Which animal is known for changing its colour?', array['Iguana', 'Crocodile', 'Turtle', 'Chameleon'], 3),
  ('nat-025', 'nature', 'Wie heißt das männliche Huhn?', array['Hahn', 'Küken', 'Henne', 'Gans'], 'What is a male chicken called?', array['Rooster', 'Chick', 'Hen', 'Goose'], 0),
  ('nat-026', 'nature', 'Wie viele Zähne hat ein erwachsener Mensch normalerweise (mit Weisheitszähnen)?', array['36', '32', '28', '30'], 'How many teeth does an adult human normally have (including wisdom teeth)?', array['36', '32', '28', '30'], 1),
  ('nat-027', 'nature', 'Wo leben Eisbären?', array['Im Himalaya', 'Im Amazonas', 'In der Arktis', 'In der Antarktis'], 'Where do polar bears live?', array['In the Himalayas', 'In the Amazon', 'In the Arctic', 'In Antarctica'], 2),
  ('nat-028', 'nature', 'Welcher Nadelbaum verliert im Herbst seine Nadeln?', array['Fichte', 'Lärche', 'Tanne', 'Kiefer'], 'Which conifer loses its needles in autumn?', array['Spruce', 'Larch', 'Fir', 'Pine'], 1),
  ('nat-029', 'nature', 'Wie nennt man Tiere, die nur Pflanzen fressen?', array['Pflanzenfresser', 'Fleischfresser', 'Allesfresser', 'Aasfresser'], 'What are animals that only eat plants called?', array['Herbivores', 'Carnivores', 'Omnivores', 'Scavengers'], 0),
  ('nat-030', 'nature', 'Welches Tier baut Dämme in Flüssen?', array['Dachs', 'Biber', 'Otter', 'Bisamratte'], 'Which animal builds dams in rivers?', array['Badger', 'Beaver', 'Otter', 'Muskrat'], 1),
  ('nat-031', 'nature', 'Was stellen Honigbienen aus Blütennektar her?', array['Honig', 'Milch', 'Harz', 'Seide'], 'What do honeybees make from flower nectar?', array['Honey', 'Milk', 'Resin', 'Silk'], 0),
  ('nat-032', 'nature', 'Welches Säugetier gilt als das langsamste?', array['Koala', 'Maulwurf', 'Igel', 'Faultier'], 'Which mammal is considered the slowest?', array['Koala', 'Mole', 'Hedgehog', 'Sloth'], 3),
  ('nat-033', 'nature', 'Wo leben Lemuren ursprünglich?', array['Auf Madagaskar', 'Auf Borneo', 'In Sri Lanka', 'In Neuseeland'], 'Where do lemurs originally live?', array['In Madagascar', 'In Borneo', 'In Sri Lanka', 'In New Zealand'], 0),
  ('nat-034', 'nature', 'Welches Säugetier legt Eier?', array['Schnabeltier', 'Känguru', 'Delfin', 'Fledermaus'], 'Which mammal lays eggs?', array['Platypus', 'Kangaroo', 'Dolphin', 'Bat'], 0)
on conflict (id) do update set
  category = excluded.category, text_de = excluded.text_de, options_de = excluded.options_de,
  text_en = excluded.text_en, options_en = excluded.options_en, answer = excluded.answer;
