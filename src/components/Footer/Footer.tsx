import Link from "next/link";
import { copy } from "@/content/copy";

export function Footer() {
  return (
    <footer className="relative z-[3] bg-night pb-[max(2.5rem,env(safe-area-inset-bottom))] pt-16 text-cream/85">
      <div className="container-page grid gap-10 md:grid-cols-[1.2fr_1fr] md:items-end">
        <div>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/brand/lockup-gold.webp" alt={`${copy.brand.name} – ${copy.brand.tagline}`} width={978} height={320} className="h-auto w-[220px] md:w-[260px]" loading="lazy" />
          <p className="mt-5 max-w-[36ch] text-[1.02rem] leading-relaxed text-cream/80">{copy.footer.note}</p>
        </div>
        <nav aria-label="Fußzeile" className="flex flex-wrap gap-x-7 gap-y-3 text-[0.97rem] md:justify-end">
          <Link href="/#buch-erstellen" className="font-semibold text-gold-soft underline-offset-4 hover:underline">
            {copy.nav.create}
          </Link>
          <Link href="/datenschutz" className="underline-offset-4 hover:underline">
            Datenschutz &amp; Fotos
          </Link>
        </nav>
      </div>
      <div className="container-page mt-12 flex flex-col gap-2 border-t border-cream/15 pt-6 text-[0.86rem] text-cream/60 md:flex-row md:justify-between">
        <p>© {new Date().getFullYear()} {copy.brand.name}</p>
        <p>{copy.footer.demo}</p>
      </div>
    </footer>
  );
}
