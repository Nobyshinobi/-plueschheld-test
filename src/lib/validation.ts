/**
 * Validierung – geteilt zwischen Formular (Client) und API-Route (Server).
 * zod/mini: gleiche Schemas wie "zod", aber tree-shakebar -> deutlich weniger Client-JS.
 */
import * as z from "zod/mini";

const text = (max: number, msg = `Bitte höchstens ${max} Zeichen.`) => z.string().check(z.trim(), z.maxLength(max, msg));
const posInt = () => z.int().check(z.positive());

export const photoRefSchema = z.object({
  id: z.string().check(z.minLength(1)),
  name: z.string().check(z.maxLength(200)),
  size: posInt(),
  width: posInt(),
  height: posInt(),
  /** nur clientseitig (Object-URL für die Vorschau) – wird nie versendet */
  url: z.optional(z.string()),
});
export type PhotoRef = z.infer<typeof photoRefSchema>;

const nameRe = /^[\p{L}\p{M}][\p{L}\p{M} '’\-.]*$/u;

export const AGES = ["unter 1", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13+"] as const;
export const PRONOUNS = [
  { id: "sie", label: "sie / ihr" },
  { id: "er", label: "er / ihm" },
  { id: "name", label: "nur den Namen verwenden" },
] as const;

const requiredPhoto = (msg: string) => z.nullable(photoRefSchema).check(z.refine((v) => v !== null, msg));
const childNameSchema = z
  .string()
  .check(
    z.trim(),
    z.minLength(1, "Wie heißt dein Kind?"),
    z.maxLength(40, "Bitte höchstens 40 Zeichen."),
    z.regex(nameRe, "Bitte nur Buchstaben, Leerzeichen oder Bindestrich verwenden."),
  );

export const stepSchemas = {
  child: z.object({ childPhoto: requiredPhoto("Bitte lade ein Foto deines Kindes hoch.") }),
  teddy: z.object({ teddyPhoto: requiredPhoto("Bitte lade ein Foto des Kuscheltiers hoch."), teddyName: text(40) }),
  details: z.object({
    childName: childNameSchema,
    childAge: z.enum(AGES, { error: "Bitte wähle das Alter aus." }),
    pronoun: z.enum(["sie", "er", "name", ""]),
  }),
  interests: z
    .object({ interests: z.array(z.string()).check(z.maxLength(12)), customInterest: text(80) })
    .check(
      z.refine((v) => v.interests.length > 0 || v.customInterest.length > 0, {
        error: "Wähle mindestens ein Interesse – oder schreib eine eigene Idee.",
        path: ["interests"],
      }),
    ),
  story: z.object({ storyIdea: text(1000, "Bitte höchstens 1000 Zeichen – ein paar Sätze reichen völlig.") }),
  review: z.object({ consent: z.literal(true, { error: "Bitte bestätige die Einwilligung, damit wir mit euren Fotos arbeiten dürfen." }) }),
};

export type StepId = keyof typeof stepSchemas;

/** Vollständige Formularwerte (Client) */
export type ConfiguratorValues = {
  childPhoto: PhotoRef | null;
  teddyPhoto: PhotoRef | null;
  teddyName: string;
  childName: string;
  childAge: (typeof AGES)[number] | "";
  pronoun: "sie" | "er" | "name" | "";
  interests: string[];
  customInterest: string;
  storyIdea: string;
  consent: boolean;
};

export const emptyValues: ConfiguratorValues = {
  childPhoto: null,
  teddyPhoto: null,
  teddyName: "",
  childName: "",
  childAge: "",
  pronoun: "",
  interests: [],
  customInterest: "",
  storyIdea: "",
  consent: false,
};

/* ------------------------------------------------------------------------
   Bestell-Entwurf (API-Vertrag). Versioniert und bewusst erweiterbar:
   weitere Personen, Orte, Anlässe, Warenkorb/Stripe, Kundenkonto.
   ------------------------------------------------------------------------ */
const photoMeta = z.omit(photoRefSchema, { url: true });
const personSchema = z.object({
  role: z.enum(["geschwister", "mama", "papa", "oma", "opa", "haustier", "freund", "andere"]),
  name: z.string().check(z.trim(), z.minLength(1), z.maxLength(40)),
  photoId: z.optional(z.string()),
});

export const orderDraftSchema = z.object({
  schemaVersion: z.literal(1),
  locale: z.literal("de-DE"),
  child: z.object({
    name: childNameSchema,
    age: z.enum(AGES),
    pronoun: z.optional(z.enum(["sie", "er", "name"])),
    photo: photoMeta,
  }),
  companion: z.object({
    kind: z.literal("kuscheltier"),
    name: z.optional(text(40)),
    photo: photoMeta,
  }),
  interests: z.array(z.string().check(z.maxLength(40))).check(z.maxLength(12)),
  customInterest: z.optional(text(80)),
  storyIdea: z.optional(text(1000)),
  /** Erweiterungen – im UI noch nicht aktiv */
  extras: z._default(
    z.object({
      people: z._default(z.array(personSchema).check(z.maxLength(6)), []),
      favoritePlace: z.optional(text(120)),
      occasion: z.optional(text(120)),
      dedication: z.optional(text(300)),
      exclusions: z.optional(text(300)),
    }),
    { people: [] },
  ),
  consent: z.object({
    photoUsage: z.literal(true),
    guardian: z.literal(true),
    acceptedAt: z.iso.datetime(),
  }),
  /** Vorbereitet für Warenkorb/Checkout */
  product: z._default(
    z.object({ sku: z._default(z.string(), "book-hardcover-a4"), quantity: z._default(z.int().check(z.minimum(1), z.maximum(10)), 1) }),
    { sku: "book-hardcover-a4", quantity: 1 },
  ),
});
export type OrderDraft = z.infer<typeof orderDraftSchema>;
