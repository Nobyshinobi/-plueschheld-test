"use client";

import Link from "next/link";
import { useEffect, useRef, useState, useSyncExternalStore } from "react";
import { copy } from "@/content/copy";
import { navTheme, type NavTheme } from "@/lib/navTheme";
import { scrollToId } from "@/lib/scrollTo";

const LINKS = [
  { id: "so-funktionierts", label: copy.nav.how },
  { id: "beispiel", label: copy.nav.example },
] as const;

type Props = {
  fixedTheme?: NavTheme;
  /** Ziel des Skip-Links (Startseite: Konfigurator hinter der langen Story; Unterseiten: Inhalt) */
  skipTo?: { id: string; label: string };
};

export function Navigation({ fixedTheme, skipTo = { id: "buch-erstellen", label: copy.nav.skip } }: Props) {
  const storeTheme = useSyncExternalStore(navTheme.subscribe, navTheme.get, () => "dark" as NavTheme);
  const theme = fixedTheme ?? storeTheme;
  const [open, setOpen] = useState(false);
  const btnRef = useRef<HTMLButtonElement>(null);
  const panelRef = useRef<HTMLDivElement>(null);

  // Menü: Escape schließt, Fokus zurück zum Button
  useEffect(() => {
    if (!open) return;
    panelRef.current?.querySelector<HTMLElement>("a,button")?.focus();
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        setOpen(false);
        btnRef.current?.focus();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open]);

  const go = (e: React.MouseEvent<HTMLAnchorElement>, id: string) => {
    if (!document.getElementById(id)) return; // Unterseite: normaler Link auf "/#id"
    e.preventDefault();
    setOpen(false);
    scrollToId(id);
  };

  const dark = theme === "dark" && !open;
  return (
    <header className={`site-nav ${dark ? "is-dark" : "is-light"} ${open ? "is-open" : ""}`}>
      <a href={`#${skipTo.id}`} onClick={(e) => go(e, skipTo.id)} className="skip-link">
        {skipTo.label}
      </a>
      <div className="container-page flex h-[var(--nav-h)] items-center justify-between gap-4">
        <Link href="/" className="relative block h-[34px] w-[108px] shrink-0 md:h-[40px] md:w-[128px]" aria-label={`${copy.brand.name} – Startseite`}>
          {/* Zwei Varianten übereinander, weiche Überblendung beim Themenwechsel */}
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/brand/wordmark-gold.webp" alt="" width={978} height={320} className="logo-img" style={{ opacity: dark ? 1 : 0 }} />
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/brand/wordmark-ink.webp" alt="" width={977} height={320} className="logo-img" style={{ opacity: dark ? 0 : 1 }} />
        </Link>

        <nav aria-label="Hauptnavigation" className="hidden items-center gap-7 md:flex">
          {LINKS.map((l) => (
            <Link key={l.id} href={`/#${l.id}`} onClick={(e) => go(e, l.id)} className="nav-link">
              {l.label}
            </Link>
          ))}
          <Link href="/#buch-erstellen" onClick={(e) => go(e, "buch-erstellen")} className={`btn !min-h-[44px] !px-5 !py-2 text-[0.95rem] ${dark ? "btn-light" : ""}`}>
            {copy.nav.create}
          </Link>
        </nav>

        <button
          ref={btnRef}
          type="button"
          className="nav-menu-btn md:hidden"
          aria-expanded={open}
          aria-controls="mobile-menu"
          onClick={() => setOpen((o) => !o)}
        >
          <span className="sr-only">{open ? copy.nav.close : copy.nav.menu}</span>
          <span aria-hidden="true" className="nav-burger" />
        </button>
      </div>

      <div id="mobile-menu" ref={panelRef} className="mobile-menu md:hidden" hidden={!open}>
        <nav aria-label="Mobile Navigation" className="container-page flex flex-col gap-1 pb-6 pt-2">
          {LINKS.map((l) => (
            <Link key={l.id} href={`/#${l.id}`} onClick={(e) => go(e, l.id)} className="mobile-link">
              {l.label}
            </Link>
          ))}
          <Link href="/#buch-erstellen" onClick={(e) => go(e, "buch-erstellen")} className="btn mt-3 w-full">
            {copy.nav.create}
          </Link>
        </nav>
      </div>
    </header>
  );
}
