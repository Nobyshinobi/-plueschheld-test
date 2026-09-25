/**
 * Alle sichtbaren Texte an einer Stelle – leicht austauschbar, ohne Komponenten anzufassen.
 */
export const copy = {
  brand: {
    name: "PlüschHeld",
    tagline: "Personalisierte Kinderbücher",
  },
  nav: {
    how: "So funktioniert’s",
    example: "Beispiel ansehen",
    create: "Buch erstellen",
    menu: "Menü",
    close: "Menü schließen",
    skip: "Direkt zum Buch-Konfigurator",
  },
  hero: {
    headline: "Jedes Kind verdient seine eigene Geschichte.",
    subline: "Aus eurem Lieblingsfoto wird ein echtes Abenteuer.",
    scrollCue: "Scrollen und eintauchen",
    sceneDescription:
      "Ein Mädchen liest abends im Bett mit seinem Kuscheltier-Faultier ein Buch. Beim Scrollen fährt die Kamera langsam bis in ihr Auge – und kommt als gemalte Kinderbuch-Illustration wieder heraus.",
  },
  transformation: {
    headline: "Und plötzlich beginnt eure Geschichte.",
    subline: "Dein Kind wird zum Helden. Sein Teddy wird zum besten Freund.",
  },
  proof: [
    "Dein Kind.",
    "Sein Lieblingskuscheltier.",
    "Eure Idee.",
    "Unsere Geschichte.",
    "Ein Buch, das es nur einmal gibt.",
  ],
  book: {
    eyebrow: "Ein Blick ins Buch",
    headline: "Blättere in eine Welt, die nach eurem Kind aussieht.",
    prev: "Vorherige Seite",
    next: "Nächste Seite",
    regionLabel: "Beispielbuch „Emma und die leuchtende Schaukel“ – zum Blättern",
    swipeHint: "Wischen oder tippen zum Blättern",
  },
  how: {
    eyebrow: "So funktioniert’s",
    headline: "Aus Lieblingsfotos werden Lieblingsgeschichten.",
    steps: [
      { title: "Fotos hochladen", text: "Ein Foto deines Kindes und eines vom Lieblingskuscheltier." },
      { title: "Wünsche erzählen", text: "Name, Alter, Interessen – und ein paar Sätze zu eurer Idee." },
      { title: "Wir gestalten euer Buch", text: "Illustriert, liebevoll geschrieben und als echtes Buch gedruckt." },
    ],
    trust: "KI unterstützt – von Menschen gestaltet.",
  },
  configurator: {
    eyebrow: "Buch erstellen",
    headline: "Jetzt beginnt eure Geschichte.",
    intro: "Fünf kleine Schritte. Du kannst jederzeit zurück und alles vor dem Absenden prüfen.",
    cta: "Mein Kinderbuch starten",
  },
  footer: {
    note: "Mit Liebe gemacht für kleine Träumer und große Helden.",
    demo: "Vorschau-Version: Es werden keine Zahlungen ausgelöst und keine Fotos übertragen.",
  },
} as const;
