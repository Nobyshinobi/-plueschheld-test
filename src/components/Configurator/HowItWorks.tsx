import { copy } from "@/content/copy";

const ICONS = [
  // Foto
  <svg key="a" viewBox="0 0 48 48" width="44" height="44" aria-hidden="true"><rect x="6" y="11" width="36" height="28" rx="7" fill="#fff8ee" stroke="#10264a" strokeWidth="2.2" /><circle cx="24" cy="25" r="7" fill="#f1dfb2" stroke="#10264a" strokeWidth="2.2" /><path d="M17 11l3-4h8l3 4" fill="none" stroke="#10264a" strokeWidth="2.2" strokeLinejoin="round" /><circle cx="36" cy="17" r="1.8" fill="#ef6a67" /></svg>,
  // Idee
  <svg key="b" viewBox="0 0 48 48" width="44" height="44" aria-hidden="true"><path d="M10 12h28a4 4 0 0 1 4 4v14a4 4 0 0 1-4 4H22l-8 7v-7h-4a4 4 0 0 1-4-4V16a4 4 0 0 1 4-4Z" fill="#fff8ee" stroke="#10264a" strokeWidth="2.2" strokeLinejoin="round" /><path d="M15 20h18M15 26h11" stroke="#d6b36a" strokeWidth="2.4" strokeLinecap="round" /></svg>,
  // Buch
  <svg key="c" viewBox="0 0 48 48" width="44" height="44" aria-hidden="true"><path d="M24 13c-5-3-11-3.5-17-2v25c6-1.5 12-1 17 2 5-3 11-3.5 17-2V11c-6-1.5-12-1-17 2Z" fill="#fff8ee" stroke="#10264a" strokeWidth="2.2" strokeLinejoin="round" /><path d="M24 13v25" stroke="#10264a" strokeWidth="2.2" /><path d="m33 17 1.2 2.6 2.8.3-2.1 1.9.6 2.8-2.5-1.5-2.5 1.5.6-2.8-2.1-1.9 2.8-.3Z" fill="#d6b36a" /></svg>,
];

export function HowItWorks() {
  return (
    <div id="so-funktionierts" className="sheet-top scroll-mt-16 pt-20 md:pt-28">
      <div className="container-page">
        <div className="mx-auto max-w-2xl text-center" data-reveal>
          <p className="eyebrow text-gold-text">{copy.how.eyebrow}</p>
          <h2 className="mt-3 text-headline text-ink">{copy.how.headline}</h2>
        </div>
        <ol className="mx-auto mt-10 grid max-w-5xl gap-4 md:mt-14 md:grid-cols-3 md:gap-6">
          {copy.how.steps.map((s, i) => (
            <li key={s.title} className="how-step" data-reveal style={{ transitionDelay: `${i * 90}ms` }}>
              <div className="flex items-center gap-4 md:flex-col md:items-start">
                <span className="how-icon">{ICONS[i]}</span>
                <div>
                  <p className="text-[0.8rem] font-bold uppercase tracking-[0.18em] text-gold-text">Schritt {i + 1}</p>
                  <h3 className="mt-1 font-display text-title text-ink">{s.title}</h3>
                </div>
              </div>
              <p className="mt-3 text-[1rem] leading-relaxed text-ink-soft">{s.text}</p>
            </li>
          ))}
        </ol>
        <p className="mt-8 text-center text-[0.95rem] font-semibold text-ink-soft" data-reveal>
          <span aria-hidden="true" className="mr-2 text-gold">✦</span>
          {copy.how.trust}
        </p>
      </div>
      <div className="mx-auto mt-16 h-px max-w-5xl bg-gradient-to-r from-transparent via-sand-deep to-transparent md:mt-20" aria-hidden="true" />
    </div>
  );
}
