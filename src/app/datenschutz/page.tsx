import type { Metadata } from "next";
import Link from "next/link";
import { Footer } from "@/components/Footer/Footer";
import { Navigation } from "@/components/Navigation/Navigation";

export const metadata: Metadata = {
  title: "Datenschutz & Kinderfotos – PlüschHeld",
  description: "Wie PlüschHeld mit Fotos von Kindern und Kuscheltieren umgeht: sparsam, transparent, sicher.",
};

const points = [
  {
    t: "Fotos bleiben auf deinem Gerät – bis du absendest",
    d: "In dieser Vorschau-Version werden Fotos ausschließlich in deinem Browser verarbeitet und zwischengespeichert (IndexedDB). Es findet keine Übertragung an Server oder Dritte statt. Nach dem Absenden oder mit „Neues Buch beginnen“ werden sie gelöscht; unvollständige Entwürfe verfallen nach 14 Tagen.",
  },
  {
    t: "Standortdaten werden entfernt",
    d: "Jedes Foto wird im Browser neu gespeichert. Dabei gehen alle Metadaten (EXIF) verloren – inklusive GPS-Position, Aufnahmedatum und Geräteinformationen.",
  },
  {
    t: "Keine Kinderfotos in Analyse- oder Werbetools",
    d: "Fotos und Namen werden niemals an Analytics-, Heatmap- oder Marketingdienste übergeben.",
  },
  {
    t: "Ausdrückliche Einwilligung",
    d: "Vor dem Absenden bestätigst du, dass du erziehungsberechtigt bist und die Fotos verwenden darfst – und dass wir sie ausschließlich für die Gestaltung eures Buches nutzen.",
  },
  {
    t: "Für den Live-Betrieb vorgesehen",
    d: "Verschlüsselte Übertragung (HTTPS), Upload direkt in einen privaten, verschlüsselten Speicher über zeitlich begrenzte, signierte Adressen, feste Löschfristen nach Fertigstellung, Löschung auf Anfrage sowie eine vollständige Datenschutzerklärung mit allen beteiligten Dienstleistern.",
  },
];

export default function DatenschutzPage() {
  return (
    <>
      <Navigation fixedTheme="light" />
      <main id="inhalt" className="bg-paper pb-24 pt-32 md:pt-40">
        <div className="container-page max-w-3xl">
          <p className="eyebrow text-gold-text">Datenschutz &amp; Fotos</p>
          <h1 className="mt-3 text-headline text-ink">Eure Fotos sind bei uns in guten Händen.</h1>
          <p className="mt-5 text-lead text-ink-soft">
            Kinderfotos sind etwas sehr Persönliches. Deshalb ist PlüschHeld von Anfang an so gebaut, dass so wenig Daten wie möglich entstehen – und nichts ohne euer Einverständnis das Gerät verlässt.
          </p>
          <ul className="mt-10 space-y-4">
            {points.map((p) => (
              <li key={p.t} className="card p-6">
                <h2 className="font-display text-title text-ink">{p.t}</h2>
                <p className="mt-2 leading-relaxed text-ink-soft">{p.d}</p>
              </li>
            ))}
          </ul>
          <p className="mt-10 rounded-2xl border border-sand bg-cream p-5 text-[0.95rem] text-ink-soft">
            Hinweis: Diese Seite beschreibt die technische Umsetzung der Vorschau-Version. Vor dem Live-Betrieb wird sie durch eine rechtlich geprüfte Datenschutzerklärung und ein Impressum ergänzt.
          </p>
          <Link href="/#buch-erstellen" className="btn mt-10">
            Zurück zum Buch
          </Link>
        </div>
      </main>
      <Footer />
    </>
  );
}
