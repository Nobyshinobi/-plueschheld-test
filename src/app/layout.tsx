import type { Metadata, Viewport } from "next";
import localFont from "next/font/local";
import "./globals.css";

// Selbst gehostete, variable Schriften (keine Anfrage an Drittanbieter, kein Layout-Shift dank Fallback-Metriken)
const fraunces = localFont({
  src: "../fonts/fraunces-soft.woff2",
  variable: "--font-fraunces",
  weight: "100 900",
  display: "swap",
  // Eigene, gemessene Fallback-Faces in globals.css (next/font rechnet für Times 126,7 % –
  // bei Fraunces@540 sind 117,9 % korrekt; zusätzlich Android/Linux-Serifen abgedeckt)
  adjustFontFallback: false,
});
const frauncesItalic = localFont({
  src: "../fonts/fraunces-soft-italic.woff2",
  variable: "--font-fraunces-italic",
  weight: "100 900",
  style: "italic",
  display: "swap",
  preload: false,
});
const figtree = localFont({
  src: "../fonts/figtree.woff2",
  variable: "--font-figtree",
  weight: "300 900",
  display: "swap",
  adjustFontFallback: "Arial",
});

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: "PlüschHeld – Personalisierte Kinderbücher mit deinem Kind und seinem Kuscheltier",
  description:
    "Aus einem Foto deines Kindes und seines Lieblingskuscheltiers entsteht ein liebevoll illustriertes Kinderbuch – ein Abenteuer, das es nur einmal gibt.",
  openGraph: {
    title: "PlüschHeld – Dein Kind wird zum Helden seiner eigenen Geschichte",
    description: "Personalisierte Kinderbücher: Kind + Kuscheltier + eure Idee = ein Buch, das es nur einmal gibt.",
    images: [{ url: "/og.jpg", width: 1200, height: 630, alt: "PlüschHeld – Personalisierte Kinderbücher" }],
    locale: "de_DE",
    type: "website",
  },
  robots: { index: true, follow: true },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#0b1d36",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="de" className={`${fraunces.variable} ${frauncesItalic.variable} ${figtree.variable}`}>
      <body>{children}</body>
    </html>
  );
}
