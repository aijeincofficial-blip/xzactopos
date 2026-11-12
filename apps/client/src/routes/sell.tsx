import { useEffect, useMemo, useRef, useState } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { formatMoney, money, uuidv7 } from "@pos/core";
import {
  Banknote,
  CheckCircle2,
  CloudOff,
  CreditCard,
  HandCoins,
  Keyboard,
  Minus,
  PauseCircle,
  Play,
  Plus,
  Printer,
  RefreshCw,
  ScanBarcode,
  Search,
  ShoppingBag,
  Smartphone,
  Star,
  Tag,
  Trash2,
  UserPlus,
  X,
} from "lucide-react";
import { Alert, Badge, Button, Card, Dialog, EmptyState, Input, Select, useToast } from "../components/ui.tsx";
import { useSession } from "../lib/session.tsx";
import { useActiveLocation } from "../lib/location-context.tsx";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import { ApiError } from "../lib/api.ts";
import { dayInTimezone } from "../lib/today.ts";
import {
  buildSplitPayments,
  cartLineDiscounts,
  cartNeedsDiscountApproval,
  cartSubtotal,
  cartTotal,
  changeDue,
  draftProblem,
  lineGrossTotal,
  lineTotal,
  parseAmount,
  type CartLine,
  type PaymentDraft,
  type PayMethod,
  type SaleDraft,
  type Wallet,
} from "../lib/sale-math.ts";
import {
  createCustomer,
  fetchCustomers,
  fetchSellables,
  nextLocalNo,
  registerWebDevice,
  submitSale,
  webDevice,
  type Sellable,
  type SoldReceipt,
} from "../lib/sell-api.ts";
import {
  fetchCategories,
  fetchLocationReorderPoints,
  fetchStockExpiries,
  fetchStockLevels,
  getExpiryStatus,
} from "../lib/stock-api.ts";
import { supabase } from "../lib/supabase.ts";
import { SupervisorPinDialog } from "../components/supervisor-pin-dialog.tsx";
import { PosShiftControl } from "../components/pos-shift-dialog.tsx";
import { ProductThumb } from "../components/product-thumb.tsx";
import { ReceiptSlipView, type ReceiptData } from "../components/receipt-slip.tsx";
import type { OfflineApprovalPayload } from "../lib/offline-pin-api.ts";
import {
  getStoredPinned,
  saveStoredPinned,
  resolveFastKeyProducts,
  isSkuPinned,
  togglePinnedSku,
} from "../lib/fast-keys.ts";
import { resolvePosHotkey } from "../lib/sell-hotkeys.ts";
import {
  discardHeldOrder,
  loadHeldOrders,
  parkOrder,
  resumeHeldOrder,
  type HeldOrder,
} from "../lib/held-orders.ts";
import { useOnlineStatus } from "../lib/network.ts";
import {
  applyOptimisticStockDeltas,
  flushPosOutbox,
  retryFailedPosOps,
  setPosOutboxTenant,
  usePosOutboxSnapshot,
} from "../lib/pos-outbox.ts";

const WALLETS: Wallet[] = ["gcash", "maya", "other"];
const CASH_BILLS_MAJOR = [50, 100, 200, 500, 1000] as const;

interface Done extends SoldReceipt {
  total: number;
  change: number;
  onUtang: number;
  receiptData?: ReceiptData;
}

function formatMajorInput(minorAmount: number): string {
  const major = minorAmount / 100;
  return Number.isInteger(major) ? String(major) : major.toFixed(2);
}

/** Kiosk-style Web POS Terminal: calm search & category bar, crisp product grid, and focused order register. */
export function SellPage() {
  const { t, i18n } = useTranslation("admin");
  const msg = useErrorMessage();
  const { access, can } = useSession();
  setPosOutboxTenant(access.tenant.id);
  const online = useOnlineStatus();
  const outboxOps = usePosOutboxSnapshot();
  const [syncingOutbox, setSyncingOutbox] = useState(false);
  const currency = access.tenant.base_currency;
  const fmt = (n: number) => formatMoney(money(n, currency), i18n.language);

  const { activeStore } = useActiveLocation();
  const store =
    activeStore && can("sale.create", activeStore.id)
      ? activeStore
      : access.locations.find((l) => l.type === "store" && can("sale.create", l.id));

  const catalog = useQuery({
    queryKey: ["sellables", currency],
    queryFn: () => fetchSellables(currency),
    staleTime: 30_000,
  });

  const categoriesQuery = useQuery({
    queryKey: ["categories"],
    queryFn: fetchCategories,
    staleTime: 60_000,
  });

  const stockQuery = useQuery({
    queryKey: ["pos-stock-levels", store?.id],
    queryFn: () => fetchStockLevels(store!.id),
    enabled: Boolean(store?.id),
    staleTime: 15_000,
  });

  const expiryQuery = useQuery({
    queryKey: ["pos-stock-expiries", store?.id],
    queryFn: () => fetchStockExpiries(store!.id).catch(() => new Map<string, string | null>()),
    enabled: Boolean(store?.id),
    staleTime: 30_000,
  });

  const reorderQuery = useQuery({
    queryKey: ["pos-reorder-points", store?.id],
    queryFn: () => fetchLocationReorderPoints(store!.id).catch(() => new Map<string, number>()),
    enabled: Boolean(store?.id),
    staleTime: 30_000,
  });

  const [search, setSearch] = useState("");
  const [activeFilter, setActiveFilter] = useState<string>("all");
  const [cart, setCart] = useState<CartLine[]>([]);
  const [discountText, setDiscountText] = useState("");
  const [method, setMethod] = useState<PayMethod>("cash");
  const [customerId, setCustomerId] = useState("");
  const [paidText, setPaidText] = useState("");
  const [newName, setNewName] = useState("");
  const [newPhone, setNewPhone] = useState("");
  const [showNew, setShowNew] = useState(false);
  const qc = useQueryClient();
  const [wallet, setWallet] = useState<Wallet>("gcash");
  const [reference, setReference] = useState("");
  const [tenderedText, setTenderedText] = useState("");
  const [splitTenders, setSplitTenders] = useState<PaymentDraft[]>([]);
  const [problem, setProblem] = useState<string | null>(null);
  const [done, setDone] = useState<Done | null>(null);
  const [approvalId, setApprovalId] = useState<string | null>(null);
  const [offlineApproval, setOfflineApproval] = useState<OfflineApprovalPayload | null>(null);
  const [showApprovalDialog, setShowApprovalDialog] = useState(false);
  const [editingVariantId, setEditingVariantId] = useState<string | null>(null);
  const [linePriceText, setLinePriceText] = useState("");
  const [lineDiscText, setLineDiscText] = useState("");
  const [heldOrders, setHeldOrders] = useState<HeldOrder[]>(() => (store?.id ? loadHeldOrders(store.id) : []));
  const [showHoldDialog, setShowHoldDialog] = useState(false);
  const [holdLabel, setHoldLabel] = useState("");
  const [showHeldListDialog, setShowHeldListDialog] = useState(false);
  const toast = useToast();
  const attempt = useRef<{ key: string; id: string; opId: string } | null>(null);
  const searchInputRef = useRef<HTMLInputElement | null>(null);
  const discountInputRef = useRef<HTMLInputElement | null>(null);
  const tenderedInputRef = useRef<HTMLInputElement | null>(null);
  const payMethodSelectRef = useRef<HTMLSelectElement | null>(null);

  useEffect(() => {
    void registerWebDevice();
  }, []);

  useEffect(() => {
    setHeldOrders(store?.id ? loadHeldOrders(store.id) : []);
  }, [store?.id]);

  const pendingOutboxCount = useMemo(
    () => outboxOps.filter((o) => o.state === "pending").length,
    [outboxOps],
  );
  const failedOutboxCount = useMemo(
    () => outboxOps.filter((o) => o.state === "failed").length,
    [outboxOps],
  );

  async function runOutboxSync(manual = false) {
    if (!online && !manual) return;
    if (manual && failedOutboxCount > 0) {
      retryFailedPosOps();
    }
    setSyncingOutbox(true);
    try {
      const res = await flushPosOutbox();
      if (res.synced > 0) {
        toast.good(t("sell.outboxSynced", { count: res.synced }));
        await Promise.all([
          qc.invalidateQueries({ queryKey: ["pos-stock-levels", store?.id] }),
          qc.invalidateQueries({ queryKey: ["customers"] }),
        ]);
      }
    } finally {
      setSyncingOutbox(false);
    }
  }

  useEffect(() => {
    if (!online || pendingOutboxCount === 0) return;
    void runOutboxSync(false);
    const timer = window.setInterval(() => {
      void runOutboxSync(false);
    }, 30_000);
    return () => window.clearInterval(timer);
  }, [online, pendingOutboxCount, store?.id]);

  const settingsQuery = useQuery({
    queryKey: ["tenant-settings-controls"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("tenant_settings")
        .select("max_cashier_discount_percent, max_cashier_void_amount, cashier_can_void_own, receipt_header, receipt_footer")
        .single();
      if (error) return null;
      return data;
    },
    staleTime: 60_000,
  });

  const maxDiscountPct = settingsQuery.data?.max_cashier_discount_percent ?? 10;
  const discount = parseAmount(discountText, currency);
  const tendered = parseAmount(tenderedText, currency);
  const lineDiscounts = cartLineDiscounts(cart);
  const subtotal = cartSubtotal(cart);
  const total = discount === null ? subtotal : cartTotal(cart, discount);

  const isDiscountOverLimit = cartNeedsDiscountApproval({
    role: access.role,
    lines: cart,
    cartDiscount: discount ?? 0,
    maxDiscountPercent: maxDiscountPct,
  });

  const paidNow = paidText.trim() === "" ? null : parseAmount(paidText, currency);
  const paidInvalid = paidText.trim() !== "" && paidNow === null;
  const splitResult = useMemo(
    () =>
      buildSplitPayments(total, splitTenders, {
        method,
        paidNow,
        tendered,
        wallet,
        reference: reference.trim(),
      }),
    [total, splitTenders, method, paidNow, tendered, wallet, reference],
  );
  const payments = paidInvalid || discount === null ? null : splitResult.payments;
  const remainingDue = splitResult.remainingDue;
  const splitExceeded = splitTenders.length > 0 && splitResult.lockedTotal > total;
  const onUtang = splitResult.onUtang;
  const change = splitResult.change;
  const customers = useQuery({ queryKey: ["customers"], queryFn: fetchCustomers, staleTime: 30_000 });

  const [customPinned, setCustomPinned] = useState<string[] | null>(() => getStoredPinned());

  const fastKeyProducts = useMemo(
    () => resolveFastKeyProducts(catalog.data ?? [], customPinned),
    [catalog.data, customPinned],
  );

  const activeCategories = useMemo(() => {
    const allItems = catalog.data ?? [];
    const usedIds = new Set(allItems.map((s) => s.categoryId).filter(Boolean));
    return (categoriesQuery.data ?? []).filter((c) => usedIds.has(c.id));
  }, [catalog.data, categoriesQuery.data]);

  const cartQtyByVariant = useMemo(() => {
    const m = new Map<string, number>();
    for (const l of cart) m.set(l.variantId, l.qty);
    return m;
  }, [cart]);

  const totalOrderUnits = useMemo(
    () => cart.reduce((sum, l) => sum + (Number.isFinite(l.qty) && l.qty > 0 ? l.qty : 0), 0),
    [cart],
  );

  const expiryMap = expiryQuery.data;
  const reorderMap = reorderQuery.data;
  const expiredCartCount = useMemo(() => {
    if (!expiryMap || cart.length === 0) return 0;
    let count = 0;
    for (const l of cart) {
      if (getExpiryStatus(expiryMap.get(l.variantId) ?? null) === "expired") {
        count += 1;
      }
    }
    return count;
  }, [cart, expiryMap]);

  const shown = useMemo(() => {
    const q = search.trim().toLowerCase();
    let pool = catalog.data ?? [];
    if (activeFilter === "pinned") {
      pool = fastKeyProducts;
    } else if (activeFilter !== "all") {
      pool = pool.filter((s) => s.categoryId === activeFilter);
    }
    if (q) {
      pool = pool.filter(
        (s) =>
          s.name.toLowerCase().includes(q) ||
          s.sku.toLowerCase().includes(q) ||
          s.barcode?.toLowerCase() === q,
      );
    }
    return pool.slice(0, 80);
  }, [catalog.data, fastKeyProducts, activeFilter, search]);

  function isPinned(sku: string): boolean {
    return isSkuPinned(sku, catalog.data ?? [], customPinned);
  }

  function togglePin(sku: string) {
    const next = togglePinnedSku(sku, catalog.data ?? [], customPinned);
    setCustomPinned(next);
    saveStoredPinned(next);
  }

  function clearApproval() {
    setApprovalId(null);
    setOfflineApproval(null);
  }

  function add(s: Sellable, qty = 1) {
    setProblem(null);
    clearApproval();
    setCart((c) => {
      const i = c.findIndex((l) => l.variantId === s.variantId);
      if (i >= 0) return c.map((l, k) => (k === i ? { ...l, qty: Number((l.qty + qty).toFixed(3)) } : l));
      return [
        ...c,
        {
          variantId: s.variantId,
          name: s.name,
          qty,
          unitPrice: s.price,
          catalogPrice: s.price,
          discount: 0,
          unitCost: s.cost,
          taxRate: s.taxRate,
          tracked: s.tracked,
        },
      ];
    });
  }

  function openLineEditor(l: CartLine) {
    if (editingVariantId === l.variantId) {
      setEditingVariantId(null);
      return;
    }
    setEditingVariantId(l.variantId);
    setLinePriceText(formatMajorInput(l.unitPrice));
    setLineDiscText((l.discount ?? 0) > 0 ? formatMajorInput(l.discount ?? 0) : "");
  }

  function applyLinePriceText(variantId: string, text: string) {
    setLinePriceText(text);
    const parsed = parseAmount(text, currency);
    if (parsed === null) return;
    setProblem(null);
    clearApproval();
    setCart((c) =>
      c.map((l) => {
        if (l.variantId !== variantId) return l;
        const gross = lineGrossTotal(l.qty, parsed);
        const clampedDisc = Math.min(l.discount ?? 0, gross);
        return { ...l, unitPrice: parsed, discount: clampedDisc };
      }),
    );
  }

  function applyLineDiscText(variantId: string, text: string) {
    setLineDiscText(text);
    const parsed = text.trim() === "" ? 0 : parseAmount(text, currency);
    if (parsed === null) return;
    setProblem(null);
    clearApproval();
    setCart((c) =>
      c.map((l) => {
        if (l.variantId !== variantId) return l;
        return { ...l, discount: parsed };
      }),
    );
  }

  function resetLinePricing(l: CartLine) {
    const orig = l.catalogPrice ?? l.unitPrice;
    setLinePriceText(formatMajorInput(orig));
    setLineDiscText("");
    setProblem(null);
    clearApproval();
    setCart((c) =>
      c.map((x) => (x.variantId === l.variantId ? { ...x, unitPrice: orig, discount: 0 } : x)),
    );
  }

  function onSearchEnter() {
    const q = search.trim().toLowerCase();
    const hit = q
      ? (catalog.data ?? []).find((s) => s.barcode?.toLowerCase() === q || s.sku.toLowerCase() === q)
      : undefined;
    if (hit) {
      add(hit);
      setSearch("");
    }
  }

  function setQty(variantId: string, text: string) {
    const qty = Number(text);
    clearApproval();
    setCart((c) => c.map((l) => (l.variantId === variantId ? { ...l, qty: Number.isFinite(qty) ? qty : 0 } : l)));
  }

  function stepCartQty(variantId: string, delta: number) {
    clearApproval();
    setCart((c) =>
      c
        .map((l) => {
          if (l.variantId !== variantId) return l;
          const next = Number((l.qty + delta).toFixed(3));
          return { ...l, qty: next };
        })
        .filter((l) => l.qty > 0),
    );
  }

  function reset() {
    setCart([]);
    setDiscountText("");
    setTenderedText("");
    setReference("");
    setPaidText("");
    setSplitTenders([]);
    setCustomerId("");
    setProblem(null);
    setApprovalId(null);
    setOfflineApproval(null);
    setShowApprovalDialog(false);
    setEditingVariantId(null);
    attempt.current = null;
  }

  function addSplitTender() {
    if (method === "utang" || paidNow === null || paidNow <= 0 || paidNow >= remainingDue) return;
    if (method === "cash" && tendered !== null && tendered > 0 && tendered < paidNow) {
      setProblem(t("sell.problem.tendered_too_low"));
      return;
    }
    const ref = reference.trim();
    const draft: PaymentDraft =
      method === "cash"
        ? { method: "cash", amount: paidNow, tendered: tendered && tendered > 0 ? tendered : paidNow }
        : method === "ewallet"
          ? { method: "ewallet", amount: paidNow, wallet, ...(ref ? { reference: ref } : {}) }
          : { method: "card", amount: paidNow, ...(ref ? { reference: ref } : {}) };
    setSplitTenders((prev) => [...prev, draft]);
    setPaidText("");
    setTenderedText("");
    setReference("");
    setProblem(null);
    setMethod(method === "cash" ? "ewallet" : "cash");
  }

  function removeSplitTender(idx: number) {
    setSplitTenders((prev) => prev.filter((_, i) => i !== idx));
    setProblem(null);
  }

  const addCustomer = useMutation({
    mutationFn: () => createCustomer(newName, newPhone),
    onSuccess: async (c) => {
      await qc.invalidateQueries({ queryKey: ["customers"] });
      setCustomerId(c.id);
      setNewName("");
      setNewPhone("");
      setShowNew(false);
    },
    onError: (e) => setProblem(msg(e)),
  });

  const charge = useMutation({
    mutationFn: async (override?: { approvalId?: string; offlineApproval?: OfflineApprovalPayload }): Promise<Done> => {
      if (!store) throw new ApiError("not_allowed", "no store");
      if (discount === null || payments === null || (method === "cash" && tendered === null)) {
        throw new ApiError("amount_invalid", "amount");
      }
      const day = dayInTimezone(access.tenant.timezone);
      const key = JSON.stringify([cart, discount, payments, store.id, customerId]);
      if (attempt.current?.key !== key) attempt.current = { key, id: uuidv7(), opId: uuidv7() };
      const currentApproval = override?.approvalId ?? approvalId;
      const currentOfflineApproval = override?.offlineApproval ?? offlineApproval;
      const base = {
        id: attempt.current.id,
        soldAt: new Date(),
        locationId: store.id,
        deviceId: webDevice().id,
        customerId: customerId || undefined,
        discount,
        approvalId: currentApproval || undefined,
        offlineApproval: currentOfflineApproval || undefined,
        lines: cart,
        payments,
      };
      const bad = draftProblem({ ...base, localNo: "X-000000-0000" });
      if (bad) throw new ApiError(bad, bad);
      for (let n = 0; ; n++) {
        const draft: SaleDraft = { ...base, localNo: nextLocalNo(day) };
        try {
          const r = await submitSale(draft, attempt.current.opId);
          const changeAmt = payments.reduce(
            (sum, p) => sum + (p.method === "cash" ? changeDue(p.tendered ?? p.amount, p.amount) : 0),
            0,
          );
          const utangAmt = payments.filter((p) => p.method === "utang").reduce((sum, p) => sum + p.amount, 0);
          const receiptData: ReceiptData = {
            tenantName: access.tenant.name,
            storeName: store.name,
            storeCode: store.code,
            storeAddress: store.address ?? null,
            receiptHeader: settingsQuery.data?.receipt_header ?? access.tenant.receipt_header ?? null,
            receiptFooter: settingsQuery.data?.receipt_footer ?? access.tenant.receipt_footer ?? null,
            receiptNo: r.saleNo ?? r.localNo,
            soldAt: new Date(),
            cashierName: access.full_name || access.username,
            customerName: (customers.data ?? []).find((c) => c.id === customerId)?.name || null,
            items: cart.map((line) => ({
              product_name: line.name,
              qty: line.qty,
              unit_price: line.unitPrice,
              ...(line.discount && line.discount > 0 ? { discount: line.discount } : {}),
              line_total: lineTotal(line.qty, line.unitPrice, line.discount ?? 0),
            })),
            subtotal,
            discount,
            total,
            payments: payments.map((p) => ({
              method: p.method,
              amount: p.amount,
              wallet: p.wallet,
              reference: p.reference,
            })),
            change: changeAmt,
            onUtang: utangAmt,
            currency,
            timezone: access.tenant.timezone,
          };
          return { ...r, total, change: changeAmt, onUtang: utangAmt, receiptData };
        } catch (e) {
          if (!(e instanceof ApiError && e.key === "duplicate_local_no" && n < 3)) throw e;
        }
      }
    },
    onSuccess: (r) => {
      void qc.invalidateQueries({ queryKey: ["pos-stock-levels", store?.id] });
      void qc.invalidateQueries({ queryKey: ["shift-expected-now"] });
      setDone(r);
      reset();
    },
    onError: (e) => {
      if (e instanceof ApiError && e.key === "approval_required") {
        setShowApprovalDialog(true);
        return;
      }
      setProblem(
        e instanceof ApiError && i18n.exists(`admin:sell.problem.${e.key}`)
          ? t(`sell.problem.${e.key}` as never)
          : msg(e),
      );
    },
  });

  function openHoldDialog() {
    if (!store || cart.length === 0) return;
    const selectedCustomer = (customers.data ?? []).find((c) => c.id === customerId);
    setHoldLabel(selectedCustomer?.name ?? "");
    setShowHoldDialog(true);
  }

  function confirmHoldOrder() {
    if (!store || cart.length === 0) return;
    const selectedCustomer = (customers.data ?? []).find((c) => c.id === customerId);
    const { held, orders } = parkOrder(store.id, {
      label: holdLabel,
      customerId,
      customerName: selectedCustomer?.name,
      discountText,
      lines: cart,
    });
    if (!held) return;
    setHeldOrders(orders);
    setShowHoldDialog(false);
    setHoldLabel("");
    reset();
    toast.good(t("sell.holdOrderSaved"));
  }

  function handleResumeHeld(heldId: string) {
    if (!store) return;
    const selectedCustomer = (customers.data ?? []).find((c) => c.id === customerId);
    const { resumed, swapped, orders } = resumeHeldOrder(
      store.id,
      heldId,
      cart.length > 0
        ? {
            label: selectedCustomer?.name ?? "",
            customerId,
            customerName: selectedCustomer?.name,
            discountText,
            lines: cart,
          }
        : undefined,
    );
    if (!resumed) return;
    setHeldOrders(orders);
    setShowHeldListDialog(false);
    reset();
    setCart(resumed.lines);
    setCustomerId(resumed.customerId);
    setDiscountText(resumed.discountText);
    toast.info(swapped ? t("sell.heldOrderSwapped") : t("sell.heldOrderResumed"));
  }

  function handleDiscardHeld(heldId: string) {
    if (!store) return;
    setHeldOrders(discardHeldOrder(store.id, heldId));
  }

  function handleCharge() {
    if (!store) return;
    if (isDiscountOverLimit && !approvalId && !offlineApproval) {
      const key = JSON.stringify([cart, discount, payments, store.id, customerId]);
      if (attempt.current?.key !== key) attempt.current = { key, id: uuidv7(), opId: uuidv7() };
      setShowApprovalDialog(true);
      return;
    }
    charge.mutate(undefined);
  }

  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      const el = e.target as HTMLElement | null;
      const tag = el?.tagName?.toLowerCase();
      const inField = tag === "input" || tag === "textarea" || tag === "select" || Boolean(el?.isContentEditable);
      const action = resolvePosHotkey({
        key: e.key,
        altKey: e.altKey,
        ctrlKey: e.ctrlKey,
        metaKey: e.metaKey,
        shiftKey: e.shiftKey,
        inField,
        modalOpen: showApprovalDialog || showHoldDialog || showHeldListDialog,
        isDoneScreen: done !== null,
        canCharge: cart.length > 0 && !charge.isPending,
      });
      if (!action) return;
      e.preventDefault();
      switch (action.type) {
        case "focus_search":
          searchInputRef.current?.focus();
          searchInputRef.current?.select();
          break;
        case "focus_discount":
          discountInputRef.current?.focus();
          discountInputRef.current?.select();
          break;
        case "hold_order":
          openHoldDialog();
          break;
        case "focus_payment":
          if (method === "cash" && tenderedInputRef.current) {
            tenderedInputRef.current.focus();
            tenderedInputRef.current.select();
          } else {
            payMethodSelectRef.current?.focus();
          }
          break;
        case "fast_key": {
          const item = fastKeyProducts[action.index];
          if (item) add(item);
          break;
        }
        case "charge":
          handleCharge();
          break;
        case "new_sale":
          setDone(null);
          break;
        case "print_receipt":
          window.print();
          break;
      }
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  });

  if (!store) {
    return (
      <div className="mx-auto w-full max-w-lg p-6">
        <EmptyState title={t("sell.noStore")} />
      </div>
    );
  }

  if (done) {
    return (
      <div className="h-full overflow-y-auto">
        <div className="mx-auto grid w-full max-w-4xl content-start gap-6 p-6 md:grid-cols-[1fr_auto]">
          <Card className="grid gap-6" data-testid="sale-done">
            <div className="flex items-start justify-between gap-3">
              <div className="flex items-center gap-3">
                <div
                  className={`flex h-12 w-12 items-center justify-center rounded-xl ${
                    done.queuedOffline ? "bg-amber-50 text-amber-600" : "bg-emerald-50 text-emerald-600"
                  }`}
                >
                  {done.queuedOffline ? <CloudOff size={24} aria-hidden /> : <CheckCircle2 size={24} aria-hidden />}
                </div>
                <div>
                  <h2 className="text-lg font-semibold text-slate-900">
                    {done.queuedOffline ? t("sell.doneOffline") : t("sell.done")}
                  </h2>
                  <div className="font-mono text-xs text-slate-500">
                    {t("sell.receiptNo")}{" "}
                    <span className="font-semibold text-slate-900">{done.saleNo ?? done.localNo}</span>
                  </div>
                </div>
              </div>
              <Badge tone={done.queuedOffline ? "warn" : "good"}>{store.code}</Badge>
            </div>

            {done.queuedOffline ? (
              <div
                data-testid="offline-sale-banner"
                className="rounded-xl border border-amber-200 bg-amber-50/80 px-4 py-3 text-xs font-medium text-amber-900"
              >
                {t("sell.offlineSaleNotice")}
              </div>
            ) : null}

            <div className="grid gap-2 rounded-xl border border-slate-200/80 bg-slate-50/70 p-4">
              <span className="text-xs font-semibold tracking-wider text-slate-500 uppercase">
                {t("sell.total")}
              </span>
              <div className="text-3xl font-semibold text-slate-900 tabular-nums">{fmt(done.total)}</div>
              {done.change > 0 ? (
                <div className="mt-2 flex items-baseline justify-between border-t border-slate-200 pt-2 text-base">
                  <span className="text-slate-600">{t("sell.change")}</span>
                  <span className="text-xl font-semibold text-emerald-700 tabular-nums">{fmt(done.change)}</span>
                </div>
              ) : null}
              {done.onUtang > 0 ? (
                <div className="mt-2 flex items-baseline justify-between border-t border-slate-200 pt-2 text-sm text-amber-800">
                  <span>{t("sell.onUtang")}</span>
                  <span className="font-semibold tabular-nums">{fmt(done.onUtang)}</span>
                </div>
              ) : null}
            </div>

            <div className="no-print flex gap-3">
              <Button
                variant="outline"
                data-testid="print-receipt-btn"
                onClick={() => window.print()}
                className="h-11 flex-1"
              >
                <Printer size={16} className="text-slate-500" aria-hidden />
                <span>{t("sell.printReceipt")}</span>
              </Button>
              <Button data-testid="new-sale" onClick={() => setDone(null)} className="h-11 flex-1">
                {t("sell.newSale")}
              </Button>
            </div>
          </Card>

          {done.receiptData ? (
            <div className="rounded-xl border border-slate-200 bg-white p-4 shadow-xs">
              <ReceiptSlipView receipt={done.receiptData} />
            </div>
          ) : null}
        </div>
      </div>
    );
  }

  const stockMap = useMemo(() => {
    if (!stockQuery.data || !store) return undefined;
    return applyOptimisticStockDeltas(stockQuery.data, store.id, outboxOps);
  }, [stockQuery.data, store, outboxOps]);
  const cashTarget = paidNow !== null ? paidNow : remainingDue;

  return (
    <div className="grid h-full min-h-0 lg:grid-cols-[1fr_400px]">
      {/* LEFT TERMINAL: Calm Search Header + Category Filter Strip + Clean Product Grid */}
      <section className="flex min-h-0 min-w-0 flex-col bg-slate-50">
        <div className="border-b border-slate-200/80 bg-white px-4 py-3">
          <div className="flex items-center gap-2.5">
            <div className="relative min-w-0 flex-1">
              <Search
                size={17}
                className="pointer-events-none absolute top-1/2 left-3.5 -translate-y-1/2 text-slate-400"
                aria-hidden
              />
              <Input
                ref={searchInputRef}
                type="search"
                data-testid="sell-search"
                placeholder={t("sell.search")}
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && onSearchEnter()}
                className="h-10.5 border-slate-200 bg-slate-50/70 pr-24 pl-10 text-sm focus:bg-white"
              />
              <div className="absolute top-1/2 right-2.5 flex -translate-y-1/2 items-center gap-1.5">
                {search.length > 0 ? (
                  <button
                    type="button"
                    aria-label={t("sell.clearSearch")}
                    data-testid="clear-sell-search"
                    onClick={() => {
                      setSearch("");
                      searchInputRef.current?.focus();
                    }}
                    className="rounded-md p-1 text-slate-400 hover:bg-slate-200/70 hover:text-slate-800"
                  >
                    <X size={14} aria-hidden />
                  </button>
                ) : null}
                <span className="pointer-events-none hidden items-center gap-1 rounded-md border border-slate-200 bg-white px-1.5 py-0.5 text-xs text-slate-400 sm:inline-flex">
                  <ScanBarcode size={13} aria-hidden />
                  <kbd className="font-mono">F2</kbd>
                </span>
              </div>
            </div>

            {store ? (
              <PosShiftControl
                storeId={store.id}
                currency={currency}
                timezone={access.tenant.timezone}
              />
            ) : null}

            {!online || outboxOps.length > 0 ? (
              <button
                type="button"
                data-testid="pos-outbox-status"
                disabled={!online && outboxOps.length === 0}
                onClick={() => void runOutboxSync(true)}
                className={`inline-flex shrink-0 cursor-pointer items-center gap-1.5 rounded-lg border px-2.5 py-2 text-xs font-semibold transition-colors disabled:cursor-default ${
                  failedOutboxCount > 0
                    ? "border-red-200 bg-red-50 text-red-800 hover:bg-red-100"
                    : !online
                      ? "border-amber-200 bg-amber-50 text-amber-900"
                      : "border-brand-200 bg-brand-50 text-brand-700 hover:bg-brand-100"
                }`}
              >
                {!online ? (
                  <CloudOff size={14} className="text-amber-600" aria-hidden />
                ) : (
                  <RefreshCw size={14} className={syncingOutbox ? "animate-spin text-brand-600" : "text-brand-600"} aria-hidden />
                )}
                <span>
                  {failedOutboxCount > 0
                    ? t("sell.outboxFailedPill", { count: failedOutboxCount })
                    : !online
                      ? pendingOutboxCount > 0
                        ? t("sell.offlineQueuedPill", { count: pendingOutboxCount })
                        : t("sell.offlineReadyPill")
                      : syncingOutbox
                        ? t("sell.outboxSyncing", { count: pendingOutboxCount })
                        : t("sell.outboxSyncNow", { count: pendingOutboxCount })}
                </span>
              </button>
            ) : null}

            <span
              className="hidden shrink-0 items-center gap-1.5 rounded-lg border border-slate-200/80 bg-slate-50 px-2.5 py-2 text-xs text-slate-500 xl:inline-flex"
              data-testid="pos-shortcuts-hint"
              title={t("sell.shortcutsHint")}
            >
              <Keyboard size={14} className="text-slate-400" aria-hidden />
              <span className="font-mono">Alt+1–6 · F4 · F6 · F8 · F9</span>
            </span>
          </div>

          {/* Category & Favorites Filter Pills */}
          <div className="mt-2.5 flex items-center gap-1.5 overflow-x-auto overflow-y-hidden pb-0.5 [scrollbar-width:none]">
            <button
              type="button"
              data-testid="pos-cat-all"
              onClick={() => setActiveFilter("all")}
              className={`shrink-0 cursor-pointer rounded-lg border px-3 py-1.5 text-xs transition-colors ${
                activeFilter === "all"
                  ? "border-brand-200 bg-brand-50 font-semibold text-brand-text"
                  : "border-slate-200/80 bg-white text-slate-600 hover:bg-slate-50 hover:text-slate-900"
              }`}
            >
              {t("sell.allItems")} ({(catalog.data ?? []).length})
            </button>
            <button
              type="button"
              data-testid="pos-cat-pinned"
              onClick={() => setActiveFilter("pinned")}
              className={`inline-flex shrink-0 cursor-pointer items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs transition-colors ${
                activeFilter === "pinned"
                  ? "border-brand-200 bg-brand-50 font-semibold text-brand-text"
                  : "border-slate-200/80 bg-white text-slate-600 hover:bg-slate-50 hover:text-slate-900"
              }`}
            >
              <Star size={13} className="text-amber-500" aria-hidden />
              <span>
                {t("sell.pinnedTab")} ({fastKeyProducts.length})
              </span>
            </button>
            {activeCategories.map((cat) => (
              <button
                key={cat.id}
                type="button"
                data-testid={`pos-cat-${cat.id}`}
                onClick={() => setActiveFilter(cat.id)}
                className={`shrink-0 cursor-pointer rounded-lg border px-3 py-1.5 text-xs transition-colors ${
                  activeFilter === cat.id
                    ? "border-brand-200 bg-brand-50 font-semibold text-brand-text"
                    : "border-slate-200/80 bg-white text-slate-600 hover:bg-slate-50 hover:text-slate-900"
                }`}
              >
                {cat.name}
              </button>
            ))}
          </div>
        </div>

        {/* Scrollable Product Canvas */}
        <div className="grid flex-1 content-start gap-3.5 overflow-y-auto p-4">
          {/* Sleek Compact Fast-Keys Pill Strip (Alt+1..6) */}
          {activeFilter === "all" &&
          search.trim() === "" &&
          (fastKeyProducts.length > 0 || (customPinned !== null && customPinned.length === 0)) ? (
            <div data-testid="fast-keys-bar" className="flex items-center gap-2 overflow-x-auto pb-0.5 [scrollbar-width:none]">
              <span className="shrink-0 text-xs font-semibold tracking-wider text-slate-400 uppercase">
                {t("sell.fastKeys")}
              </span>
              {fastKeyProducts.length === 0 ? (
                <span className="text-xs text-slate-400">{t("sell.fastKeysEmpty")}</span>
              ) : (
                fastKeyProducts.map((s, idx) => (
                  <button
                    key={s.variantId}
                    type="button"
                    data-testid={`fast-key-${s.sku}`}
                    onClick={() => add(s)}
                    className="inline-flex shrink-0 cursor-pointer items-center gap-2 rounded-lg border border-slate-200/90 bg-white px-2.5 py-1.5 text-xs shadow-2xs transition-colors hover:border-brand-400 hover:bg-brand-50/40"
                  >
                    {idx < 6 ? (
                      <kbd className="rounded bg-slate-100 px-1.5 py-0.5 font-mono text-xs text-slate-500">
                        Alt+{idx + 1}
                      </kbd>
                    ) : null}
                    <span className="max-w-[140px] truncate font-semibold text-slate-800">{s.name}</span>
                    <span className="text-slate-500 tabular-nums">{fmt(s.price)}</span>
                  </button>
                ))
              )}
            </div>
          ) : null}

          {catalog.isPending ? (
            <ul className="grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-5">
              {Array.from({ length: 10 }).map((_, i) => (
                <li key={i} className="h-28 animate-pulse rounded-xl border border-slate-200/80 bg-white" />
              ))}
            </ul>
          ) : null}
          {catalog.isError ? <Alert>{t("sell.loadError")}</Alert> : null}
          {catalog.data && catalog.data.length === 0 ? <EmptyState title={t("sell.noProducts")} /> : null}
          {catalog.data && catalog.data.length > 0 && shown.length === 0 ? (
            <EmptyState title={t("sell.noMatch")} />
          ) : null}

          {shown.length > 0 ? (
            <ul className="grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-5">
              {shown.map((s) => {
                const pinned = isPinned(s.sku);
                const inCartQty = cartQtyByVariant.get(s.variantId) ?? 0;
                const stockQty = s.tracked && stockMap ? (stockMap.get(s.variantId) ?? 0) : null;
                const effectiveReorder = reorderMap?.get(s.variantId) ?? s.reorderPoint ?? 0;
                const isOut = stockQty !== null && stockQty <= 0;
                const isLow =
                  stockQty !== null &&
                  stockQty > 0 &&
                  effectiveReorder > 0 &&
                  stockQty <= effectiveReorder;
                const expStatus = getExpiryStatus(expiryMap?.get(s.variantId) ?? null);

                return (
                  <li
                    key={s.variantId}
                    className={`group relative flex flex-col rounded-xl border bg-white transition-all ${
                      inCartQty > 0
                        ? "border-brand-500 shadow-sm ring-1 ring-brand-500/40"
                        : "border-slate-200/90 shadow-2xs hover:border-slate-300 hover:shadow-xs"
                    }`}
                  >
                    <button
                      type="button"
                      data-testid={`product-${s.sku}`}
                      onClick={() => add(s)}
                      className="flex flex-1 cursor-pointer flex-col justify-between gap-3 p-3.5 text-left focus:outline-none"
                    >
                      <div className="flex w-full items-start justify-between gap-2 pr-6">
                        <ProductThumb
                          photoPath={s.photoPath}
                          name={s.name}
                          size="md"
                          active={inCartQty > 0}
                        />
                        <div className="flex flex-wrap items-center justify-end gap-1">
                          {expStatus === "expired" ? (
                            <Badge tone="danger">{t("sell.expiredBadge")}</Badge>
                          ) : expStatus === "expiring_soon" ? (
                            <Badge tone="warn">{t("sell.expiringSoonBadge")}</Badge>
                          ) : null}
                          {inCartQty > 0 ? <Badge tone="good">×{inCartQty}</Badge> : null}
                        </div>
                      </div>

                      <div className="min-w-0">
                        <div className="line-clamp-2 text-sm leading-snug font-semibold text-slate-900">
                          {s.name}
                        </div>
                        <div className="mt-0.5 truncate font-mono text-xs text-slate-400">{s.sku}</div>
                      </div>

                      <div className="flex w-full items-baseline justify-between gap-2 pt-1">
                        <span className="text-base font-semibold text-slate-900 tabular-nums">{fmt(s.price)}</span>
                        {stockQty !== null ? (
                          isOut ? (
                            <Badge tone="danger">{t("sell.outOfStock")}</Badge>
                          ) : isLow ? (
                            <Badge tone="warn">{t("sell.lowStock", { qty: stockQty })}</Badge>
                          ) : (
                            <span className="text-xs text-slate-400 tabular-nums">
                              {t("sell.stockLeft", { qty: stockQty })}
                            </span>
                          )
                        ) : null}
                      </div>
                    </button>

                    <button
                      type="button"
                      data-testid={`pin-toggle-${s.sku}`}
                      title={pinned ? t("sell.unpinFromFastKeys") : t("sell.pinToFastKeys")}
                      aria-label={pinned ? t("sell.unpinFromFastKeys") : t("sell.pinToFastKeys")}
                      onClick={() => togglePin(s.sku)}
                      className={`absolute top-2.5 right-2.5 flex h-6.5 w-6.5 cursor-pointer items-center justify-center rounded-md text-xs transition-all ${
                        pinned
                          ? "bg-amber-50 text-amber-500 hover:bg-amber-100"
                          : "text-slate-300 opacity-0 group-hover:opacity-100 focus:opacity-100 hover:bg-slate-100 hover:text-slate-600"
                      }`}
                    >
                      ★
                    </button>
                  </li>
                );
              })}
            </ul>
          ) : null}
        </div>
      </section>

      {/* RIGHT TERMINAL: Clean Focused POS Order Register */}
      <aside
        className="flex min-h-0 flex-col border-t border-slate-200/90 bg-white lg:border-t-0 lg:border-l"
        data-testid="cart"
      >
        <div className="grid gap-2.5 border-b border-slate-100 px-4 py-3">
          <div className="flex items-center justify-between gap-2">
            <div className="flex items-center gap-2">
              <h2 className="text-sm font-semibold text-slate-900">{t("sell.cart")}</h2>
              {totalOrderUnits > 0 ? (
                <Badge tone="neutral">{t("sell.itemsInOrder", { count: totalOrderUnits })}</Badge>
              ) : null}
            </div>
            <div className="flex items-center gap-1.5">
              {heldOrders.length > 0 ? (
                <Button
                  variant="outline"
                  size="sm"
                  data-testid="held-orders-btn"
                  onClick={() => setShowHeldListDialog(true)}
                  className="border-brand-200 bg-brand-50/70 text-brand-700 hover:bg-brand-100/80"
                >
                  <PauseCircle size={14} className="text-brand-600" aria-hidden />
                  <span>{t("sell.heldOrdersBtn", { count: heldOrders.length })}</span>
                </Button>
              ) : null}
              {cart.length > 0 ? (
                <>
                  <Button
                    variant="outline"
                    size="sm"
                    data-testid="hold-order-btn"
                    title="F6"
                    onClick={openHoldDialog}
                  >
                    <PauseCircle size={14} className="text-slate-500" aria-hidden />
                    <span>{t("sell.holdOrder")}</span>
                  </Button>
                  <Button variant="ghost" size="sm" onClick={reset} aria-label={t("sell.clear")}>
                    <Trash2 size={14} className="text-slate-400" aria-hidden />
                  </Button>
                </>
              ) : null}
            </div>
          </div>

          <div className="flex items-center gap-2">
            <Select
              aria-label={t("sell.customer")}
              data-testid="customer"
              value={customerId}
              onChange={(e) => setCustomerId(e.target.value)}
              className="h-8.5 flex-1 text-xs"
            >
              <option value="">{method === "utang" ? t("sell.chooseCustomer") : t("sell.noCustomer")}</option>
              {(customers.data ?? []).map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </Select>
            {!showNew ? (
              <Button
                variant="outline"
                size="sm"
                data-testid="new-customer"
                onClick={() => setShowNew(true)}
                title={t("sell.newCustomer")}
              >
                <UserPlus size={14} className="text-slate-500" aria-hidden />
                <span className="sr-only sm:not-sr-only">{t("sell.newCustomer")}</span>
              </Button>
            ) : null}
          </div>

          {showNew ? (
            <div className="grid gap-2 rounded-xl border border-slate-200/80 bg-slate-50 p-3">
              <Input
                data-testid="new-customer-name"
                placeholder={t("sell.customerName")}
                value={newName}
                maxLength={80}
                onChange={(e) => setNewName(e.target.value)}
                className="h-8.5 text-xs"
              />
              <Input
                placeholder={t("sell.customerPhone")}
                value={newPhone}
                maxLength={32}
                onChange={(e) => setNewPhone(e.target.value)}
                className="h-8.5 text-xs"
              />
              <div className="flex gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  data-testid="save-customer"
                  disabled={newName.trim() === "" || addCustomer.isPending}
                  onClick={() => addCustomer.mutate()}
                >
                  {t("sell.addCustomer")}
                </Button>
                <Button size="sm" variant="ghost" onClick={() => setShowNew(false)}>
                  {t("sell.cancel")}
                </Button>
              </div>
            </div>
          ) : null}
        </div>

        {/* Scrollable Ticket Line Items */}
        <div className="min-h-[140px] flex-1 overflow-y-auto px-4 py-2.5">
          {expiredCartCount > 0 ? (
            <div
              data-testid="cart-expiry-warning"
              className="mb-2.5 rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-xs font-medium text-amber-900"
            >
              {t("sell.cartExpiryWarning", { count: expiredCartCount })}
            </div>
          ) : null}
          {cart.length === 0 ? (
            <div className="flex h-full flex-col items-center justify-center gap-2 py-8 text-center">
              <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-slate-100 text-slate-400">
                <ShoppingBag size={20} aria-hidden />
              </div>
              <p className="text-sm font-semibold text-slate-700">{t("sell.emptyCart")}</p>
              <p className="max-w-[240px] text-xs text-slate-400">{t("sell.emptyCartHint")}</p>
            </div>
          ) : (
            <ul className="divide-y divide-slate-100">
              {cart.map((l) => {
                const lineDisc = l.discount ?? 0;
                const gross = lineGrossTotal(l.qty, l.unitPrice);
                const net = lineTotal(l.qty, l.unitPrice, lineDisc);
                const isPriceChanged = l.catalogPrice !== undefined && l.unitPrice !== l.catalogPrice;
                const isEditing = editingVariantId === l.variantId;
                return (
                  <li key={l.variantId} className="grid gap-1.5 py-2.5 first:pt-0 last:pb-0">
                    <div className="flex items-baseline justify-between gap-2">
                      <span className="truncate text-sm font-semibold text-slate-900">{l.name}</span>
                      <span className="flex items-baseline gap-1.5 tabular-nums">
                        {lineDisc > 0 ? (
                          <span className="text-xs text-slate-400 line-through">{fmt(gross)}</span>
                        ) : null}
                        <span className="text-sm font-semibold text-slate-900">{fmt(net)}</span>
                      </span>
                    </div>
                    <div className="flex items-center justify-between gap-2">
                      <div className="flex flex-wrap items-center gap-1.5">
                        <button
                          type="button"
                          data-testid={`edit-line-${l.variantId}`}
                          title={t("sell.editLine")}
                          aria-label={t("sell.editLine")}
                          onClick={() => openLineEditor(l)}
                          className={`inline-flex cursor-pointer items-center gap-1 rounded-md border px-1.5 py-0.5 text-xs tabular-nums transition-colors ${
                            isEditing || isPriceChanged || lineDisc > 0
                              ? "border-brand-200 bg-brand-50 font-medium text-brand-700"
                              : "border-transparent text-slate-500 hover:border-slate-200 hover:bg-slate-50 hover:text-slate-700"
                          }`}
                        >
                          <Tag size={11} aria-hidden />
                          <span>{fmt(l.unitPrice)}</span>
                          {lineDisc > 0 ? (
                            <span className="text-emerald-700">(-{fmt(lineDisc)})</span>
                          ) : null}
                        </button>
                      </div>
                      <div className="flex items-center gap-1">
                        <button
                          type="button"
                          aria-label={`Decrease ${l.name}`}
                          onClick={() => stepCartQty(l.variantId, -1)}
                          className="flex h-7 w-7 cursor-pointer items-center justify-center rounded-md border border-slate-200 bg-white text-slate-600 hover:bg-slate-50"
                        >
                          <Minus size={13} aria-hidden />
                        </button>
                        <Input
                          aria-label={t("sell.qty")}
                          data-testid={`qty-${l.variantId}`}
                          inputMode="decimal"
                          value={String(l.qty)}
                          onChange={(e) => setQty(l.variantId, e.target.value)}
                          className="h-7 w-14 px-1.5 py-0.5 text-center text-xs tabular-nums"
                        />
                        <button
                          type="button"
                          aria-label={`Increase ${l.name}`}
                          onClick={() => stepCartQty(l.variantId, 1)}
                          className="flex h-7 w-7 cursor-pointer items-center justify-center rounded-md border border-slate-200 bg-white text-slate-600 hover:bg-slate-50"
                        >
                          <Plus size={13} aria-hidden />
                        </button>
                        <button
                          type="button"
                          aria-label={t("sell.remove")}
                          onClick={() => {
                            clearApproval();
                            if (editingVariantId === l.variantId) setEditingVariantId(null);
                            setCart((c) => c.filter((x) => x.variantId !== l.variantId));
                          }}
                          className="ml-1 flex h-7 w-7 cursor-pointer items-center justify-center rounded-md text-slate-400 hover:bg-red-50 hover:text-red-600"
                        >
                          <X size={14} aria-hidden />
                        </button>
                      </div>
                    </div>

                    {isPriceChanged && !isEditing && l.catalogPrice !== undefined ? (
                      <div className="text-[11px] text-amber-700">
                        {t("sell.priceOverridden", { catalog: fmt(l.catalogPrice) })}
                      </div>
                    ) : null}

                    {isEditing ? (
                      <div
                        data-testid={`line-editor-${l.variantId}`}
                        className="mt-1 grid gap-2 rounded-lg border border-slate-200 bg-slate-50/90 p-2.5 text-xs"
                      >
                        <div className="grid grid-cols-2 gap-2">
                          <label className="grid gap-1 text-slate-600">
                            <span className="font-medium">{t("sell.unitPrice")}</span>
                            <Input
                              data-testid={`line-price-${l.variantId}`}
                              inputMode="decimal"
                              value={linePriceText}
                              onChange={(e) => applyLinePriceText(l.variantId, e.target.value)}
                              className="h-7.5 bg-white text-right text-xs tabular-nums"
                            />
                          </label>
                          <label className="grid gap-1 text-slate-600">
                            <span className="font-medium">{t("sell.lineDiscount")}</span>
                            <Input
                              data-testid={`line-discount-${l.variantId}`}
                              inputMode="decimal"
                              placeholder="0.00"
                              value={lineDiscText}
                              onChange={(e) => applyLineDiscText(l.variantId, e.target.value)}
                              className="h-7.5 bg-white text-right text-xs tabular-nums"
                            />
                          </label>
                        </div>
                        <div className="flex items-center justify-between gap-2 pt-0.5">
                          {isPriceChanged || lineDisc > 0 ? (
                            <Button
                              size="sm"
                              variant="ghost"
                              data-testid={`reset-line-${l.variantId}`}
                              onClick={() => resetLinePricing(l)}
                              className="h-7 px-2 text-xs"
                            >
                              {t("sell.resetLinePricing")}
                            </Button>
                          ) : (
                            <span />
                          )}
                          <Button
                            size="sm"
                            variant="outline"
                            data-testid={`close-line-${l.variantId}`}
                            onClick={() => setEditingVariantId(null)}
                            className="h-7 px-2.5 text-xs"
                          >
                            {t("sell.applyLinePricing")}
                          </Button>
                        </div>
                      </div>
                    ) : null}
                  </li>
                );
              })}
            </ul>
          )}
        </div>

        {/* Pinned Register Checkout & Tender Pad */}
        <div className="grid gap-3 border-t border-slate-200/90 bg-slate-50/70 px-4 py-3.5 text-sm">
          <div className="grid gap-1.5">
            {lineDiscounts > 0 ? (
              <div className="flex items-baseline justify-between text-xs text-emerald-700">
                <span>{t("sell.lineDiscountsTotal")}</span>
                <span className="font-medium tabular-nums">-{fmt(lineDiscounts)}</span>
              </div>
            ) : null}
            <div className="flex items-baseline justify-between text-xs text-slate-500">
              <span>{t("sell.subtotal")}</span>
              <span className="tabular-nums">{fmt(subtotal)}</span>
            </div>
            <label className="flex items-center justify-between gap-2 text-xs text-slate-500">
              <span className="flex items-center gap-1.5">
                <span>{t("sell.discount")}</span>
                <kbd className="rounded bg-slate-200/60 px-1 font-mono text-xs text-slate-500">F4</kbd>
              </span>
              <Input
                ref={discountInputRef}
                className="h-7.5 w-24 bg-white text-right text-xs tabular-nums"
                data-testid="discount"
                inputMode="decimal"
                placeholder="0.00"
                value={discountText}
                onChange={(e) => {
                  clearApproval();
                  setDiscountText(e.target.value);
                }}
              />
            </label>
            <div
              className="flex items-baseline justify-between border-t border-slate-200/80 pt-2 text-lg font-semibold text-slate-900 tabular-nums"
              data-testid="cart-total"
            >
              <span>{t("sell.total")}</span>
              <span>{fmt(total)}</span>
            </div>
          </div>

          <div className="grid gap-2">
            {splitTenders.length > 0 ? (
              <div
                data-testid="split-tenders-list"
                className="grid gap-1.5 rounded-lg border border-brand-200 bg-white px-3 py-2 text-xs shadow-2xs"
              >
                <div className="flex items-center justify-between">
                  <span className="font-semibold tracking-wider text-slate-500 uppercase">
                    {t("sell.splitTendersLabel")}
                  </span>
                  <button
                    type="button"
                    data-testid="clear-split-tenders"
                    onClick={() => setSplitTenders([])}
                    className="cursor-pointer text-xs font-medium text-slate-500 hover:text-slate-800"
                  >
                    {t("sell.splitClearAll")}
                  </button>
                </div>
                {splitTenders.map((sp, idx) => (
                  <div
                    key={`${sp.method}-${idx}`}
                    data-testid={`split-line-${idx}`}
                    className="flex items-center justify-between gap-2 border-t border-slate-100 pt-1.5"
                  >
                    <span className="truncate font-medium text-slate-700">
                      {sp.method === "ewallet" && sp.wallet
                        ? `${t("sell.ewallet")} (${t(`sell.wallets.${sp.wallet}`)})`
                        : sp.method === "card"
                          ? `${t("sell.card")}${sp.reference ? ` · ${sp.reference}` : ""}`
                          : t(`sell.${sp.method}`)}
                    </span>
                    <div className="flex items-center gap-1.5">
                      <span className="font-semibold text-slate-900 tabular-nums">{fmt(sp.amount)}</span>
                      <button
                        type="button"
                        aria-label={t("sell.splitRemove")}
                        data-testid={`remove-split-${idx}`}
                        onClick={() => removeSplitTender(idx)}
                        className="cursor-pointer rounded p-0.5 text-slate-400 hover:bg-slate-100 hover:text-red-600"
                      >
                        <X size={13} aria-hidden />
                      </button>
                    </div>
                  </div>
                ))}
                <div className="flex items-baseline justify-between border-t border-brand-100 pt-1.5 text-brand-700">
                  <span className="font-semibold">{t("sell.splitRemaining")}</span>
                  <span className="text-sm font-semibold tabular-nums" data-testid="split-remaining">
                    {fmt(remainingDue)}
                  </span>
                </div>
              </div>
            ) : null}

            {splitExceeded ? <Alert>{t("sell.splitExceeded")}</Alert> : null}

            <select
              ref={payMethodSelectRef}
              aria-label={t("sell.payment")}
              data-testid="pay-method"
              value={method}
              onChange={(e) => setMethod(e.target.value as PayMethod)}
              className="sr-only"
            >
              <option value="cash">{t("sell.cash")}</option>
              <option value="ewallet">{t("sell.ewallet")}</option>
              <option value="card">{t("sell.card")}</option>
              <option value="utang">{t("sell.utang")}</option>
            </select>

            {remainingDue > 0 || splitTenders.length === 0 ? (
              <>
                <div className="grid grid-cols-4 gap-1.5" role="group" aria-label={t("sell.payment")}>
                  {(
                    [
                      ["cash", t("sell.cash"), Banknote],
                      ["ewallet", t("sell.ewallet"), Smartphone],
                      ["card", t("sell.card"), CreditCard],
                      ["utang", t("sell.utang"), HandCoins],
                    ] as const
                  ).map(([val, label, Icon]) => {
                    const active = method === val;
                    return (
                      <button
                        key={val}
                        type="button"
                        data-testid={`tender-btn-${val}`}
                        onClick={() => setMethod(val)}
                        className={`flex cursor-pointer flex-col items-center justify-center gap-1 rounded-lg border px-2 py-2 text-xs transition-all ${
                          active
                            ? "border-brand-500 bg-brand-50 font-semibold text-brand-text shadow-2xs"
                            : "border-slate-200/90 bg-white text-slate-600 hover:bg-slate-50 hover:text-slate-900"
                        }`}
                      >
                        <Icon size={15} className={active ? "text-brand-600" : "text-slate-400"} aria-hidden />
                        <span className="truncate">{label}</span>
                      </button>
                    );
                  })}
                </div>

                {method !== "utang" ? (
                  <div className="grid grid-cols-2 gap-2">
                    <label className="grid gap-1 text-xs text-slate-500">
                      <span>{t("sell.paidNow")}</span>
                      <Input
                        className="h-8 bg-white text-right text-xs tabular-nums"
                        data-testid="paid-now"
                        inputMode="decimal"
                        placeholder={fmt(remainingDue)}
                        value={paidText}
                        onChange={(e) => setPaidText(e.target.value)}
                      />
                    </label>

                    {method === "cash" ? (
                      <label className="grid gap-1 text-xs text-slate-500">
                        <span className="flex items-center justify-between">
                          <span>{t("sell.tendered")}</span>
                          <kbd className="rounded bg-slate-200/60 px-1 font-mono text-xs text-slate-500">F8</kbd>
                        </span>
                        <Input
                          ref={tenderedInputRef}
                          className="h-8 bg-white text-right text-xs tabular-nums"
                          data-testid="tendered"
                          inputMode="decimal"
                          placeholder={fmt(cashTarget)}
                          value={tenderedText}
                          onChange={(e) => setTenderedText(e.target.value)}
                        />
                      </label>
                    ) : (
                      <div />
                    )}
                  </div>
                ) : null}

                {method !== "utang" && paidNow !== null && paidNow > 0 && paidNow < remainingDue ? (
                  <Button
                    type="button"
                    size="sm"
                    variant="outline"
                    data-testid="add-split-tender"
                    onClick={addSplitTender}
                    className="h-8 w-full justify-center border-brand-200 bg-brand-50/70 text-xs font-semibold text-brand-700 hover:bg-brand-100/70"
                  >
                    {t("sell.splitAddTender", {
                      method:
                        method === "ewallet"
                          ? t(`sell.wallets.${wallet}`)
                          : t(`sell.${method}`),
                      amount: fmt(paidNow),
                    })}
                  </Button>
                ) : null}
              </>
            ) : null}

            {method === "cash" && cashTarget > 0 ? (
              <div className="flex flex-wrap gap-1.5" data-testid="quick-cash-presets">
                <button
                  type="button"
                  onClick={() => setTenderedText(formatMajorInput(cashTarget))}
                  className="cursor-pointer rounded-md border border-slate-200 bg-white px-2.5 py-1 text-xs font-semibold text-slate-700 transition-colors hover:bg-slate-100 tabular-nums"
                >
                  {t("sell.exactCash")}
                </button>
                {CASH_BILLS_MAJOR.filter((b) => b * 100 >= cashTarget)
                  .slice(0, 4)
                  .map((bill) => (
                    <button
                      key={bill}
                      type="button"
                      onClick={() => setTenderedText(String(bill))}
                      className="cursor-pointer rounded-md border border-slate-200 bg-white px-2.5 py-1 text-xs font-semibold text-slate-700 transition-colors hover:bg-slate-100 tabular-nums"
                    >
                      {fmt(bill * 100)}
                    </button>
                  ))}
              </div>
            ) : null}

            {change > 0 ? (
              <div className="flex items-baseline justify-between rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-2 text-emerald-900">
                <span className="text-xs font-semibold tracking-wider uppercase">{t("sell.change")}</span>
                <span className="text-base font-semibold tabular-nums" data-testid="change">
                  {fmt(change)}
                </span>
              </div>
            ) : null}

            {onUtang > 0 ? (
              <div className="flex items-baseline justify-between rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-amber-900">
                <span className="text-xs font-semibold tracking-wider uppercase">{t("sell.onUtang")}</span>
                <span className="text-sm font-semibold tabular-nums" data-testid="on-utang">
                  {fmt(onUtang)}
                </span>
              </div>
            ) : null}

            {method === "ewallet" ? (
              <div className="grid grid-cols-2 gap-2">
                <Select
                  aria-label={t("sell.wallet")}
                  data-testid="pay-wallet"
                  value={wallet}
                  onChange={(e) => setWallet(e.target.value as Wallet)}
                  className="h-8 bg-white text-xs"
                >
                  {WALLETS.map((w) => (
                    <option key={w} value={w}>
                      {t(`sell.wallets.${w}`)}
                    </option>
                  ))}
                </Select>
                <Input
                  placeholder={t("sell.reference")}
                  value={reference}
                  maxLength={64}
                  onChange={(e) => setReference(e.target.value)}
                  className="h-8 bg-white text-xs"
                />
              </div>
            ) : null}

            {method === "card" ? (
              <Input
                data-testid="pay-card-ref"
                placeholder={t("sell.cardRefPlaceholder")}
                value={reference}
                maxLength={64}
                onChange={(e) => setReference(e.target.value)}
                className="h-8 bg-white text-xs"
              />
            ) : null}
          </div>

          {problem ? <Alert>{problem}</Alert> : null}

          <Button
            data-testid="charge"
            disabled={cart.length === 0 || charge.isPending}
            onClick={handleCharge}
            className="h-11.5 w-full justify-between text-base"
          >
            <span className="tabular-nums">
              {charge.isPending ? t("sell.charging") : t("sell.charge", { total: fmt(total) })}
            </span>
            <kbd className="rounded bg-white/15 px-2 py-0.5 font-mono text-xs text-white">F9</kbd>
          </Button>
        </div>
      </aside>

      <SupervisorPinDialog
        open={showApprovalDialog}
        onOpenChange={setShowApprovalDialog}
        locationId={store.id}
        action="sale_discount"
        refId={attempt.current?.id ?? ""}
        onApproved={(apprId, offlineAppr) => {
          setApprovalId(apprId || null);
          setOfflineApproval(offlineAppr || null);
          charge.mutate({ approvalId: apprId || undefined, offlineApproval: offlineAppr || undefined });
        }}
      />

      <Dialog
        open={showHoldDialog}
        onOpenChange={setShowHoldDialog}
        title={t("sell.holdOrderTitle")}
        closeLabel={t("sell.cancel")}
      >
        <form
          data-testid="hold-order-dialog"
          className="grid gap-4"
          onSubmit={(e) => {
            e.preventDefault();
            confirmHoldOrder();
          }}
        >
          <p className="-mt-2 text-xs text-slate-500">{t("sell.holdOrderDesc")}</p>
          <label className="grid gap-1.5 text-sm">
            <span className="font-medium text-slate-700">{t("sell.holdOrderLabel")}</span>
            <Input
              autoFocus
              data-testid="hold-order-label"
              placeholder={t("sell.holdOrderPlaceholder")}
              maxLength={60}
              value={holdLabel}
              onChange={(e) => setHoldLabel(e.target.value)}
            />
          </label>
          <div className="flex justify-end gap-2">
            <Button type="button" variant="ghost" onClick={() => setShowHoldDialog(false)}>
              {t("sell.cancel")}
            </Button>
            <Button type="submit" data-testid="confirm-hold-order">
              {t("sell.holdOrderConfirm")}
            </Button>
          </div>
        </form>
      </Dialog>

      <Dialog
        open={showHeldListDialog}
        onOpenChange={setShowHeldListDialog}
        title={t("sell.heldOrdersTitle")}
        closeLabel={t("sell.cancel")}
      >
        <div data-testid="held-orders-dialog" className="grid gap-3">
          {cart.length > 0 && heldOrders.length > 0 ? (
            <div className="rounded-lg border border-brand-200 bg-brand-50/70 px-3 py-2 text-xs text-brand-700">
              {t("sell.heldOrderSwapHint")}
            </div>
          ) : null}
          {heldOrders.length === 0 ? (
            <p className="py-6 text-center text-sm text-slate-500">{t("sell.heldOrdersEmpty")}</p>
          ) : (
            <ul className="grid max-h-[380px] gap-2.5 overflow-y-auto pr-0.5">
              {heldOrders.map((h) => {
                const heldDisc = parseAmount(h.discountText, currency) ?? 0;
                const heldTotal = cartTotal(h.lines, heldDisc);
                const heldUnits = h.lines.reduce((s, l) => s + l.qty, 0);
                const timeStr = new Date(h.createdAt).toLocaleTimeString(i18n.language, {
                  hour: "2-digit",
                  minute: "2-digit",
                });
                const titleText =
                  h.label || h.customerName || t("sell.heldOrderUntitled", { time: timeStr });
                return (
                  <li
                    key={h.id}
                    data-testid={`held-order-${h.id}`}
                    className="flex items-center justify-between gap-3 rounded-xl border border-slate-200 bg-slate-50/60 p-3"
                  >
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-2">
                        <span className="truncate text-sm font-semibold text-slate-900">{titleText}</span>
                        <span className="shrink-0 font-mono text-xs text-slate-400">{timeStr}</span>
                      </div>
                      <div className="mt-0.5 truncate text-xs text-slate-500">
                        {h.lines.map((l) => `${l.qty}× ${l.name}`).join(", ")}
                      </div>
                      <div className="mt-1 flex items-center gap-2 text-xs">
                        <span className="font-semibold text-slate-900 tabular-nums">{fmt(heldTotal)}</span>
                        <span className="text-slate-400">·</span>
                        <span className="text-slate-500">{t("sell.itemsInOrder", { count: heldUnits })}</span>
                      </div>
                    </div>
                    <div className="flex shrink-0 items-center gap-1.5">
                      <Button
                        size="sm"
                        data-testid={`resume-held-${h.id}`}
                        onClick={() => handleResumeHeld(h.id)}
                      >
                        <Play size={13} aria-hidden />
                        <span>{t("sell.heldOrderResume")}</span>
                      </Button>
                      <Button
                        size="sm"
                        variant="ghost"
                        aria-label={t("sell.heldOrderDiscard")}
                        data-testid={`discard-held-${h.id}`}
                        onClick={() => handleDiscardHeld(h.id)}
                      >
                        <Trash2 size={14} className="text-slate-400 hover:text-red-600" aria-hidden />
                      </Button>
                    </div>
                  </li>
                );
              })}
            </ul>
          )}
        </div>
      </Dialog>
    </div>
  );
}
