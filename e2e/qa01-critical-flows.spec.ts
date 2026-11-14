import { expect, test } from "@playwright/test";
import {
  ALPHA_SLUG,
  EMAILS,
  apiAuth,
  ensurePosEnabled,
  ensureServiceWorkerControlled,
  getStockQty,
  resolveAlphaFixtures,
  restGet,
  rpc,
  rpcRaw,
  signInEmail,
  signInWarehousePortal,
  type AlphaFixtures,
} from "./helpers.ts";

let ownerToken = "";
let fx: AlphaFixtures;

test.describe.serial("QA-01 Critical Flows (Web POS & Warehouse)", () => {
  test.beforeAll(async () => {
    const auth = await apiAuth(EMAILS.owner);
    ownerToken = auth.token;
    await ensurePosEnabled(ownerToken);
    fx = await resolveAlphaFixtures(ownerToken);
  });

  test.afterAll(async () => {
    if (ownerToken) {
      await ensurePosEnabled(ownerToken);
    }
  });

  test("Flow 1: Cashier sells multi-variant items across Cash, Card & QR with receipt and stock deduction", async ({
    page,
  }) => {
    const beforeReg = await getStockQty(ownerToken, fx.s01Id, fx.latteRegId);
    const beforeLarge = await getStockQty(ownerToken, fx.s01Id, fx.latteLargeId);

    await signInEmail(page, EMAILS.cashier);
    await expect(page).toHaveURL(/\/app\/sell/);
    await expect(page.getByTestId(`product-${fx.latteRegSku}`)).toBeVisible();

    // 1) Cash sale of Iced Latte (Regular) + Iced Latte (Large)
    await page.getByTestId(`product-${fx.latteRegSku}`).click();
    await expect(page.getByTestId("variant-picker-dialog")).toBeVisible();
    await page.getByTestId(`pick-variant-${fx.latteRegSku}`).click();

    await page.getByTestId(`product-${fx.latteRegSku}`).click();
    await page.getByTestId(`pick-variant-${fx.latteLargeSku}`).click();

    await page.getByTestId("tender-btn-cash").click();
    await page.getByTestId("tendered").fill("300");
    await page.getByTestId("charge").click();
    await expect(page.getByTestId("print-receipt-btn")).toBeVisible();
    await page.getByTestId("new-sale").click();

    // 2) Card sale of Iced Latte (Regular)
    await page.getByTestId(`product-${fx.latteRegSku}`).click();
    await page.getByTestId(`pick-variant-${fx.latteRegSku}`).click();
    await page.getByTestId("tender-btn-card").click();
    await page.getByTestId("pay-card-ref").fill("VISA-4242");
    await page.getByTestId("charge").click();
    await expect(page.getByTestId("print-receipt-btn")).toBeVisible();
    await page.getByTestId("new-sale").click();

    // 3) QR / E-wallet sale of Iced Latte (Large)
    await page.getByTestId(`product-${fx.latteRegSku}`).click();
    await page.getByTestId(`pick-variant-${fx.latteLargeSku}`).click();
    await page.getByTestId("tender-btn-ewallet").click();
    await expect(page.getByTestId("pay-wallet")).toBeVisible();
    await page.getByTestId("charge").click();
    await expect(page.getByTestId("print-receipt-btn")).toBeVisible();

    await expect
      .poll(() => getStockQty(ownerToken, fx.s01Id, fx.latteRegId), { timeout: 10_000 })
      .toBe(beforeReg - 2);
    await expect
      .poll(() => getStockQty(ownerToken, fx.s01Id, fx.latteLargeId), { timeout: 10_000 })
      .toBe(beforeLarge - 2);
  });

  test("Flow 2: Offline sale (3 orders -> reload while offline -> go online -> all 3 sync once)", async ({
    browser,
  }) => {
    const context = await browser.newContext();
    const page = await context.newPage();
    try {
      const beforeReg = await getStockQty(ownerToken, fx.s01Id, fx.latteRegId);
      const beforeSales = await restGet<Array<{ id: string }>>(
        ownerToken,
        `sales?location_id=eq.${fx.s01Id}&select=id`,
      );

      await signInEmail(page, EMAILS.cashier);
      await expect(page.getByTestId(`product-${fx.latteRegSku}`)).toBeVisible();
      await ensureServiceWorkerControlled(page);
      await expect(page.getByTestId(`product-${fx.latteRegSku}`)).toBeVisible();

      await context.setOffline(true);
      await expect(page.getByTestId("pos-outbox-status")).toBeVisible();

      for (let i = 0; i < 3; i++) {
        await page.getByTestId(`product-${fx.latteRegSku}`).click();
        await page.getByTestId(`pick-variant-${fx.latteRegSku}`).click();
        await page.getByTestId("tender-btn-cash").click();
        await page.getByTestId("tendered").fill("150");
        await page.getByTestId("charge").click();
        await expect(page.getByTestId("offline-sale-banner")).toBeVisible();
        await page.getByTestId("new-sale").click();
      }

      // Reload app while offline: PWA SW + localStorage cache must boot /app/sell with 3 queued ops intact.
      await page.reload({ waitUntil: "domcontentloaded" });
      await expect(page.getByTestId("cart")).toBeVisible({ timeout: 15_000 });
      await expect(page.getByTestId("pos-outbox-status")).toContainText("3");

      // Reconnect: auto outbox flush submits all 3 once with client_op_id dedup.
      await context.setOffline(false);
      await expect(page.getByTestId("pos-outbox-status")).toHaveCount(0, { timeout: 25_000 });

      await expect
        .poll(
          async () =>
            (await restGet<Array<{ id: string }>>(ownerToken, `sales?location_id=eq.${fx.s01Id}&select=id`)).length,
          { timeout: 15_000 },
        )
        .toBe(beforeSales.length + 3);

      const beforeIds = new Set(beforeSales.map((s) => s.id));
      const afterSales = await restGet<Array<{ id: string; local_no: string; sale_no: string | null }>>(
        ownerToken,
        `sales?location_id=eq.${fx.s01Id}&select=id,local_no,sale_no&order=sold_at.desc&limit=10`,
      );
      const newSales = afterSales.filter((s) => !beforeIds.has(s.id));
      expect(newSales.length).toBe(3);
      expect(new Set(newSales.map((s) => s.local_no)).size).toBe(3);

      await expect
        .poll(() => getStockQty(ownerToken, fx.s01Id, fx.latteRegId), { timeout: 10_000 })
        .toBe(beforeReg - 3);
    } finally {
      await context.setOffline(false).catch(() => undefined);
      await context.close();
    }
  });

  test("Flow 3: Partial return and sale void create append-only movements and restore stock", async ({ page }) => {
    await signInEmail(page, EMAILS.manager);
    await page.goto("/app/sell");
    await expect(page.getByTestId(`product-${fx.latteRegSku}`)).toBeVisible();

    // Sale A: 2x Regular (for partial return of 1)
    await page.getByTestId(`product-${fx.latteRegSku}`).click();
    await page.getByTestId(`pick-variant-${fx.latteRegSku}`).click();
    await page.getByTestId(`product-${fx.latteRegSku}`).click();
    await page.getByTestId(`pick-variant-${fx.latteRegSku}`).click();
    await page.getByTestId("tender-btn-cash").click();
    await page.getByTestId("tendered").fill("300");
    await page.getByTestId("charge").click();
    await expect(page.getByTestId("print-receipt-btn")).toBeVisible();
    await page.getByTestId("new-sale").click();

    // Sale B: 1x Large (for full void)
    await page.getByTestId(`product-${fx.latteRegSku}`).click();
    await page.getByTestId(`pick-variant-${fx.latteLargeSku}`).click();
    await page.getByTestId("tender-btn-cash").click();
    await page.getByTestId("tendered").fill("200");
    await page.getByTestId("charge").click();
    await expect(page.getByTestId("print-receipt-btn")).toBeVisible();

    const recentSales = await restGet<Array<{ id: string; sale_no: string; local_no: string }>>(
      ownerToken,
      `sales?location_id=eq.${fx.s01Id}&status=eq.completed&select=id,sale_no,local_no&order=sold_at.desc&limit=2`,
    );
    expect(recentSales.length).toBe(2);
    const [saleB, saleA] = recentSales;

    const beforeReg = await getStockQty(ownerToken, fx.s01Id, fx.latteRegId);
    const beforeLarge = await getStockQty(ownerToken, fx.s01Id, fx.latteLargeId);
    const beforeMovements = await restGet<Array<{ id: string; qty_delta: number; type: string }>>(
      ownerToken,
      `stock_movements?location_id=eq.${fx.s01Id}&variant_id=in.(${fx.latteRegId},${fx.latteLargeId})&select=id,qty_delta,type&order=created_at.asc`,
    );

    await page.goto("/app/sales");

    // Partial return on Sale A (1 of 2 Regular)
    const saleAKey = saleA!.sale_no ?? saleA!.local_no;
    await page.getByTestId(`sale-${saleAKey}`).click();
    await expect(page.getByTestId("sale-detail")).toBeVisible();
    await page.getByTestId("return-items-btn").click();
    await expect(page.getByTestId("return-items-dialog")).toBeVisible();

    const saleAItems = await restGet<Array<{ id: string }>>(
      ownerToken,
      `sale_items?sale_id=eq.${saleA!.id}&select=id`,
    );
    await page.getByTestId(`return-inc-${saleAItems[0]!.id}`).click();
    await page.getByTestId("return-reason-input").fill("QA partial return");
    await page.getByTestId("confirm-return-btn").click();
    await expect(page.getByTestId("return-items-dialog")).toHaveCount(0);
    await page.getByRole("button", { name: "Back to sales" }).click();

    // Full void on Sale B
    const saleBKey = saleB!.sale_no ?? saleB!.local_no;
    await page.getByTestId(`sale-${saleBKey}`).click();
    await page.getByTestId("void-start").click();
    await page.getByTestId("void-reason").fill("QA full void");
    await page.getByTestId("void-confirm").click();
    await expect(page.getByTestId("void-confirm")).toHaveCount(0);

    await expect
      .poll(() => getStockQty(ownerToken, fx.s01Id, fx.latteRegId), { timeout: 10_000 })
      .toBe(beforeReg + 1);
    await expect
      .poll(() => getStockQty(ownerToken, fx.s01Id, fx.latteLargeId), { timeout: 10_000 })
      .toBe(beforeLarge + 1);

    const afterMovements = await restGet<Array<{ id: string; qty_delta: number; type: string }>>(
      ownerToken,
      `stock_movements?location_id=eq.${fx.s01Id}&variant_id=in.(${fx.latteRegId},${fx.latteLargeId})&select=id,qty_delta,type&order=created_at.asc`,
    );
    const afterMap = new Map(afterMovements.map((m) => [m.id, m]));
    for (const prev of beforeMovements) {
      expect(afterMap.get(prev.id)).toEqual(prev);
    }
    expect(afterMovements.length).toBeGreaterThanOrEqual(beforeMovements.length + 2);
  });

  test("Flow 4: Receive warehouse stock -> transfer to store -> bin sum equals warehouse stock", async ({
    browser,
  }) => {
    const preInv = await rpc<Array<{ is_valid: boolean }>>(ownerToken, "check_bin_stock_invariant", {
      p_warehouse_id: fx.w01Id,
    });
    expect(preInv.every((r) => r.is_valid)).toBe(true);

    const beforeWh = await getStockQty(ownerToken, fx.w01Id, fx.kapeId);
    const beforeS01 = await getStockQty(ownerToken, fx.s01Id, fx.kapeId);

    const whCtx = await browser.newContext();
    const whPage = await whCtx.newPage();
    try {
      await signInWarehousePortal(whPage, ALPHA_SLUG, "whclerk");

      // Walk-in receive +10 at W01
      await whPage.goto("/app/purchasing");
      await whPage.getByTestId("open-walkin").click();
      await whPage.getByTestId("walkin-warehouse").selectOption(fx.w01Id);
      await whPage.getByTestId("line-0-product").selectOption(fx.kapeId);
      await whPage.getByTestId("line-0-qty").fill("10");
      await whPage.getByTestId("line-0-cost").fill("80");
      await whPage.getByTestId("confirm-walkin").click();
      await expect(whPage.getByTestId("confirm-walkin")).toHaveCount(0);

      await expect
        .poll(() => getStockQty(ownerToken, fx.w01Id, fx.kapeId), { timeout: 10_000 })
        .toBe(beforeWh + 10);

      // Create draft transfer W01 -> S01 for 5 units, pick into staging (bins enabled), and ship
      const beforeTransfers = await restGet<Array<{ id: string }>>(
        ownerToken,
        `transfers?from_location_id=eq.${fx.w01Id}&select=id`,
      );
      await whPage.goto("/app/transfers");
      await whPage.getByRole("button", { name: /new transfer/i }).click();
      const modalForm = whPage.locator("form").filter({ has: whPage.locator("input[type='checkbox']") });
      const selects = modalForm.locator("select");
      await selects.nth(0).selectOption(fx.w01Id);
      await selects.nth(1).selectOption(fx.s01Id);
      await selects.nth(2).selectOption(fx.kapeId);
      await modalForm.locator("input[type='number']").fill("5");
      await modalForm.locator("button[type='submit']").click();

      await expect
        .poll(
          async () =>
            (await restGet<Array<{ id: string }>>(ownerToken, `transfers?from_location_id=eq.${fx.w01Id}&select=id`))
              .length,
          { timeout: 10_000 },
        )
        .toBe(beforeTransfers.length + 1);

      const [draftTrf] = await restGet<Array<{ id: string; transfer_no: string; status: string }>>(
        ownerToken,
        `transfers?from_location_id=eq.${fx.w01Id}&to_location_id=eq.${fx.s01Id}&select=id,transfer_no,status&order=created_at.desc&limit=1`,
      );
      expect(draftTrf?.status).toBe("draft");

      const trfRow = whPage.locator("tr", { hasText: draftTrf!.transfer_no });
      await expect(trfRow).toBeVisible();
      await expect(trfRow).toContainText("S01");

      // Generate pick list, confirm pick into staging, then ship
      await trfRow.getByRole("button", { name: "Pick List", exact: true }).click();
      await whPage.getByTestId("generate-picklist-btn").click();
      await whPage.locator("[data-testid^='pick-item-btn-']").first().click();
      await whPage.getByTestId("pick-qty-input").fill("5");
      await whPage.getByTestId("save-pick-btn").click();
      await expect(whPage.getByText("Picked", { exact: true })).toBeVisible();
      await whPage.getByRole("button", { name: "Close", exact: true }).last().click();

      await trfRow.getByRole("button", { name: "Ship", exact: true }).click();
      await expect
        .poll(
          async () =>
            (await restGet<Array<{ status: string }>>(ownerToken, `transfers?id=eq.${draftTrf!.id}&select=status`))[0]
              ?.status,
          { timeout: 10_000 },
        )
        .toBe("shipped");
    } finally {
      await whCtx.close();
    }

    const [latestTrf] = await restGet<Array<{ id: string; transfer_no: string; status: string }>>(
      ownerToken,
      `transfers?to_location_id=eq.${fx.s01Id}&status=eq.shipped&select=id,transfer_no,status&order=created_at.desc&limit=1`,
    );
    expect(latestTrf).toBeTruthy();

    // Store staff receives transfer on /app/receive-stock
    const posCtx = await browser.newContext();
    const posPage = await posCtx.newPage();
    try {
      await signInEmail(posPage, EMAILS.manager);
      await posPage.goto("/app/receive-stock");
      await posPage.getByTestId(`pos-receive-btn-${latestTrf!.transfer_no}`).click();
      await posPage.getByTestId("pos-confirm-receive-btn").click();
      await expect(posPage.getByTestId("pos-confirm-receive-btn")).toHaveCount(0);
    } finally {
      await posCtx.close();
    }

    await expect
      .poll(() => getStockQty(ownerToken, fx.w01Id, fx.kapeId), { timeout: 10_000 })
      .toBe(beforeWh + 5);
    await expect
      .poll(() => getStockQty(ownerToken, fx.s01Id, fx.kapeId), { timeout: 10_000 })
      .toBe(beforeS01 + 5);

    const postInv = await rpc<
      Array<{ variant_id: string; warehouse_qty: number; bins_qty: number; is_valid: boolean }>
    >(ownerToken, "check_bin_stock_invariant", { p_warehouse_id: fx.w01Id });
    expect(postInv.every((r) => r.is_valid)).toBe(true);
  });

  test("Flow 5: Stock count / adjustment writes only new movements and never edits existing rows", async ({
    page,
  }) => {
    const beforeQty = await getStockQty(ownerToken, fx.s01Id, fx.pandesalId);
    const beforeMovements = await restGet<Array<{ id: string; qty_delta: number; type: string }>>(
      ownerToken,
      `stock_movements?location_id=eq.${fx.s01Id}&variant_id=eq.${fx.pandesalId}&select=id,qty_delta,type&order=created_at.asc`,
    );

    await signInEmail(page, EMAILS.manager);
    await page.goto("/app/inventory");
    await expect(page.getByTestId(`inv-row-${fx.pandesalSku}`)).toBeVisible();
    await page.getByTestId(`inv-adjust-${fx.pandesalSku}`).click();
    await page.getByTestId("inventory-count-input").fill(String(beforeQty + 4));
    await page.getByTestId("inventory-count-submit").click();
    await expect(page.getByTestId("inventory-count-submit")).toHaveCount(0);

    await expect
      .poll(() => getStockQty(ownerToken, fx.s01Id, fx.pandesalId), { timeout: 10_000 })
      .toBe(beforeQty + 4);

    const afterMovements = await restGet<Array<{ id: string; qty_delta: number; type: string }>>(
      ownerToken,
      `stock_movements?location_id=eq.${fx.s01Id}&variant_id=eq.${fx.pandesalId}&select=id,qty_delta,type&order=created_at.asc`,
    );
    const afterMap = new Map(afterMovements.map((m) => [m.id, m]));
    for (const prev of beforeMovements) {
      expect(afterMap.get(prev.id)).toEqual(prev);
    }
    expect(afterMovements.length).toBe(beforeMovements.length + 1);
    const newest = afterMovements[afterMovements.length - 1]!;
    expect(newest.type).toBe("count_correction");
    expect(Number(newest.qty_delta)).toBe(4);
  });

  test("Flow 6: Admin creates multi-variant product + edits price; cashier sees update after poll", async ({
    browser,
  }) => {
    test.setTimeout(120_000);
    const tag = Date.now().toString(36).toUpperCase();
    const prodName = `QA Matcha ${tag}`;
    const skuSmall = `QM-S-${tag}`;
    const skuMed = `QM-M-${tag}`;

    const adminCtx = await browser.newContext();
    const cashierCtx = await browser.newContext();
    const adminPage = await adminCtx.newPage();
    const cashierPage = await cashierCtx.newPage();
    try {
      await signInEmail(adminPage, EMAILS.owner);
      await signInEmail(cashierPage, EMAILS.cashier);
      await expect(cashierPage.getByTestId(`product-${fx.latteRegSku}`)).toBeVisible();

      // Admin creates multi-variant product
      await adminPage.goto("/app/products");
      await adminPage.getByTestId("add-product").click();
      await adminPage.getByTestId("pf-name").fill(prodName);
      await adminPage.getByTestId("pf-cost").fill("50");
      await adminPage.getByTestId("pf-add-variant").click();

      await adminPage.getByTestId("pf-variant-name-0").fill("Small");
      await adminPage.getByTestId("pf-variant-price-0").fill("90");
      await adminPage.getByTestId("pf-variant-cost-0").fill("50");
      await adminPage.getByTestId("pf-variant-sku-0").fill(skuSmall);
      await adminPage.getByTestId("pf-variant-opening-0").fill("5");

      await adminPage.getByTestId("pf-variant-name-1").fill("Medium");
      await adminPage.getByTestId("pf-variant-price-1").fill("115");
      await adminPage.getByTestId("pf-variant-cost-1").fill("60");
      await adminPage.getByTestId("pf-variant-sku-1").fill(skuMed);
      await adminPage.getByTestId("pf-variant-opening-1").fill("5");

      await adminPage.getByTestId("pf-save").click();
      await expect(adminPage.getByTestId(`row-${skuSmall}`)).toBeVisible({ timeout: 10_000 });

      // Wait for cashier's sellables staleTime (30s) and re-enter Sell screen cleanly (no page reload).
      await cashierPage.waitForTimeout(31_000);
      await cashierPage.getByRole("link", { name: /^sales$/i }).click();
      await cashierPage.getByRole("link", { name: /^sell$/i }).click();
      await expect(cashierPage.getByTestId(`product-${skuSmall}`)).toBeVisible({ timeout: 10_000 });

      // Admin updates Small price 90 -> 95
      await adminPage.getByTestId(`row-${skuSmall}`).click();
      await adminPage.getByTestId("pf-variant-price-0").fill("95");
      await adminPage.getByTestId("pf-save").click();
      await expect
        .poll(async () => {
          const variants = await restGet<Array<{ id: string }>>(
            ownerToken,
            `product_variants?sku=eq.${encodeURIComponent(skuSmall)}&select=id`,
          );
          const vid = variants[0]?.id;
          if (!vid) return undefined;
          const prices = await restGet<Array<{ price: number }>>(
            ownerToken,
            `variant_prices?variant_id=eq.${vid}&currency=eq.PHP&select=price`,
          );
          return prices[0]?.price;
        })
        .toBe(9500);

      await cashierPage.waitForTimeout(31_000);
      await cashierPage.getByRole("link", { name: /^sales$/i }).click();
      await cashierPage.getByRole("link", { name: /^sell$/i }).click();
      await cashierPage.getByTestId(`product-${skuSmall}`).click();
      await expect(cashierPage.getByTestId(`pick-variant-${skuSmall}`)).toContainText("95");
    } finally {
      await adminCtx.close();
      await cashierCtx.close();
    }
  });

  test("Flow 7: Disabling POS module hides POS navigation AND refuses POS RPCs", async ({ browser }) => {
    const cashierAuth = await apiAuth(EMAILS.cashier);

    const adminCtx = await browser.newContext();
    const cashierCtx = await browser.newContext();
    const adminPage = await adminCtx.newPage();
    const cashierPage = await cashierCtx.newPage();
    try {
      await signInEmail(adminPage, EMAILS.owner);
      await adminPage.goto("/app/modules");
      const posCheckbox = adminPage.locator("fieldset input[type='checkbox']").nth(1);
      await expect(posCheckbox).toBeChecked();
      await posCheckbox.uncheck();
      await adminPage.locator("main").getByRole("button", { name: "Save", exact: true }).click();
      await expect
        .poll(async () => {
          const rows = await restGet<Array<{ pos: boolean }>>(
            ownerToken,
            `tenant_modules?tenant_id=eq.${fx.tenantId}&select=pos`,
          );
          return rows[0]?.pos;
        })
        .toBe(false);

      // Cashier logs in with POS disabled: Sell link is hidden and /app/sell redirects away
      await signInEmail(cashierPage, EMAILS.cashier);
      await expect(cashierPage).not.toHaveURL(/\/app\/sell/);
      await expect(cashierPage.locator("nav a[href='/app/sell']")).toHaveCount(0);
      await cashierPage.goto("/app/sell");
      await expect(cashierPage).not.toHaveURL(/\/app\/sell/);

      // Direct POS RPCs must refuse
      const pullRes = await rpcRaw(cashierAuth.token, "sync_pull_pos", { p_cursors: {}, p_limit: 10 });
      expect(pullRes.ok).toBe(false);

      const salePushRes = await rpcRaw(cashierAuth.token, "sync_push", {
        p_ops: [
          {
            op_id: "019a0000-0000-7000-8000-000000000001",
            kind: "record_sale",
            payload: {
              id: "019a0000-0000-7000-8000-000000000002",
              location_id: fx.s01Id,
              local_no: "QA-MOD-OFF-1",
              sold_at: new Date().toISOString(),
              discount: 0,
              lines: [{ variant_id: fx.latteRegId, qty: 1, unit_price: 12000 }],
              payments: [{ method: "cash", amount: 12000, tendered: 12000 }],
            },
          },
        ],
      });
      const pushRefused =
        !salePushRes.ok ||
        (Array.isArray(salePushRes.body) &&
          (salePushRes.body[0] as { status?: string } | undefined)?.status === "rejected");
      expect(pushRefused).toBe(true);
    } finally {
      await ensurePosEnabled(ownerToken);
      await adminCtx.close();
      await cashierCtx.close();
    }
  });
});
