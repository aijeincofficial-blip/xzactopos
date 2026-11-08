import { useState } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { formatMoney, money } from "@pos/core";
import { Alert, Badge, Button, Card, Dialog, Input, Select } from "../components/ui.tsx";
import { useSession } from "../lib/session.tsx";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import {
  fetchPlatformMetrics,
  fetchPlatformTenants,
  provisionPlatformTenant,
  setPlatformTenantPlan,
  setPlatformTenantStatus,
  type PlatformTenant,
} from "../lib/platform-api.ts";

function Labeled({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="grid gap-1 text-sm">
      <span className="font-medium text-slate-700">{label}</span>
      {children}
    </label>
  );
}

/** Dialog to suspend or reactivate a business tenant */
function StatusModal({
  tenant,
  onClose,
}: {
  tenant: PlatformTenant | null;
  onClose: () => void;
}) {
  const { t } = useTranslation(["admin", "common"]);
  const qc = useQueryClient();
  const msg = useErrorMessage();
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);

  const nextStatus = tenant?.status === "active" ? "suspended" : "active";

  const mutation = useMutation({
    mutationFn: () => {
      if (!tenant) throw new Error("No tenant");
      return setPlatformTenantStatus(tenant.id, nextStatus, reason);
    },
    onSuccess: async () => {
      await Promise.all([
        qc.invalidateQueries({ queryKey: ["platform-tenants"] }),
        qc.invalidateQueries({ queryKey: ["platform-metrics"] }),
      ]);
      onClose();
    },
    onError: (e) => setError(msg(e)),
  });

  if (!tenant) return null;

  return (
    <Dialog open={Boolean(tenant)} onOpenChange={(open) => !open && onClose()} title={t("platform.confirmStatus")} closeLabel={t("common:actions.close")}>
      <div className="grid gap-3">
        <p className="text-sm text-slate-600">
          {nextStatus === "suspended"
            ? `Suspend business "${tenant.name}" (${tenant.slug})? Active cashiers and managers will be blocked from logging in or changing data.`
            : `Reactivate business "${tenant.name}" (${tenant.slug})? Staff access will be restored immediately.`}
        </p>

        <Labeled label={t("platform.reasonPrompt")}>
          <Input
            value={reason}
            placeholder={t("platform.reasonPlaceholder")}
            onChange={(e) => setReason(e.target.value)}
          />
        </Labeled>

        {error ? <Alert>{error}</Alert> : null}

        <div className="flex justify-end gap-2 mt-2">
          <Button variant="ghost" onClick={onClose}>
            {t("sell.cancel")}
          </Button>
          <Button
            variant={nextStatus === "suspended" ? "danger" : "primary"}
            disabled={mutation.isPending}
            onClick={() => mutation.mutate()}
          >
            {mutation.isPending
              ? t("platform.title")
              : nextStatus === "suspended"
              ? t("platform.suspendAction")
              : t("platform.activateAction")}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}

/** Dialog to adjust subscription plan and resource quota limits */
function PlanLimitsModal({
  tenant,
  onClose,
}: {
  tenant: PlatformTenant | null;
  onClose: () => void;
}) {
  const { t } = useTranslation(["admin", "common"]);
  const qc = useQueryClient();
  const msg = useErrorMessage();

  const [plan, setPlan] = useState<"free" | "pro">(tenant?.plan ?? "free");
  const [maxLocs, setMaxLocs] = useState(String(tenant?.max_locations ?? 25));
  const [maxUsers, setMaxUsers] = useState(String(tenant?.max_users ?? 100));
  const [maxDevs, setMaxDevs] = useState(String(tenant?.max_devices ?? 50));
  const [maxProds, setMaxProds] = useState(String(tenant?.max_products ?? 10000));
  const [error, setError] = useState<string | null>(null);

  const mutation = useMutation({
    mutationFn: () => {
      if (!tenant) throw new Error("No tenant");
      return setPlatformTenantPlan(tenant.id, plan, {
        max_locations: parseInt(maxLocs, 10) || 25,
        max_users: parseInt(maxUsers, 10) || 100,
        max_devices: parseInt(maxDevs, 10) || 50,
        max_products: parseInt(maxProds, 10) || 10000,
      });
    },
    onSuccess: async () => {
      await Promise.all([
        qc.invalidateQueries({ queryKey: ["platform-tenants"] }),
        qc.invalidateQueries({ queryKey: ["platform-metrics"] }),
      ]);
      onClose();
    },
    onError: (e) => setError(msg(e)),
  });

  if (!tenant) return null;

  return (
    <Dialog open={Boolean(tenant)} onOpenChange={(open) => !open && onClose()} title={t("platform.planDialogTitle")} closeLabel={t("common:actions.close")}>
      <div className="grid gap-3">
        <p className="text-xs text-slate-500">
          Managing infrastructure subscription and quota ceilings for <strong>{tenant.name}</strong>.
        </p>

        <Labeled label={t("platform.selectPlan")}>
          <Select value={plan} onChange={(e) => setPlan(e.target.value as "free" | "pro")}>
            <option value="free">Free Tier (Solo)</option>
            <option value="pro">Pro Plan (Full Multi-Store)</option>
          </Select>
        </Labeled>

        <div className="grid grid-cols-2 gap-2">
          <Labeled label={t("platform.maxLocations")}>
            <Input type="number" min="1" value={maxLocs} onChange={(e) => setMaxLocs(e.target.value)} />
          </Labeled>
          <Labeled label={t("platform.maxUsers")}>
            <Input type="number" min="1" value={maxUsers} onChange={(e) => setMaxUsers(e.target.value)} />
          </Labeled>
          <Labeled label={t("platform.maxDevices")}>
            <Input type="number" min="1" value={maxDevs} onChange={(e) => setMaxDevs(e.target.value)} />
          </Labeled>
          <Labeled label={t("platform.maxProducts")}>
            <Input type="number" min="1" value={maxProds} onChange={(e) => setMaxProds(e.target.value)} />
          </Labeled>
        </div>

        {error ? <Alert>{error}</Alert> : null}

        <div className="flex justify-end gap-2 mt-2">
          <Button variant="ghost" onClick={onClose}>
            {t("sell.cancel")}
          </Button>
          <Button disabled={mutation.isPending} onClick={() => mutation.mutate()}>
            {mutation.isPending ? t("products.save") : t("products.save")}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}

/** Dialog to provision a brand-new business tenant */
function ProvisionModal({
  open,
  onClose,
}: {
  open: boolean;
  onClose: () => void;
}) {
  const { t } = useTranslation(["admin", "common"]);
  const qc = useQueryClient();
  const msg = useErrorMessage();

  const [name, setName] = useState("");
  const [slug, setSlug] = useState("");
  const [baseCurrency, setBaseCurrency] = useState("PHP");
  const [ownerUserId, setOwnerUserId] = useState("");
  const [ownerUsername, setOwnerUsername] = useState("");
  const [ownerFullName, setOwnerFullName] = useState("");
  const [preset, setPreset] = useState("all");
  const [timezone, setTimezone] = useState("Asia/Manila");
  const [error, setError] = useState<string | null>(null);

  const mutation = useMutation({
    mutationFn: () =>
      provisionPlatformTenant({
        name,
        slug,
        baseCurrency,
        ownerUserId,
        ownerUsername,
        preset,
        timezone,
        ownerFullName,
      }),
    onSuccess: async () => {
      setName("");
      setSlug("");
      setOwnerUserId("");
      setOwnerUsername("");
      setOwnerFullName("");
      await Promise.all([
        qc.invalidateQueries({ queryKey: ["platform-tenants"] }),
        qc.invalidateQueries({ queryKey: ["platform-metrics"] }),
      ]);
      onClose();
    },
    onError: (e) => setError(msg(e)),
  });

  return (
    <Dialog open={open} onOpenChange={(o) => !o && onClose()} title={t("platform.provisionTitle")} closeLabel={t("common:actions.close")}>
      <div className="grid gap-3">
        <div className="grid sm:grid-cols-2 gap-2">
          <Labeled label={t("platform.businessName")}>
            <Input value={name} maxLength={80} onChange={(e) => setName(e.target.value)} />
          </Labeled>
          <Labeled label={t("platform.businessSlug")}>
            <Input
              value={slug}
              maxLength={40}
              placeholder="e.g. acme-corp"
              onChange={(e) => setSlug(e.target.value.toLowerCase().replace(/[^a-z0-9-]/g, ""))}
            />
          </Labeled>
        </div>

        <div className="grid sm:grid-cols-2 gap-2">
          <Labeled label={t("platform.baseCurrency")}>
            <Select value={baseCurrency} onChange={(e) => setBaseCurrency(e.target.value)}>
              <option value="PHP">PHP (Philippine Peso)</option>
              <option value="USD">USD (US Dollar)</option>
            </Select>
          </Labeled>
          <Labeled label={t("platform.timezone")}>
            <Select value={timezone} onChange={(e) => setTimezone(e.target.value)}>
              <option value="Asia/Manila">Asia/Manila (GMT+8)</option>
              <option value="UTC">UTC (Universal)</option>
            </Select>
          </Labeled>
        </div>

        <div className="grid sm:grid-cols-2 gap-2">
          <Labeled label={t("platform.ownerUsername")}>
            <Input
              value={ownerUsername}
              placeholder="e.g. owner"
              onChange={(e) => setOwnerUsername(e.target.value.toLowerCase())}
            />
          </Labeled>
          <Labeled label={t("platform.ownerUserId")}>
            <Input
              value={ownerUserId}
              placeholder="auth.users UUID"
              onChange={(e) => setOwnerUserId(e.target.value.trim())}
            />
          </Labeled>
        </div>

        <Labeled label={t("platform.preset")}>
          <Select value={preset} onChange={(e) => setPreset(e.target.value)}>
            <option value="all">{t("platform.presetAll")}</option>
            <option value="pos">{t("platform.presetPos")}</option>
            <option value="warehouse">{t("platform.presetWarehouse")}</option>
          </Select>
        </Labeled>

        {error ? <Alert>{error}</Alert> : null}

        <div className="flex justify-end gap-2 mt-2">
          <Button variant="ghost" onClick={onClose}>
            {t("sell.cancel")}
          </Button>
          <Button
            disabled={mutation.isPending || !name.trim() || !slug.trim() || !ownerUserId.trim() || !ownerUsername.trim()}
            onClick={() => mutation.mutate()}
          >
            {mutation.isPending ? t("products.save") : t("platform.provisionBtn")}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}

/** Platform Administration Page */
export function PlatformPage() {
  const { t, i18n } = useTranslation(["admin", "common"]);
  const { access } = useSession();

  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [statusTarget, setStatusTarget] = useState<PlatformTenant | null>(null);
  const [planTarget, setPlanTarget] = useState<PlatformTenant | null>(null);
  const [showProvision, setShowProvision] = useState(false);

  const metricsQuery = useQuery({
    queryKey: ["platform-metrics"],
    queryFn: fetchPlatformMetrics,
    enabled: Boolean(access.is_platform_admin),
  });

  const tenantsQuery = useQuery({
    queryKey: ["platform-tenants", search, statusFilter],
    queryFn: () => fetchPlatformTenants(search, statusFilter),
    enabled: Boolean(access.is_platform_admin),
  });

  if (!access.is_platform_admin) {
    return (
      <div className="p-6">
        <Alert>{t("platform.notAuthorized")}</Alert>
      </div>
    );
  }

  const m = metricsQuery.data;
  const tenants = tenantsQuery.data ?? [];
  const fmt = (minor: number, cur: string) => formatMoney(money(minor, cur), i18n.language);

  return (
    <div className="grid gap-6">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold tracking-tight text-slate-900">{t("platform.title")}</h2>
          <p className="text-xs text-slate-500 mt-0.5">{t("platform.subtitle")}</p>
        </div>
        <Button onClick={() => setShowProvision(true)}>
          + {t("platform.provisionBtn")}
        </Button>
      </div>

      {/* KPI Cards */}
      {m ? (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <Card className="grid gap-1">
            <span className="text-xs text-slate-500 font-medium uppercase">{t("platform.totalTenants")}</span>
            <div className="text-2xl font-bold text-slate-900">{m.total_tenants}</div>
            <div className="flex gap-2 text-xs text-slate-600 mt-1">
              <span className="text-emerald-700 font-medium">{m.active_tenants} {t("platform.activeTenants")}</span>
              <span>·</span>
              <span className="text-amber-700 font-medium">{m.suspended_tenants} {t("platform.suspendedTenants")}</span>
            </div>
          </Card>

          <Card className="grid gap-1">
            <span className="text-xs text-slate-500 font-medium uppercase">{t("platform.proTenants")}</span>
            <div className="text-2xl font-bold text-indigo-700">{m.pro_tenants}</div>
            <div className="text-xs text-slate-500 mt-1">
              {m.total_tenants - m.pro_tenants} Free Tier
            </div>
          </Card>

          <Card className="grid gap-1">
            <span className="text-xs text-slate-500 font-medium uppercase">{t("platform.totalUsers")}</span>
            <div className="text-2xl font-bold text-slate-900">{m.total_users}</div>
            <div className="text-xs text-slate-500 mt-1">
              {m.total_sales_count.toLocaleString()} completed sales
            </div>
          </Card>

          <Card className="grid gap-1.5">
            <div className="flex justify-between items-center text-xs">
              <span className="text-slate-500 font-medium uppercase">{t("platform.storageQuota")}</span>
              <Badge tone={m.storage.status === "healthy" ? "good" : "warn"}>
                {m.storage.used_mb} MB / 500 MB
              </Badge>
            </div>
            <div className="h-2 w-full bg-slate-100 rounded-full overflow-hidden mt-1">
              <div
                className={`h-full transition-all ${
                  m.storage.status === "critical"
                    ? "bg-rose-500"
                    : m.storage.status === "warning"
                    ? "bg-amber-500"
                    : "bg-emerald-500"
                }`}
                style={{ width: `${Math.min(m.storage.percent_used, 100)}%` }}
              />
            </div>
            <span className="text-xs text-slate-500 text-right">{m.storage.percent_used}% used</span>
          </Card>
        </div>
      ) : null}

      {/* Filter and Search Bar */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap items-center gap-2 flex-1 max-w-lg">
          <Input
            placeholder={t("platform.searchPlaceholder")}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          <Select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)} className="w-40">
            <option value="">{t("platform.filterAll")}</option>
            <option value="active">Active</option>
            <option value="suspended">Suspended</option>
            <option value="archived">Archived</option>
          </Select>
        </div>
      </div>

      {/* Tenants Table */}
      <Card className="overflow-x-auto p-0">
        <table className="w-full text-left text-sm">
          <thead className="bg-slate-50 text-slate-500 uppercase text-xs border-b border-slate-200">
            <tr>
              <th className="p-3">{t("platform.colBusiness")}</th>
              <th className="p-3">{t("platform.colPlan")}</th>
              <th className="p-3">{t("platform.colStatus")}</th>
              <th className="p-3 text-center">{t("platform.colLocations")}</th>
              <th className="p-3 text-center">{t("platform.colStaff")}</th>
              <th className="p-3 text-right">{t("platform.colSales")}</th>
              <th className="p-3">{t("platform.colCreated")}</th>
              <th className="p-3 text-right">{t("platform.colActions")}</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {tenants.map((tn) => (
              <tr key={tn.id} className="hover:bg-slate-50">
                <td className="p-3">
                  <div className="font-semibold text-slate-900">{tn.name}</div>
                  <div className="text-xs text-slate-500 font-mono">{tn.slug}</div>
                </td>
                <td className="p-3">
                  <Badge tone={tn.plan === "pro" ? "good" : "neutral"}>
                    {tn.plan === "pro" ? "Pro" : "Free"}
                  </Badge>
                </td>
                <td className="p-3">
                  <Badge tone={tn.status === "active" ? "good" : tn.status === "suspended" ? "warn" : "neutral"}>
                    {tn.status}
                  </Badge>
                </td>
                <td className="p-3 text-center text-xs">
                  <span className="font-semibold">{tn.store_count}</span> stores ·{" "}
                  <span className="font-semibold">{tn.warehouse_count}</span> wh
                </td>
                <td className="p-3 text-center text-xs font-semibold">{tn.user_count}</td>
                <td className="p-3 text-right font-medium">
                  {fmt(tn.gross_sales, tn.base_currency)}
                </td>
                <td className="p-3 text-xs text-slate-500">
                  {new Date(tn.created_at).toLocaleDateString()}
                </td>
                <td className="p-3 text-right">
                  <div className="flex justify-end gap-1.5">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => setPlanTarget(tn)}
                    >
                      {t("platform.planLimitsAction")}
                    </Button>
                    <Button
                      variant={tn.status === "active" ? "danger" : "outline"}
                      size="sm"
                      onClick={() => setStatusTarget(tn)}
                    >
                      {tn.status === "active" ? t("platform.suspendAction") : t("platform.activateAction")}
                    </Button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>

      {/* Modals */}
      <StatusModal tenant={statusTarget} onClose={() => setStatusTarget(null)} />
      <PlanLimitsModal tenant={planTarget} onClose={() => setPlanTarget(null)} />
      <ProvisionModal open={showProvision} onClose={() => setShowProvision(false)} />
    </div>
  );
}
