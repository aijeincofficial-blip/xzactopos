import { describe, expect, it, vi } from "vitest";
import { ApiError, fetchAllPages } from "./api.ts";

describe("fetchAllPages pagination helper (P06)", () => {
  it("fetches consecutive pages until a short page ends traversal", async () => {
    const pageFn = vi
      .fn()
      .mockResolvedValueOnce({ data: [{ id: 1 }, { id: 2 }], error: null })
      .mockResolvedValueOnce({ data: [{ id: 3 }], error: null });

    const rows = await fetchAllPages<{ id: number }>(pageFn, 2);
    expect(rows).toEqual([{ id: 1 }, { id: 2 }, { id: 3 }]);
    expect(pageFn).toHaveBeenNthCalledWith(1, 0, 1);
    expect(pageFn).toHaveBeenNthCalledWith(2, 2, 3);
  });

  it("caps fetched rows at maxRows and maps raw database errors", async () => {
    const cappedFn = vi.fn().mockResolvedValue({ data: [{ id: 1 }, { id: 2 }], error: null });
    const capped = await fetchAllPages<{ id: number }>(cappedFn, 2, 4);
    expect(capped).toHaveLength(4);
    expect(cappedFn).toHaveBeenCalledTimes(2);

    const errFn = vi.fn().mockResolvedValue({
      data: null,
      error: { code: "42501", message: "permission denied", hint: "not_allowed" },
    });
    await expect(fetchAllPages(errFn, 10)).rejects.toThrowError(ApiError);
    await expect(fetchAllPages(errFn, 10)).rejects.toMatchObject({ key: "not_allowed" });
  });
});
