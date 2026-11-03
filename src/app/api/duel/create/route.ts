import { createRoom } from "@/lib/duel/server";
import { handle, readJson } from "@/lib/duel/http";

export async function POST(request: Request) {
  return handle(async () => {
    const { nickname } = await readJson(request);
    return createRoom(String(nickname ?? ""));
  });
}
