import { useEffect } from "react";
import { useTranslation } from "react-i18next";
import { Link, Outlet, useNavigate } from "@tanstack/react-router";
import { useQueryClient } from "@tanstack/react-query";
import { accessQuery } from "../lib/session.tsx";
import { PERMISSION_KEYS, type PermissionKey } from "@pos/core";
import { saveMyLocale, signOut } from "../lib/api.ts";
import { tenantMode } from "../lib/mode.ts";
import { pickLocale, storeLocale } from "../i18n/index.ts";
import { useSession } from "../lib/session.tsx";
import { useActiveLocation } from "../lib/location-context.tsx";
import { Badge, Button, Card } from "../components/ui.tsx";
import { LanguageSelect } from "../components/LanguageSelect.tsx";

const NAV = [
  { to: "/app", key: "dashboard", perm: null, fullOnly: false },
  { to: "/app/sell", key: "sell", perm: "sale.create", fullOnly: false },
  { to: "/app/sales", key: "sales", perm: "sale.create", fullOnly: false },
  { to: "/app/products", key: "products", perm: "catalog.manage", fullOnly: false },
  { to: "/app/transfers", key: "transfers", perm: null, perms: ["transfer.manage", "stock.adjust_store"] as const, fullOnly: true },
  { to: "/app/bins", key: "bins", perm: null, perms: ["transfer.manage", "stock.adjust_store", "locations.manage"] as const, fullOnly: true },
  { to: "/app/purchasing", key: "purchasing", perm: "purchasing.manage", fullOnly: true },
  { to: "/app/counts", key: "counts", perm: "stock.adjust_warehouse", fullOnly: true },
  { to: "/app/warehouses", key: "overview", perm: "reports.warehouse", fullOnly: true },
  { to: "/app/utang", key: "utang", perm: "sale.create", fullOnly: false },
  { to: "/app/expenses", key: "expenses", perm: "shift.manage", fullOnly: false },
  { to: "/app/day-close", key: "dayClose", perm: "shift.manage", fullOnly: false },
  { to: "/app/reports", key: "reports", perm: null, perms: ["reports.store", "reports.warehouse"] as const, fullOnly: true },
  { to: "/app/upgrade", key: "upgrade", perm: "tenant.modules", fullOnly: false, soloOnly: true },
  { to: "/app/locations", key: "locations", perm: "locations.manage", fullOnly: true },
  { to: "/app/users", key: "users", perm: "users.manage", fullOnly: true },
  { to: "/app/modules", key: "modules", perm: "tenant.modules", fullOnly: true },
  { to: "/app/settings", key: "settings", perm: "tenant.settings", fullOnly: false },
  { to: "/app/platform", key: "platform", perm: null, fullOnly: false, platformAdminOnly: true },
] as const satisfies ReadonlyArray<{
  to: string;
  key: string;
  perm: PermissionKey | null;
  perms?: readonly PermissionKey[];
  fullOnly: boolean;
  soloOnly?: boolean;
  platformAdminOnly?: boolean;
}>;

export function AppLayout() {
  const { t, i18n } = useTranslation(["common", "admin"]);
  const { access, can } = useSession();
  const { activeStoreId, stores, setActiveStoreId } = useActiveLocation();
  const mode = tenantMode(access);
  const qc = useQueryClient();
  const navigate = useNavigate();

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

  return (
    <div className="min-h-screen">
      <header className="border-b border-slate-200 bg-white">
        <div className="mx-auto flex max-w-5xl flex-wrap items-center gap-3 px-4 py-3">
          <div className="mr-auto">
            <div className="font-semibold">{access.tenant.name}</div>
            <div className="text-xs text-slate-500">
              {access.full_name || access.username} · {t(`admin:roles.${access.role}`)}
            </div>
          </div>
          {stores.length > 1 ? (
            <div className="flex items-center gap-1.5 rounded-md border border-slate-200 bg-slate-50 px-2.5 py-1 text-xs">
              <span className="font-medium text-slate-500">🏪 {t("admin:users.store")}:</span>
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
          <LanguageSelect onChoose={(l) => void chooseLocale(l)} />
          <Button variant="outline" size="sm" onClick={() => void leave()}>
            {t("common:actions.signOut")}
          </Button>
        </div>
        {access.tenant.setup_completed ? (
          <nav aria-label={t("admin:nav.label")} className="mx-auto flex max-w-5xl gap-1 px-4">
            {NAV.filter((n) => {
              if ("platformAdminOnly" in n && n.platformAdminOnly && !access.is_platform_admin) return false;
              const permOk = "perms" in n && n.perms
                ? (n.perms as readonly PermissionKey[]).some((p) => can(p))
                : n.perm === null || can(n.perm);
              return permOk && (!n.fullOnly || mode === "full") && (!("soloOnly" in n && n.soloOnly) || mode === "solo");
            }).map((n) => (
              <Link
                key={n.to}
                to={n.to}
                activeOptions={{ exact: n.to === "/app" }}
                className="rounded-t-md border-b-2 border-transparent px-3 py-2 text-sm text-slate-600 hover:text-slate-900"
                activeProps={{ className: "border-slate-900 font-medium text-slate-900" }}
              >
                {t(`admin:nav.${n.key}`)}
              </Link>
            ))}
          </nav>
        ) : null}
      </header>
      <main className="mx-auto grid max-w-5xl gap-4 px-4 py-6">
        {access.tenant.status !== "active" ? (
          <p role="alert" className="rounded-md bg-amber-50 px-3 py-2 text-sm text-amber-900">
            {t("admin:suspended")}
          </p>
        ) : null}
        <Outlet />
      </main>
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
