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
