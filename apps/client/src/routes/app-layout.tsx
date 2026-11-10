import { useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import { Link, Outlet, useNavigate, useRouterState } from "@tanstack/react-router";
import { useQueryClient } from "@tanstack/react-query";
import {
  ArrowLeftRight,
  Banknote,
  BarChart3,
  Blocks,
  Boxes,
  ClipboardCheck,
  HandCoins,
  Home,
  type LucideIcon,
  MapPin,
  Menu,
  Monitor,
  Moon,
  Package,
  PowerOff,
  Receipt,
  Rocket,
  Settings,
  ShieldCheck,
  ShoppingCart,
  Sun,
  Truck,
  Users,
  Warehouse,
  WifiOff,
  X,
} from "lucide-react";
import { accessQuery } from "../lib/session.tsx";
import { PERMISSION_KEYS, type PermissionKey } from "@pos/core";
import { saveMyLocale, signOut } from "../lib/api.ts";
import { tenantMode } from "../lib/mode.ts";
import { pickLocale, storeLocale } from "../i18n/index.ts";
import { useSession } from "../lib/session.tsx";
import { useActiveLocation } from "../lib/location-context.tsx";
import { applyTheme, nextTheme, readTheme, type ThemeChoice } from "../lib/theme.ts";
import { Badge, Button, Card } from "../components/ui.tsx";
import { LanguageSelect } from "../components/LanguageSelect.tsx";
import { useOnlineStatus } from "../lib/network.ts";

type NavGroup = "daily" | "stock" | "business";

const NAV = [
  { to: "/app", key: "dashboard", icon: Home, group: "daily", perm: null, fullOnly: false },
  { to: "/app/sell", key: "sell", icon: ShoppingCart, group: "daily", perm: "sale.create", fullOnly: false },
  { to: "/app/sales", key: "sales", icon: Receipt, group: "daily", perm: "sale.create", fullOnly: false },
  { to: "/app/utang", key: "utang", icon: HandCoins, group: "daily", perm: "sale.create", fullOnly: false },
  { to: "/app/expenses", key: "expenses", icon: Banknote, group: "daily", perm: "shift.manage", fullOnly: false },
  { to: "/app/day-close", key: "dayClose", icon: PowerOff, group: "daily", perm: "shift.manage", fullOnly: false },
  { to: "/app/products", key: "products", icon: Package, group: "stock", perm: "catalog.manage", fullOnly: false },
  { to: "/app/transfers", key: "transfers", icon: ArrowLeftRight, group: "stock", perm: null, perms: ["transfer.manage", "stock.adjust_store"] as const, fullOnly: true },
  { to: "/app/bins", key: "bins", icon: Boxes, group: "stock", perm: null, perms: ["transfer.manage", "stock.adjust_store", "locations.manage"] as const, fullOnly: true },
  { to: "/app/purchasing", key: "purchasing", icon: Truck, group: "stock", perm: "purchasing.manage", fullOnly: true },
  { to: "/app/counts", key: "counts", icon: ClipboardCheck, group: "stock", perm: "stock.adjust_warehouse", fullOnly: true },
  { to: "/app/warehouses", key: "overview", icon: Warehouse, group: "stock", perm: "reports.warehouse", fullOnly: true },
  { to: "/app/reports", key: "reports", icon: BarChart3, group: "business", perm: null, perms: ["reports.store", "reports.warehouse"] as const, fullOnly: true },
  { to: "/app/upgrade", key: "upgrade", icon: Rocket, group: "business", perm: "tenant.modules", fullOnly: false, soloOnly: true },
  { to: "/app/locations", key: "locations", icon: MapPin, group: "business", perm: "locations.manage", fullOnly: true },
  { to: "/app/users", key: "users", icon: Users, group: "business", perm: "users.manage", fullOnly: true },
  { to: "/app/modules", key: "modules", icon: Blocks, group: "business", perm: "tenant.modules", fullOnly: true },
  { to: "/app/settings", key: "settings", icon: Settings, group: "business", perm: "tenant.settings", fullOnly: false },
  { to: "/app/platform", key: "platform", icon: ShieldCheck, group: "business", perm: null, fullOnly: false, platformAdminOnly: true },
] as const satisfies ReadonlyArray<{
  to: string;
  key: string;
  icon: LucideIcon;
  group: NavGroup;
  perm: PermissionKey | null;
  perms?: readonly PermissionKey[];
  fullOnly: boolean;
  soloOnly?: boolean;
  platformAdminOnly?: boolean;
}>;

const GROUPS: readonly NavGroup[] = ["daily", "stock", "business"];
const THEME_ICON: Record<ThemeChoice, LucideIcon> = { system: Monitor, light: Sun, dark: Moon };

export function AppLayout() {
  const { t, i18n } = useTranslation(["common", "admin"]);
  const { access, can } = useSession();
  const { activeStoreId, stores, setActiveStoreId } = useActiveLocation();
  const isOnline = useOnlineStatus();
  const mode = tenantMode(access);
  const qc = useQueryClient();
  const navigate = useNavigate();
  const [menuOpen, setMenuOpen] = useState(false);
  const [theme, setTheme] = useState<ThemeChoice>(readTheme);
  const path = useRouterState({ select: (s) => s.location.pathname });
  const ThemeIcon = THEME_ICON[theme];

  useEffect(() => applyTheme(theme), [theme]);
  // a phone user picks a screen and the drawer gets out of the way
  useEffect(() => setMenuOpen(false), [path]);

  // Apply the user's saved language once per sign-in (profile locale, else tenant default).
  // Later manual changes are not overridden because this only re-runs for a different user.
  useEffect(() => {
    const l = pickLocale(access.locale, null);
    void i18n.changeLanguage(l);
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
    await signOut();
    qc.clear();
    await navigate({ to: "/t/$slug", params: { slug: access.tenant.slug } });
  }

  const visible = NAV.filter((n) => {
    if ("platformAdminOnly" in n && n.platformAdminOnly && !access.is_platform_admin) return false;
    const permOk = "perms" in n && n.perms ? (n.perms as readonly PermissionKey[]).some((p) => can(p)) : n.perm === null || can(n.perm);
    return permOk && (!n.fullOnly || mode === "full") && (!("soloOnly" in n && n.soloOnly) || mode === "solo");
  });
  const showNav = access.tenant.setup_completed;

  const sidebar = (
    <nav aria-label={t("admin:nav.label")} className="grid content-start gap-5 overflow-y-auto px-3 py-4">
      {GROUPS.map((g) => {
        const items = visible.filter((n) => n.group === g);
        if (items.length === 0) return null;
        return (
          <div key={g} className="grid gap-0.5">
            <div className="px-2 pb-1 text-xs font-semibold tracking-wider text-slate-400 uppercase">{t(`admin:nav.group.${g}`)}</div>
            {items.map((n) => {
              const Icon = n.icon;
              return (
                <Link
                  key={n.to}
                  to={n.to}
                  activeOptions={{ exact: n.to === "/app" }}
                  className="flex items-center gap-2.5 rounded-md px-2.5 py-1.5 text-sm text-slate-600 hover:bg-slate-100 hover:text-slate-900"
                  activeProps={{ className: "bg-brand-50 font-semibold text-brand-text hover:bg-brand-50 hover:text-brand-text", "aria-current": "page" }}
                >
                  <Icon size={17} aria-hidden />
                  {t(`admin:nav.${n.key}`)}
                </Link>
              );
            })}
          </div>
        );
      })}
    </nav>
  );

  const identity = (
    <div className="border-b border-slate-200 px-4 py-3">
      <div className="truncate font-semibold">{access.tenant.name}</div>
      <div className="truncate text-xs text-slate-500">
        {access.full_name || access.username} · {t(`admin:roles.${access.role}`)}
      </div>
    </div>
  );

  return (
    <div className="min-h-screen md:grid md:grid-cols-[15rem_1fr]">
      {showNav ? (
        <>
          <aside className="sticky top-0 hidden h-screen grid-rows-[auto_1fr] border-r border-slate-200 bg-white md:grid">
            {identity}
            {sidebar}
          </aside>
          {menuOpen ? (
            <div className="fixed inset-0 z-40 md:hidden">
              <button aria-label={t("common:actions.close")} className="absolute inset-0 bg-black/50" onClick={() => setMenuOpen(false)} />
              <aside className="absolute inset-y-0 left-0 grid w-64 grid-rows-[auto_1fr] bg-white shadow-xl">
                <div className="flex items-center justify-between">
                  {identity}
                  <button aria-label={t("common:actions.close")} className="mr-2 rounded p-1 hover:bg-slate-100" onClick={() => setMenuOpen(false)}>
                    <X size={18} />
                  </button>
                </div>
                {sidebar}
              </aside>
            </div>
          ) : null}
        </>
      ) : null}
      <div className="min-w-0">
        <header className="sticky top-0 z-30 flex flex-wrap items-center gap-2 border-b border-slate-200 bg-white/95 px-4 py-2 backdrop-blur">
          {showNav ? (
            <Button variant="ghost" size="sm" className="md:hidden" aria-label={t("admin:nav.menu")} onClick={() => setMenuOpen(true)}>
              <Menu size={18} />
            </Button>
          ) : null}
          <div className="mr-auto font-semibold md:hidden">{access.tenant.name}</div>
          <div className="mr-auto hidden md:block" />
          {stores.length > 1 ? (
            <div className="flex items-center gap-1.5 rounded-md border border-slate-200 bg-slate-50 px-2.5 py-1 text-xs">
              <span className="font-semibold text-slate-500">🏪 {t("admin:users.store")}:</span>
              <select
                value={activeStoreId ?? ""}
                onChange={(e) => setActiveStoreId(e.target.value)}
                className="cursor-pointer bg-transparent font-semibold text-slate-800 focus:outline-none"
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
          {!isOnline ? (
            <div data-testid="offline-badge">
              <Badge tone="warn">
                <span className="flex items-center gap-1">
                  <WifiOff size={13} aria-hidden />
                  <span>{t("common:offline.badge")}</span>
                </span>
              </Badge>
            </div>
          ) : null}
          <LanguageSelect onChoose={(l) => void chooseLocale(l)} />
          <Button
            variant="outline"
            size="sm"
            data-testid="theme-toggle"
            aria-label={`${t("common:theme.label")}: ${t(`common:theme.${theme}`)}`}
            title={`${t("common:theme.label")}: ${t(`common:theme.${theme}`)}`}
            onClick={() => setTheme(nextTheme(theme))}
          >
            <ThemeIcon size={16} aria-hidden />
          </Button>
          <Button variant="outline" size="sm" onClick={() => void leave()}>
            {t("common:actions.signOut")}
          </Button>
        </header>
        <main className="mx-auto grid max-w-6xl gap-4 px-4 py-6">
          {!isOnline ? (
            <div
              role="status"
              aria-live="polite"
              data-testid="offline-banner"
              className="flex items-start gap-3 rounded-lg border border-amber-300 bg-amber-50 p-3.5 text-sm text-amber-900 shadow-xs dark:border-amber-900/40 dark:bg-amber-950/30 dark:text-amber-200"
            >
              <WifiOff className="mt-0.5 size-5 shrink-0 text-amber-600 dark:text-amber-400" aria-hidden />
              <div>
                <p className="font-semibold">{t("common:offline.bannerTitle")}</p>
                <p className="mt-0.5 text-xs text-amber-800 dark:text-amber-300/90">{t("common:offline.bannerDescription")}</p>
              </div>
            </div>
          ) : null}
          {access.tenant.status !== "active" ? (
            <p role="alert" className="rounded-md bg-amber-50 px-3 py-2 text-sm text-amber-900">
              {t("admin:suspended")}
            </p>
          ) : null}
          <Outlet />
        </main>
      </div>
    </div>
  );
}

/** Home: what this user can do, store by store (an admin with two stores sees different actions per store). */
export function DashboardPage() {
  const { t } = useTranslation("admin");
  const { access, check } = useSession();
  const modules = (["inventory", "pos", "warehouse"] as const).filter((m) => access.modules[m]);

  if (!access.tenant.setup_completed) {
    return (
      <Card>
        <p>{t("dashboard.setupPending")}</p>
      </Card>
    );
  }

  return (
    <>
      <Card className="flex flex-wrap items-center gap-2">
        <span className="text-sm font-medium">{t("dashboard.modules")}</span>
        {modules.map((m) => (
          <Badge key={m} tone="good">
            {t(`modules.${m}`)}
          </Badge>
        ))}
        <span className="ml-auto text-sm text-slate-500">
          {access.tenant.base_currency} · {access.tenant.timezone}
        </span>
      </Card>

      <h2 className="text-lg font-semibold">{t("dashboard.yourLocations")}</h2>
      {access.locations.length === 0 ? (
        <Card>
          <p className="text-sm text-slate-600">{t("dashboard.noLocations")}</p>
        </Card>
      ) : (
        <div className="grid gap-3 sm:grid-cols-2">
          {access.locations.map((loc) => {
            const allowed = PERMISSION_KEYS.map((key) => ({ key, d: check(key, loc.id) })).filter((x) => x.d.allowed);
            return (
              <Card key={loc.id} data-testid={`loc-${loc.code}`}>
                <div className="mb-2 flex flex-wrap items-center gap-2">
                  <h3 className="font-medium">
                    {loc.code} · {loc.name}
                  </h3>
                  <Badge>{t(`locations.type.${loc.type}`)}</Badge>
                  {loc.position ? <Badge tone="warn">{t(`positions.${loc.position}`)}</Badge> : null}
                </div>
                {allowed.length === 0 ? (
                  <p className="text-sm text-slate-500">{t("dashboard.noActions")}</p>
                ) : (
                  <ul className="flex flex-wrap gap-1.5">
                    {allowed.map(({ key, d }) => (
                      <li key={key}>
                        <Badge>
                          {t(`perm.${key}`)}
                          {d.allowed && d.condition ? ` (${t(`condition.${d.condition}`)})` : ""}
                        </Badge>
                      </li>
                    ))}
                  </ul>
                )}
              </Card>
            );
          })}
        </div>
      )}
    </>
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
