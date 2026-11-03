import { advanceRoom } from "@/lib/duel/server";
import { handle, readJson } from "@/lib/duel/http";

export async function POST(request: Request, ctx: RouteContext<"/api/duel/[code]/advance">) {
  return handle(async () => {
    const { code } = await ctx.params;
    const { playerId, token } = await readJson(request);
    await advanceRoom(code, playerId, token);
  });
}
