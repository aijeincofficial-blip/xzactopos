import { describe, expect, it } from "vitest";
import {
  exportCustomerLedgerCsv,
  exportDayClosesCsv,
  exportProductsCsv,
  exportSalesCsv,
  exportShiftsCsv,
  matchExistingProduct,
  parseAndValidateImport,
  parseCsv,
} from "./csv-helper.ts";
import type { ProductRow } from "./stock-api.ts";

describe("csv-helper", () => {
  it("exports product rows to CSV with proper quoting", () => {
    const rows: ProductRow[] = [
      {
        productId: "p1",
        variantId: "v1",
        name: 'Coke, 1.5L "Bottle"',
        sku: "COKE-15",
        barcode: "123456",
        unit: "btl",
        price: 7550, // 75.50
        cost: 6000,  // 60.00
        reorderPoint: 10,
        taxRate: 0.12,
        tracked: true,
        active: true,
        qty: 24,
        categoryId: "c1",
        categoryName: "Drinks, Cold",
        breaksIntoVariantId: null,
        breaksIntoQty: null,
        expiresOn: "2026-12-31",
      },
    ];

    const csv = exportProductsCsv(rows, "PHP");
    expect(csv).toContain('"Coke, 1.5L ""Bottle"""');
    expect(csv).toContain('"Drinks, Cold"');
    expect(csv).toContain("75.50");
    expect(csv).toContain("60.00");
    expect(csv).toContain("2026-12-31");
  });

  it("parses CSV grid handling commas inside quotes and escaped quotes", () => {
    const input = 'Name,Price\r\n"Item, with comma",25.00\r\n"Item with ""quote""",10.50';
    const grid = parseCsv(input);
    expect(grid).toEqual([
      ["Name", "Price"],
      ["Item, with comma", "25.00"],
      ['Item with "quote"', "10.50"],
    ]);
  });

  it("validates import rows and reports errors for invalid inputs", () => {
    const csv = [
      "Name,Price,Cost,OnHand,Tracked,ExpiresOn",
      "Valid Item,15.50,10.00,5,true,2027-01-01",
      ",10.00,5.00,0,true,", // Missing name
      "Bad Price,invalid,5.00,0,true,", // Bad price
    ].join("\n");

    const result = parseAndValidateImport(csv);
    expect(result.valid.length).toBe(1);
    expect(result.valid[0]!.name).toBe("Valid Item");
    expect(result.valid[0]!.price).toBe(1550);
    expect(result.valid[0]!.cost).toBe(1000);
    expect(result.valid[0]!.openingQty).toBe(5);
    expect(result.valid[0]!.expiresOn).toBe("2027-01-01");

    expect(result.errors.length).toBe(2);
    expect(result.errors[0]!).toContain("Line 3: Missing product name");
    expect(result.errors[1]!).toContain("Line 4: Invalid price");
  });

  it("exports shift rows to CSV with proper headers and values", () => {
    const csv = exportShiftsCsv([
      {
        id: "sh-1",
        cashier: "Juan Dela Cruz",
        status: "closed",
        openedAt: "2026-11-10T08:00:00Z",
        closedAt: "2026-11-10T16:00:00Z",
        openingCash: 50000,
        expectedCash: 125000,
        countedCash: 124500,
        difference: -500,
        closedBy: "Maria Santos",
        note: "Short 5 pesos",
      },
    ]);

    expect(csv).toContain("Shift ID,Cashier,Status");
    expect(csv).toContain("Juan Dela Cruz");
    expect(csv).toContain("500.00");
    expect(csv).toContain("1250.00");
    expect(csv).toContain("1245.00");
    expect(csv).toContain("-5.00");
    expect(csv).toContain("Maria Santos");
    expect(csv).toContain("Short 5 pesos");
  });

  it("exports day close rows to CSV with proper formatting", () => {
    const csv = exportDayClosesCsv([
      {
        day: "2026-11-10",
        openingCash: 50000,
        expectedCash: 250000,
        countedCash: 250000,
        difference: 0,
        closedAt: "2026-11-10T20:00:00Z",
        closedBy: "Owner Admin",
        note: "Balanced drawer",
      },
    ]);

    expect(csv).toContain("Date,Opening Cash,Expected Cash");
    expect(csv).toContain("2026-11-10");
    expect(csv).toContain("500.00");
    expect(csv).toContain("2500.00");
    expect(csv).toContain("0.00");
    expect(csv).toContain("Owner Admin");
    expect(csv).toContain("Balanced drawer");
  });

  it("exports customer ledger to CSV with proper columns and formatting", () => {
    const csv = exportCustomerLedgerCsv(
      "Maria Santos",
      [
        {
          date: "2026-11-08",
          kind: "Charge (Sale)",
          description: "Grocery purchase",
          method: "—",
          amount: 15000, // 150.00
        },
        {
          date: "2026-11-09",
          kind: "Payment",
          description: "Partial cash payment",
          method: "cash",
          amount: -5000, // -50.00
        },
      ],
      "PHP"
    );

    expect(csv).toContain("Date,Customer,Transaction Type");
    expect(csv).toContain("Maria Santos");
    expect(csv).toContain("Charge (Sale)");
    expect(csv).toContain("Grocery purchase");
    expect(csv).toContain("150.00");
    expect(csv).toContain("-50.00");
    expect(csv).toContain("cash");
  });

  it("parses Mobile export columns, Filipino headers, TSV paste, BOM, and ₱ formatted money without float drift", () => {
    const mobileExport = "\uFEFFname,price,barcode,cost,stock,unit\r\nLucky Me Canton,\"₱ 1,299.99\",4807770270017,PHP 950.05,24,box";
    const parsedMobile = parseAndValidateImport(mobileExport, "PHP");
    expect(parsedMobile.errors).toEqual([]);
    expect(parsedMobile.valid).toHaveLength(1);
    expect(parsedMobile.valid[0]).toMatchObject({
      name: "Lucky Me Canton",
      price: 129999,
      barcode: "4807770270017",
      cost: 95005,
      openingQty: 24,
      unit: "box",
    });

    const filTsv = "Pangalan\tPresyo\tPuhunan\tBilang\nSardinas\t23.50\t19.25\t12";
    const parsedFil = parseAndValidateImport(filTsv, "PHP");
    expect(parsedFil.errors).toEqual([]);
    expect(parsedFil.valid[0]).toMatchObject({
      name: "Sardinas",
      price: 2350,
      cost: 1925,
      openingQty: 12,
    });
  });

  it("guards formula-injection cells and matches existing rows by SKU or barcode", () => {
    const existing: ProductRow = {
      productId: "p1",
      variantId: "v1",
      name: "=SUM(A1:A2)",
      sku: "RICE-25KG",
      barcode: "480001",
      unit: "sack",
      price: 155000,
      cost: 130000,
      reorderPoint: 5,
      taxRate: 0,
      tracked: true,
      active: true,
      qty: 10,
      categoryId: null,
      categoryName: null,
      breaksIntoVariantId: null,
      breaksIntoQty: null,
      expiresOn: null,
    };
    const csv = exportProductsCsv([existing], "PHP");
    expect(csv).toContain("'=SUM(A1:A2)");

    expect(matchExistingProduct({ sku: "rice-25kg", barcode: "" }, [existing])?.variantId).toBe("v1");
    expect(matchExistingProduct({ sku: "", barcode: "480001" }, [existing])?.variantId).toBe("v1");
    expect(matchExistingProduct({ sku: "NEW-SKU", barcode: "999999" }, [existing])).toBeNull();
  });

  it("exports sales receipts to CSV with net totals and formula-injection guards", () => {
    const csv = exportSalesCsv(
      [
        {
          receiptNo: "S01-261112-0001",
          soldAt: "2026-11-12T06:30:00Z",
          status: "completed",
          customer: "Aling Rosa",
          paymentMethods: "cash + utang",
          subtotal: 12000,
          discount: 1000,
          total: 11000,
          refunded: 2500,
          netTotal: 8500,
        },
        {
          receiptNo: "S01-261112-0002",
          soldAt: "2026-11-12T07:00:00Z",
          status: "voided",
          customer: "=HACK()",
          paymentMethods: "ewallet",
          subtotal: 5000,
          discount: 0,
          total: 5000,
          refunded: 0,
          netTotal: 0,
        },
      ],
      "PHP",
    );

    expect(csv).toContain("Receipt No,Sold At,Status,Customer,Payment Methods,Subtotal (PHP),Discount (PHP),Total (PHP),Refunded (PHP),Net Total (PHP)");
    expect(csv).toContain("S01-261112-0001,2026-11-12T06:30:00Z,completed,Aling Rosa,cash + utang,120.00,10.00,110.00,25.00,85.00");
    expect(csv).toContain("'=HACK()");
    expect(csv).toContain("50.00,0.00,50.00,0.00,0.00");
  });
});
