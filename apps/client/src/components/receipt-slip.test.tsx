import { beforeAll, describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import { initI18n } from "../i18n/index.ts";
import { ReceiptSlipView, type ReceiptData } from "./receipt-slip.tsx";

beforeAll(async () => {
  await initI18n("en");
});

const baseReceipt: ReceiptData = {
  tenantName: "Nena Sari-Sari",
  storeName: "Poblacion Main",
  storeCode: "S01",
  receiptNo: "S01-20261112-0001",
  soldAt: "2026-11-12T08:30:00Z",
  cashierName: "Jun Cashier",
  items: [
    {
      product_name: "Barako Coffee 250g",
      qty: 2,
      unit_price: 15000,
      line_total: 30000,
    },
  ],
  subtotal: 30000,
  discount: 0,
  total: 30000,
  payments: [{ method: "cash", amount: 30000 }],
  currency: "PHP",
  timezone: "Asia/Manila",
};

describe("ReceiptSlipView", () => {
  it("renders store address, custom receipt header, and custom receipt footer when provided", () => {
    const html = renderToStaticMarkup(
      <ReceiptSlipView
        receipt={{
          ...baseReceipt,
          storeAddress: "123 Rizal St, Poblacion",
          receiptHeader: "TIN 123-456-789-000 VAT REG",
          receiptFooter: "Maraming salamat po! No return without receipt.",
        }}
      />,
    );

    expect(html).toContain("Nena Sari-Sari");
    expect(html).toContain("Poblacion Main (S01)");
    expect(html).toContain("123 Rizal St, Poblacion");
    expect(html).toContain("TIN 123-456-789-000 VAT REG");
    expect(html).toContain("Maraming salamat po! No return without receipt.");
    expect(html).toContain('data-testid="receipt-store-address"');
    expect(html).toContain('data-testid="receipt-custom-header"');
    expect(html).toContain('data-testid="receipt-custom-footer"');
  });

  it("falls back to default thank-you message when custom footer is blank or null", () => {
    const html = renderToStaticMarkup(
      <ReceiptSlipView
        receipt={{
          ...baseReceipt,
          storeAddress: "   ",
          receiptHeader: null,
          receiptFooter: "  ",
        }}
      />,
    );

    expect(html).not.toContain('data-testid="receipt-store-address"');
    expect(html).not.toContain('data-testid="receipt-custom-header"');
    expect(html).not.toContain('data-testid="receipt-custom-footer"');
    expect(html).toContain("Thank you");
  });
});
