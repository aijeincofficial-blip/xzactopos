import { useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import { Link, Outlet, useNavigate, useRouterState } from "@tanstack/react-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import {
  ArrowDownToLine,
  ArrowLeftRight,
  Banknote,
  BarChart3,
  Blocks,
  Boxes,
  ClipboardCheck,
  ClipboardList,
  HandCoins,
  Home,
  LogOut,
  type LucideIcon,
  MapPin,
  Maximize2,
  Menu,
  Minimize2,
  Monitor,
  Moon,
  Package,
  PanelLeft,
  PanelLeftClose,
  PowerOff,
  Receipt,
  Rocket,
  ScrollText,
  Settings,
  ShieldCheck,
  ShoppingCart,
  Smartphone,
  Store,
  Sun,
  Truck,
  Users,
  Warehouse,
  WifiOff,
  X,
} from "lucide-react";
import { accessQuery, useSession } from "../lib/session.tsx";
import type { PermissionKey } from "@pos/core";
import { saveMyLocale, signOut } from "../lib/api.ts";
import { setPosOutboxTenant } from "../lib/pos-outbox.ts";
import { tenantMode } from "../lib/mode.ts";
import { pickLocale, storeLocale } from "../i18n/index.ts";
import { useActiveLocation } from "../lib/location-context.tsx";
import {
  canAccessReceiveStockRoute,
  canAccessReportsRoute,
  portalForPath,
  readStoredPortal,
  resolveAllowedPortals,
  resolveEffectivePortal,
  saveStoredPortal,
  type PortalKind,
} from "../lib/portal.ts";
import { listStoreIncomingTransfers } from "../lib/transfers-api.ts";
import { applyTheme, nextTheme, readTheme, type ThemeChoice } from "../lib/theme.ts";
import { Badge, Button, Card, PageHeader } from "../components/ui.tsx";
import { LanguageSelect } from "../components/LanguageSelect.tsx";
import { SyncStatusPill } from "../components/sync-status-pill.tsx";
import { useOnlineStatus } from "../lib/network.ts";
import { usePollInterval, useVisibilityResumeInvalidation } from "../lib/polling.ts";

type NavGroup = "daily" | "warehouseOps" | "stock" | "business";
type NavPortalScope = "pos" | "warehouse" | "both";

const NAV = [
  // POS Portal routes
  { to: "/app", key: "dashboard", icon: Home, group: "daily", portal: "pos", perm: null, fullOnly: false },
  { to: "/app/sell", key: "sell", icon: ShoppingCart, group: "daily", portal: "pos", perm: "sale.create", fullOnly: false },
  {
    to: "/app/receive-stock",
    key: "receiveStock",
    icon: ArrowDownToLine,
    group: "daily",
    portal: "pos",
    perm: null,
    perms: ["sale.create", "stock.adjust_store", "transfer.manage"] as const,
    fullOnly: true,
  },
  { to: "/app/sales", key: "sales", icon: Receipt, group: "daily", portal: "pos", perm: "sale.create", fullOnly: false },
  { to: "/app/utang", key: "utang", icon: HandCoins, group: "daily", portal: "pos", perm: "sale.create", fullOnly: false },
  { to: "/app/services", key: "services", icon: Smartphone, group: "daily", portal: "pos", perm: "sale.create", fullOnly: false },
  { to: "/app/expenses", key: "expenses", icon: Banknote, group: "daily", portal: "pos", perm: "shift.manage", fullOnly: false },
  { to: "/app/day-close", key: "dayClose", icon: PowerOff, group: "daily", portal: "pos", perm: "shift.manage", fullOnly: false },

  // Warehouse Portal routes
  { to: "/app/warehouses", key: "overview", icon: Warehouse, group: "warehouseOps", portal: "warehouse", perm: "reports.warehouse", fullOnly: true },
  { to: "/app/transfers", key: "dispatchToPos", icon: ArrowLeftRight, group: "warehouseOps", portal: "warehouse", perm: null, perms: ["transfer.manage", "stock.adjust_store"] as const, fullOnly: true },
  { to: "/app/purchasing", key: "purchasing", icon: Truck, group: "warehouseOps", portal: "warehouse", perm: "purchasing.manage", fullOnly: true },
  { to: "/app/bins", key: "bins", icon: Boxes, group: "warehouseOps", portal: "warehouse", perm: null, perms: ["transfer.manage", "stock.adjust_store", "locations.manage"] as const, fullOnly: true },
  { to: "/app/counts", key: "counts", icon: ClipboardCheck, group: "warehouseOps", portal: "warehouse", perm: "stock.adjust_warehouse", fullOnly: true },

  // Catalog & Business routes
  {
    to: "/app/inventory",
    key: "inventory",
    icon: ClipboardList,
    group: "stock",
    portal: "both",
    perm: null,
    perms: [
      "sale.create",
      "catalog.manage",
      "stock.adjust_store",
      "stock.adjust_warehouse",
      "reports.warehouse",
      "transfer.manage",
    ] as const,
    fullOnly: false,
  },
  { to: "/app/products", key: "products", icon: Package, group: "stock", portal: "both", perm: "catalog.manage", fullOnly: false },
  { to: "/app/reports", key: "reports", icon: BarChart3, group: "business", portal: "both", perm: null, perms: ["reports.store", "reports.warehouse"] as const, fullOnly: true },
  { to: "/app/audit", key: "audit", icon: ScrollText, group: "business", portal: "both", perm: "audit.read", fullOnly: false },
  { to: "/app/upgrade", key: "upgrade", icon: Rocket, group: "business", portal: "pos", perm: "tenant.modules", fullOnly: false, soloOnly: true },
  { to: "/app/locations", key: "locations", icon: MapPin, group: "business", portal: "both", perm: "locations.manage", fullOnly: true },
  { to: "/app/users", key: "users", icon: Users, group: "business", portal: "both", perm: "users.manage", fullOnly: true },
  { to: "/app/modules", key: "modules", icon: Blocks, group: "business", portal: "both", perm: "tenant.modules", fullOnly: true },
  { to: "/app/settings", key: "settings", icon: Settings, group: "business", portal: "both", perm: "tenant.settings", fullOnly: false },
  { to: "/app/platform", key: "platform", icon: ShieldCheck, group: "business", portal: "both", perm: null, fullOnly: false, platformAdminOnly: true },
] as const satisfies ReadonlyArray<{
  to: string;
  key: string;
  icon: LucideIcon;
  group: NavGroup;
  portal: NavPortalScope;
  perm: PermissionKey | null;
  perms?: readonly PermissionKey[];
  fullOnly: boolean;
  soloOnly?: boolean;
  platformAdminOnly?: boolean;
}>;

const GROUPS: readonly NavGroup[] = ["daily", "warehouseOps", "stock", "business"];
const THEME_ICON: Record<ThemeChoice, LucideIcon> = { system: Monitor, light: Sun, dark: Moon };

function userInitials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "U";
  if (parts.length === 1) return parts[0]!.slice(0, 2).toUpperCase();
  return `${parts[0]![0] ?? ""}${parts[1]![0] ?? ""}`.toUpperCase();
}

export function AppLayout() {
  const { t, i18n } = useTranslation(["common", "admin"]);
  const { access, can } = useSession();
  const {
    activeStoreId,
    stores,
    setActiveStoreId,
    activeWarehouseId,
    warehouses,
    setActiveWarehouseId,
  } = useActiveLocation();
  const isOnline = useOnlineStatus();
  const mode = tenantMode(access);
  const qc = useQueryClient();
  useVisibilityResumeInvalidation(qc);
  const pollInterval = usePollInterval(120_000);
  useEffect(() => {
    setPosOutboxTenant(access.tenant.id);
  }, [access.tenant.id]);
  const navigate = useNavigate();
  const [menuOpen, setMenuOpen] = useState(false);
  const [savedPortal, setSavedPortal] = useState<PortalKind | null>(() => readStoredPortal());
  const [kioskMode, setKioskMode] = useState<boolean>(() => {
    try {
      const saved = localStorage.getItem("pos.kioskMode");
      return saved === null ? true : saved === "1";
    } catch {
      return true;
    }
  });
  const [theme, setTheme] = useState<ThemeChoice>(readTheme);
  const [isFullscreen, setIsFullscreen] = useState<boolean>(
    () => typeof document !== "undefined" && Boolean(document.fullscreenElement),
  );
  const path = useRouterState({ select: (s) => s.location.pathname });
  const isSellRoute = path === "/app/sell" || path.startsWith("/app/sell/");
  const allowedPortals = resolveAllowedPortals(access, mode);
  const activePortal = resolveEffectivePortal(access, mode, path, savedPortal);
  const isWarehousePortal = activePortal === "warehouse";
  const canSwitchPortal = allowedPortals.length > 1;
  const hideDockedSidebar = isSellRoute && kioskMode && !isWarehousePortal;
  const ThemeIcon = THEME_ICON[theme];

  // Sync stored portal when navigating to a portal-specific route
  useEffect(() => {
    const routePortal = portalForPath(path);
    if (routePortal && allowedPortals.includes(routePortal) && routePortal !== savedPortal) {
      setSavedPortal(routePortal);
      saveStoredPortal(routePortal);
    }
  }, [path, allowedPortals, savedPortal]);

  // Poll incoming warehouse shipments for the active POS store so store staff see a live badge
  const canReceiveStoreStock = can("sale.create") || can("stock.adjust_store") || can("transfer.manage");
  // Defer non-critical nav transfer badge query past initial route paint/hydration.
  const [navBadgeReady, setNavBadgeReady] = useState(false);
  useEffect(() => {
    const timer = window.setTimeout(() => setNavBadgeReady(true), 150);
    return () => window.clearTimeout(timer);
  }, []);

  const incomingPosQuery = useQuery({
    queryKey: ["pos-incoming-transfers", activeStoreId, "shipped-count"],
    queryFn: () => listStoreIncomingTransfers(activeStoreId!, false),
    enabled:
      navBadgeReady &&
      !isWarehousePortal &&
      mode === "full" &&
      access.modules.warehouse &&
      Boolean(activeStoreId) &&
      canReceiveStoreStock,
    refetchInterval: pollInterval,
    staleTime: 15_000,
  });
  const incomingCount = incomingPosQuery.data?.length ?? 0;

  useEffect(() => {
    const onFsChange = () => setIsFullscreen(Boolean(document.fullscreenElement));
    document.addEventListener("fullscreenchange", onFsChange);
    return () => document.removeEventListener("fullscreenchange", onFsChange);
  }, []);

  async function toggleFullscreenKiosk() {
    try {
      if (document.fullscreenElement) {
        await document.exitFullscreen();
      } else {
        setKioskMode(true);
        try {
          localStorage.setItem("pos.kioskMode", "1");
        } catch {
          /* ignore storage failure */
        }
        await document.documentElement.requestFullscreen();
      }
    } catch {
      /* fullscreen disallowed or unsupported */
    }
  }

  function toggleKioskMode() {
    setKioskMode((prev) => {
      const next = !prev;
      try {
        localStorage.setItem("pos.kioskMode", next ? "1" : "0");
      } catch {
        /* ignore storage failure */
      }
      return next;
    });
  }

  function switchPortal(target: PortalKind) {
    setSavedPortal(target);
    saveStoredPortal(target);
    if (target === "warehouse") {
      void navigate({ to: "/app/warehouses" });
    } else {
      void navigate({ to: "/app/sell" });
    }
  }

  useEffect(() => applyTheme(theme), [theme]);
  useEffect(() => setMenuOpen(false), [path]);

  useEffect(() => {
    const l = pickLocale(access.locale, null);
    if (i18n.language !== l) {
      void i18n.changeLanguage(l);
    }
    storeLocale(l);
  }, [access.user_id]);

  async function chooseLocale(l: "en" | "fil") {
    try {
      await saveMyLocale(access.user_id, l);
      qc.setQueryData(accessQuery.queryKey, { ...access, locale: l });
    } catch {
      /* the language still changed locally; it will sync on the next choice */
    }
  }

  async function leave() {
    const wasWarehouseStaff = access.role === "warehouse";
    await signOut();
    setPosOutboxTenant(null);
    qc.clear();
    if (wasWarehouseStaff) {
      await navigate({ to: "/warehouse" });
    } else {
      await navigate({ to: "/t/$slug", params: { slug: access.tenant.slug } });
    }
  }

  const visible = NAV.filter((n) => {
    if ("platformAdminOnly" in n && n.platformAdminOnly && !access.is_platform_admin) return false;
    if (n.to === "/app" && (access.role === "cashier" || access.role === "warehouse")) return false;
    if (n.to === "/app/receive-stock" && !canAccessReceiveStockRoute(access)) return false;
    if (n.portal === "pos" && n.to !== "/app/receive-stock" && !access.modules.pos) return false;
    if (n.to === "/app/expenses" && access.role === "cashier") return false;
    if (n.to === "/app/reports" && !canAccessReportsRoute(access)) {
      return false;
    }
    if (n.portal !== "both" && n.portal !== activePortal && !(n.to === "/app/receive-stock" && !access.modules.pos)) {
      return false;
    }
    const permOk =
      "perms" in n && n.perms
        ? (n.perms as readonly PermissionKey[]).some((p) => can(p))
        : n.perm === null || can(n.perm);
    return permOk && (!n.fullOnly || mode === "full") && (!("soloOnly" in n && n.soloOnly) || mode === "solo");
  });
  const showNav = access.tenant.setup_completed;
  const showDockedSidebar = showNav && !hideDockedSidebar;
  const displayName = access.full_name || access.username;

  const identity = (
    <div className="grid gap-1.5 border-b-[1.5px] border-ink-line px-4 py-4">
      <div className="flex items-center justify-between gap-2">
        <img
          src="/brand/xzacto-logo-on-dark.svg"
          alt="xzacto"
          width={108}
          height={28}
          className="h-7 w-auto"
        />
        <span
          className={
            isWarehousePortal
              ? "rounded-full bg-sw-pastry px-2.5 py-0.5 font-mono text-[10px] font-semibold tracking-[0.06em] text-sw-pastry-fg uppercase"
              : "rounded-full bg-lime px-2.5 py-0.5 font-mono text-[10px] font-semibold tracking-[0.06em] text-ink uppercase"
          }
        >
          {isWarehousePortal ? t("admin:portal.warehouseBadge") : t("admin:portal.posBadge")}
        </span>
      </div>
      <div className="truncate font-mono text-[11px] font-medium text-muted-on-dark">
        {access.tenant.name}
      </div>
    </div>
  );

  const sidebar = (
    <nav aria-label={t("admin:nav.label")} className="grid content-start gap-5 overflow-y-auto px-3 py-4">
      {GROUPS.map((g) => {
        const items = visible.filter((n) => n.group === g);
        if (items.length === 0) return null;
        return (
          <div key={g} className="grid gap-1">
            <div className="px-3 pb-1 font-mono text-[10px] font-semibold tracking-[0.08em] text-muted-on-dark uppercase">
              {t(`admin:nav.group.${g}`)}
            </div>
            {items.map((n) => {
              const Icon = n.icon;
              const showReceiveBadge = n.to === "/app/receive-stock" && incomingCount > 0;
              return (
                <Link
                  key={n.to}
                  to={n.to}
                  activeOptions={{ exact: n.to === "/app" }}
                  className="flex min-h-[42px] items-center justify-between gap-2 rounded-[14px] px-3 py-2 text-sm font-medium transition-colors [&:not([aria-current='page'])]:text-muted-on-dark [&:not([aria-current='page'])]:hover:bg-ink-2 [&:not([aria-current='page'])]:hover:text-lime"
                  activeProps={{
                    className:
                      "bg-lime font-semibold text-ink hover:bg-lime-hover hover:text-ink",
                    "aria-current": "page",
                  }}
                >
                  <span className="flex items-center gap-2.5 truncate">
                    <Icon size={17} className="shrink-0" aria-hidden />
                    <span className="truncate">{t(`admin:nav.${n.key}`)}</span>
                  </span>
                  {showReceiveBadge ? <Badge tone="warn">{incomingCount}</Badge> : null}
                </Link>
              );
            })}
          </div>
        );
      })}
    </nav>
  );

  const sidebarFooter = (
    <div className="grid gap-3 border-t-[1.5px] border-ink-line bg-ink-2 p-3.5">
      <div className="flex items-center gap-2.5 px-1">
        <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-[12px] bg-lime font-display text-xs font-extrabold text-ink">
          {userInitials(displayName)}
        </div>
        <div className="min-w-0 flex-1">
          <div className="truncate text-xs font-semibold text-text-on-dark">{displayName}</div>
          <div className="truncate font-mono text-[11px] text-muted-on-dark">{t(`admin:roles.${access.role}`)}</div>
        </div>
      </div>
      <div className="flex items-center justify-between gap-2">
        <div className="flex-1 [&_select]:min-h-[36px] [&_select]:h-9 [&_select]:w-full [&_select]:rounded-full [&_select]:border-ink-line-2 [&_select]:bg-ink [&_select]:px-3 [&_select]:text-xs [&_select]:text-text-on-dark">
          <LanguageSelect onChoose={(l) => void chooseLocale(l)} />
        </div>
        <Button
          variant="outline"
          size="sm"
          onClick={() => void leave()}
          title={t("common:actions.signOut")}
          className="shrink-0 border-ink-line-2 bg-transparent text-text-on-dark hover:border-lime hover:text-lime"
        >
          <LogOut size={14} aria-hidden />
          <span>{t("common:actions.signOut")}</span>
        </Button>
      </div>
    </div>
  );

  return (
    <div className={showDockedSidebar ? "min-h-screen md:grid md:grid-cols-[16rem_1fr]" : "min-h-screen"}>
      {showNav ? (
        <>
          {!hideDockedSidebar ? (
            <aside className="sticky top-0 hidden h-screen grid-rows-[auto_1fr_auto] border-r-[1.5px] border-ink-line bg-ink text-text-on-dark md:grid">
              {identity}
              {sidebar}
              {sidebarFooter}
            </aside>
          ) : null}
          {menuOpen ? (
            <div className={hideDockedSidebar ? "fixed inset-0 z-50" : "fixed inset-0 z-50 md:hidden"}>
              <button
                aria-label={t("common:actions.close")}
                className="absolute inset-0 bg-ink/75"
                onClick={() => setMenuOpen(false)}
              />
              <aside className="receipt-float absolute inset-y-0 left-0 grid w-72 grid-rows-[auto_1fr_auto] border-r-[1.5px] border-ink-line bg-ink text-text-on-dark">
                <div className="flex items-center justify-between pr-2">
                  <div className="min-w-0 flex-1">{identity}</div>
                  <button
                    aria-label={t("common:actions.close")}
                    className="rounded-full p-2 text-muted-on-dark hover:bg-ink-2 hover:text-lime"
                    onClick={() => setMenuOpen(false)}
                  >
                    <X size={18} />
                  </button>
                </div>
                {sidebar}
                {sidebarFooter}
              </aside>
            </div>
          ) : null}
        </>
      ) : null}

      <div className={isSellRoute ? "flex min-h-screen min-w-0 flex-col lg:h-screen lg:overflow-hidden" : "min-w-0"}>
        <header
          className={
            hideDockedSidebar
              ? "sticky top-0 z-30 flex min-h-14 items-center gap-2 border-b-[1.5px] border-ink-line bg-ink px-4 text-text-on-dark"
              : "sticky top-0 z-30 flex min-h-14 items-center gap-2 border-b-[1.5px] border-slate-200 bg-white px-4"
          }
        >
          {showNav ? (
            <Button
              variant="ghost"
              size="sm"
              className={
                hideDockedSidebar
                  ? "px-2.5 text-text-on-dark hover:bg-ink-2 hover:text-lime"
                  : "px-2.5 md:hidden"
              }
              aria-label={t("admin:nav.menu")}
              data-testid="nav-drawer-btn"
              onClick={() => setMenuOpen(true)}
            >
              <Menu size={18} aria-hidden />
            </Button>
          ) : null}

          {hideDockedSidebar ? (
            <div className="flex min-w-0 flex-1 items-center gap-2.5 overflow-hidden">
              <img
                src="/brand/xzacto-mark.svg"
                alt="xzacto"
                width={28}
                height={28}
                className="h-7 w-7 shrink-0"
              />
              <span className="hidden max-w-[140px] shrink-0 truncate font-display text-sm font-extrabold tracking-tight text-text-on-dark sm:inline lg:hidden 2xl:inline">
                {access.tenant.name}
              </span>
              {showNav ? (
                <nav
                  aria-label="POS quick links"
                  className="ml-1 hidden min-w-0 flex-1 items-center gap-0.5 overflow-x-auto [scrollbar-width:none] lg:flex"
                >
                  {access.modules.pos ? (
                    <Link
                      to="/app/sell"
                      className="shrink-0 whitespace-nowrap rounded-full px-2.5 py-1.5 text-xs font-medium transition-colors [&:not([aria-current='page'])]:text-muted-on-dark [&:not([aria-current='page'])]:hover:bg-ink-2 [&:not([aria-current='page'])]:hover:text-lime"
                      activeProps={{
                        className: "bg-lime font-semibold text-ink hover:bg-lime-hover hover:text-ink",
                        "aria-current": "page",
                      }}
                    >
                      {t("admin:nav.sell")}
                    </Link>
                  ) : null}
                  <Link
                    to="/app/inventory"
                    data-testid="kiosk-inventory-link"
                    className="shrink-0 whitespace-nowrap rounded-full px-2.5 py-1.5 text-xs font-medium transition-colors [&:not([aria-current='page'])]:text-muted-on-dark [&:not([aria-current='page'])]:hover:bg-ink-2 [&:not([aria-current='page'])]:hover:text-lime"
                    activeProps={{
                      className: "bg-lime font-semibold text-ink hover:bg-lime-hover hover:text-ink",
                      "aria-current": "page",
                    }}
                  >
                    {t("admin:nav.inventory")}
                  </Link>
                  {mode === "full" && access.modules.warehouse ? (
                    <Link
                      to="/app/receive-stock"
                      data-testid="kiosk-receive-stock-link"
                      className="inline-flex shrink-0 items-center gap-1.5 whitespace-nowrap rounded-full px-2.5 py-1.5 text-xs font-medium transition-colors [&:not([aria-current='page'])]:text-muted-on-dark [&:not([aria-current='page'])]:hover:bg-ink-2 [&:not([aria-current='page'])]:hover:text-lime"
                      activeProps={{
                        className: "bg-lime font-semibold text-ink hover:bg-lime-hover hover:text-ink",
                        "aria-current": "page",
                      }}
                    >
                      <span>{t("admin:nav.receiveStock")}</span>
                      {incomingCount > 0 ? <Badge tone="warn">{incomingCount}</Badge> : null}
                    </Link>
                  ) : null}
                  {access.modules.pos ? (
                    <>
                      <Link
                        to="/app/sales"
                        className="shrink-0 whitespace-nowrap rounded-full px-2.5 py-1.5 text-xs font-medium transition-colors [&:not([aria-current='page'])]:text-muted-on-dark [&:not([aria-current='page'])]:hover:bg-ink-2 [&:not([aria-current='page'])]:hover:text-lime"
                        activeProps={{
                          className: "bg-lime font-semibold text-ink hover:bg-lime-hover hover:text-ink",
                          "aria-current": "page",
                        }}
                      >
                        {t("admin:nav.sales")}
                      </Link>
                      <Link
                        to="/app/utang"
                        className="shrink-0 whitespace-nowrap rounded-full px-2.5 py-1.5 text-xs font-medium transition-colors [&:not([aria-current='page'])]:text-muted-on-dark [&:not([aria-current='page'])]:hover:bg-ink-2 [&:not([aria-current='page'])]:hover:text-lime"
                        activeProps={{
                          className: "bg-lime font-semibold text-ink hover:bg-lime-hover hover:text-ink",
                          "aria-current": "page",
                        }}
                      >
                        {t("admin:nav.utang")}
                      </Link>
                      {can("shift.manage") ? (
                        <Link
                          to="/app/day-close"
                          className="shrink-0 whitespace-nowrap rounded-full px-2.5 py-1.5 text-xs font-medium transition-colors [&:not([aria-current='page'])]:text-muted-on-dark [&:not([aria-current='page'])]:hover:bg-ink-2 [&:not([aria-current='page'])]:hover:text-lime"
                          activeProps={{
                            className: "bg-lime font-semibold text-ink hover:bg-lime-hover hover:text-ink",
                            "aria-current": "page",
                          }}
                        >
                          {t("admin:nav.dayClose")}
                        </Link>
                      ) : null}
                    </>
                  ) : null}
                </nav>
              ) : null}
            </div>
          ) : (
            <div className="mr-auto flex min-w-0 items-center gap-2">
              <span
                className={
                  showDockedSidebar
                    ? "truncate font-display text-sm font-extrabold text-slate-900 md:hidden"
                    : "truncate font-display text-sm font-extrabold text-slate-900"
                }
              >
                {access.tenant.name}
              </span>
              {/* Active Location Context Pill */}
              {isWarehousePortal && warehouses.length >= 1 ? (
                <div className="flex items-center gap-2 rounded-full border-[1.5px] border-slate-200 bg-slate-50 px-3 py-1 text-xs">
                  <Warehouse size={14} className="shrink-0 text-amber-700" aria-hidden />
                  {warehouses.length > 1 ? (
                    <select
                      value={activeWarehouseId ?? ""}
                      onChange={(e) => setActiveWarehouseId(e.target.value)}
                      className="cursor-pointer bg-transparent font-mono font-semibold text-slate-900 focus:outline-none"
                      aria-label="Active warehouse"
                      data-testid="active-warehouse-select"
                    >
                      {warehouses.map((w) => (
                        <option key={w.id} value={w.id}>
                          {w.code} · {w.name}
                        </option>
                      ))}
                    </select>
                  ) : (
                    <span className="font-mono font-semibold text-slate-900">
                      {warehouses[0]!.code} · {warehouses[0]!.name}
                    </span>
                  )}
                </div>
              ) : !isWarehousePortal && stores.length >= 1 ? (
                <div className="hidden items-center gap-2 rounded-full border-[1.5px] border-slate-200 bg-slate-50 px-3 py-1 text-xs sm:flex">
                  <Store size={14} className="shrink-0 text-slate-900" aria-hidden />
                  {stores.length > 1 ? (
                    <select
                      value={activeStoreId ?? ""}
                      onChange={(e) => setActiveStoreId(e.target.value)}
                      className="cursor-pointer bg-transparent font-mono font-semibold text-slate-900 focus:outline-none"
                      aria-label="Active store"
                    >
                      {stores.map((s) => (
                        <option key={s.id} value={s.id}>
                          {s.code} · {s.name}
                        </option>
                      ))}
                    </select>
                  ) : (
                    <span className="font-mono font-semibold text-slate-900">
                      {stores[0]!.code} · {stores[0]!.name}
                    </span>
                  )}
                </div>
              ) : null}
            </div>
          )}

          {/* Store Selector when in Kiosk Mode with multiple stores */}
          {hideDockedSidebar && stores.length > 1 ? (
            <div className="hidden shrink-0 items-center gap-1.5 rounded-full border-[1.5px] border-ink-line-2 bg-ink-2 px-3 py-1 text-xs sm:flex">
              <Store size={13} className="text-lime" aria-hidden />
              <select
                value={activeStoreId ?? ""}
                onChange={(e) => setActiveStoreId(e.target.value)}
                className="cursor-pointer bg-ink-2 font-mono font-semibold text-text-on-dark focus:outline-none"
                aria-label="Active store"
              >
                {stores.map((s) => (
                  <option key={s.id} value={s.id}>
                    {s.code} · {s.name}
                  </option>
                ))}
              </select>
            </div>
          ) : null}

          <SyncStatusPill
            tenantId={access.tenant.id}
            currency={access.tenant.base_currency}
            timezone={access.tenant.timezone}
          />

          {/* Portal Switcher for Owners / Multi-Portal Roles */}
          {showNav && canSwitchPortal ? (
            isWarehousePortal ? (
              <Button
                variant="outline"
                size="sm"
                data-testid="switch-pos-portal"
                onClick={() => switchPortal("pos")}
              >
                <ShoppingCart size={14} aria-hidden />
                <span className="hidden sm:inline">{t("admin:portal.switchToPos")}</span>
              </Button>
            ) : (
              <Button
                variant="outline"
                size="sm"
                className={hideDockedSidebar ? "border-ink-line-2 bg-ink-2 text-text-on-dark hover:border-lime hover:text-lime" : ""}
                data-testid="switch-warehouse-portal"
                onClick={() => switchPortal("warehouse")}
              >
                <Warehouse size={14} className={hideDockedSidebar ? "text-lime" : "text-amber-700"} aria-hidden />
                <span className="hidden sm:inline">{t("admin:portal.switchToWarehouse")}</span>
              </Button>
            )
          ) : null}

          {isSellRoute && showNav ? (
            <>
              <Button
                variant="ghost"
                size="sm"
                className={hideDockedSidebar ? "px-2 text-muted-on-dark hover:bg-ink-2 hover:text-lime" : "px-2"}
                data-testid="fullscreen-kiosk-btn"
                onClick={() => void toggleFullscreenKiosk()}
                aria-label={isFullscreen ? t("admin:sell.exitFullscreen") : t("admin:sell.enterFullscreen")}
                title={isFullscreen ? t("admin:sell.exitFullscreen") : t("admin:sell.enterFullscreen")}
              >
                {isFullscreen ? <Minimize2 size={16} aria-hidden /> : <Maximize2 size={16} aria-hidden />}
              </Button>
              <Button
                variant="ghost"
                size="sm"
                className={
                  hideDockedSidebar
                    ? "hidden px-2 text-muted-on-dark hover:bg-ink-2 hover:text-lime md:inline-flex"
                    : "hidden px-2 md:inline-flex"
                }
                data-testid="kiosk-mode-toggle"
                onClick={toggleKioskMode}
                aria-label={hideDockedSidebar ? t("admin:sell.dockSidebar") : t("admin:sell.kioskMode")}
                title={hideDockedSidebar ? t("admin:sell.dockSidebar") : t("admin:sell.kioskMode")}
              >
                {hideDockedSidebar ? <PanelLeft size={16} aria-hidden /> : <PanelLeftClose size={16} aria-hidden />}
              </Button>
            </>
          ) : null}

          <Button
            variant="ghost"
            size="sm"
            className={hideDockedSidebar ? "px-2 text-muted-on-dark hover:bg-ink-2 hover:text-lime" : "px-2"}
            data-testid="theme-toggle"
            aria-label={`${t("common:theme.label")}: ${t(`common:theme.${theme}`)}`}
            title={`${t("common:theme.label")}: ${t(`common:theme.${theme}`)}`}
            onClick={() => setTheme(nextTheme(theme))}
          >
            <ThemeIcon size={16} aria-hidden />
          </Button>

          {!showNav ? (
            <Button variant="outline" size="sm" onClick={() => void leave()}>
              {t("common:actions.signOut")}
            </Button>
          ) : null}
        </header>

        <main
          className={
            isSellRoute
              ? "grid min-h-0 flex-1 lg:overflow-hidden"
              : "mx-auto grid w-full max-w-6xl gap-6 px-4 pt-6 pb-24 sm:px-6 md:pb-8"
          }
        >
          {!isOnline ? (
            <div
              role="status"
              aria-live="polite"
              data-testid="offline-banner"
              className="m-4 flex items-start gap-3 rounded-[20px] border-[1.5px] border-ink bg-ink p-4 text-sm text-text-on-dark"
            >
              <WifiOff className="mt-0.5 size-5 shrink-0 text-lime" aria-hidden />
              <div>
                <p className="font-semibold text-lime">{t("common:offline.bannerTitle")}</p>
                <p className="mt-1 text-xs text-muted-on-dark">{t("common:offline.bannerDescription")}</p>
              </div>
            </div>
          ) : null}
          {access.tenant.status !== "active" ? (
            <p role="alert" className="m-4 rounded-[16px] border-[1.5px] border-sw-pastry-fg/20 bg-sw-pastry px-4 py-3 text-sm font-medium text-sw-pastry-fg">
              {t("admin:suspended")}
            </p>
          ) : null}
          <Outlet />
        </main>

        {showNav && !isSellRoute ? (
          <nav
            aria-label={t("admin:nav.label")}
            className="fixed inset-x-0 bottom-0 z-30 flex items-center justify-around gap-1 border-t-[1.5px] border-ink-line bg-ink px-2 py-2 text-text-on-dark md:hidden"
          >
            {visible.slice(0, 4).map((n) => {
              const Icon = n.icon;
              return (
                <Link
                  key={n.to}
                  to={n.to}
                  activeOptions={{ exact: n.to === "/app" }}
                  className="flex min-h-[44px] min-w-0 flex-1 flex-col items-center justify-center gap-0.5 rounded-[14px] px-1.5 py-1 text-[11px] font-medium transition-colors [&:not([aria-current='page'])]:text-muted-on-dark [&:not([aria-current='page'])]:hover:text-lime"
                  activeProps={{
                    className: "bg-lime font-semibold text-ink hover:text-ink",
                    "aria-current": "page",
                  }}
                >
                  <Icon size={17} strokeWidth={1.75} aria-hidden />
                  <span className="max-w-full truncate">{t(`admin:nav.${n.key}`)}</span>
                </Link>
              );
            })}
            <button
              type="button"
              onClick={() => setMenuOpen(true)}
              className="flex min-h-[44px] min-w-0 flex-1 cursor-pointer flex-col items-center justify-center gap-0.5 rounded-[14px] px-1.5 py-1 text-[11px] font-medium text-muted-on-dark transition-colors hover:text-lime"
            >
              <Menu size={17} strokeWidth={1.75} aria-hidden />
              <span className="max-w-full truncate">{t("admin:nav.menu")}</span>
            </button>
          </nav>
        ) : null}
      </div>
    </div>
  );
}

/** Home: Clean workspace launcher and assigned locations overview without debug permission clutter. */
export function DashboardPage() {
  const { t } = useTranslation("admin");
  const navigate = useNavigate();
  const { access, can } = useSession();
  const mode = tenantMode(access);
  const allowedPortals = resolveAllowedPortals(access, mode);
  const modules = (["inventory", "pos", "warehouse"] as const).filter((m) => access.modules[m]);

  if (!access.tenant.setup_completed) {
    return (
      <Card>
        <p>{t("dashboard.setupPending")}</p>
      </Card>
    );
  }

  return (
    <div className="grid gap-6">
      <PageHeader
        title={access.tenant.name}
        subtitle={`${access.tenant.base_currency} · ${access.tenant.timezone}`}
        actions={
          <div className="flex flex-wrap items-center gap-1.5">
            {modules.map((m) => (
              <Badge key={m} tone="good">
                {t(`modules.${m}`)}
              </Badge>
            ))}
          </div>
        }
      />

      {mode === "full" && allowedPortals.length > 0 ? (
        <div className="grid gap-4 sm:grid-cols-2">
          {allowedPortals.includes("pos") && can("sale.create") ? (
            <Card className="grid content-between gap-5" data-testid="portal-card-pos">
              <div className="flex items-start gap-3.5">
                <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-[16px] bg-ink text-lime">
                  <ShoppingCart size={20} aria-hidden />
                </div>
                <div className="grid gap-1">
                  <div className="flex items-center gap-2">
                    <h2 className="font-display text-lg font-extrabold tracking-[-0.02em] text-slate-900">
                      {t("portal.posPortalTitle")}
                    </h2>
                    <Badge tone="good">{t("portal.posBadge")}</Badge>
                  </div>
                  <p className="text-sm text-slate-500">{t("portal.posPortalDesc")}</p>
                </div>
              </div>
              <div className="flex flex-wrap gap-2">
                <Button
                  onClick={() => {
                    saveStoredPortal("pos");
                    void navigate({ to: "/app/sell" });
                  }}
                >
                  {t("portal.openPosBtn")}
                </Button>
                <Button
                  variant="outline"
                  onClick={() => {
                    saveStoredPortal("pos");
                    void navigate({ to: "/app/inventory" });
                  }}
                >
                  {t("inventory.storeTitle")}
                </Button>
                {access.modules.warehouse ? (
                  <Button
                    variant="outline"
                    onClick={() => {
                      saveStoredPortal("pos");
                      void navigate({ to: "/app/receive-stock" });
                    }}
                  >
                    {t("portal.receiveStockBtn")}
                  </Button>
                ) : null}
              </div>
            </Card>
          ) : null}

          {allowedPortals.includes("warehouse") ? (
            <Card className="grid content-between gap-5" data-testid="portal-card-warehouse">
              <div className="flex items-start gap-3.5">
                <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-[16px] bg-sw-pastry text-sw-pastry-fg">
                  <Warehouse size={20} aria-hidden />
                </div>
                <div className="grid gap-1">
                  <div className="flex items-center gap-2">
                    <h2 className="font-display text-lg font-extrabold tracking-[-0.02em] text-slate-900">
                      {t("portal.warehousePortalTitle")}
                    </h2>
                    <Badge tone="warn">{t("portal.warehouseBadge")}</Badge>
                  </div>
                  <p className="text-sm text-slate-500">{t("portal.warehousePortalDesc")}</p>
                </div>
              </div>
              <div className="flex flex-wrap gap-2">
                <Button
                  variant={allowedPortals.includes("pos") && can("sale.create") ? "outline" : "primary"}
                  onClick={() => {
                    saveStoredPortal("warehouse");
                    void navigate({ to: "/app/warehouses" });
                  }}
                >
                  {t("portal.openWarehouseBtn")}
                </Button>
                <Button
                  variant="outline"
                  onClick={() => {
                    saveStoredPortal("warehouse");
                    void navigate({ to: "/app/inventory" });
                  }}
                >
                  {t("inventory.warehouseTitle")}
                </Button>
              </div>
            </Card>
          ) : null}
        </div>
      ) : null}

      <section className="grid gap-3">
        <h2 className="font-mono text-xs font-semibold tracking-[0.08em] text-slate-500 uppercase">
          {t("dashboard.yourLocations")}
        </h2>
        {access.locations.length === 0 ? (
          <Card>
            <p className="text-sm text-slate-500">{t("dashboard.noLocations")}</p>
          </Card>
        ) : (
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {access.locations.map((loc) => {
              const isWh = loc.type === "warehouse";
              return (
                <Card key={loc.id} data-testid={`loc-${loc.code}`} className="flex items-start gap-3 p-4 sm:p-5">
                  <div
                    className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-[12px] ${
                      isWh ? "bg-sw-pastry text-sw-pastry-fg" : "bg-ink text-lime"
                    }`}
                  >
                    {isWh ? <Warehouse size={17} aria-hidden /> : <Store size={17} aria-hidden />}
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-sm font-semibold text-slate-900">{loc.name}</div>
                    <div className="mt-1 flex flex-wrap items-center gap-1.5 text-xs text-slate-500">
                      <span className="font-mono">{loc.code}</span>
                      <span>·</span>
                      <span>{t(`locations.type.${loc.type}`)}</span>
                      {loc.position ? <Badge tone="neutral">{t(`positions.${loc.position}`)}</Badge> : null}
                    </div>
                  </div>
                </Card>
              );
            })}
          </div>
        )}
      </section>
    </div>
  );
}

export function ForbiddenPage() {
  const { t } = useTranslation("admin");
  return (
    <Card>
      <p>{t("forbidden")}</p>
    </Card>
  );
}
