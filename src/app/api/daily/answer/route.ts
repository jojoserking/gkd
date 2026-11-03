import { dailyQuestions, todayKey } from "@/lib/daily";

// Prüft eine Antwort auf dem Server. So steht die Lösung nie im Browser.
export async function POST(request: Request) {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "invalid json" }, { status: 400 });
  }

  const { questionId, choice } = (body ?? {}) as { questionId?: unknown; choice?: unknown };
  if (typeof questionId !== "string" || typeof choice !== "number") {
    return Response.json({ error: "questionId and choice required" }, { status: 400 });
  }

  const question = dailyQuestions(todayKey()).find((q) => q.id === questionId);
  if (!question) {
    return Response.json({ error: "not in today's quiz" }, { status: 404 });
  }

  return Response.json({ correct: choice === question.answer, correctIndex: question.answer });
}
