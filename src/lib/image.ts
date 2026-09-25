/**
 * Bildverarbeitung im Browser – datenschutzfreundlich
 * ===================================================
 * - Nichts verlässt das Gerät. Kein Upload, kein Drittanbieter.
 * - HEIC/HEIF: nativ dekodieren (Safari); sonst Konverter (heic-to) erst bei Bedarf laden.
 * - Neu-Kodierung als JPEG über Canvas entfernt ALLE Metadaten (EXIF inkl. GPS-Standort).
 * - Ausrichtung (EXIF-Orientation) wird vorher korrekt angewendet.
 * - Lange Kante auf max. 2400 px begrenzt (reicht für Illustrationsvorlagen, spart Speicher).
 */
export const ACCEPTED_TYPES = ["image/jpeg", "image/png", "image/heic", "image/heif", "image/webp"];
export const ACCEPT_ATTR = "image/jpeg,image/png,image/heic,image/heif,image/webp,.jpg,.jpeg,.png,.heic,.heif,.webp";
export const MAX_INPUT_BYTES = 25 * 1024 * 1024;
const MAX_EDGE = 2400;
const MIN_SHORT_EDGE = 700;

export type ProcessedImage = {
  blob: Blob;
  width: number;
  height: number;
  /** Hinweis ohne Fehler (z. B. geringe Auflösung) */
  warning?: string;
};

export class ImageError extends Error {}

const isHeicName = (f: File) => /\.(heic|heif)$/i.test(f.name) || /hei[cf]/i.test(f.type);

export function validateFile(file: File): string | null {
  const okType = ACCEPTED_TYPES.includes(file.type.toLowerCase()) || /\.(jpe?g|png|heic|heif|webp)$/i.test(file.name);
  if (!okType) return "Dieses Dateiformat können wir leider nicht verwenden. Bitte wähle ein JPG-, PNG- oder HEIC-Foto.";
  if (file.size > MAX_INPUT_BYTES) return "Das Foto ist größer als 25 MB. Bitte wähle eine kleinere Datei.";
  if (file.size < 1024) return "Diese Datei scheint beschädigt oder leer zu sein.";
  return null;
}

async function decode(file: Blob): Promise<ImageBitmap | HTMLImageElement> {
  if (typeof createImageBitmap === "function") {
    try {
      return await createImageBitmap(file, { imageOrientation: "from-image" });
    } catch {
      /* Fallback unten */
    }
  }
  const url = URL.createObjectURL(file);
  try {
    const img = new Image();
    img.decoding = "async";
    img.src = url;
    await img.decode();
    return img;
  } finally {
    URL.revokeObjectURL(url);
  }
}

export async function processImage(file: File): Promise<ProcessedImage> {
  const invalid = validateFile(file);
  if (invalid) throw new ImageError(invalid);

  let source: ImageBitmap | HTMLImageElement;
  try {
    source = await decode(file);
  } catch {
    if (!isHeicName(file)) throw new ImageError("Das Foto konnte nicht geöffnet werden. Bitte versuche es mit einem anderen Bild.");
    try {
      const { heicTo } = await import("heic-to/next");
      const jpeg = await heicTo({ blob: file, type: "image/jpeg", quality: 0.92 });
      source = await decode(jpeg);
    } catch {
      throw new ImageError("Dieses HEIC-Foto konnte nicht umgewandelt werden. Tipp: In den iPhone-Einstellungen unter „Kamera → Formate“ auf „Maximale Kompatibilität“ stellen oder das Foto als JPG teilen.");
    }
  }

  const sw = "naturalWidth" in source ? source.naturalWidth : source.width;
  const sh = "naturalHeight" in source ? source.naturalHeight : source.height;
  if (!sw || !sh) throw new ImageError("Das Foto konnte nicht gelesen werden.");
  const scale = Math.min(1, MAX_EDGE / Math.max(sw, sh));
  const w = Math.round(sw * scale);
  const h = Math.round(sh * scale);

  const canvas = document.createElement("canvas");
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new ImageError("Dein Browser kann das Foto leider nicht verarbeiten.");
  ctx.imageSmoothingQuality = "high";
  ctx.drawImage(source, 0, 0, w, h);
  if ("close" in source) source.close();

  const blob = await new Promise<Blob | null>((res) => canvas.toBlob(res, "image/jpeg", 0.9));
  canvas.width = canvas.height = 0; // Speicher sofort freigeben (iOS)
  if (!blob) throw new ImageError("Das Foto konnte nicht gespeichert werden.");

  const short = Math.min(sw, sh);
  return {
    blob,
    width: w,
    height: h,
    warning: short < MIN_SHORT_EDGE ? "Das Foto ist recht klein. Für die schönsten Illustrationen lieber ein größeres, scharfes Foto verwenden." : undefined,
  };
}

export const formatBytes = (n: number) => (n < 1024 * 1024 ? `${Math.max(1, Math.round(n / 1024))} KB` : `${(n / 1024 / 1024).toFixed(1).replace(".", ",")} MB`);
