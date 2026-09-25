"use client";

import { forwardRef, useId } from "react";
import { fillExample, storyExamples } from "@/content/interests";

type Props = {
  value: string;
  onChange: (v: string) => void;
  childName: string;
  teddyName: string;
  error?: string;
};

const MAX = 1000;

/** Großes, freundliches Textfeld – keine Formularwand, sondern "erzähl einfach". */
export const StoryInput = forwardRef<HTMLTextAreaElement, Props>(function StoryInput({ value, onChange, childName, teddyName, error }, ref) {
  const id = useId();
  const personalize = (s: string) => fillExample(s, childName, teddyName);

  return (
    <div>
      <label htmlFor={id} className="label">
        Worum soll es gehen?
      </label>
      <p id={`${id}-hint`} className="hint mb-3">
        Ein paar Sätze reichen völlig. Keine Idee? Kein Problem – dann überraschen wir euch.
      </p>
      <textarea
        ref={ref}
        id={id}
        className="field min-h-[168px] resize-y leading-relaxed"
        rows={6}
        maxLength={MAX}
        value={value}
        aria-describedby={`${id}-hint ${id}-count${error ? ` ${id}-err` : ""}`}
        aria-invalid={error ? true : undefined}
        placeholder={`z. B. „${personalize(storyExamples[0].text)}“`}
        onChange={(e) => onChange(e.target.value)}
      />
      <div className="mt-2 flex items-start justify-between gap-4">
        <div className="flex flex-wrap gap-2">
          <span className="text-[0.85rem] text-ink-soft">Inspiration:</span>
          {storyExamples.map((ex) => (
            <button
              key={ex.label}
              type="button"
              className="rounded-full bg-sand/60 px-3 py-1 text-left text-[0.85rem] font-medium text-ink transition-colors hover:bg-sand"
              onClick={() => onChange(personalize(ex.text))}
            >
              {ex.label}
            </button>
          ))}
        </div>
        <p id={`${id}-count`} className="shrink-0 text-[0.82rem] tabular-nums text-ink-soft">
          {value.length} / {MAX}
        </p>
      </div>
      {error && (
        <p id={`${id}-err`} className="error-text mt-2" role="alert">
          {error}
        </p>
      )}
    </div>
  );
});
