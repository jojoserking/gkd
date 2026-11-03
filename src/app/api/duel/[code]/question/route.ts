import { currentQuestion } from "@/lib/duel/server";
import { handle } from "@/lib/duel/http";

export async function GET(request: Request, ctx: RouteContext<"/api/duel/[code]/question">) {
  return handle(async () => {
    const { code } = await ctx.params;
    const lang = new URL(request.url).searchParams.get("lang") === "de" ? "de" : "en";
    return currentQuestion(code, lang);
  });
}
