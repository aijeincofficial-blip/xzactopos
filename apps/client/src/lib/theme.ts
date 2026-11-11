// Light / dark / follow-the-device. The choice is a per-browser convenience, kept in localStorage.
export const THEME_CHOICES = ["system", "light", "dark"] as const;
export type ThemeChoice = (typeof THEME_CHOICES)[number];

const KEY = "pos.theme";

export function parseTheme(raw: string | null | undefined): ThemeChoice {
  return (THEME_CHOICES as readonly string[]).includes(raw ?? "") ? (raw as ThemeChoice) : "system";
}

/** Next choice when the toggle is pressed: system, then light, then dark, then back. */
export function nextTheme(c: ThemeChoice): ThemeChoice {
  return THEME_CHOICES[(THEME_CHOICES.indexOf(c) + 1) % THEME_CHOICES.length]!;
}

export function readTheme(): ThemeChoice {
  try {
    return parseTheme(localStorage.getItem(KEY));
  } catch {
    return "system";
  }
}

/** Puts the choice on <html>. "system" removes the attribute so the CSS follows the device. */
export function applyTheme(c: ThemeChoice): void {
  const el = document.documentElement;
  if (c === "system") el.removeAttribute("data-theme");
  else el.setAttribute("data-theme", c);
  try {
    localStorage.setItem(KEY, c);
  } catch {
    /* private window: the choice lasts until the tab closes */
  }
}

/** WCAG 2.1 relative luminance for a 6-digit hex color (#rrggbb). */
export function relativeLuminance(hex: string): number {
  const clean = hex.replace(/^#/, "");
  const r = parseInt(clean.slice(0, 2), 16) / 255;
  const g = parseInt(clean.slice(2, 4), 16) / 255;
  const b = parseInt(clean.slice(4, 6), 16) / 255;
  const linear = (c: number) => (c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4));
  return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b);
}

/** WCAG 2.1 contrast ratio between two hex colors (1 to 21). */
export function contrastRatio(fgHex: string, bgHex: string): number {
  const l1 = relativeLuminance(fgHex);
  const l2 = relativeLuminance(bgHex);
  const hi = Math.max(l1, l2);
  const lo = Math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

/** Canonical foreground/background pairs rendered across Light & Dark themes (must meet WCAG AA >= 4.5:1). */
export const WCAG_TOKEN_PAIRS: ReadonlyArray<{ label: string; fg: string; bg: string }> = [
  // Light mode surfaces & hierarchy
  { label: "light: primary text (slate-900) on card (white)", fg: "#3b3226", bg: "#ffffff" },
  { label: "light: primary text (slate-900) on page (slate-50)", fg: "#3b3226", bg: "#fbfaf9" },
  { label: "light: secondary text (slate-700) on card (white)", fg: "#716450", bg: "#ffffff" },
  { label: "light: primary button (white on brand-600)", fg: "#ffffff", bg: "#3419d2" },
  { label: "light: danger button (white on red-600)", fg: "#ffffff", bg: "#cd201d" },
  { label: "light: neutral badge (slate-800 on slate-100)", fg: "#594c3b", bg: "#f1eee9" },
  { label: "light: good badge (green-900 on green-50)", fg: "#0e532a", bg: "#f1fdf9" },
  { label: "light: warn badge (amber-900 on amber-50)", fg: "#613700", bg: "#fffcf0" },
  { label: "light: danger badge (red-900 on red-50)", fg: "#5b060b", bg: "#fff3f0" },
  // Dark mode surfaces, badges & buttons
  { label: "dark: primary text (slate-900) on card (white->#1e1b18)", fg: "#fbfaf9", bg: "#1e1b18" },
  { label: "dark: primary text (slate-900) on page (slate-50)", fg: "#fbfaf9", bg: "#12100e" },
  { label: "dark: secondary text (slate-700) on card", fg: "#cec4b6", bg: "#1e1b18" },
  { label: "dark: tertiary text (slate-600) on card", fg: "#b3a694", bg: "#1e1b18" },
  { label: "dark: muted text (slate-500) on card", fg: "#9a8c79", bg: "#1e1b18" },
  { label: "dark: primary button (#1e1b18 on brand-600)", fg: "#1e1b18", bg: "#a38cf8" },
  { label: "dark: danger button (#1e1b18 on red-600)", fg: "#1e1b18", bg: "#eb655c" },
  { label: "dark: neutral badge (slate-800 on slate-100)", fg: "#e3ddd3", bg: "#1e1b17" },
  { label: "dark: good badge (green-900 on green-50)", fg: "#f1fdf9", bg: "#072b16" },
  { label: "dark: warn badge (amber-900 on amber-50)", fg: "#fffcf0", bg: "#331e00" },
  { label: "dark: danger badge (red-900 on red-50)", fg: "#fff3f0", bg: "#381113" },
  { label: "dark: info alert (slate-900 on brand-50)", fg: "#fbfaf9", bg: "#191438" },
];
