import { interests as interestList } from "@/content/interests";
import type { ConfiguratorValues } from "@/lib/validation";

/** Live-Vorschau: das Cover füllt sich mit euren Angaben – Kind + Teddy → Geschichte → Buch. */
export function BookPreviewCard({ values, compact = false }: { values: ConfiguratorValues; compact?: boolean }) {
  const name = values.childName.trim();
  const teddy = values.teddyName.trim();
  const chips = values.interests.map((i) => interestList.find((x) => x.id === i)).filter(Boolean).slice(0, 4);
  return (
    <div className={compact ? "" : "card p-6"}>
      {!compact && <p className="eyebrow text-gold-text">Euer Buch entsteht</p>}
      <div className={`mini-cover ${compact ? "mx-auto max-w-[240px]" : "mt-4"}`}>
        <div className="mini-cover-foil" aria-hidden="true" />
        <p className="mini-cover-title">{name || "Dein Kind"}</p>
        <p className="mini-cover-sub">und {teddy || "sein Lieblingskuscheltier"}</p>
        <div className="mt-auto flex items-end justify-center gap-3 pb-2">
          {(["childPhoto", "teddyPhoto"] as const).map((f, i) => (
            <div key={f} className={`mini-portrait ${i === 1 ? "-rotate-3" : "rotate-2"}`}>
              {values[f]?.url ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={values[f]!.url} alt="" className="h-full w-full object-cover" />
              ) : (
                <span className="text-[0.72rem] font-semibold text-ink-soft">{i === 0 ? "Kind" : "Teddy"}</span>
              )}
            </div>
          ))}
        </div>
      </div>
      {!compact && (
        <div className="mt-5 min-h-[3rem]">
          {chips.length > 0 ? (
            <ul className="flex flex-wrap gap-1.5" aria-label="Gewählte Interessen">
              {chips.map((c) => (
                <li key={c!.id} className="rounded-full bg-sand/60 px-2.5 py-1 text-[0.82rem] font-medium text-ink">
                  <span aria-hidden="true">{c!.icon} </span>
                  {c!.label}
                </li>
              ))}
            </ul>
          ) : (
            <p className="text-[0.9rem] text-ink-soft">Mit jedem Schritt wird dieses Cover ein bisschen mehr zu eurem.</p>
          )}
          {values.storyIdea.trim() && <p className="mt-3 line-clamp-3 text-[0.9rem] italic text-ink-soft">„{values.storyIdea.trim()}“</p>}
        </div>
      )}
    </div>
  );
}
