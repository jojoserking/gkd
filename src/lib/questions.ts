import "server-only";

// Beispiel-Fragenpool. Die echten Fragen liegen in Supabase (Tabelle "questions").
// Diese Liste dient als Ersatz, solange Supabase nicht eingerichtet ist, und als Quelle für supabase/setup.sql.
// "answer" ist die Position der richtigen Antwort (0 bis 3) und wird nie an den Browser geschickt.

export type Category =
  | "geography"
  | "history"
  | "science"
  | "culture"
  | "sport"
  | "nature";

export type Question = {
  id: string;
  category: Category;
  de: { text: string; options: [string, string, string, string] };
  en: { text: string; options: [string, string, string, string] };
  answer: 0 | 1 | 2 | 3;
};

export const questions: Question[] = [
  {
    id: "geo-001",
    category: "geography",
    de: { text: "Was ist die Hauptstadt von Australien?", options: ["Sydney", "Canberra", "Melbourne", "Perth"] },
    en: { text: "What is the capital of Australia?", options: ["Sydney", "Canberra", "Melbourne", "Perth"] },
    answer: 1,
  },
  {
    id: "geo-002",
    category: "geography",
    de: { text: "Welcher ist der längste Fluss Deutschlands?", options: ["Elbe", "Donau", "Rhein", "Main"] },
    en: { text: "Which river flows the longest distance within Germany?", options: ["Elbe", "Danube", "Rhine", "Main"] },
    answer: 2,
  },
  {
    id: "geo-003",
    category: "geography",
    de: { text: "Auf welchem Kontinent liegt Ägypten?", options: ["Asien", "Afrika", "Europa", "Südamerika"] },
    en: { text: "On which continent is Egypt?", options: ["Asia", "Africa", "Europe", "South America"] },
    answer: 1,
  },
  {
    id: "geo-004",
    category: "geography",
    de: { text: "Welcher ist der höchste Berg der Erde?", options: ["K2", "Mont Blanc", "Kilimandscharo", "Mount Everest"] },
    en: { text: "What is the highest mountain on Earth?", options: ["K2", "Mont Blanc", "Kilimanjaro", "Mount Everest"] },
    answer: 3,
  },
  {
    id: "geo-005",
    category: "geography",
    de: { text: "Welches Land hat die meisten Einwohner?", options: ["Indien", "USA", "China", "Indonesien"] },
    en: { text: "Which country has the largest population?", options: ["India", "USA", "China", "Indonesia"] },
    answer: 0,
  },
  {
    id: "geo-006",
    category: "geography",
    de: { text: "Welcher Ozean ist der größte?", options: ["Atlantik", "Indischer Ozean", "Pazifik", "Arktischer Ozean"] },
    en: { text: "Which ocean is the largest?", options: ["Atlantic", "Indian Ocean", "Pacific", "Arctic Ocean"] },
    answer: 2,
  },
  {
    id: "his-001",
    category: "history",
    de: { text: "In welchem Jahr fiel die Berliner Mauer?", options: ["1987", "1989", "1990", "1991"] },
    en: { text: "In which year did the Berlin Wall fall?", options: ["1987", "1989", "1990", "1991"] },
    answer: 1,
  },
  {
    id: "his-002",
    category: "history",
    de: { text: "Wer war der erste Mensch auf dem Mond?", options: ["Buzz Aldrin", "Juri Gagarin", "Neil Armstrong", "Michael Collins"] },
    en: { text: "Who was the first person to walk on the Moon?", options: ["Buzz Aldrin", "Yuri Gagarin", "Neil Armstrong", "Michael Collins"] },
    answer: 2,
  },
  {
    id: "his-003",
    category: "history",
    de: { text: "In welchem Jahr begann der Erste Weltkrieg?", options: ["1912", "1914", "1916", "1918"] },
    en: { text: "In which year did World War I begin?", options: ["1912", "1914", "1916", "1918"] },
    answer: 1,
  },
  {
    id: "his-004",
    category: "history",
    de: { text: "Welches Volk baute die Pyramiden von Gizeh?", options: ["Die Römer", "Die Griechen", "Die alten Ägypter", "Die Maya"] },
    en: { text: "Which people built the pyramids of Giza?", options: ["The Romans", "The Greeks", "The ancient Egyptians", "The Maya"] },
    answer: 2,
  },
  {
    id: "his-005",
    category: "history",
    de: { text: "Wer erfand den Buchdruck mit beweglichen Lettern in Europa?", options: ["Johannes Gutenberg", "Martin Luther", "Leonardo da Vinci", "Galileo Galilei"] },
    en: { text: "Who invented printing with movable type in Europe?", options: ["Johannes Gutenberg", "Martin Luther", "Leonardo da Vinci", "Galileo Galilei"] },
    answer: 0,
  },
  {
    id: "sci-001",
    category: "science",
    de: { text: "Welches chemische Symbol hat Gold?", options: ["Go", "Gd", "Au", "Ag"] },
    en: { text: "What is the chemical symbol for gold?", options: ["Go", "Gd", "Au", "Ag"] },
    answer: 2,
  },
  {
    id: "sci-002",
    category: "science",
    de: { text: "Welcher Planet ist der Sonne am nächsten?", options: ["Venus", "Merkur", "Mars", "Erde"] },
    en: { text: "Which planet is closest to the Sun?", options: ["Venus", "Mercury", "Mars", "Earth"] },
    answer: 1,
  },
  {
    id: "sci-003",
    category: "science",
    de: { text: "Bei wie viel Grad Celsius kocht Wasser auf Meereshöhe?", options: ["90 °C", "100 °C", "110 °C", "120 °C"] },
    en: { text: "At what temperature does water boil at sea level?", options: ["90 °C", "100 °C", "110 °C", "120 °C"] },
    answer: 1,
  },
  {
    id: "sci-004",
    category: "science",
    de: { text: "Wie viele Knochen hat ein erwachsener Mensch ungefähr?", options: ["106", "156", "206", "306"] },
    en: { text: "About how many bones does an adult human have?", options: ["106", "156", "206", "306"] },
    answer: 2,
  },
  {
    id: "sci-005",
    category: "science",
    de: { text: "Welches Gas brauchen Pflanzen für die Fotosynthese?", options: ["Sauerstoff", "Stickstoff", "Kohlendioxid", "Helium"] },
    en: { text: "Which gas do plants need for photosynthesis?", options: ["Oxygen", "Nitrogen", "Carbon dioxide", "Helium"] },
    answer: 2,
  },
  {
    id: "sci-006",
    category: "science",
    de: { text: "Wie viele Planeten hat unser Sonnensystem?", options: ["7", "8", "9", "10"] },
    en: { text: "How many planets are in our solar system?", options: ["7", "8", "9", "10"] },
    answer: 1,
  },
  {
    id: "cul-001",
    category: "culture",
    de: { text: "Wer malte die Mona Lisa?", options: ["Michelangelo", "Raffael", "Leonardo da Vinci", "Vincent van Gogh"] },
    en: { text: "Who painted the Mona Lisa?", options: ["Michelangelo", "Raphael", "Leonardo da Vinci", "Vincent van Gogh"] },
    answer: 2,
  },
  {
    id: "cul-002",
    category: "culture",
    de: { text: "Wer schrieb „Romeo und Julia“?", options: ["Goethe", "William Shakespeare", "Charles Dickens", "Friedrich Schiller"] },
    en: { text: "Who wrote “Romeo and Juliet”?", options: ["Goethe", "William Shakespeare", "Charles Dickens", "Friedrich Schiller"] },
    answer: 1,
  },
  {
    id: "cul-003",
    category: "culture",
    de: { text: "Aus welchem Land stammt die Band ABBA?", options: ["Norwegen", "Dänemark", "Schweden", "Finnland"] },
    en: { text: "Which country is the band ABBA from?", options: ["Norway", "Denmark", "Sweden", "Finland"] },
    answer: 2,
  },
  {
    id: "cul-004",
    category: "culture",
    de: { text: "Welcher Komponist wurde in Bonn geboren?", options: ["Mozart", "Ludwig van Beethoven", "Johann Sebastian Bach", "Richard Wagner"] },
    en: { text: "Which composer was born in Bonn?", options: ["Mozart", "Ludwig van Beethoven", "Johann Sebastian Bach", "Richard Wagner"] },
    answer: 1,
  },
  {
    id: "cul-005",
    category: "culture",
    de: { text: "In welcher Stadt steht der Eiffelturm?", options: ["Lyon", "Brüssel", "Paris", "Marseille"] },
    en: { text: "In which city is the Eiffel Tower?", options: ["Lyon", "Brussels", "Paris", "Marseille"] },
    answer: 2,
  },
  {
    id: "spo-001",
    category: "sport",
    de: { text: "Wie viele Spieler hat eine Fußballmannschaft auf dem Feld?", options: ["9", "10", "11", "12"] },
    en: { text: "How many players does a football (soccer) team have on the field?", options: ["9", "10", "11", "12"] },
    answer: 2,
  },
  {
    id: "spo-002",
    category: "sport",
    de: { text: "Wie oft wurde Deutschland (inkl. BRD) bis 2022 Fußball-Weltmeister der Männer?", options: ["2-mal", "3-mal", "4-mal", "5-mal"] },
    en: { text: "How many men's FIFA World Cups had Germany (incl. West Germany) won by 2022?", options: ["2", "3", "4", "5"] },
    answer: 2,
  },
  {
    id: "spo-003",
    category: "sport",
    de: { text: "Wie viele Ringe hat das olympische Symbol?", options: ["4", "5", "6", "7"] },
    en: { text: "How many rings are in the Olympic symbol?", options: ["4", "5", "6", "7"] },
    answer: 1,
  },
  {
    id: "spo-004",
    category: "sport",
    de: { text: "In welcher Sportart gibt es einen „Slam Dunk“?", options: ["Volleyball", "Tennis", "Basketball", "Handball"] },
    en: { text: "In which sport is there a “slam dunk”?", options: ["Volleyball", "Tennis", "Basketball", "Handball"] },
    answer: 2,
  },
  {
    id: "nat-001",
    category: "nature",
    de: { text: "Welches ist das größte Säugetier der Welt?", options: ["Afrikanischer Elefant", "Blauwal", "Giraffe", "Pottwal"] },
    en: { text: "What is the largest mammal in the world?", options: ["African elephant", "Blue whale", "Giraffe", "Sperm whale"] },
    answer: 1,
  },
  {
    id: "nat-002",
    category: "nature",
    de: { text: "Wie viele Beine hat eine Spinne?", options: ["6", "8", "10", "12"] },
    en: { text: "How many legs does a spider have?", options: ["6", "8", "10", "12"] },
    answer: 1,
  },
  {
    id: "nat-003",
    category: "nature",
    de: { text: "Welches Tier ist das schnellste an Land?", options: ["Löwe", "Gepard", "Pferd", "Antilope"] },
    en: { text: "Which is the fastest land animal?", options: ["Lion", "Cheetah", "Horse", "Antelope"] },
    answer: 1,
  },
  {
    id: "nat-004",
    category: "nature",
    de: { text: "Wovon ernähren sich Pandas hauptsächlich?", options: ["Fisch", "Bambus", "Früchte", "Insekten"] },
    en: { text: "What do pandas mainly eat?", options: ["Fish", "Bamboo", "Fruit", "Insects"] },
    answer: 1,
  },
];
