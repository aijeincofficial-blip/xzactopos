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
import { Alert, Badge, Button, Dialog, EmptyState, Input, Select, useToast } from "../components/ui.tsx";
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
import { fetchCustomersWithBalances } from "../lib/utang-api.ts";
import {
  evaluateCustomerCreditStatus,
  filterCustomersForPos,
  isOverdue,
  type CustomerBalanceInput,
} from "../lib/utang-math.ts";
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
  const [mobileCartOpen, setMobileCartOpen] = useState(false);
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
  const customerBalances = useQuery({
    queryKey: ["customers", "balances"],
    queryFn: fetchCustomersWithBalances,
    staleTime: 30_000,
  });
  const [customerQuery, setCustomerQuery] = useState("");
  const todayInStoreTz = useMemo(() => dayInTimezone(access.tenant.timezone), [access.tenant.timezone]);

  const allCustomerBalances = useMemo<CustomerBalanceInput[]>(() => {
    const byId = new Map<string, CustomerBalanceInput>();
    for (const b of customerBalances.data ?? []) {
      byId.set(b.customerId, b);
    }
    for (const c of customers.data ?? []) {
      if (!byId.has(c.id)) {
        byId.set(c.id, {
          customerId: c.id,
          name: c.name,
          phone: c.phone,
          dueOn: null,
          balance: 0,
        });
      }
    }
    return Array.from(byId.values());
  }, [customerBalances.data, customers.data]);

  const filteredCustomerOptions = useMemo(() => {
    const matches = filterCustomersForPos(allCustomerBalances, customerQuery);
    if (customerId && !matches.some((c) => c.customerId === customerId)) {
      const selected = allCustomerBalances.find((c) => c.customerId === customerId);
      if (selected) return [selected, ...matches];
    }
    return matches;
  }, [allCustomerBalances, customerQuery, customerId]);

  const selectedCustomerBalance = useMemo(
    () => (customerId ? allCustomerBalances.find((c) => c.customerId === customerId) ?? null : null),
    [allCustomerBalances, customerId],
  );

  const creditStatus = useMemo(
    () => evaluateCustomerCreditStatus(selectedCustomerBalance, todayInStoreTz, onUtang),
    [selectedCustomerBalance, todayInStoreTz, onUtang],
  );

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

  const categoryCounts = useMemo(() => {
    const counts = new Map<string, number>();
    for (const item of catalog.data ?? []) {
      if (!item.categoryId) continue;
      counts.set(item.categoryId, (counts.get(item.categoryId) ?? 0) + 1);
    }
    return counts;
  }, [catalog.data]);

  const categorySwatchMap = useMemo(() => {
    const tones = [
      "bg-sw-coffee text-sw-coffee-fg",
      "bg-sw-noncoffee text-sw-noncoffee-fg",
      "bg-sw-pastry text-sw-pastry-fg",
      "bg-sw-meal text-sw-meal-fg",
    ] as const;
    const m = new Map<string, (typeof tones)[number]>();
    activeCategories.forEach((cat, idx) => {
      m.set(cat.id, tones[idx % tones.length] ?? tones[0]);
    });
    return m;
  }, [activeCategories]);

  const estimatedVat = useMemo(() => {
    let vat = 0;
    for (const l of cart) {
      if (l.taxRate > 0) {
        const net = lineTotal(l.qty, l.unitPrice, l.discount ?? 0);
        vat += Math.round((net * l.taxRate) / (100 + l.taxRate));
      }
    }
    return vat;
  }, [cart]);

  useEffect(() => {
    if (done || cart.length === 0) {
      setMobileCartOpen(false);
    }
  }, [done, cart.length]);

  const cartQtyByVariant = useMemo(() => {
    const m = new Map<string, number>();
    for (const l of cart) m.set(l.variantId, l.qty);
    return m;
  }, [cart]);

  const totalOrderUnits = useMemo(
    () => cart.reduce((sum, l) => sum + (Number.isFinite(l.qty) && l.qty > 0 ? l.qty : 0), 0),
    [cart],
  );

  const stockMap = useMemo(() => {
    if (!stockQuery.data || !store) return undefined;
    return applyOptimisticStockDeltas(stockQuery.data, store.id, outboxOps);
  }, [stockQuery.data, store, outboxOps]);
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
    setCustomerQuery("");
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
      void qc.invalidateQueries({ queryKey: ["customers"] });
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
      <div className="h-full overflow-y-auto bg-ink text-text-on-dark">
        <div className="mx-auto grid w-full max-w-4xl content-start gap-6 p-4 sm:p-6 md:grid-cols-[1fr_auto]">
          <div
            className="grid gap-6 rounded-[28px] border-[1.5px] border-ink-line bg-ink-2 p-6 text-text-on-dark sm:p-7"
            data-testid="sale-done"
          >
            <div className="flex items-start justify-between gap-3">
              <div className="flex items-center gap-3.5">
                <div
                  className={`flex h-13 w-13 shrink-0 items-center justify-center rounded-full ${
                    done.queuedOffline
                      ? "bg-sw-pastry text-sw-pastry-fg"
                      : "bg-lime text-ink"
                  }`}
                >
                  {done.queuedOffline ? <CloudOff size={24} aria-hidden /> : <CheckCircle2 size={26} aria-hidden />}
                </div>
                <div>
                  <h2 className="font-display text-xl font-extrabold tracking-tight text-text-on-dark sm:text-2xl">
                    {done.queuedOffline ? t("sell.doneOffline") : t("sell.done")}
                  </h2>
                  <div className="mt-0.5 font-mono text-xs text-muted-on-dark">
                    {t("sell.receiptNo")}{" "}
                    <span className="font-semibold text-lime">{done.saleNo ?? done.localNo}</span>
                  </div>
                </div>
              </div>
              <span className="rounded-full border border-ink-line-2 bg-ink px-3 py-1 font-mono text-xs font-semibold text-text-on-dark">
                {store.code}
              </span>
            </div>

            {done.queuedOffline ? (
              <div
                data-testid="offline-sale-banner"
                className="rounded-[16px] border-[1.5px] border-sw-pastry/50 bg-sw-pastry/15 px-4 py-3 text-xs font-medium text-sw-pastry"
              >
                {t("sell.offlineSaleNotice")}
              </div>
            ) : null}

            <div className="grid gap-2 rounded-[20px] border-[1.5px] border-ink-line-2 bg-ink p-5">
              <span className="font-mono text-[11px] font-semibold tracking-wider text-muted-on-dark uppercase">
                {t("sell.total")}
              </span>
              <div className="font-display text-4xl font-extrabold tracking-tight text-lime tabular-nums">
                {fmt(done.total)}
              </div>
              {done.change > 0 ? (
                <div className="mt-2 flex items-baseline justify-between border-t border-dashed border-ink-line-2 pt-3 text-base">
                  <span className="text-muted-on-dark">{t("sell.change")}</span>
                  <span className="font-display text-xl font-extrabold text-lime tabular-nums">{fmt(done.change)}</span>
                </div>
              ) : null}
              {done.onUtang > 0 ? (
                <div className="mt-2 flex items-baseline justify-between border-t border-dashed border-ink-line-2 pt-3 text-sm text-sw-pastry">
                  <span>{t("sell.onUtang")}</span>
                  <span className="font-mono font-semibold tabular-nums">{fmt(done.onUtang)}</span>
                </div>
              ) : null}
            </div>

            <div className="no-print flex flex-col gap-3 sm:flex-row">
              <button
                type="button"
                data-testid="print-receipt-btn"
                onClick={() => window.print()}
                className="inline-flex min-h-[48px] flex-1 cursor-pointer items-center justify-center gap-2 rounded-full border-[1.5px] border-ink-line-2 bg-transparent px-5 text-sm font-semibold text-text-on-dark transition-colors hover:border-text-on-dark hover:bg-ink"
              >
                <Printer size={16} className="text-muted-on-dark" aria-hidden />
                <span>{t("sell.printReceipt")}</span>
              </button>
              <button
                type="button"
                data-testid="new-sale"
                onClick={() => setDone(null)}
                className="inline-flex min-h-[52px] flex-1 cursor-pointer items-center justify-center gap-2 rounded-full bg-lime px-6 font-display text-base font-extrabold text-ink transition-colors hover:bg-lime-hover"
              >
                {t("sell.newSale")}
              </button>
            </div>
          </div>

          {done.receiptData ? (
            <div className="receipt paper-surface rounded-t-[20px] border-[1.5px] border-sand-line bg-paper px-5 pt-5 pb-8 text-text-on-light">
              <ReceiptSlipView receipt={done.receiptData} />
            </div>
          ) : null}
        </div>
      </div>
    );
  }

  const cashTarget = paidNow !== null ? paidNow : remainingDue;

  const chipTone = (categoryId?: string | null) =>
    (categoryId ? categorySwatchMap.get(categoryId) : undefined) ?? "bg-sw-noncoffee text-sw-noncoffee-fg";

  return (
    <div className="relative grid h-full min-h-0 bg-sand lg:grid-cols-[1fr_420px]">
      {/* LEFT TERMINAL: Night Market Catalog & Category Pills */}
      <section className="flex min-h-0 min-w-0 flex-col bg-sand">
        <div className="border-b-[1.5px] border-sand-line bg-paper px-4 py-3">
          <div className="flex flex-wrap items-center gap-2.5 sm:flex-nowrap">
            <div className="relative min-w-0 flex-1 basis-48">
              <Search
                size={17}
                className="pointer-events-none absolute top-1/2 left-3.5 -translate-y-1/2 text-muted-on-light"
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
                className="h-11 rounded-[14px] border-sand-line bg-sand pr-24 pl-10 text-sm focus:bg-paper"
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
                    className="rounded-full p-1 text-muted-on-light hover:bg-sand hover:text-ink"
                  >
                    <X size={14} aria-hidden />
                  </button>
                ) : null}
                <span className="pointer-events-none hidden items-center gap-1 rounded-full border border-sand-line bg-paper px-2 py-0.5 text-[11px] text-muted-on-light sm:inline-flex">
                  <ScanBarcode size={12} aria-hidden />
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
                className={`inline-flex min-h-[36px] shrink-0 cursor-pointer items-center gap-1.5 rounded-full border-[1.5px] px-3 py-1.5 font-mono text-xs font-semibold transition-colors disabled:cursor-default ${
                  failedOutboxCount > 0
                    ? "border-sw-meal-fg/30 bg-sw-meal text-sw-meal-fg hover:opacity-90"
                    : !online
                      ? "border-ink bg-ink text-text-on-dark"
                      : "border-ink bg-lime text-ink hover:bg-lime-hover"
                }`}
              >
                {!online ? (
                  <CloudOff size={14} className="text-lime" aria-hidden />
                ) : (
                  <RefreshCw size={14} className={syncingOutbox ? "animate-spin" : ""} aria-hidden />
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
              className="hidden shrink-0 items-center gap-1.5 rounded-full border border-sand-line bg-sand px-3 py-1.5 text-xs text-muted-on-light xl:inline-flex"
              data-testid="pos-shortcuts-hint"
              title={t("sell.shortcutsHint")}
            >
              <Keyboard size={14} aria-hidden />
              <span className="font-mono text-[11px]">Alt+1–6 · F4 · F6 · F8 · F9</span>
            </span>
          </div>

          {/* Category & Quick Keys Filter Pills */}
          <div className="mt-2.5 flex items-center gap-1.5 overflow-x-auto overflow-y-hidden pb-0.5 [scrollbar-width:none]">
            <button
              type="button"
              data-testid="pos-cat-all"
              onClick={() => setActiveFilter("all")}
              className={`inline-flex min-h-[34px] shrink-0 cursor-pointer items-center gap-1.5 rounded-full border-[1.5px] px-3.5 py-1 text-xs font-semibold transition-colors ${
                activeFilter === "all"
                  ? "border-ink bg-ink text-text-on-dark"
                  : "border-sand-line bg-paper text-text-on-light hover:border-ink"
              }`}
            >
              <span>{t("sell.allItems")}</span>
              <span className="font-mono text-[11px] opacity-70">{(catalog.data ?? []).length}</span>
            </button>
            <button
              type="button"
              data-testid="pos-cat-pinned"
              onClick={() => setActiveFilter("pinned")}
              className={`inline-flex min-h-[34px] shrink-0 cursor-pointer items-center gap-1.5 rounded-full border-[1.5px] px-3.5 py-1 text-xs font-semibold transition-colors ${
                activeFilter === "pinned"
                  ? "border-ink bg-ink text-text-on-dark"
                  : "border-sand-line bg-paper text-text-on-light hover:border-ink"
              }`}
            >
              <Star size={12} className={activeFilter === "pinned" ? "text-lime" : "text-sw-pastry-fg"} aria-hidden />
              <span>{t("sell.pinnedTab")}</span>
              <span className="font-mono text-[11px] opacity-70">{fastKeyProducts.length}</span>
            </button>
            {activeCategories.map((cat) => (
              <button
                key={cat.id}
                type="button"
                data-testid={`pos-cat-${cat.id}`}
                onClick={() => setActiveFilter(cat.id)}
                className={`inline-flex min-h-[34px] shrink-0 cursor-pointer items-center gap-1.5 rounded-full border-[1.5px] px-3.5 py-1 text-xs font-semibold transition-colors ${
                  activeFilter === cat.id
                    ? "border-ink bg-ink text-text-on-dark"
                    : "border-sand-line bg-paper text-text-on-light hover:border-ink"
                }`}
              >
                <span>{cat.name}</span>
                <span className="font-mono text-[11px] opacity-70">{categoryCounts.get(cat.id) ?? 0}</span>
              </button>
            ))}
          </div>
        </div>

        {/* Scrollable Product Canvas */}
        <div className="grid flex-1 content-start gap-3.5 overflow-y-auto p-3.5 sm:p-4">
          {/* Compact Fast-Keys Pill Strip (Alt+1..6) */}
          {activeFilter === "all" &&
          search.trim() === "" &&
          (fastKeyProducts.length > 0 || (customPinned !== null && customPinned.length === 0)) ? (
            <div data-testid="fast-keys-bar" className="flex items-center gap-2 overflow-x-auto pb-0.5 [scrollbar-width:none]">
              <span className="shrink-0 font-mono text-[11px] font-semibold tracking-wider text-muted-on-light uppercase">
                {t("sell.fastKeys")}
              </span>
              {fastKeyProducts.length === 0 ? (
                <span className="text-xs text-muted-on-light">{t("sell.fastKeysEmpty")}</span>
              ) : (
                fastKeyProducts.map((s, idx) => (
                  <button
                    key={s.variantId}
                    type="button"
                    data-testid={`fast-key-${s.sku}`}
                    onClick={() => add(s)}
                    className="inline-flex min-h-[34px] shrink-0 cursor-pointer items-center gap-2 rounded-full border-[1.5px] border-sand-line bg-paper px-3 py-1 text-xs transition-colors hover:border-ink"
                  >
                    {idx < 6 ? (
                      <kbd className="rounded-full bg-sand px-2 py-0.5 font-mono text-[11px] font-semibold text-ink">
                        Alt+{idx + 1}
                      </kbd>
                    ) : null}
                    <span className="max-w-[140px] truncate font-semibold text-text-on-light">{s.name}</span>
                    <span className="font-mono font-semibold text-muted-on-light tabular-nums">{fmt(s.price)}</span>
                  </button>
                ))
              )}
            </div>
          ) : null}

          {catalog.isPending ? (
            <ul className="grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-5">
              {Array.from({ length: 10 }).map((_, i) => (
                <li key={i} className="h-32 animate-pulse rounded-[20px] border-[1.5px] border-sand-line bg-paper" />
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
                    className={`group relative flex flex-col rounded-[20px] border-[1.5px] transition-colors ${
                      inCartQty > 0
                        ? "border-ink bg-paper ring-1 ring-ink"
                        : "border-sand-line bg-paper hover:border-ink"
                    }`}
                  >
                    <button
                      type="button"
                      data-testid={`product-${s.sku}`}
                      onClick={() => add(s)}
                      className="flex flex-1 cursor-pointer flex-col justify-between gap-2.5 p-3.5 text-left focus:outline-none"
                    >
                      <div className="flex w-full items-start justify-between gap-2 pr-6">
                        <div className="relative">
                          <ProductThumb
                            photoPath={s.photoPath}
                            name={s.name}
                            size="md"
                            active={inCartQty > 0}
                          />
                          {s.categoryId ? (
                            <span
                              className={`-bottom-1 -right-1 absolute h-3.5 w-3.5 rounded-full border-2 border-paper ${chipTone(s.categoryId)}`}
                              aria-hidden
                            />
                          ) : null}
                        </div>
                        <div className="flex flex-wrap items-center justify-end gap-1">
                          {expStatus === "expired" ? (
                            <Badge tone="danger">{t("sell.expiredBadge")}</Badge>
                          ) : expStatus === "expiring_soon" ? (
                            <Badge tone="warn">{t("sell.expiringSoonBadge")}</Badge>
                          ) : null}
                          {inCartQty > 0 ? (
                            <span className="rounded-full bg-lime px-2.5 py-0.5 font-mono text-xs font-extrabold text-ink tabular-nums">
                              ×{inCartQty}
                            </span>
                          ) : null}
                        </div>
                      </div>

                      <div className="min-w-0">
                        <div className="font-display line-clamp-2 text-sm leading-snug font-bold text-text-on-light">
                          {s.name}
                        </div>
                        <div className="mt-0.5 truncate font-mono text-[11px] text-muted-on-light">{s.sku}</div>
                      </div>

                      <div className="flex w-full items-baseline justify-between gap-2 pt-1">
                        <span className="font-mono text-base font-bold text-text-on-light tabular-nums">
                          {fmt(s.price)}
                        </span>
                        {stockQty !== null ? (
                          isOut ? (
                            <span className="rounded-full bg-ink px-2 py-0.5 font-mono text-[11px] font-semibold text-text-on-dark">
                              {t("sell.outOfStock")}
                            </span>
                          ) : isLow ? (
                            <span className="rounded-full bg-sw-meal px-2 py-0.5 font-mono text-[11px] font-semibold text-sw-meal-fg">
                              {t("sell.lowStock", { qty: stockQty })}
                            </span>
                          ) : (
                            <span className="font-mono text-[11px] text-muted-on-light tabular-nums">
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
                      className={`absolute top-2.5 right-2.5 flex h-7 w-7 cursor-pointer items-center justify-center rounded-full text-xs transition-all ${
                        pinned
                          ? "bg-sw-pastry text-sw-pastry-fg hover:opacity-90"
                          : "text-muted-on-light/50 opacity-0 group-hover:opacity-100 focus:opacity-100 hover:bg-sand hover:text-ink"
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

        {/* MOBILE (<1024px) Sticky Bottom Charge Bar */}
        <div className="flex shrink-0 items-center justify-between gap-3 border-t border-ink-line bg-ink px-4 py-2.5 text-text-on-dark lg:hidden">
          <div className="min-w-0">
            <div className="font-mono text-[11px] text-muted-on-dark">
              {totalOrderUnits > 0 ? t("sell.itemsInOrder", { count: totalOrderUnits }) : t("sell.cart")}
            </div>
            <div className="font-display text-lg font-extrabold text-lime tabular-nums">{fmt(total)}</div>
          </div>
          <div className="flex shrink-0 items-center gap-2">
            {heldOrders.length > 0 ? (
              <button
                type="button"
                onClick={() => setShowHeldListDialog(true)}
                className="min-h-[40px] cursor-pointer rounded-full border border-ink-line-2 bg-ink-2 px-3.5 text-xs font-semibold text-text-on-dark"
              >
                {t("sell.heldOrdersBtn", { count: heldOrders.length })}
              </button>
            ) : null}
            <button
              type="button"
              onClick={() => setMobileCartOpen(true)}
              className="inline-flex min-h-[44px] cursor-pointer items-center gap-2 rounded-full bg-lime px-5 font-display text-sm font-extrabold text-ink transition-colors hover:bg-lime-hover"
            >
              <span>{t("sell.reviewOrder")}</span>
              <span className="font-mono text-xs">{fmt(total)}</span>
            </button>
          </div>
        </div>
      </section>

      {/* RIGHT TERMINAL: Night Market --ink Panel + Torn-Edge Receipt Ticket */}
      <aside
        className={`${
          mobileCartOpen ? "fixed inset-0 z-40 flex" : "hidden lg:flex"
        } min-h-0 flex-col border-ink-line bg-ink text-text-on-dark lg:border-l-[1.5px]`}
        data-testid="cart"
      >
        <div className="flex min-h-0 flex-1 flex-col px-3 pt-3">
          <div className="receipt paper-surface flex min-h-0 flex-1 flex-col rounded-t-[20px] bg-paper px-4 pt-3.5 pb-6 text-text-on-light">
            {/* Receipt Ticket Header */}
            <div className="grid gap-2.5 border-b-[1.5px] border-dashed border-dash pb-3">
              <div className="flex items-center justify-between gap-2">
                <div className="flex min-w-0 items-center gap-2">
                  {mobileCartOpen ? (
                    <button
                      type="button"
                      onClick={() => setMobileCartOpen(false)}
                      className="inline-flex min-h-[30px] cursor-pointer items-center gap-1 rounded-full border border-sand-line bg-sand px-2.5 text-xs font-semibold text-ink lg:hidden"
                    >
                      <X size={13} aria-hidden />
                      <span>{t("sell.backToCatalog")}</span>
                    </button>
                  ) : null}
                  <h2 className="font-display truncate text-base font-extrabold text-ink">
                    {t("sell.orderHeader")}
                  </h2>
                  {totalOrderUnits > 0 ? (
                    <span className="rounded-full bg-ink px-2.5 py-0.5 font-mono text-[11px] font-bold text-lime tabular-nums">
                      {totalOrderUnits}
                    </span>
                  ) : null}
                </div>
                <div className="flex shrink-0 items-center gap-1.5">
                  {heldOrders.length > 0 ? (
                    <button
                      type="button"
                      data-testid="held-orders-btn"
                      onClick={() => setShowHeldListDialog(true)}
                      className="inline-flex min-h-[30px] cursor-pointer items-center gap-1 rounded-full bg-lime px-2.5 font-mono text-[11px] font-bold text-ink transition-colors hover:bg-lime-hover"
                    >
                      <PauseCircle size={13} aria-hidden />
                      <span>{t("sell.heldOrdersBtn", { count: heldOrders.length })}</span>
                    </button>
                  ) : null}
                  {cart.length > 0 ? (
                    <>
                      <button
                        type="button"
                        data-testid="hold-order-btn"
                        title="F6"
                        onClick={openHoldDialog}
                        className="inline-flex min-h-[30px] cursor-pointer items-center gap-1 rounded-full border-[1.5px] border-sand-line bg-paper px-2.5 text-xs font-semibold text-ink transition-colors hover:border-ink"
                      >
                        <PauseCircle size={13} aria-hidden />
                        <span>{t("sell.holdOrder")}</span>
                      </button>
                      <button
                        type="button"
                        onClick={reset}
                        aria-label={t("sell.clear")}
                        className="inline-flex h-7.5 w-7.5 cursor-pointer items-center justify-center rounded-full text-muted-on-light transition-colors hover:bg-sw-meal hover:text-sw-meal-fg"
                      >
                        <Trash2 size={14} aria-hidden />
                      </button>
                    </>
                  ) : null}
                </div>
              </div>

              <div className="grid gap-1.5">
                {allCustomerBalances.length >= 4 || customerQuery.trim() !== "" ? (
                  <div className="relative">
                    <Search
                      size={13}
                      className="pointer-events-none absolute top-1/2 left-2.5 -translate-y-1/2 text-muted-on-light"
                      aria-hidden
                    />
                    <Input
                      data-testid="customer-search"
                      value={customerQuery}
                      onChange={(e) => setCustomerQuery(e.target.value)}
                      placeholder={t("sell.customerSearchPlaceholder")}
                      className="h-8 min-h-[32px] rounded-[12px] bg-sand pr-7 pl-7 text-xs"
                    />
                    {customerQuery ? (
                      <button
                        type="button"
                        aria-label={t("sell.cancel")}
                        onClick={() => setCustomerQuery("")}
                        className="absolute top-1/2 right-2 -translate-y-1/2 cursor-pointer text-muted-on-light hover:text-ink"
                      >
                        <X size={12} />
                      </button>
                    ) : null}
                  </div>
                ) : null}

                <div className="flex items-center gap-2">
                  <Select
                    aria-label={t("sell.customer")}
                    data-testid="customer"
                    value={customerId}
                    onChange={(e) => setCustomerId(e.target.value)}
                    className="h-9 min-h-[36px] flex-1 rounded-[12px] bg-sand text-xs"
                  >
                    <option value="">{method === "utang" ? t("sell.chooseCustomer") : t("sell.noCustomer")}</option>
                    {filteredCustomerOptions.map((c) => {
                      const overdue = isOverdue(c.balance, c.dueOn, todayInStoreTz);
                      return (
                        <option key={c.customerId} value={c.customerId}>
                          {c.name}
                          {c.balance > 0
                            ? ` · ${fmt(c.balance)}${overdue ? ` (${t("utang.overdue")})` : ""}`
                            : ""}
                        </option>
                      );
                    })}
                  </Select>
                  {!showNew ? (
                    <button
                      type="button"
                      data-testid="new-customer"
                      onClick={() => setShowNew(true)}
                      title={t("sell.newCustomer")}
                      className="inline-flex h-9 shrink-0 cursor-pointer items-center gap-1.5 rounded-[12px] border-[1.5px] border-sand-line bg-paper px-2.5 text-xs font-semibold text-ink transition-colors hover:border-ink"
                    >
                      <UserPlus size={14} aria-hidden />
                      <span className="sr-only sm:not-sr-only">{t("sell.newCustomer")}</span>
                    </button>
                  ) : null}
                </div>

                {customerQuery.trim() !== "" && filteredCustomerOptions.length === 0 ? (
                  <p className="text-[11px] text-muted-on-light">{t("sell.customerNoMatch")}</p>
                ) : null}

                {creditStatus.hasBalance ? (
                  <div
                    data-testid={creditStatus.overdue ? "customer-overdue-warning" : "customer-balance-pill"}
                    className={`rounded-[12px] border-[1.5px] px-2.5 py-1.5 text-xs ${
                      creditStatus.overdue
                        ? "border-sw-meal-fg/30 bg-sw-meal text-sw-meal-fg"
                        : "border-sw-pastry-fg/30 bg-sw-pastry text-sw-pastry-fg"
                    }`}
                  >
                    <div className="font-semibold tabular-nums">
                      {creditStatus.overdue
                        ? t("sell.customerOverdueWarning", {
                            amount: fmt(creditStatus.currentBalance),
                            due: creditStatus.dueOn ?? "",
                          })
                        : t("sell.customerOwesInfo", {
                            amount: fmt(creditStatus.currentBalance),
                          })}
                    </div>
                    {onUtang > 0 ? (
                      <div className="mt-0.5 font-mono text-[11px] opacity-90 tabular-nums">
                        {t("sell.customerProjectedUtang", {
                          amount: fmt(creditStatus.projectedBalance),
                        })}
                      </div>
                    ) : null}
                  </div>
                ) : null}
              </div>

              {showNew ? (
                <div className="grid gap-2 rounded-[16px] border-[1.5px] border-sand-line bg-sand p-3">
                  <Input
                    data-testid="new-customer-name"
                    placeholder={t("sell.customerName")}
                    value={newName}
                    maxLength={80}
                    onChange={(e) => setNewName(e.target.value)}
                    className="h-9 min-h-[36px] text-xs"
                  />
                  <Input
                    placeholder={t("sell.customerPhone")}
                    value={newPhone}
                    maxLength={32}
                    onChange={(e) => setNewPhone(e.target.value)}
                    className="h-9 min-h-[36px] text-xs"
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
            <div className="min-h-[110px] flex-1 overflow-y-auto py-2.5">
              {expiredCartCount > 0 ? (
                <div
                  data-testid="cart-expiry-warning"
                  className="mb-2.5 rounded-[12px] border border-sw-pastry-fg/30 bg-sw-pastry px-3 py-2 text-xs font-medium text-sw-pastry-fg"
                >
                  {t("sell.cartExpiryWarning", { count: expiredCartCount })}
                </div>
              ) : null}
              {cart.length === 0 ? (
                <div className="flex h-full flex-col items-center justify-center gap-2 py-6 text-center">
                  <div className="flex h-11 w-11 items-center justify-center rounded-full bg-sand text-muted-on-light">
                    <ShoppingBag size={20} aria-hidden />
                  </div>
                  <p className="font-display text-sm font-bold text-text-on-light">{t("sell.emptyCart")}</p>
                  <p className="max-w-[240px] text-xs text-muted-on-light">{t("sell.emptyCartHint")}</p>
                </div>
              ) : (
                <ul className="divide-y-[1.5px] divide-dashed divide-dash">
                  {cart.map((l) => {
                    const lineDisc = l.discount ?? 0;
                    const gross = lineGrossTotal(l.qty, l.unitPrice);
                    const net = lineTotal(l.qty, l.unitPrice, lineDisc);
                    const isPriceChanged = l.catalogPrice !== undefined && l.unitPrice !== l.catalogPrice;
                    const isEditing = editingVariantId === l.variantId;
                    return (
                      <li key={l.variantId} className="grid gap-1.5 py-2.5 first:pt-0 last:pb-0">
                        <div className="flex items-baseline justify-between gap-2">
                          <span className="truncate text-sm font-semibold text-text-on-light">{l.name}</span>
                          <span className="flex items-baseline gap-1.5 font-mono tabular-nums">
                            {lineDisc > 0 ? (
                              <span className="text-xs text-muted-on-light line-through">{fmt(gross)}</span>
                            ) : null}
                            <span className="text-sm font-bold text-text-on-light">{fmt(net)}</span>
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
                              className={`inline-flex cursor-pointer items-center gap-1 rounded-full border px-2 py-0.5 font-mono text-[11px] tabular-nums transition-colors ${
                                isEditing || isPriceChanged || lineDisc > 0
                                  ? "border-ink bg-lime/40 font-semibold text-ink"
                                  : "border-transparent text-muted-on-light hover:border-sand-line hover:bg-sand hover:text-ink"
                              }`}
                            >
                              <Tag size={11} aria-hidden />
                              <span>{fmt(l.unitPrice)}</span>
                              {lineDisc > 0 ? (
                                <span className="text-ok-fg">(-{fmt(lineDisc)})</span>
                              ) : null}
                            </button>
                          </div>
                          <div className="flex items-center gap-1">
                            <button
                              type="button"
                              aria-label={`Decrease ${l.name}`}
                              onClick={() => stepCartQty(l.variantId, -1)}
                              className="flex h-8 w-8 cursor-pointer items-center justify-center rounded-full border-[1.5px] border-sand-line bg-sand text-ink transition-colors hover:border-ink"
                            >
                              <Minus size={13} aria-hidden />
                            </button>
                            <Input
                              aria-label={t("sell.qty")}
                              data-testid={`qty-${l.variantId}`}
                              inputMode="decimal"
                              value={String(l.qty)}
                              onChange={(e) => setQty(l.variantId, e.target.value)}
                              className="h-8 min-h-[32px] w-13 rounded-[10px] px-1 py-0.5 text-center font-mono text-xs font-semibold tabular-nums"
                            />
                            <button
                              type="button"
                              aria-label={`Increase ${l.name}`}
                              onClick={() => stepCartQty(l.variantId, 1)}
                              className="flex h-8 w-8 cursor-pointer items-center justify-center rounded-full border-[1.5px] border-sand-line bg-sand text-ink transition-colors hover:border-ink"
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
                              className="ml-0.5 flex h-8 w-8 cursor-pointer items-center justify-center rounded-full text-muted-on-light transition-colors hover:bg-sw-meal hover:text-sw-meal-fg"
                            >
                              <X size={14} aria-hidden />
                            </button>
                          </div>
                        </div>

                        {isPriceChanged && !isEditing && l.catalogPrice !== undefined ? (
                          <div className="font-mono text-[11px] text-sw-pastry-fg">
                            {t("sell.priceOverridden", { catalog: fmt(l.catalogPrice) })}
                          </div>
                        ) : null}

                        {isEditing ? (
                          <div
                            data-testid={`line-editor-${l.variantId}`}
                            className="mt-1 grid gap-2 rounded-[14px] border-[1.5px] border-sand-line bg-sand p-2.5 text-xs"
                          >
                            <div className="grid grid-cols-2 gap-2">
                              <label className="grid gap-1 text-text-on-light">
                                <span className="font-medium">{t("sell.unitPrice")}</span>
                                <Input
                                  data-testid={`line-price-${l.variantId}`}
                                  inputMode="decimal"
                                  value={linePriceText}
                                  onChange={(e) => applyLinePriceText(l.variantId, e.target.value)}
                                  className="h-8 min-h-[32px] bg-paper text-right font-mono text-xs tabular-nums"
                                />
                              </label>
                              <label className="grid gap-1 text-text-on-light">
                                <span className="font-medium">{t("sell.lineDiscount")}</span>
                                <Input
                                  data-testid={`line-discount-${l.variantId}`}
                                  inputMode="decimal"
                                  placeholder="0.00"
                                  value={lineDiscText}
                                  onChange={(e) => applyLineDiscText(l.variantId, e.target.value)}
                                  className="h-8 min-h-[32px] bg-paper text-right font-mono text-xs tabular-nums"
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

            {/* Ticket Totals Footer */}
            <div className="grid gap-1.5 border-t-[1.5px] border-dashed border-dash pt-2.5">
              {lineDiscounts > 0 ? (
                <div className="flex items-baseline justify-between text-xs text-ok-fg">
                  <span>{t("sell.lineDiscountsTotal")}</span>
                  <span className="font-mono font-semibold tabular-nums">-{fmt(lineDiscounts)}</span>
                </div>
              ) : null}
              <div className="flex items-baseline justify-between text-xs text-muted-on-light">
                <span>{t("sell.subtotal")}</span>
                <span className="font-mono tabular-nums">{fmt(subtotal)}</span>
              </div>
              <label className="flex items-center justify-between gap-2 text-xs text-muted-on-light">
                <span className="flex items-center gap-1.5">
                  <span>{t("sell.discount")}</span>
                  <kbd className="rounded bg-sand px-1.5 py-0.5 font-mono text-[10px] font-semibold text-ink">F4</kbd>
                </span>
                <Input
                  ref={discountInputRef}
                  className="h-8 min-h-[32px] w-24 rounded-[10px] bg-sand text-right font-mono text-xs font-semibold tabular-nums"
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
              {estimatedVat > 0 ? (
                <div className="flex items-baseline justify-between text-[11px] text-muted-on-light">
                  <span>{t("sell.vatIncluded")}</span>
                  <span className="font-mono tabular-nums">{fmt(estimatedVat)}</span>
                </div>
              ) : null}
              <div
                className="mt-1 flex items-baseline justify-between border-t-[1.5px] border-dashed border-dash pt-2 text-ink tabular-nums"
                data-testid="cart-total"
              >
                <span className="font-display text-lg font-extrabold tracking-tight">{t("sell.total")}</span>
                <span className="font-display text-2xl font-extrabold tracking-tight">{fmt(total)}</span>
              </div>
            </div>
          </div>
        </div>

        {/* Lower Dark --ink Payment Pad & Full-Width Lime Charge Button */}
        <div className="grid shrink-0 gap-2.5 bg-ink px-4 pt-2 pb-4 text-sm text-text-on-dark">
          {splitTenders.length > 0 ? (
            <div
              data-testid="split-tenders-list"
              className="grid gap-1.5 rounded-[16px] border-[1.5px] border-ink-line-2 bg-ink-2 px-3 py-2 text-xs text-text-on-dark"
            >
              <div className="flex items-center justify-between">
                <span className="font-mono text-[11px] font-semibold tracking-wider text-muted-on-dark uppercase">
                  {t("sell.splitTendersLabel")}
                </span>
                <button
                  type="button"
                  data-testid="clear-split-tenders"
                  onClick={() => setSplitTenders([])}
                  className="cursor-pointer text-xs font-medium text-muted-on-dark hover:text-lime"
                >
                  {t("sell.splitClearAll")}
                </button>
              </div>
              {splitTenders.map((sp, idx) => (
                <div
                  key={`${sp.method}-${idx}`}
                  data-testid={`split-line-${idx}`}
                  className="flex items-center justify-between gap-2 border-t border-ink-line-2 pt-1.5"
                >
                  <span className="truncate font-medium text-text-on-dark">
                    {sp.method === "ewallet" && sp.wallet
                      ? `${t("sell.ewallet")} (${t(`sell.wallets.${sp.wallet}`)})`
                      : sp.method === "card"
                        ? `${t("sell.card")}${sp.reference ? ` · ${sp.reference}` : ""}`
                        : t(`sell.${sp.method}`)}
                  </span>
                  <div className="flex items-center gap-1.5">
                    <span className="font-mono font-semibold text-lime tabular-nums">{fmt(sp.amount)}</span>
                    <button
                      type="button"
                      aria-label={t("sell.splitRemove")}
                      data-testid={`remove-split-${idx}`}
                      onClick={() => removeSplitTender(idx)}
                      className="cursor-pointer rounded-full p-0.5 text-muted-on-dark hover:bg-ink hover:text-sw-meal"
                    >
                      <X size={13} aria-hidden />
                    </button>
                  </div>
                </div>
              ))}
              <div className="flex items-baseline justify-between border-t border-ink-line-2 pt-1.5 text-lime">
                <span className="font-semibold">{t("sell.splitRemaining")}</span>
                <span className="font-mono text-sm font-bold tabular-nums" data-testid="split-remaining">
                  {fmt(remainingDue)}
                </span>
              </div>
            </div>
          ) : null}

          {splitExceeded ? (
            <div className="rounded-[12px] border border-sw-meal-fg/40 bg-sw-meal px-3 py-2 text-xs font-medium text-sw-meal-fg">
              {t("sell.splitExceeded")}
            </div>
          ) : null}

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
                      className={`flex min-h-[52px] cursor-pointer flex-col items-center justify-center gap-1 rounded-[14px] border-[1.5px] px-1.5 py-2 text-[11px] font-semibold transition-colors ${
                        active
                          ? "border-lime bg-ink-2 text-lime"
                          : "border-ink-line-2 bg-ink-2/50 text-muted-on-dark hover:border-text-on-dark hover:text-text-on-dark"
                      }`}
                    >
                      <Icon size={15} className={active ? "text-lime" : "text-muted-on-dark"} aria-hidden />
                      <span className="w-full truncate text-center">{label}</span>
                    </button>
                  );
                })}
              </div>

              {method !== "utang" ? (
                <div className="grid grid-cols-2 gap-2">
                  <label className="grid gap-1 text-[11px] text-muted-on-dark">
                    <span>{t("sell.paidNow")}</span>
                    <input
                      className="h-9 rounded-[12px] border-[1.5px] border-ink-line-2 bg-ink-2 px-3 text-right font-mono text-xs text-text-on-dark placeholder:text-muted-on-dark focus:border-lime focus:outline-none tabular-nums"
                      data-testid="paid-now"
                      inputMode="decimal"
                      placeholder={fmt(remainingDue)}
                      value={paidText}
                      onChange={(e) => setPaidText(e.target.value)}
                    />
                  </label>

                  {method === "cash" ? (
                    <label className="grid gap-1 text-[11px] text-muted-on-dark">
                      <span className="flex items-center justify-between">
                        <span>{t("sell.tendered")}</span>
                        <kbd className="rounded bg-ink-2 px-1 font-mono text-[10px] text-lime">F8</kbd>
                      </span>
                      <input
                        ref={tenderedInputRef}
                        className="h-9 rounded-[12px] border-[1.5px] border-ink-line-2 bg-ink-2 px-3 text-right font-mono text-xs text-text-on-dark placeholder:text-muted-on-dark focus:border-lime focus:outline-none tabular-nums"
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
                <button
                  type="button"
                  data-testid="add-split-tender"
                  onClick={addSplitTender}
                  className="min-h-[34px] w-full cursor-pointer rounded-full border-[1.5px] border-lime bg-ink-2 px-3 text-xs font-semibold text-lime transition-colors hover:bg-ink"
                >
                  {t("sell.splitAddTender", {
                    method:
                      method === "ewallet"
                        ? t(`sell.wallets.${wallet}`)
                        : t(`sell.${method}`),
                    amount: fmt(paidNow),
                  })}
                </button>
              ) : null}
            </>
          ) : null}

          {method === "cash" && cashTarget > 0 ? (
            <div className="flex flex-wrap gap-1.5" data-testid="quick-cash-presets">
              <button
                type="button"
                onClick={() => setTenderedText(formatMajorInput(cashTarget))}
                className="cursor-pointer rounded-full border border-ink-line-2 bg-ink-2 px-3 py-1 font-mono text-xs font-semibold text-text-on-dark transition-colors hover:border-lime hover:text-lime tabular-nums"
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
                    className="cursor-pointer rounded-full border border-ink-line-2 bg-ink-2 px-3 py-1 font-mono text-xs font-semibold text-text-on-dark transition-colors hover:border-lime hover:text-lime tabular-nums"
                  >
                    {fmt(bill * 100)}
                  </button>
                ))}
            </div>
          ) : null}

          {change > 0 ? (
            <div className="flex items-baseline justify-between rounded-[14px] border border-lime/40 bg-ink-2 px-3.5 py-2 text-lime">
              <span className="font-mono text-xs font-semibold tracking-wider uppercase">{t("sell.change")}</span>
              <span className="font-display text-lg font-extrabold tabular-nums" data-testid="change">
                {fmt(change)}
              </span>
            </div>
          ) : null}

          {onUtang > 0 ? (
            <div className="flex items-baseline justify-between rounded-[14px] border border-sw-pastry/50 bg-sw-pastry/15 px-3.5 py-2 text-sw-pastry">
              <span className="font-mono text-xs font-semibold tracking-wider uppercase">{t("sell.onUtang")}</span>
              <span className="font-mono text-sm font-bold tabular-nums" data-testid="on-utang">
                {fmt(onUtang)}
              </span>
            </div>
          ) : null}

          {method === "ewallet" ? (
            <div className="grid grid-cols-2 gap-2">
              <select
                aria-label={t("sell.wallet")}
                data-testid="pay-wallet"
                value={wallet}
                onChange={(e) => setWallet(e.target.value as Wallet)}
                className="h-9 rounded-[12px] border-[1.5px] border-ink-line-2 bg-ink-2 px-2.5 text-xs text-text-on-dark focus:border-lime focus:outline-none"
              >
                {WALLETS.map((w) => (
                  <option key={w} value={w}>
                    {t(`sell.wallets.${w}`)}
                  </option>
                ))}
              </select>
              <input
                placeholder={t("sell.reference")}
                value={reference}
                maxLength={64}
                onChange={(e) => setReference(e.target.value)}
                className="h-9 rounded-[12px] border-[1.5px] border-ink-line-2 bg-ink-2 px-3 text-xs text-text-on-dark placeholder:text-muted-on-dark focus:border-lime focus:outline-none"
              />
            </div>
          ) : null}

          {method === "card" ? (
            <input
              data-testid="pay-card-ref"
              placeholder={t("sell.cardRefPlaceholder")}
              value={reference}
              maxLength={64}
              onChange={(e) => setReference(e.target.value)}
              className="h-9 rounded-[12px] border-[1.5px] border-ink-line-2 bg-ink-2 px-3 text-xs text-text-on-dark placeholder:text-muted-on-dark focus:border-lime focus:outline-none"
            />
          ) : null}

          {problem ? (
            <div className="rounded-[14px] border border-sw-meal-fg/40 bg-sw-meal px-3 py-2 text-xs font-medium text-sw-meal-fg">
              {problem}
            </div>
          ) : null}

          <button
            type="button"
            data-testid="charge"
            disabled={cart.length === 0 || charge.isPending}
            onClick={handleCharge}
            aria-label={charge.isPending ? t("sell.charging") : t("sell.charge", { total: fmt(total) })}
            className="flex min-h-[60px] w-full cursor-pointer items-center justify-between gap-3 rounded-full bg-lime px-6 font-display text-lg font-extrabold text-ink transition-colors hover:bg-lime-hover disabled:cursor-not-allowed disabled:opacity-45"
          >
            <span>{charge.isPending ? t("sell.charging") : t("sell.chargeLabel")}</span>
            <span className="flex items-center gap-2 tabular-nums">
              <span className="font-mono text-base font-bold">{fmt(total)}</span>
              <kbd className="rounded-full bg-ink/10 px-2 py-0.5 font-mono text-[11px] font-bold text-ink">
                F9
              </kbd>
            </span>
          </button>
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
          <p className="-mt-2 text-xs text-muted-on-light">{t("sell.holdOrderDesc")}</p>
          <label className="grid gap-1.5 text-sm">
            <span className="font-medium text-text-on-light">{t("sell.holdOrderLabel")}</span>
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
            <div className="rounded-[14px] border-[1.5px] border-lime/50 bg-lime/20 px-3 py-2 text-xs font-medium text-ink">
              {t("sell.heldOrderSwapHint")}
            </div>
          ) : null}
          {heldOrders.length === 0 ? (
            <p className="py-6 text-center text-sm text-muted-on-light">{t("sell.heldOrdersEmpty")}</p>
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
                    className="flex items-center justify-between gap-3 rounded-[18px] border-[1.5px] border-sand-line bg-sand p-3"
                  >
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-2">
                        <span className="truncate font-display text-sm font-bold text-text-on-light">
                          {titleText}
                        </span>
                        <span className="shrink-0 font-mono text-xs text-muted-on-light">{timeStr}</span>
                      </div>
                      <div className="mt-0.5 truncate text-xs text-muted-on-light">
                        {h.lines.map((l) => `${l.qty}× ${l.name}`).join(", ")}
                      </div>
                      <div className="mt-1 flex items-center gap-2 text-xs">
                        <span className="font-mono font-bold text-text-on-light tabular-nums">
                          {fmt(heldTotal)}
                        </span>
                        <span className="text-muted-on-light">·</span>
                        <span className="text-muted-on-light">
                          {t("sell.itemsInOrder", { count: heldUnits })}
                        </span>
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
                        <Trash2 size={14} className="text-muted-on-light hover:text-sw-meal-fg" aria-hidden />
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
