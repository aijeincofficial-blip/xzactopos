import { afterEach, describe, expect, it, vi } from "vitest";

const { createSignedUrlsMock, uploadMock } = vi.hoisted(() => ({
  createSignedUrlsMock: vi.fn(),
  uploadMock: vi.fn(),
}));

vi.mock("./supabase.ts", () => ({
  supabase: {
    storage: {
      from: () => ({
        createSignedUrls: createSignedUrlsMock,
        upload: uploadMock,
      }),
    },
  },
}));

import {
  buildProductPhotoPath,
  clearPhotoUrlCache,
  isValidProductPhotoPath,
  productMonogram,
  resolveProductPhotoUrl,
  scaleDimensions,
  uploadProductPhoto,
} from "./product-photos.ts";

const TENANT_ID = "0190a000-0000-7000-8000-000000000010";
const PRODUCT_ID = "0190a000-0000-7000-8000-000000000020";
const OP_ID_1 = "0190a000-0000-7000-8000-000000000031";
const OP_ID_2 = "0190a000-0000-7000-8000-000000000032";

describe("product-photos", () => {
  afterEach(() => {
    clearPhotoUrlCache();
    createSignedUrlsMock.mockReset();
    uploadMock.mockReset();
  });

  it("builds and validates RLS-compliant <tenant>/<product>/<op>.jpg paths", () => {
    const p = buildProductPhotoPath(TENANT_ID, PRODUCT_ID, OP_ID_1);
    expect(p).toBe(`${TENANT_ID}/${PRODUCT_ID}/${OP_ID_1}.jpg`);
    expect(isValidProductPhotoPath(p, TENANT_ID)).toBe(true);
    expect(isValidProductPhotoPath(p, "0190a000-0000-7000-8000-999999999999")).toBe(false);
    expect(isValidProductPhotoPath(`${TENANT_ID}/${PRODUCT_ID}.jpg`, TENANT_ID)).toBe(false);
  });

  it("scales dimensions down to <= 640px longest edge without upscaling smaller images", () => {
    expect(scaleDimensions(400, 300)).toEqual({ width: 400, height: 300 });
    expect(scaleDimensions(1280, 960)).toEqual({ width: 640, height: 480 });
    expect(scaleDimensions(900, 1800)).toEqual({ width: 320, height: 640 });
    expect(productMonogram("Lucky Me Pancit Canton")).toBe("LM");
    expect(productMonogram("Asukal")).toBe("AS");
  });

  it("coalesces concurrent resolveProductPhotoUrl calls into one createSignedUrls batch and caches hits", async () => {
    const p1 = buildProductPhotoPath(TENANT_ID, PRODUCT_ID, OP_ID_1);
    const p2 = buildProductPhotoPath(TENANT_ID, PRODUCT_ID, OP_ID_2);
    createSignedUrlsMock.mockResolvedValueOnce({
      data: [
        { path: p1, signedUrl: "https://storage.example.test/signed-1" },
        { path: p2, signedUrl: "https://storage.example.test/signed-2" },
      ],
      error: null,
    });

    const [u1, u2, u1Dup] = await Promise.all([
      resolveProductPhotoUrl(p1),
      resolveProductPhotoUrl(p2),
      resolveProductPhotoUrl(p1),
    ]);

    expect(createSignedUrlsMock).toHaveBeenCalledTimes(1);
    expect(createSignedUrlsMock).toHaveBeenCalledWith([p1, p2], 3600);
    expect(u1).toBe("https://storage.example.test/signed-1");
    expect(u1Dup).toBe("https://storage.example.test/signed-1");
    expect(u2).toBe("https://storage.example.test/signed-2");

    // Subsequent call uses memory cache without hitting Storage again
    const cached = await resolveProductPhotoUrl(p1);
    expect(cached).toBe("https://storage.example.test/signed-1");
    expect(createSignedUrlsMock).toHaveBeenCalledTimes(1);
  });

  it("uploads JPEG bytes to product-photos bucket and seeds local cache", async () => {
    uploadMock.mockResolvedValueOnce({ data: { path: "ok" }, error: null });
    const blob = new Blob([new Uint8Array([0xff, 0xd8, 0xff, 0xd9])], { type: "image/jpeg" });
    const path = await uploadProductPhoto({
      tenantId: TENANT_ID,
      productId: PRODUCT_ID,
      jpeg: blob,
      opId: OP_ID_1,
    });
    expect(path).toBe(`${TENANT_ID}/${PRODUCT_ID}/${OP_ID_1}.jpg`);
    expect(uploadMock).toHaveBeenCalledTimes(1);
    expect(uploadMock).toHaveBeenCalledWith(path, blob, {
      contentType: "image/jpeg",
      upsert: true,
    });
  });
});
