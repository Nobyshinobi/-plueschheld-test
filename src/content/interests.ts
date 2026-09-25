export type Interest = { id: string; label: string; icon: string };

/** Emoji bewusst dezent als Bildzeichen (aria-hidden) – Label ist immer Text. */
export const interests: Interest[] = [
  { id: "tiere", label: "Tiere", icon: "🦊" },
  { id: "dinosaurier", label: "Dinosaurier", icon: "🦕" },
  { id: "weltraum", label: "Weltraum", icon: "🚀" },
  { id: "prinzessinnen", label: "Prinzessinnen", icon: "👑" },
  { id: "ritter", label: "Ritter", icon: "🛡️" },
  { id: "fahrzeuge", label: "Fahrzeuge", icon: "🚒" },
  { id: "fussball", label: "Fußball", icon: "⚽" },
  { id: "meer", label: "Meer", icon: "🐚" },
  { id: "magie", label: "Magie", icon: "✨" },
  { id: "abenteuer", label: "Abenteuer", icon: "🧭" },
  { id: "feen", label: "Feen", icon: "🧚" },
  { id: "drachen", label: "Drachen", icon: "🐉" },
];

/**
 * Inspiration für die Story-Idee. Platzhalter: {name}, {teddy} (Nominativ), {teddyDat} (Dativ).
 */
export const storyExamples = [
  { label: "Geheime Tür", text: "{name} und {teddy} sollen nachts eine geheime Tür entdecken und in eine magische Welt reisen." },
  { label: "Reise zum Mond", text: "{name} baut mit {teddyDat} eine Rakete und fliegt zum Mond, um dort einen neuen Freund zu finden." },
  { label: "Mutmach-Geschichte", text: "Eine Mutmach-Geschichte über den ersten Kindergartentag – mit {teddyDat} als Beschützer." },
];

export function fillExample(text: string, name: string, teddyName: string) {
  const n = name.trim() || "Emma";
  const t = teddyName.trim();
  return text
    .replaceAll("{name}", n)
    .replaceAll("{teddyDat}", t || "dem Kuscheltier")
    .replaceAll("{teddy}", t || "das Kuscheltier");
}
