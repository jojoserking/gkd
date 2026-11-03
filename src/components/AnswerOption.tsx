// Eine Antwortmöglichkeit mit Buchstaben A–D. Wird im Tagesquiz und im Live-Duell benutzt.
export type OptionState = "idle" | "chosen" | "correct" | "wrong" | "dimmed";

const styles: Record<OptionState, string> = {
  idle: "bg-card ring-indigo-500/20 hover:-translate-y-0.5 hover:ring-indigo-500 hover:shadow-md",
  chosen: "bg-indigo-600/15 ring-indigo-600",
  correct: "bg-green-500/20 ring-green-600",
  wrong: "bg-red-500/15 ring-red-600",
  dimmed: "bg-card ring-indigo-500/10 opacity-50",
};
const badge: Record<OptionState, string> = {
  idle: "bg-indigo-500/10 text-indigo-600 dark:text-indigo-300",
  chosen: "bg-indigo-600 text-white",
  correct: "bg-green-600 text-white",
  wrong: "bg-red-600 text-white",
  dimmed: "bg-indigo-500/10 text-indigo-600 dark:text-indigo-300",
};

export default function AnswerOption({
  index, text, state, disabled, onClick,
}: { index: number; text: string; state: OptionState; disabled: boolean; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className={`flex items-center gap-4 rounded-2xl px-4 py-4 text-left text-lg ring-2 shadow-sm backdrop-blur transition ${styles[state]}`}
    >
      <span className={`grid h-9 w-9 shrink-0 place-items-center rounded-xl text-sm font-bold ${badge[state]}`}>
        {state === "correct" ? "✓" : state === "wrong" ? "✗" : "ABCD"[index]}
      </span>
      <span>{text}</span>
    </button>
  );
}
