import type { NextConfig } from "next";

const securityHeaders = [
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  // Kamera/Mikrofon/Standort werden nie benötigt – Fotos kommen ausschließlich über die Dateiauswahl.
  { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=(), interest-cohort=()" },
  { key: "X-Frame-Options", value: "SAMEORIGIN" },
];

const nextConfig: NextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  images: { unoptimized: true }, // Bild-Derivate (AVIF/WebP, responsive) erzeugt die eigene Pipeline
  // ~14 kB CSS inline im <head>: keine render-blockierende Anfrage (Landingpage, v. a. Erstbesucher)
  experimental: { inlineCss: true },
  async headers() {
    return [
      { source: "/:path*", headers: securityHeaders },
      {
        // Sequenz-Frames, Buchseiten & Marke: lange cachen, aber revalidierbar (Dateinamen sind nicht gehasht)
        source: "/(media|brand)/:path*",
        headers: [{ key: "Cache-Control", value: "public, max-age=604800, stale-while-revalidate=86400" }],
      },
    ];
  },
};

export default nextConfig;
