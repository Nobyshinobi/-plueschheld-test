"use client";

import { useId, useState } from "react";
import { interests } from "@/content/interests";

type Props = {
  value: string[];
  onChange: (next: string[]) => void;
  custom: string;
  onCustomChange: (v: string) => void;
  error?: string;
};

export function InterestSelector({ value, onChange, custom, onCustomChange, error }: Props) {
  const id = useId();
  const [showCustom, setShowCustom] = useState(custom.length > 0);
  const toggle = (k: string) => onChange(value.includes(k) ? value.filter((x) => x !== k) : [...value, k]);

  return (
    <fieldset aria-describedby={`${id}-hint${error ? ` ${id}-err` : ""}`}>
      <legend className="sr-only">Interessen deines Kindes (Mehrfachauswahl)</legend>
      <p id={`${id}-hint`} className="hint mb-4">
        Mehrfachauswahl möglich – wir weben sie in die Geschichte ein.
      </p>
      <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-3 lg:grid-cols-4">
        {interests.map((it) => {
          const on = value.includes(it.id);
          return (
            <button key={it.id} type="button" className={`chip ${on ? "is-on" : ""}`} aria-pressed={on} onClick={() => toggle(it.id)}>
              <span aria-hidden="true" className="chip-icon">
                {it.icon}
              </span>
              <span>{it.label}</span>
              <span aria-hidden="true" className="chip-check">
                <svg viewBox="0 0 16 16" width="14" height="14">
                  <path d="m3.5 8.5 3 3 6-7" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </span>
            </button>
          );
        })}
        <button
          type="button"
          className={`chip ${showCustom ? "is-on" : ""}`}
          aria-pressed={showCustom}
          aria-controls={`${id}-custom`}
          onClick={() => {
            const next = !showCustom;
            setShowCustom(next);
            if (!next) onCustomChange("");
          }}
        >
          <span aria-hidden="true" className="chip-icon">
            💡
          </span>
          <span>Eigene Idee</span>
        </button>
      </div>
      {showCustom && (
        <div className="mt-4 animate-[fade-up_300ms_var(--ease-out-soft)]" id={`${id}-custom`}>
          <label htmlFor={`${id}-input`} className="label">
            Eigene Idee
          </label>
          <input
            id={`${id}-input`}
            className="field"
            value={custom}
            maxLength={80}
            autoComplete="off"
            placeholder="z. B. Bagger, Einhörner, Ballett …"
            onChange={(e) => onCustomChange(e.target.value)}
          />
        </div>
      )}
      {error && (
        <p id={`${id}-err`} className="error-text mt-3" role="alert">
          {error}
        </p>
      )}
    </fieldset>
  );
}
