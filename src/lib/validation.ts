/**
 * Validierung (Zod) – geteilt zwischen Formular (Client) und API-Route (Server).
 */
import { z } from "zod";

export const photoRefSchema = z.object({
  id: z.string().min(1),
  name: z.string().max(200),
  size: z.number().int().positive(),
  width: z.number().int().positive(),
  height: z.number().int().positive(),
  /** nur clientseitig (Object-URL für die Vorschau) – wird nie versendet */
  url: z.string().optional(),
});
export type PhotoRef = z.infer<typeof photoRefSchema>;

const nameRe = /^[\p{L}\p{M}][\p{L}\p{M} '’\-.]*$/u;

export const AGES = ["unter 1", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13+"] as const;
export const PRONOUNS = [
  { id: "sie", label: "sie / ihr" },
  { id: "er", label: "er / ihm" },
  { id: "name", label: "nur den Namen verwenden" },
] as const;

export const stepSchemas = {
  child: z.object({
    childPhoto: photoRefSchema.nullable().refine((v) => v !== null, "Bitte lade ein Foto deines Kindes hoch."),
  }),
  teddy: z.object({
    teddyPhoto: photoRefSchema.nullable().refine((v) => v !== null, "Bitte lade ein Foto des Kuscheltiers hoch."),
    teddyName: z.string().trim().max(40, "Bitte höchstens 40 Zeichen."),
  }),
  details: z.object({
    childName: z
      .string()
      .trim()
      .min(1, "Wie heißt dein Kind?")
      .max(40, "Bitte höchstens 40 Zeichen.")
      .regex(nameRe, "Bitte nur Buchstaben, Leerzeichen oder Bindestrich verwenden."),
    childAge: z.enum(AGES, { message: "Bitte wähle das Alter aus." }),
    pronoun: z.enum(["sie", "er", "name", ""]),
  }),
  interests: z
    .object({
      interests: z.array(z.string()).max(12),
      customInterest: z.string().trim().max(80, "Bitte höchstens 80 Zeichen."),
    })
    .refine((v) => v.interests.length > 0 || v.customInterest.length > 0, {
      message: "Wähle mindestens ein Interesse – oder schreib eine eigene Idee.",
      path: ["interests"],
    }),
  story: z.object({
    storyIdea: z.string().trim().max(1000, "Bitte höchstens 1000 Zeichen – ein paar Sätze reichen völlig."),
  }),
  review: z.object({
    consent: z.literal(true, { message: "Bitte bestätige die Einwilligung, damit wir mit euren Fotos arbeiten dürfen." }),
  }),
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
const personSchema = z.object({
  role: z.enum(["geschwister", "mama", "papa", "oma", "opa", "haustier", "freund", "andere"]),
  name: z.string().trim().min(1).max(40),
  photoId: z.string().optional(),
});

export const orderDraftSchema = z.object({
  schemaVersion: z.literal(1),
  locale: z.literal("de-DE"),
  child: z.object({
    name: z.string().trim().min(1).max(40).regex(nameRe),
    age: z.enum(AGES),
    pronoun: z.enum(["sie", "er", "name"]).optional(),
    photo: photoRefSchema.omit({ url: true }),
  }),
  companion: z.object({
    kind: z.literal("kuscheltier"),
    name: z.string().trim().max(40).optional(),
    photo: photoRefSchema.omit({ url: true }),
  }),
  interests: z.array(z.string().max(40)).max(12),
  customInterest: z.string().trim().max(80).optional(),
  storyIdea: z.string().trim().max(1000).optional(),
  /** Erweiterungen – im UI noch nicht aktiv */
  extras: z
    .object({
      people: z.array(personSchema).max(6).default([]),
      favoritePlace: z.string().trim().max(120).optional(),
      occasion: z.string().trim().max(120).optional(),
      dedication: z.string().trim().max(300).optional(),
      exclusions: z.string().trim().max(300).optional(),
    })
    .default({ people: [] }),
  consent: z.object({
    photoUsage: z.literal(true),
    guardian: z.literal(true),
    acceptedAt: z.string().datetime(),
  }),
  /** Vorbereitet für Warenkorb/Checkout */
  product: z
    .object({ sku: z.string().default("book-hardcover-a4"), quantity: z.number().int().min(1).max(10).default(1) })
    .default({ sku: "book-hardcover-a4", quantity: 1 }),
});
export type OrderDraft = z.infer<typeof orderDraftSchema>;
