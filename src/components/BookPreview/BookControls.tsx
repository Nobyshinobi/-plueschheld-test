"use client";

import { copy } from "@/content/copy";

type Props = {
  /** 0-basierte aktuelle Seite/Doppelseite, -1 = Buch geschlossen */
  index: number;
  total: number;
  mode: "single" | "spread";
  onPrev: () => void;
  onNext: () => void;
  tone?: "paper" | "plain";
};

export function BookControls({ index, total, mode, onPrev, onNext }: Props) {
  const label = mode === "spread" ? "Doppelseite" : "Seite";
  const shown = Math.max(0, index);
  return (
    <div className="flex items-center justify-center gap-3 sm:gap-5">
      <button type="button" className="book-nav-btn" onClick={onPrev} disabled={index <= 0} aria-label={copy.book.prev}>
        <svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true">
          <path d="M14.5 5.5 8 12l6.5 6.5" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </button>
      <p className="min-w-[9.5rem] text-center text-[0.95rem] font-semibold tabular-nums text-ink" aria-live="polite" aria-atomic="true">
        {label} {shown + 1} <span className="font-normal text-ink-soft">von {total}</span>
      </p>
      <button type="button" className="book-nav-btn" onClick={onNext} disabled={index >= total - 1} aria-label={copy.book.next}>
        <svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true">
          <path d="M9.5 5.5 16 12l-6.5 6.5" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </button>
    </div>
  );
}
