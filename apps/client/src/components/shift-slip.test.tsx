import { beforeAll, describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import { initI18n } from "../i18n/index.ts";
import { DayCloseSlipView, ShiftSlipView } from "./shift-slip.tsx";

beforeAll(async () => {
  await initI18n("en");
});

describe("ShiftSlipView & DayCloseSlipView", () => {
  it("renders thermal Z shift slip with store address, custom header/footer, closedBy, and over/short difference", () => {
    const html = renderToStaticMarkup(
      <ShiftSlipView
        slip={{
          kind: "z",
          tenantName: "Nena Sari-Sari",
          storeName: "Poblacion Main",
          storeCode: "S01",
          storeAddress: "88 Mabini Ave, Poblacion",
          receiptHeader: "TIN 000-111-222 VAT",
          receiptFooter: "Keep Z slip in safe envelope.",
          cashierName: "Maria Santos",
          openedAt: "2026-11-12T01:00:00Z",
          closedAt: "2026-11-12T09:00:00Z",
          closedByName: "Store Manager",
          openingCash: 100000,
          expectedCash: 450000,
          countedCash: 448000,
          difference: -2000,
          note: "Short 20 pesos coin roll",
          currency: "PHP",
          timezone: "Asia/Manila",
        }}
      />,
    );

    expect(html).toContain("printable-slip");
    expect(html).toContain("Nena Sari-Sari");
    expect(html).toContain("Poblacion Main (S01)");
    expect(html).toContain("88 Mabini Ave, Poblacion");
    expect(html).toContain("TIN 000-111-222 VAT");
    expect(html).toContain("Keep Z slip in safe envelope.");
    expect(html).toContain("Maria Santos");
    expect(html).toContain("Store Manager");
    expect(html).toContain("Short 20 pesos coin roll");
    expect(html).toContain('data-testid="shift-slip-store-address"');
    expect(html).toContain('data-testid="shift-slip-custom-header"');
    expect(html).toContain('data-testid="shift-slip-custom-footer"');
    expect(html).toContain('data-testid="shift-slip-diff"');
  });

  it("renders interim X day-close slip with drawer cash breakdown and tender summary", () => {
    const html = renderToStaticMarkup(
      <DayCloseSlipView
        slip={{
          kind: "x",
          tenantName: "Nena Sari-Sari",
          storeName: "Poblacion Main",
          storeCode: "S01",
          dayLabel: "2026-11-12",
          timeLabel: "14:30:00",
          closedByName: "Jun Cashier",
          openingCash: 50000,
          cashSales: 320000,
          cashUtang: 40000,
          cashExpenses: 15000,
          expectedCash: 395000,
          totals: {
            gross: 500000,
            net: 500000,
            txns: 18,
            ewallet: 75000,
            card: 10000,
            utang: 20000,
          },
          currency: "PHP",
        }}
      />,
    );

    expect(html).toContain("printable-slip");
    expect(html).toContain("Jun Cashier");
    expect(html).toContain("18");
    expect(html).not.toContain('data-testid="shift-slip-store-address"');
  });
});
