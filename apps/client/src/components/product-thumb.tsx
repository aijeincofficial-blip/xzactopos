import { useEffect, useState } from "react";
import { cn } from "../lib/utils.ts";
import { getCachedPhotoUrl, productMonogram, resolveProductPhotoUrl } from "../lib/product-photos.ts";

const SIZE_CLASSES: Record<"xs" | "sm" | "md" | "lg", string> = {
  xs: "h-5 w-5 rounded text-[10px]",
  sm: "h-8 w-8 rounded-lg text-xs",
  md: "h-9 w-9 rounded-lg text-xs",
  lg: "h-16 w-16 rounded-xl text-base",
};

export function ProductThumb({
  photoPath,
  previewUrl,
  name,
  size = "md",
  active = false,
  className,
}: {
  photoPath?: string | null;
  previewUrl?: string | null;
  name: string;
  size?: "xs" | "sm" | "md" | "lg";
  active?: boolean;
  className?: string;
}) {
  const [resolved, setResolved] = useState<{ path: string; url: string } | null>(() => {
    const cached = getCachedPhotoUrl(photoPath);
    return photoPath && cached ? { path: photoPath, url: cached } : null;
  });
  const [failedUrl, setFailedUrl] = useState<string | null>(null);

  useEffect(() => {
    if (previewUrl || !photoPath) return;
    const cached = getCachedPhotoUrl(photoPath);
    if (cached) {
      setResolved({ path: photoPath, url: cached });
      return;
    }
    let cancelled = false;
    void resolveProductPhotoUrl(photoPath).then((url) => {
      if (!cancelled && url) {
        setResolved({ path: photoPath, url });
      }
    });
    return () => {
      cancelled = true;
    };
  }, [photoPath, previewUrl]);

  const activeUrl =
    previewUrl ?? (photoPath && resolved?.path === photoPath ? resolved.url : getCachedPhotoUrl(photoPath));
  const showImage = Boolean(activeUrl && activeUrl !== failedUrl);

  return (
    <div
      data-testid="product-thumb"
      className={cn(
        "relative flex shrink-0 items-center justify-center overflow-hidden font-semibold select-none",
        SIZE_CLASSES[size],
        active
          ? "bg-brand-50 text-brand-text ring-1 ring-brand-200"
          : "bg-gradient-to-br from-slate-100 to-brand-50/70 text-slate-600 ring-1 ring-slate-200/70",
        className,
      )}
    >
      {showImage && activeUrl ? (
        <img
          src={activeUrl}
          alt={name || "Product"}
          loading="lazy"
          decoding="async"
          onError={() => setFailedUrl(activeUrl)}
          className="h-full w-full object-cover"
        />
      ) : (
        <span>{productMonogram(name)}</span>
      )}
    </div>
  );
}
