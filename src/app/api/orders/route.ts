/**
 * POST /api/orders – nimmt einen Bestell-ENTWURF entgegen (nur Metadaten, keine Fotos).
 * Demo: validiert und antwortet mit einer Entwurfs-ID, speichert nichts.
 * Produktion: Entwurf persistieren, signierte Upload-URLs (privater Bucket) zurückgeben,
 * danach Checkout (Stripe) – siehe src/lib/order.ts.
 */
import { NextResponse } from "next/server";
import { orderDraftSchema } from "@/lib/validation";

const MAX_BODY = 32 * 1024;

export async function POST(req: Request) {
  const text = await req.text();
  if (text.length > MAX_BODY) return NextResponse.json({ error: "payload_too_large" }, { status: 413 });
  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch {
    return NextResponse.json({ error: "invalid_json" }, { status: 400 });
  }
  const parsed = orderDraftSchema.safeParse(json);
  if (!parsed.success) {
    return NextResponse.json({ error: "validation_failed", issues: parsed.error.issues.map((i) => ({ path: i.path.join("."), message: i.message })) }, { status: 422 });
  }
  const draftId = `draft_${crypto.randomUUID()}`;
  return NextResponse.json({ draftId, status: "draft", next: "upload-photos" }, { status: 201, headers: { "Cache-Control": "no-store" } });
}
