/**
 * Pure keyboard shortcut resolver for the Web POS (Sell screen).
 * Keeps cashier hotkeys fast, predictable, and safe when typing in text inputs.
 */

export type PosHotkeyAction =
  | { type: "focus_search" }
  | { type: "focus_discount" }
  | { type: "focus_payment" }
  | { type: "hold_order" }
  | { type: "fast_key"; index: number }
  | { type: "charge" }
  | { type: "new_sale" }
  | { type: "print_receipt" };

export interface PosHotkeyInput {
  key: string;
  altKey?: boolean;
  ctrlKey?: boolean;
  metaKey?: boolean;
  shiftKey?: boolean;
  /** True when event target is an <input>, <textarea>, <select>, or contentEditable element. */
  inField: boolean;
  /** True when a modal dialog (e.g. supervisor PIN) is open. */
  modalOpen: boolean;
  /** True when the sale completion receipt view is currently shown. */
  isDoneScreen: boolean;
  /** True when cart has >= 1 item and charge is not currently submitting. */
  canCharge: boolean;
}

export function resolvePosHotkey(e: PosHotkeyInput): PosHotkeyAction | null {
  if (e.modalOpen) return null;

  // Sale completed screen shortcuts
  if (e.isDoneScreen) {
    if (e.key === "F9" || (!e.inField && e.key === "Enter" && !e.ctrlKey && !e.metaKey && !e.altKey)) {
      return { type: "new_sale" };
    }
    if (e.key === "F8") {
      return { type: "print_receipt" };
    }
    return null;
  }

  // Alt+1 .. Alt+6 trigger Quick Fast-Keys (0..5) regardless of focused field
  if (e.altKey && !e.ctrlKey && !e.metaKey && !e.shiftKey) {
    const n = Number(e.key);
    if (Number.isInteger(n) && n >= 1 && n <= 6) {
      return { type: "fast_key", index: n - 1 };
    }
  }

  if (e.ctrlKey || e.metaKey || e.altKey) return null;

  if (e.key === "F2" || (!e.inField && e.key === "/")) {
    return { type: "focus_search" };
  }
  if (e.key === "F4") {
    return { type: "focus_discount" };
  }
  if (e.key === "F6" && e.canCharge) {
    return { type: "hold_order" };
  }
  if (e.key === "F8") {
    return { type: "focus_payment" };
  }
  if (e.key === "F9" && e.canCharge) {
    return { type: "charge" };
  }

  return null;
}
