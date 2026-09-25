/**
 * Erstes sichtbares Bild (LCP) – exakt der erste Kamerazustand der Sequenz.
 * Portrait-/Landscape-Band sind entlang des Look-at-Punkts geschnitten -> object-position: center
 * entspricht pixelgenau dem ersten Canvas-Frame (kein Sprung bei der Übergabe).
 */
import type { Ref } from "react";

type Props = { className?: string; ref?: Ref<HTMLImageElement>; priority?: boolean; alt?: string };

export function HeroPoster({ className = "", ref, priority = true, alt = "" }: Props) {
  return (
    <picture>
      <source media="(max-aspect-ratio: 57/100)" srcSet="/media/hero/p/001.webp" type="image/webp" />
      <source media="(min-aspect-ratio: 143/100)" srcSet="/media/hero/l/001.webp" type="image/webp" />
      <img
        ref={ref}
        src="/media/hero/f/001.webp"
        width={960}
        height={1280}
        alt={alt}
        className={className}
        fetchPriority={priority ? "high" : "auto"}
        loading={priority ? "eager" : "lazy"}
        decoding={priority ? "sync" : "async"}
        draggable={false}
      />
    </picture>
  );
}
