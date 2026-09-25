"use client";

import { useId, useRef, useState } from "react";
import { ACCEPT_ATTR, formatBytes, ImageError, processImage } from "@/lib/image";
import type { PhotoRef } from "@/lib/validation";

type Props = {
  label: string;
  hint: string;
  /** Kurzer Datenschutzhinweis direkt am Upload */
  privacyNote?: string;
  value: PhotoRef | null;
  error?: string;
  illustration: "child" | "teddy";
  onSelected: (blob: Blob, meta: Omit<PhotoRef, "id" | "url">) => void | Promise<void>;
  onRemove: () => void;
};

type Status = { kind: "idle" } | { kind: "processing" } | { kind: "error"; message: string };

export function ImageUpload({ label, hint, privacyNote, value, error, illustration, onSelected, onRemove }: Props) {
  const id = useId();
  const inputRef = useRef<HTMLInputElement>(null);
  const [status, setStatus] = useState<Status>({ kind: "idle" });
  const [dragging, setDragging] = useState(false);
  const [warning, setWarning] = useState<string | undefined>();

  const handleFile = async (file: File | undefined) => {
    if (!file) return;
    setStatus({ kind: "processing" });
    setWarning(undefined);
    try {
      const img = await processImage(file);
      await onSelected(img.blob, { name: file.name.slice(0, 120), size: img.blob.size, width: img.width, height: img.height });
      setWarning(img.warning);
      setStatus({ kind: "idle" });
    } catch (e) {
      setStatus({ kind: "error", message: e instanceof ImageError ? e.message : "Beim Vorbereiten des Fotos ist etwas schiefgelaufen. Bitte versuche es noch einmal." });
    } finally {
      if (inputRef.current) inputRef.current.value = "";
    }
  };

  const message = status.kind === "error" ? status.message : error;
  const describedBy = `${id}-hint ${message ? `${id}-err` : ""}`.trim();

  return (
    <div className="upload">
      <input
        ref={inputRef}
        id={id}
        type="file"
        accept={ACCEPT_ATTR}
        className="sr-only"
        aria-describedby={describedBy}
        aria-invalid={message ? true : undefined}
        onChange={(e) => handleFile(e.target.files?.[0])}
      />

      {!value ? (
        <label
          htmlFor={id}
          className={`upload-zone ${dragging ? "is-drag" : ""} ${message ? "is-error" : ""}`}
          onDragOver={(e) => {
            e.preventDefault();
            setDragging(true);
          }}
          onDragLeave={() => setDragging(false)}
          onDrop={(e) => {
            e.preventDefault();
            setDragging(false);
            handleFile(e.dataTransfer.files?.[0]);
          }}
        >
          {status.kind === "processing" ? (
            <span className="flex flex-col items-center gap-3" role="status">
              <span className="upload-spinner" aria-hidden="true" />
              <span className="font-semibold">Foto wird vorbereitet …</span>
            </span>
          ) : (
            <>
              <UploadArt kind={illustration} />
              <span className="mt-4 block font-display text-[1.35rem] leading-tight text-ink">{label}</span>
              <span className="upload-cta mt-4">
                <svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true">
                  <path d="M12 16V4m0 0-4.5 4.5M12 4l4.5 4.5M4 15v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
                Foto auswählen
              </span>
              <span className="mt-2 hidden text-[0.9rem] text-ink-soft md:block">oder hierher ziehen</span>
              <span className="mt-3 block text-[0.82rem] text-ink-soft">JPG, PNG oder HEIC · bis 25 MB</span>
            </>
          )}
        </label>
      ) : (
        <div className="upload-preview">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={value.url} alt={`Vorschau: ${label}`} className="upload-img" width={value.width} height={value.height} />
          <div className="upload-meta">
            <p className="flex items-center gap-2 font-semibold text-ink">
              <svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true" className="text-sage">
                <circle cx="12" cy="12" r="10" fill="currentColor" opacity=".16" />
                <path d="m7.5 12.5 3 3 6-6.5" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
              Foto bereit
            </p>
            <p className="mt-1 text-[0.88rem] leading-snug text-ink-soft">
              {value.width} × {value.height} px · {formatBytes(value.size)}
            </p>
            <div className="mt-4 flex flex-wrap gap-2">
              <label htmlFor={id} className="btn btn-ghost !min-h-[44px] cursor-pointer !px-4 !py-2 text-[0.95rem]">
                Ersetzen
              </label>
              <button type="button" className="btn btn-ghost !min-h-[44px] !px-4 !py-2 text-[0.95rem]" onClick={onRemove}>
                Entfernen
              </button>
            </div>
            {status.kind === "processing" && (
              <p className="mt-3 text-[0.9rem] text-ink-soft" role="status">
                Neues Foto wird vorbereitet …
              </p>
            )}
          </div>
        </div>
      )}

      <p id={`${id}-hint`} className="hint mt-3">
        {hint}
      </p>
      {warning && value && (
        <p className="mt-2 rounded-xl bg-gold-soft/40 px-3 py-2 text-[0.9rem] text-ink" role="status">
          {warning}
        </p>
      )}
      {message && (
        <p id={`${id}-err`} className="error-text mt-2" role="alert">
          {message}
        </p>
      )}
      {privacyNote && (
        <p className="mt-3 flex items-start gap-2 text-[0.85rem] text-ink-soft">
          <svg viewBox="0 0 24 24" width="16" height="16" aria-hidden="true" className="mt-[3px] shrink-0">
            <path d="M12 3 5 6v5c0 4.5 3 8.3 7 10 4-1.7 7-5.5 7-10V6l-7-3Z" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" />
          </svg>
          {privacyNote}
        </p>
      )}
    </div>
  );
}

/** Dezente Linien-Illustration (kein Stockfoto, keine fremden Personen) */
function UploadArt({ kind }: { kind: "child" | "teddy" }) {
  return (
    <svg viewBox="0 0 120 96" width="120" height="96" aria-hidden="true" className="upload-art">
      <rect x="14" y="10" width="92" height="76" rx="14" fill="#fff8ee" stroke="#d9c6a6" strokeWidth="2" />
      <path d="M22 76 46 52l14 14 12-10 26 20" fill="none" stroke="#eadcc6" strokeWidth="2" />
      {kind === "child" ? (
        <g stroke="#10264a" strokeWidth="2.2" fill="none" strokeLinecap="round">
          <circle cx="60" cy="42" r="15" fill="#f6e3cf" />
          <path d="M45 40c2-12 26-14 30 0" stroke="#c9953f" strokeWidth="5" />
          <circle cx="55" cy="43" r="1.4" fill="#10264a" stroke="none" />
          <circle cx="65" cy="43" r="1.4" fill="#10264a" stroke="none" />
          <path d="M56 49c2.4 2 5.6 2 8 0" />
          <path d="M41 78c3-10 11-15 19-15s16 5 19 15" fill="#ef6a67" fillOpacity=".25" />
        </g>
      ) : (
        <g stroke="#10264a" strokeWidth="2.2" fill="none" strokeLinecap="round">
          <circle cx="47" cy="30" r="7" fill="#d9b88a" />
          <circle cx="73" cy="30" r="7" fill="#d9b88a" />
          <circle cx="60" cy="45" r="16" fill="#e6c9a0" />
          <ellipse cx="60" cy="50" rx="7" ry="5" fill="#f6e3cf" />
          <circle cx="54" cy="42" r="1.5" fill="#10264a" stroke="none" />
          <circle cx="66" cy="42" r="1.5" fill="#10264a" stroke="none" />
          <path d="M58 50h4" />
          <path d="M44 78c2-9 8-14 16-14s14 5 16 14" fill="#d6b36a" fillOpacity=".35" />
        </g>
      )}
      <circle cx="98" cy="18" r="3" fill="#d6b36a" />
    </svg>
  );
}
