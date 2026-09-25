/**
 * Zwischenspeichern des Konfigurators – ausschließlich lokal auf dem Gerät.
 *  - Texte/Auswahl: localStorage (klein, synchron)
 *  - Fotos: IndexedDB (Blobs), damit ein Safari-Reload nichts vernichtet
 * Nach dem Absenden oder per "Angaben löschen" wird alles entfernt.
 * Kinderfotos werden NIE an Analytics/Tracking oder Dritte übergeben.
 */
import type { ConfiguratorValues, PhotoRef } from "./validation";

const LS_KEY = "plh:draft:v1";
const DB_NAME = "plueschheld";
const STORE = "photos";

export type PhotoSlot = "child" | "teddy";
type StoredDraft = { v: 1; step: number; values: Omit<ConfiguratorValues, "childPhoto" | "teddyPhoto" | "consent"> & { childPhoto: PhotoRef | null; teddyPhoto: PhotoRef | null }; savedAt: number };

const safe = <T>(fn: () => T, fallback: T): T => {
  try {
    return fn();
  } catch {
    return fallback;
  }
};

export function saveDraft(step: number, values: ConfiguratorValues) {
  const strip = (p: PhotoRef | null) => (p ? { ...p, url: undefined } : null);
  const { consent: _consent, ...rest } = values;
  void _consent;
  const data: StoredDraft = { v: 1, step, values: { ...rest, childPhoto: strip(values.childPhoto), teddyPhoto: strip(values.teddyPhoto) }, savedAt: Date.now() };
  safe(() => localStorage.setItem(LS_KEY, JSON.stringify(data)), undefined);
}

export function loadDraft(): StoredDraft | null {
  return safe(() => {
    const raw = localStorage.getItem(LS_KEY);
    if (!raw) return null;
    const d = JSON.parse(raw) as StoredDraft;
    // Entwürfe älter als 14 Tage verwerfen (Datensparsamkeit)
    if (d.v !== 1 || Date.now() - d.savedAt > 14 * 864e5) return null;
    return d;
  }, null);
}

function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    if (typeof indexedDB === "undefined") return reject(new Error("no idb"));
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = () => req.result.createObjectStore(STORE);
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function tx<T>(mode: IDBTransactionMode, fn: (s: IDBObjectStore) => IDBRequest<T> | void): Promise<T | undefined> {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const t = db.transaction(STORE, mode);
    const r = fn(t.objectStore(STORE));
    t.oncomplete = () => {
      db.close();
      resolve(r ? (r as IDBRequest<T>).result : undefined);
    };
    t.onerror = () => {
      db.close();
      reject(t.error);
    };
  });
}

export const photoStore = {
  put: (slot: PhotoSlot, blob: Blob) => tx("readwrite", (s) => void s.put(blob, slot)).catch(() => undefined),
  get: (slot: PhotoSlot) => tx<Blob>("readonly", (s) => s.get(slot)).catch(() => undefined),
  remove: (slot: PhotoSlot) => tx("readwrite", (s) => void s.delete(slot)).catch(() => undefined),
  clear: () => tx("readwrite", (s) => void s.clear()).catch(() => undefined),
};

export async function clearDraft() {
  safe(() => localStorage.removeItem(LS_KEY), undefined);
  await photoStore.clear();
}
