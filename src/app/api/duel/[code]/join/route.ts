import { joinRoom } from "@/lib/duel/server";
import { handle, readJson } from "@/lib/duel/http";

export async function POST(request: Request, ctx: RouteContext<"/api/duel/[code]/join">) {
  return handle(async () => {
    const { code } = await ctx.params;
    const { nickname } = await readJson(request);
    return joinRoom(code, String(nickname ?? ""));
  });
}
