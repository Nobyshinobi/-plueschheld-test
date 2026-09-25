"use client";

/**
 * Konfigurator – "Jetzt beginnt eure Geschichte."
 * ===============================================
 * Große Karten, ein Schritt nach dem anderen, jederzeit zurück, alles vor dem Absenden prüfbar.
 * Formularzustand unabhängig von der Cinematic-Timeline (Storytelling ≠ Geschäftslogik).
 */
import { useCallback, useEffect, useRef, useState } from "react";
import { useForm } from "react-hook-form";
import { EXIT_LEN } from "@/animations/storyTimeline";
import { ImageUpload } from "@/components/ImageUpload/ImageUpload";
import { InterestSelector } from "@/components/InterestSelector/InterestSelector";
import { StoryInput } from "@/components/StoryInput/StoryInput";
import { copy } from "@/content/copy";
import { interests as interestList } from "@/content/interests";
import { clearDraft, loadDraft, photoStore, type PhotoSlot, saveDraft } from "@/lib/draftStorage";
import { buildOrderDraft, submitOrderDraft, type SubmitResult } from "@/lib/order";
import { AGES, type ConfiguratorValues, emptyValues, type PhotoRef, PRONOUNS, stepSchemas, type StepId } from "@/lib/validation";
import { BookPreviewCard } from "./BookPreviewCard";
import { HowItWorks } from "./HowItWorks";

const STEPS: { id: StepId; title: string; short: string; fields: (keyof ConfiguratorValues)[] }[] = [
  { id: "child", title: "Foto deines Kindes", short: "Kind", fields: ["childPhoto"] },
  { id: "teddy", title: "Foto des Lieblingskuscheltiers", short: "Kuscheltier", fields: ["teddyPhoto", "teddyName"] },
  { id: "details", title: "Wer ist unser Held?", short: "Name & Alter", fields: ["childName", "childAge", "pronoun"] },
  { id: "interests", title: "Was liebt dein Kind?", short: "Interessen", fields: ["interests", "customInterest"] },
  { id: "story", title: "Erzähl uns eure Idee.", short: "Idee", fields: ["storyIdea"] },
  { id: "review", title: "Fast geschafft!", short: "Prüfen", fields: ["consent"] },
];
const NUMBERED = STEPS.length - 1; // "Prüfen" ist der Abschluss, kein eigener nummerierter Schritt

type Errors = Partial<Record<keyof ConfiguratorValues, string>>;

export function Configurator() {
  const { register, watch, setValue, getValues, reset } = useForm<ConfiguratorValues>({ defaultValues: emptyValues });
  const values = watch();
  const [step, setStep] = useState(0);
  const [errors, setErrors] = useState<Errors>({});
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [done, setDone] = useState<SubmitResult | null>(null);
  const [restored, setRestored] = useState(false);
  const headingRef = useRef<HTMLHeadingElement>(null);
  const cardRef = useRef<HTMLDivElement>(null);
  const urls = useRef<Partial<Record<PhotoSlot, string>>>({});
  const focusOnStep = useRef(false);

  // ---------- Entwurf wiederherstellen (nur Client, nach Hydration) ----------
  useEffect(() => {
    let alive = true;
    (async () => {
      const d = loadDraft();
      if (!d) return setRestored(true);
      const v: ConfiguratorValues = { ...emptyValues, ...d.values, childPhoto: null, teddyPhoto: null, consent: false };
      for (const slot of ["child", "teddy"] as const) {
        const meta = d.values[slot === "child" ? "childPhoto" : "teddyPhoto"];
        if (!meta) continue;
        const blob = await photoStore.get(slot);
        if (blob && alive) {
          const url = URL.createObjectURL(blob);
          urls.current[slot] = url;
          v[slot === "child" ? "childPhoto" : "teddyPhoto"] = { ...meta, url };
        }
      }
      if (!alive) return;
      reset(v);
      setStep(Math.min(d.step, STEPS.length - 1));
      setRestored(true);
    })();
    const u = urls.current;
    return () => {
      alive = false;
      Object.values(u).forEach((x) => x && URL.revokeObjectURL(x));
    };
  }, [reset]);

  // ---------- Zwischenspeichern (entprellt) ----------
  useEffect(() => {
    if (!restored || done) return;
    const t = window.setTimeout(() => saveDraft(step, getValues()), 350);
    return () => window.clearTimeout(t);
  }, [values, step, restored, done, getValues]);

  // ---------- Fokus auf die Schritt-Überschrift (Tastatur/Screenreader) ----------
  useEffect(() => {
    if (!focusOnStep.current) return;
    focusOnStep.current = false;
    headingRef.current?.focus({ preventScroll: true });
    const card = cardRef.current;
    if (card) {
      const r = card.getBoundingClientRect();
      if (r.top < 70 || r.top > window.innerHeight * 0.5) {
        const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
        window.scrollTo({ top: window.scrollY + r.top - 88, behavior: reduce ? "auto" : "smooth" });
      }
    }
  }, [step, done]);

  const setPhoto = useCallback(
    async (slot: PhotoSlot, blob: Blob, meta: Omit<PhotoRef, "id" | "url">) => {
      const old = urls.current[slot];
      if (old) URL.revokeObjectURL(old);
      const url = URL.createObjectURL(blob);
      urls.current[slot] = url;
      await photoStore.put(slot, blob);
      const field = slot === "child" ? "childPhoto" : "teddyPhoto";
      setValue(field, { ...meta, id: `${slot}-${Date.now().toString(36)}`, url }, { shouldDirty: true });
      setErrors((e) => ({ ...e, [field]: undefined }));
    },
    [setValue],
  );

  const removePhoto = (slot: PhotoSlot) => {
    const old = urls.current[slot];
    if (old) URL.revokeObjectURL(old);
    delete urls.current[slot];
    void photoStore.remove(slot);
    setValue(slot === "child" ? "childPhoto" : "teddyPhoto", null, { shouldDirty: true });
  };

  const validateStep = (i: number): boolean => {
    const s = STEPS[i];
    const v = getValues();
    const pick = Object.fromEntries(s.fields.map((f) => [f, v[f]]));
    const res = stepSchemas[s.id].safeParse(pick);
    if (res.success) {
      setErrors({});
      return true;
    }
    const next: Errors = {};
    for (const issue of res.error.issues) {
      const k = issue.path[0] as keyof ConfiguratorValues;
      if (!next[k]) next[k] = issue.message;
    }
    setErrors(next);
    // erstes fehlerhaftes Feld fokussieren
    requestAnimationFrame(() => cardRef.current?.querySelector<HTMLElement>("[aria-invalid='true'], .chip, input[type='file']")?.focus());
    return false;
  };

  const goTo = (i: number) => {
    focusOnStep.current = true;
    setErrors({});
    setStep(i);
  };

  const onNext = async () => {
    if (!validateStep(step)) return;
    if (step < STEPS.length - 1) return goTo(step + 1);
    // Absenden
    setSubmitting(true);
    setSubmitError(null);
    try {
      const draft = buildOrderDraft(getValues());
      const res = await submitOrderDraft(draft);
      await clearDraft();
      focusOnStep.current = true;
      setDone(res);
    } catch (e) {
      setSubmitError(e instanceof Error ? e.message : "Das hat leider nicht geklappt. Bitte versuche es noch einmal.");
    } finally {
      setSubmitting(false);
    }
  };

  const restart = async () => {
    await clearDraft();
    Object.values(urls.current).forEach((x) => x && URL.revokeObjectURL(x));
    urls.current = {};
    reset(emptyValues);
    setDone(null);
    goTo(0);
  };

  /** register + Fehler des Feldes beim Korrigieren sofort entfernen */
  const reg = (name: "teddyName" | "childName" | "childAge" | "pronoun" | "consent") =>
    register(name, { onChange: () => setErrors((e) => (e[name] ? { ...e, [name]: undefined } : e)) });

  const s = STEPS[step];
  const numbered = Math.min(step + 1, NUMBERED);

  return (
    <section
      id="konfigurator"
      className="configurator relative z-[2] bg-paper"
      style={{ marginTop: `calc(${-EXIT_LEN} * 100 * var(--vh-small))` }}
      aria-labelledby="config-title"
    >
      <HowItWorks />

      <div id="buch-erstellen" className="container-page scroll-mt-20 pb-24 pt-6 md:pb-32">
        <div className="mx-auto max-w-2xl text-center">
          <p className="eyebrow text-gold-text">{copy.configurator.eyebrow}</p>
          <h2 id="config-title" className="mt-3 text-headline text-ink">
            {copy.configurator.headline}
          </h2>
          <p className="mx-auto mt-4 max-w-[46ch] text-lead text-ink-soft">{copy.configurator.intro}</p>
        </div>

        <div className="mt-10 grid items-start gap-8 lg:mt-14 lg:grid-cols-[minmax(0,1fr)_340px] lg:gap-10">
          <div ref={cardRef} className="card scroll-mt-24 overflow-hidden">
            {done ? (
              <SuccessState result={done} name={values.childName} headingRef={headingRef} onRestart={restart} />
            ) : (
              <form
                noValidate
                onSubmit={(e) => {
                  e.preventDefault();
                  void onNext();
                }}
              >
                {/* Fortschritt */}
                <div className="border-b border-sand/80 px-5 pb-4 pt-5 sm:px-8 sm:pt-7">
                  <div className="flex items-center justify-between gap-3 text-[0.9rem]">
                    <p className="font-semibold text-ink">
                      {step < NUMBERED ? (
                        <>
                          Schritt {numbered} <span className="font-normal text-ink-soft">von {NUMBERED}</span>
                        </>
                      ) : (
                        "Zusammenfassung"
                      )}
                    </p>
                    <p className="text-ink-soft">
                      <span className="sr-only">Aktueller Schritt: </span>
                      {s.short}
                    </p>
                  </div>
                  <div className="mt-3 h-1.5 overflow-hidden rounded-full bg-sand/70" aria-hidden="true">
                    <div className="h-full rounded-full bg-coral-deep transition-[width] duration-500 ease-[var(--ease-out-soft)]" style={{ width: `${((step + 1) / STEPS.length) * 100}%` }} />
                  </div>
                  <ol className="mt-4 hidden gap-1 sm:flex" aria-label="Schritte">
                    {STEPS.map((st, i) => (
                      <li key={st.id} className="flex-1">
                        <button
                          type="button"
                          className={`step-pill ${i === step ? "is-current" : i < step ? "is-done" : ""}`}
                          disabled={i > step}
                          aria-current={i === step ? "step" : undefined}
                          onClick={() => i < step && goTo(i)}
                        >
                          {st.short}
                        </button>
                      </li>
                    ))}
                  </ol>
                </div>

                <div key={s.id} className="step-panel px-5 py-7 sm:px-8 sm:py-9">
                  <h3 ref={headingRef} tabIndex={-1} className="text-title text-ink outline-none">
                    {s.title}
                  </h3>

                  <div className="mt-5">
                    {s.id === "child" && (
                      <ImageUpload
                        illustration="child"
                        label="Foto deines Kindes"
                        hint="Am besten funktioniert ein gut beleuchtetes Foto, auf dem Gesicht und Haare vollständig sichtbar sind."
                        privacyNote="Deine Fotos bleiben bis zum Absenden nur auf diesem Gerät. Standortdaten (EXIF) entfernen wir automatisch."
                        value={values.childPhoto}
                        error={errors.childPhoto}
                        onSelected={(b, m) => setPhoto("child", b, m)}
                        onRemove={() => removePhoto("child")}
                      />
                    )}

                    {s.id === "teddy" && (
                      <div className="space-y-6">
                        <ImageUpload
                          illustration="teddy"
                          label="Foto des Lieblingskuscheltiers"
                          hint="Fotografiere das Kuscheltier möglichst vollständig und bei gutem Licht."
                          value={values.teddyPhoto}
                          error={errors.teddyPhoto}
                          onSelected={(b, m) => setPhoto("teddy", b, m)}
                          onRemove={() => removePhoto("teddy")}
                        />
                        <div>
                          <label htmlFor="teddyName" className="label">
                            Wie heißt das Kuscheltier? <span className="font-normal text-ink-soft">(optional)</span>
                          </label>
                          <input id="teddyName" className="field" autoComplete="off" maxLength={40} placeholder="z. B. Fauli" aria-invalid={errors.teddyName ? true : undefined} {...reg("teddyName")} />
                          {errors.teddyName && <p className="error-text mt-2">{errors.teddyName}</p>}
                        </div>
                      </div>
                    )}

                    {s.id === "details" && (
                      <div className="grid gap-6 sm:grid-cols-[1fr_180px]">
                        <div>
                          <label htmlFor="childName" className="label">
                            Name des Kindes
                          </label>
                          <input
                            id="childName"
                            className="field"
                            autoComplete="off"
                            autoCapitalize="words"
                            enterKeyHint="next"
                            maxLength={40}
                            placeholder="z. B. Emma"
                            aria-invalid={errors.childName ? true : undefined}
                            aria-describedby={errors.childName ? "childName-err" : undefined}
                            {...reg("childName")}
                          />
                          {errors.childName && (
                            <p id="childName-err" className="error-text mt-2" role="alert">
                              {errors.childName}
                            </p>
                          )}
                        </div>
                        <div>
                          <label htmlFor="childAge" className="label">
                            Alter
                          </label>
                          <div className="relative">
                            <select
                              id="childAge"
                              className="field appearance-none pr-10"
                              aria-invalid={errors.childAge ? true : undefined}
                              aria-describedby={errors.childAge ? "childAge-err" : undefined}
                              {...reg("childAge")}
                            >
                              <option value="">Bitte wählen</option>
                              {AGES.map((a) => (
                                <option key={a} value={a}>
                                  {a === "unter 1" ? "unter 1 Jahr" : a === "1" ? "1 Jahr" : a === "13+" ? "13 Jahre oder älter" : `${a} Jahre`}
                                </option>
                              ))}
                            </select>
                            <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true" className="pointer-events-none absolute right-4 top-1/2 -translate-y-1/2 text-ink-soft">
                              <path d="m6 9 6 6 6-6" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
                            </svg>
                          </div>
                          {errors.childAge && (
                            <p id="childAge-err" className="error-text mt-2" role="alert">
                              {errors.childAge}
                            </p>
                          )}
                        </div>
                        <fieldset className="sm:col-span-2">
                          <legend className="label">
                            Gewünschte Ansprache <span className="font-normal text-ink-soft">(optional)</span>
                          </legend>
                          <div className="flex flex-wrap gap-2.5">
                            {PRONOUNS.map((p) => (
                              <label key={p.id} className="radio-pill">
                                <input type="radio" value={p.id} className="sr-only" {...reg("pronoun")} />
                                <span>{p.label}</span>
                              </label>
                            ))}
                          </div>
                        </fieldset>
                      </div>
                    )}

                    {s.id === "interests" && (
                      <InterestSelector
                        value={values.interests}
                        onChange={(v) => {
                          setValue("interests", v, { shouldDirty: true });
                          setErrors({});
                        }}
                        custom={values.customInterest}
                        onCustomChange={(v) => setValue("customInterest", v, { shouldDirty: true })}
                        error={errors.interests}
                      />
                    )}

                    {s.id === "story" && (
                      <StoryInput
                        value={values.storyIdea}
                        onChange={(v) => setValue("storyIdea", v, { shouldDirty: true })}
                        childName={values.childName}
                        teddyName={values.teddyName}
                        error={errors.storyIdea}
                      />
                    )}

                    {s.id === "review" && <Review values={values} onEdit={goTo} consentError={errors.consent} registerConsent={reg("consent")} />}
                  </div>

                  {submitError && (
                    <p className="error-text mt-6" role="alert">
                      {submitError}
                    </p>
                  )}

                  <div className="mt-8 flex flex-col-reverse gap-3 sm:flex-row sm:items-center sm:justify-between">
                    {step > 0 ? (
                      <button type="button" className="btn btn-ghost" onClick={() => goTo(step - 1)}>
                        Zurück
                      </button>
                    ) : (
                      <span className="hidden sm:block" />
                    )}
                    <button type="submit" className={`btn ${s.id === "review" ? "btn-cta" : ""}`} disabled={submitting}>
                      {s.id === "review" ? (submitting ? "Wird gesendet …" : copy.configurator.cta) : "Weiter"}
                      <svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true">
                        <path d="M5 12h13m-5-5 5 5-5 5" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                      </svg>
                    </button>
                  </div>
                </div>
              </form>
            )}
          </div>

          <aside className="hidden lg:sticky lg:top-24 lg:block" aria-label="Live-Vorschau eures Buches">
            <BookPreviewCard values={values} />
          </aside>
        </div>
      </div>
    </section>
  );
}

function Review({
  values,
  onEdit,
  consentError,
  registerConsent,
}: {
  values: ConfiguratorValues;
  onEdit: (i: number) => void;
  consentError?: string;
  registerConsent: ReturnType<ReturnType<typeof useForm<ConfiguratorValues>>["register"]>;
}) {
  const labels = values.interests.map((i) => interestList.find((x) => x.id === i)?.label ?? i);
  if (values.customInterest.trim()) labels.push(values.customInterest.trim());
  const rows: { k: string; v: React.ReactNode; step: number }[] = [
    { k: "Kind", v: `${values.childName || "–"}${values.childAge ? `, ${values.childAge === "unter 1" ? "unter 1 Jahr" : values.childAge === "1" ? "1 Jahr" : `${values.childAge} Jahre`}` : ""}`, step: 2 },
    { k: "Kuscheltier", v: values.teddyName || "ohne Namen", step: 1 },
    { k: "Interessen", v: labels.join(", ") || "–", step: 3 },
    { k: "Eure Idee", v: values.storyIdea.trim() ? `„${values.storyIdea.trim()}“` : "Wir lassen uns überraschen", step: 4 },
  ];
  return (
    <div>
      <div className="lg:hidden">
        <BookPreviewCard values={values} compact />
      </div>
      <div className="mt-6 grid grid-cols-2 gap-3 lg:mt-0">
        {(["childPhoto", "teddyPhoto"] as const).map((f, i) => (
          <div key={f} className="relative overflow-hidden rounded-2xl bg-sand/40">
            {values[f]?.url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={values[f]!.url} alt={i === 0 ? "Foto des Kindes" : "Foto des Kuscheltiers"} className="aspect-[4/5] w-full object-cover" />
            ) : (
              <div className="aspect-[4/5]" />
            )}
            <button type="button" onClick={() => onEdit(i)} className="absolute bottom-2 right-2 rounded-full bg-cream/95 px-3 py-1.5 text-[0.85rem] font-semibold text-ink shadow">
              Ändern<span className="sr-only"> ({i === 0 ? "Foto des Kindes" : "Foto des Kuscheltiers"})</span>
            </button>
          </div>
        ))}
      </div>
      <dl className="mt-6 divide-y divide-sand/80 rounded-2xl border border-sand/80 bg-[#fffdf9]">
        {rows.map((r) => (
          <div key={r.k} className="flex items-start justify-between gap-4 px-4 py-3.5">
            <div className="min-w-0">
              <dt className="text-[0.85rem] font-semibold text-ink-soft">{r.k}</dt>
              <dd className="mt-0.5 break-words text-ink">{r.v}</dd>
            </div>
            <button type="button" className="shrink-0 text-[0.9rem] font-semibold text-coral-deep underline-offset-4 hover:underline" onClick={() => onEdit(r.step)}>
              Ändern<span className="sr-only"> ({r.k})</span>
            </button>
          </div>
        ))}
      </dl>

      <label className={`consent mt-6 ${consentError ? "is-error" : ""}`}>
        <input type="checkbox" className="consent-box" aria-invalid={consentError ? true : undefined} aria-describedby="consent-desc" {...registerConsent} />
        <span id="consent-desc" className="text-[0.95rem] leading-relaxed text-ink">
          Ich bin erziehungsberechtigt und darf die Fotos verwenden. Ich bin einverstanden, dass PlüschHeld sie ausschließlich zur Gestaltung dieses Buches nutzt und nach Fertigstellung löscht.{" "}
          <a href="/datenschutz" className="font-semibold text-coral-deep underline underline-offset-2">
            Mehr zum Datenschutz
          </a>
        </span>
      </label>
      {consentError && (
        <p className="error-text mt-2" role="alert">
          {consentError}
        </p>
      )}
      <p className="mt-4 text-[0.88rem] text-ink-soft">Im nächsten Schritt wählst du Format und Versand. Noch wird nichts bezahlt.</p>
    </div>
  );
}

function SuccessState({ result, name, headingRef, onRestart }: { result: SubmitResult; name: string; headingRef: React.RefObject<HTMLHeadingElement | null>; onRestart: () => void }) {
  return (
    <div className="px-6 py-12 text-center sm:px-10 sm:py-16" role="status">
      <div className="mx-auto grid h-16 w-16 place-items-center rounded-full bg-gold-soft/60 text-3xl" aria-hidden="true">
        ✨
      </div>
      <h3 ref={headingRef} tabIndex={-1} className="mt-6 text-headline text-ink outline-none">
        Danke! {name ? `${name}s` : "Eure"} Geschichte beginnt.
      </h3>
      <p className="mx-auto mt-4 max-w-[42ch] text-lead text-ink-soft">
        Wir haben alles, was wir brauchen. Als Nächstes würdest du Format und Versand wählen – und wir machen uns an die ersten Skizzen.
      </p>
      <p className="mx-auto mt-6 max-w-[48ch] rounded-2xl bg-sand/50 px-4 py-3 text-[0.9rem] text-ink">
        Vorschau-Version: Es wurde nichts bezahlt und keine Fotos übertragen. Entwurfs-Nr. <span className="font-mono text-[0.82rem]">{result.draftId.slice(0, 14)}</span>
      </p>
      <button type="button" className="btn btn-ghost mt-8" onClick={onRestart}>
        Neues Buch beginnen
      </button>
    </div>
  );
}
