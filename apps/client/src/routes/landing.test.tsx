import type { ReactNode } from "react";
import { beforeAll, describe, expect, it, vi } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import { initI18n } from "../i18n/index.ts";

vi.mock("@tanstack/react-router", () => ({
  Link: ({
    to,
    children,
    ...rest
  }: {
    to: string;
    children?: ReactNode;
    className?: string;
    "data-testid"?: string;
  }) => (
    <a href={to} {...rest}>
      {children}
    </a>
  ),
}));

import { LandingPage } from "./landing.tsx";

describe("Night Market Landing Page (UI-02)", () => {
  beforeAll(async () => {
    await initI18n("en");
  });

  it("renders brand marks, Web POS CTA, sample receipt math, and pricing in English", async () => {
    await initI18n("en");
    const html = renderToStaticMarkup(<LandingPage />);

    expect(html).toContain("/brand/xzacto-logo-on-dark.svg");
    expect(html).toContain("/brand/xzacto-logo-on-light.svg");
    expect(html).toContain('data-testid="landing-pos-btn"');
    expect(html).toContain('href="/login"');
    expect(html).toContain('href="/signup"');
    expect(html).toContain('href="/warehouse"');
    expect(html).toContain("Open the register");
    expect(html).toContain("3,100.00");
    expect(html).toContain("110.00");
    expect(html).toContain("435.00");
    expect(html).toContain("3,645.00");
    expect(html).toContain("1,499.00");
    expect(html).toContain("receipt-float");
  });

  it("switches copy cleanly to Filipino (fil)", async () => {
    await initI18n("fil");
    const html = renderToStaticMarkup(<LandingPage />);

    expect(html).toContain("Buksan ang kaha");
    expect(html).toContain("Gumawa ng libreng Solo store");
    expect(html).toContain("3,645.00");
  });
});
