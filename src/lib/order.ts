/**
 * Bestell-Entwurf erzeugen und an die API senden.
 *
 * Datenfluss (heute, Demo):   Formular → OrderDraft (nur Metadaten, KEINE Fotos) → POST /api/orders
 * Datenfluss (Produktion):    1. POST /api/orders           → draftId + signierte Upload-URLs
 *                             2. PUT Foto direkt in privaten Storage (z. B. S3/R2, verschlüsselt, Ablauf)
 *                             3. Checkout (Stripe Checkout Session mit draftId als metadata)
 *                             4. Webhook bestätigt Zahlung → Auftrag an Illustration/Redaktion
 */
import { type ConfiguratorValues, type OrderDraft, orderDraftSchema } from "./validation";

export function buildOrderDraft(v: ConfiguratorValues): OrderDraft {
  const strip = <T extends { url?: string }>(p: T) => {
    const { url: _u, ...rest } = p;
    void _u;
    return rest;
  };
  if (!v.childPhoto || !v.teddyPhoto || !v.childAge) throw new Error("Unvollständige Angaben");
  return orderDraftSchema.parse({
    schemaVersion: 1,
    locale: "de-DE",
    child: { name: v.childName.trim(), age: v.childAge, pronoun: v.pronoun || undefined, photo: strip(v.childPhoto) },
    companion: { kind: "kuscheltier", name: v.teddyName.trim() || undefined, photo: strip(v.teddyPhoto) },
    interests: v.interests,
    customInterest: v.customInterest.trim() || undefined,
    storyIdea: v.storyIdea.trim() || undefined,
    extras: { people: [] },
    consent: { photoUsage: true, guardian: true, acceptedAt: new Date().toISOString() },
    product: { sku: "book-hardcover-a4", quantity: 1 },
  });
}

export type SubmitResult = { draftId: string; status: "draft"; next: "upload-photos" | "checkout" };

export async function submitOrderDraft(draft: OrderDraft): Promise<SubmitResult> {
  const res = await fetch("/api/orders", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(draft),
  });
  if (!res.ok) throw new Error(`Die Anfrage ist fehlgeschlagen (${res.status}).`);
  return res.json();
}
