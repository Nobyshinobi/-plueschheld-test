/**
 * Buchvorschau-Manifest.
 *
 * ASSET-HINWEIS: Das Kinderbuch-PDF lag den Projektdateien nicht bei. Die Seiten p0–p5 sind
 * Interim-Vorschauseiten, gesetzt aus dem echten Material von „Emma und die leuchtende Schaukel“
 * (Illustrationen aus dem Transformationsvideo, Titel + Rückseitenzitat vom echten Cover).
 * Echte PDF-Seiten ersetzen sie ohne Code-Änderung:  npm run book:import-pdf -- buch.pdf --pages …
 * Danach nur `alt` unten an die echten Seiten anpassen.
 */
export type BookPage = {
  id: string;
  /** Bildpfad ohne Breite/Endung – Varianten: -720.webp, -1080.webp */
  src: string;
  alt: string;
};

export const bookMeta = {
  title: "Emma und die leuchtende Schaukel",
  hero: "Emma",
  source: "interim" as "interim" | "pdf",
  coverArt: "/media/story/cover-art",
};

export const bookPages: BookPage[] = [
  {
    id: "p0",
    src: "/media/book/p0",
    alt: "Vorsatzblatt mit goldenen Sternen und Monden auf Nachtblau. Etikett: „Dieses Buch gehört Emma – Geschrieben für ein ganz besonderes Kind.“",
  },
  {
    id: "p1",
    src: "/media/book/p1",
    alt: "Titelseite: „Emma und die leuchtende Schaukel“ mit einer runden Illustration der golden leuchtenden Schaukel. „Eine Geschichte über Mut, Freundschaft und ein kleines bisschen Magie.“",
  },
  {
    id: "p2",
    src: "/media/book/p2",
    alt: "Textseite: „Manchmal beginnt die größte Magie mit einem kleinen Traum …“ An diesem Abend konnte Emma einfach nicht einschlafen. Sie drückte ihr Faultier ganz fest an sich – ihren allerbesten Freund. Draußen im Garten raschelte es. Leise. Geheimnisvoll.",
  },
  {
    id: "p3",
    src: "/media/book/p3",
    alt: "Ganzseitige Illustration: Emma mit blonden Locken hält ihr Faultier im gelben Pulli „Lazy with style“ im Arm und schaut staunend aus dem Fenster zur leuchtenden Schaukel.",
  },
  {
    id: "p4",
    src: "/media/book/p4",
    alt: "Textseite: Emma schlich zum Fenster. Die Seile der Schaukel glitzerten wie Sternenstaub. „Siehst du das?“, flüsterte Emma. Ihr Faultier sagte kein Wort. Aber Emma war ganz sicher, dass es lächelte.",
  },
  {
    id: "p5",
    src: "/media/book/p5",
    alt: "Illustration: Emma im Sternen-Schlafanzug am offenen Fenster, draußen leuchtet die Schaukel unter dem Baum im Mondlicht. „Heute Nacht, das spürte Emma ganz genau, würde ein Abenteuer beginnen.“",
  },
];
