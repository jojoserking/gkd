import { submitAnswer } from "@/lib/duel/server";
import { handle, readJson } from "@/lib/duel/http";

export async function POST(request: Request, ctx: RouteContext<"/api/duel/[code]/answer">) {
  return handle(async () => {
    const { code } = await ctx.params;
    const { playerId, token, choice } = await readJson(request);
    return submitAnswer(code, playerId, token, choice);
  });
}
