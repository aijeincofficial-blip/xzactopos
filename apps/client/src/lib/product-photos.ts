import { uuidv7 } from "@pos/core";
import { ApiError, fromRaw } from "./api.ts";
import { supabase } from "./supabase.ts";

export const PHOTO_BUCKET = "product-photos";
export const MAX_PHOTO_DIMENSION = 640;
export const TARGET_PHOTO_BYTES = 100 * 1024;
export const MAX_UPLOAD_BYTES = 200 * 1024;
export const MAX_SOURCE_FILE_BYTES = 15 * 1024 * 1024;

const SIGNED_URL_TTL_SECONDS = 3600;
const CACHE_TTL_MS = 50 * 60 * 1000;
const PHOTO_PATH_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$/i;

export function buildProductPhotoPath(tenantId: string, productId: string, opId: string = uuidv7()): string {
  return `${tenantId}/${productId}/${opId}.jpg`;
}

export function isValidProductPhotoPath(path: string, tenantId?: string): boolean {
  if (!PHOTO_PATH_RE.test(path)) return false;
  if (tenantId && !path.toLowerCase().startsWith(`${tenantId.toLowerCase()}/`)) return false;
  return true;
}

export function scaleDimensions(
  width: number,
  height: number,
  maxDim: number = MAX_PHOTO_DIMENSION,
): { width: number; height: number } {
  const safeW = Math.max(1, Math.round(width));
  const safeH = Math.max(1, Math.round(height));
  const longest = Math.max(safeW, safeH);
  if (longest <= maxDim) return { width: safeW, height: safeH };
  const ratio = maxDim / longest;
  return {
    width: Math.max(1, Math.round(safeW * ratio)),
    height: Math.max(1, Math.round(safeH * ratio)),
  };
}

export function productMonogram(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "?";
  if (parts.length === 1) return (parts[0] ?? "?").slice(0, 2).toUpperCase();
  return `${parts[0]?.[0] ?? ""}${parts[1]?.[0] ?? ""}`.toUpperCase();
}

async function decodeImageSource(
  blob: Blob,
): Promise<{ width: number; height: number; draw: (ctx: CanvasRenderingContext2D, w: number, h: number) => void; close: () => void }> {
  if (typeof createImageBitmap === "function") {
    const bmp = await createImageBitmap(blob);
    return {
      width: bmp.width,
      height: bmp.height,
      draw: (ctx, w, h) => ctx.drawImage(bmp, 0, 0, w, h),
      close: () => bmp.close(),
    };
  }
  const objectUrl = URL.createObjectURL(blob);
  try {
    const img = await new Promise<HTMLImageElement>((resolve, reject) => {
      const el = new Image();
      el.onload = () => resolve(el);
      el.onerror = () => reject(new ApiError("photo_invalid", "Could not decode image"));
      el.src = objectUrl;
    });
    return {
      width: img.naturalWidth || img.width,
      height: img.naturalHeight || img.height,
      draw: (ctx, w, h) => ctx.drawImage(img, 0, 0, w, h),
      close: () => URL.revokeObjectURL(objectUrl),
    };
  } catch (err) {
    URL.revokeObjectURL(objectUrl);
    throw err;
  }
}

function canvasToJpeg(canvas: HTMLCanvasElement, quality: number): Promise<Blob> {
  return new Promise<Blob>((resolve, reject) => {
    canvas.toBlob(
      (b) => (b ? resolve(b) : reject(new ApiError("photo_invalid", "Failed to encode JPEG"))),
      "image/jpeg",
      quality,
    );
  });
}

/** Resizes an input image to <= 640px longest edge and compresses to a JPEG under 100 KB (hard cap 200 KB). */
export async function compressImageToJpeg(file: Blob): Promise<Blob> {
  if (!file || file.size <= 0) {
    throw new ApiError("photo_invalid", "Empty image file");
  }
  if (file.type && !file.type.startsWith("image/")) {
    throw new ApiError("photo_invalid", "File must be an image");
  }
  if (file.size > MAX_SOURCE_FILE_BYTES) {
    throw new ApiError("photo_too_large", "Image file is too large");
  }

  const decoded = await decodeImageSource(file);
  try {
    const { width, height } = scaleDimensions(decoded.width, decoded.height, MAX_PHOTO_DIMENSION);
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext("2d");
    if (!ctx) throw new ApiError("photo_invalid", "Canvas context unavailable");
    // Fill crisp white so transparent PNG/WebP product cutouts do not turn black in JPEG
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, width, height);
    decoded.draw(ctx, width, height);

    const qualities = [0.82, 0.72, 0.6, 0.48, 0.36];
    let lastBlob: Blob | null = null;
    for (const q of qualities) {
      const candidate = await canvasToJpeg(canvas, q);
      lastBlob = candidate;
      if (candidate.size <= TARGET_PHOTO_BYTES) return candidate;
    }
    if (lastBlob && lastBlob.size <= MAX_UPLOAD_BYTES) return lastBlob;
    throw new ApiError("photo_too_large", "Compressed photo exceeds 200 KB limit");
  } finally {
    decoded.close();
  }
}

// ---------------------------------------------------------------------------
// Signed URL cache & micro-batch resolver (zero N+1 requests across catalog/POS)
// ---------------------------------------------------------------------------

interface CachedUrl {
  url: string;
  expiresAt: number;
}

const urlCache = new Map<string, CachedUrl>();
const pendingWaiters = new Map<string, Array<(url: string | null) => void>>();
let batchTimer: ReturnType<typeof setTimeout> | null = null;

export function seedPhotoUrlCache(path: string, url: string, ttlMs: number = CACHE_TTL_MS): void {
  urlCache.set(path, { url, expiresAt: Date.now() + ttlMs });
}

export function clearPhotoUrlCache(): void {
  urlCache.clear();
  pendingWaiters.clear();
  if (batchTimer !== null) {
    clearTimeout(batchTimer);
    batchTimer = null;
  }
}

export function getCachedPhotoUrl(path: string | null | undefined): string | null {
  if (!path) return null;
  const hit = urlCache.get(path);
  if (!hit) return null;
  if (hit.expiresAt <= Date.now()) {
    urlCache.delete(path);
    return null;
  }
  return hit.url;
}

async function flushPhotoBatch(): Promise<void> {
  batchTimer = null;
  const paths = Array.from(pendingWaiters.keys());
  if (paths.length === 0) return;

  const waitersSnapshot = new Map<string, Array<(url: string | null) => void>>();
  for (const p of paths) {
    waitersSnapshot.set(p, pendingWaiters.get(p) ?? []);
    pendingWaiters.delete(p);
  }

  const resolvedMap = new Map<string, string>();
  const chunkSize = 100;
  for (let i = 0; i < paths.length; i += chunkSize) {
    const slice = paths.slice(i, i + chunkSize);
    try {
      const { data, error } = await supabase.storage
        .from(PHOTO_BUCKET)
        .createSignedUrls(slice, SIGNED_URL_TTL_SECONDS);
      if (!error && Array.isArray(data)) {
        for (const entry of data) {
          if (entry.path && entry.signedUrl) {
            resolvedMap.set(entry.path, entry.signedUrl);
            seedPhotoUrlCache(entry.path, entry.signedUrl);
          }
        }
      }
    } catch {
      // Offline or transient failure: fall back cleanly to monogram placeholder
    }
  }

  for (const [p, callbacks] of waitersSnapshot.entries()) {
    const signed = resolvedMap.get(p) ?? null;
    for (const cb of callbacks) cb(signed);
  }
}

export function resolveProductPhotoUrl(path: string | null | undefined): Promise<string | null> {
  if (!path) return Promise.resolve(null);
  const cached = getCachedPhotoUrl(path);
  if (cached) return Promise.resolve(cached);

  return new Promise<string | null>((resolve) => {
    const existing = pendingWaiters.get(path);
    if (existing) {
      existing.push(resolve);
    } else {
      pendingWaiters.set(path, [resolve]);
    }
    if (batchTimer === null) {
      batchTimer = setTimeout(() => {
        void flushPhotoBatch();
      }, 16);
    }
  });
}

export async function uploadProductPhoto(params: {
  tenantId: string;
  productId: string;
  jpeg: Blob;
  opId?: string;
}): Promise<string> {
  if (params.jpeg.size > MAX_UPLOAD_BYTES) {
    throw new ApiError("photo_too_large", "Photo exceeds 200 KB limit");
  }
  const path = buildProductPhotoPath(params.tenantId, params.productId, params.opId ?? uuidv7());
  if (!isValidProductPhotoPath(path, params.tenantId)) {
    throw new ApiError("invalid_value", "Invalid product photo storage path");
  }
  const { error } = await supabase.storage.from(PHOTO_BUCKET).upload(path, params.jpeg, {
    contentType: "image/jpeg",
    upsert: true,
  });
  if (error) throw fromRaw(error);

  if (typeof URL !== "undefined" && typeof URL.createObjectURL === "function") {
    seedPhotoUrlCache(path, URL.createObjectURL(params.jpeg), 24 * 60 * 60 * 1000);
  }
  return path;
}
