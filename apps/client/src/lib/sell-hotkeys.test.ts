import { describe, expect, it } from "vitest";
import { resolvePosHotkey, type PosHotkeyInput } from "./sell-hotkeys.ts";

const base: PosHotkeyInput = {
  key: "",
  inField: false,
  modalOpen: false,
  isDoneScreen: false,
  canCharge: true,
};

describe("resolvePosHotkey", () => {
  it("focuses search on F2 anywhere or '/' outside form fields", () => {
    expect(resolvePosHotkey({ ...base, key: "F2", inField: true })).toEqual({ type: "focus_search" });
    expect(resolvePosHotkey({ ...base, key: "/", inField: false })).toEqual({ type: "focus_search" });
    expect(resolvePosHotkey({ ...base, key: "/", inField: true })).toBeNull();
  });

  it("maps Alt+1..Alt+6 to fast_key 0..5 and ignores out-of-range digits", () => {
    expect(resolvePosHotkey({ ...base, key: "1", altKey: true, inField: true })).toEqual({ type: "fast_key", index: 0 });
    expect(resolvePosHotkey({ ...base, key: "6", altKey: true })).toEqual({ type: "fast_key", index: 5 });
    expect(resolvePosHotkey({ ...base, key: "7", altKey: true })).toBeNull();
  });

  it("maps F4 to discount, F8 to payment, and F9 to charge only when canCharge", () => {
    expect(resolvePosHotkey({ ...base, key: "F4", inField: true })).toEqual({ type: "focus_discount" });
    expect(resolvePosHotkey({ ...base, key: "F8" })).toEqual({ type: "focus_payment" });
    expect(resolvePosHotkey({ ...base, key: "F9", canCharge: true })).toEqual({ type: "charge" });
    expect(resolvePosHotkey({ ...base, key: "F9", canCharge: false })).toBeNull();
  });

  it("handles done screen shortcuts and suppresses all shortcuts while a modal is open", () => {
    expect(resolvePosHotkey({ ...base, isDoneScreen: true, key: "F9" })).toEqual({ type: "new_sale" });
    expect(resolvePosHotkey({ ...base, isDoneScreen: true, key: "Enter" })).toEqual({ type: "new_sale" });
    expect(resolvePosHotkey({ ...base, isDoneScreen: true, key: "F8" })).toEqual({ type: "print_receipt" });
    expect(resolvePosHotkey({ ...base, modalOpen: true, key: "F2" })).toBeNull();
  });
});
