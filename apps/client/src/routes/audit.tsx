import { useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
import { useQuery } from "@tanstack/react-query";
import { Download, Eye, RefreshCw, Search, ShieldAlert, X } from "lucide-react";
import { useSession } from "../lib/session.tsx";
import {
  classifyAuditCategory,
  fetchAuditActors,
  fetchAuditLogs,
  filterAuditLogs,
  isSecuritySensitiveAudit,
  summarizeAuditMeta,
  type AuditCategory,
  type AuditLogRow,
} from "../lib/audit-api.ts";
import { downloadCsv, exportAuditLogsCsv } from "../lib/csv-helper.ts";
import {
  Badge,
  Button,
  Card,
  Dialog,
  EmptyState,
  ErrorState,
  Field,
  Input,
  PageHeader,
  Select,
  Table,
  TableSkeleton,
  Td,
  Th,
} from "../components/ui.tsx";

const PAGE_SIZE = 25;

function formatTimestamp(iso: string, timezone?: string): string {
  try {
    return new Intl.DateTimeFormat(undefined, {
      timeZone: timezone || "Asia/Manila",
      year: "numeric",
      month: "short",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    }).format(new Date(iso));
  } catch {
    return new Date(iso).toLocaleString();
  }
}

function categoryBadgeTone(cat: AuditCategory): "neutral" | "good" | "warn" | "danger" {
  if (cat === "sales") return "good";
  if (cat === "stock") return "neutral";
  if (cat === "shifts_cash") return "warn";
  return "neutral";
}

export function AuditPage() {
  const { t } = useTranslation("admin");
  const { t: tc } = useTranslation("common");
  const { access } = useSession();

  const [search, setSearch] = useState("");
  const [category, setCategory] = useState<"all" | AuditCategory>("all");
  const [locationId, setLocationId] = useState("all");
  const [actorId, setActorId] = useState("all");
  const [onlySensitive, setOnlySensitive] = useState(false);
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const [page, setPage] = useState(1);
  const [selectedRow, setSelectedRow] = useState<AuditLogRow | null>(null);

  const logsQuery = useQuery({
    queryKey: ["audit-logs", access.tenant.id],
    queryFn: () => fetchAuditLogs(500),
  });

  const actorsQuery = useQuery({
    queryKey: ["audit-actors", access.tenant.id],
    queryFn: fetchAuditActors,
    staleTime: 60_000,
  });

  const actorLabels = useMemo(() => {
    const map = new Map<string, string>();
    for (const a of actorsQuery.data ?? []) {
      const label = a.full_name?.trim() || a.username?.trim() || a.user_id.slice(0, 8);
      map.set(a.user_id, label);
    }
    if (access.user_id && !map.has(access.user_id)) {
      map.set(access.user_id, access.full_name || access.username || access.user_id.slice(0, 8));
    }
    return map;
  }, [actorsQuery.data, access.user_id, access.full_name, access.username]);

  const locationLabels = useMemo(() => {
    const map = new Map<string, string>();
    for (const loc of access.locations) {
      map.set(loc.id, loc.name);
    }
    return map;
  }, [access.locations]);

  const actorOptions = useMemo(() => {
    const seen = new Map<string, string>();
    for (const [id, label] of actorLabels.entries()) {
      seen.set(id, label);
    }
    for (const row of logsQuery.data ?? []) {
      if (row.user_id && !seen.has(row.user_id)) {
        seen.set(row.user_id, row.user_id.slice(0, 8));
      }
    }
    return Array.from(seen.entries()).sort((a, b) => a[1].localeCompare(b[1]));
  }, [actorLabels, logsQuery.data]);

  const filtered = useMemo(
    () =>
      filterAuditLogs(
        logsQuery.data ?? [],
        {
          search,
          category,
          actorId,
          locationId,
          onlySensitive,
          dateFrom,
          dateTo,
          timezone: access.tenant.timezone,
        },
        actorLabels,
        locationLabels,
      ),
    [
      logsQuery.data,
      search,
      category,
      actorId,
      locationId,
      onlySensitive,
      dateFrom,
      dateTo,
      access.tenant.timezone,
      actorLabels,
      locationLabels,
    ],
  );

  const kpis = useMemo(() => {
    let sales = 0;
    let stock = 0;
    let sensitive = 0;
    for (const row of filtered) {
      const cat = classifyAuditCategory(row.action, row.entity);
      if (cat === "sales") sales += 1;
      if (cat === "stock") stock += 1;
      if (isSecuritySensitiveAudit(row.action)) sensitive += 1;
    }
    return {
      total: filtered.length,
      sales,
      stock,
      sensitive,
    };
  }, [filtered]);

  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const safePage = Math.min(page, totalPages);
  const pageStart = (safePage - 1) * PAGE_SIZE;
  const pageRows = filtered.slice(pageStart, pageStart + PAGE_SIZE);

  const hasActiveFilters =
    search.trim() !== "" ||
    category !== "all" ||
    locationId !== "all" ||
    actorId !== "all" ||
    onlySensitive ||
    dateFrom !== "" ||
    dateTo !== "";

  function clearAllFilters() {
    setSearch("");
    setCategory("all");
    setLocationId("all");
    setActorId("all");
    setOnlySensitive(false);
    setDateFrom("");
    setDateTo("");
    setPage(1);
  }

  function resolveActorName(userId: string | null): string {
    if (!userId) return t("audit.actorSystem");
    return actorLabels.get(userId) ?? userId.slice(0, 8);
  }

  function resolveLocationName(locId: string | null): string {
    if (!locId) return t("audit.locationGlobal");
    return locationLabels.get(locId) ?? locId.slice(0, 8);
  }

  function resolveCategoryLabel(cat: AuditCategory): string {
    return t(`audit.categories.${cat}`);
  }

  function handleExportCsv() {
    const csv = exportAuditLogsCsv(
      filtered.map((row) => {
        const cat = classifyAuditCategory(row.action, row.entity);
        return {
          createdAt: row.created_at,
          action: row.action,
          category: resolveCategoryLabel(cat),
          actor: resolveActorName(row.user_id),
          location: resolveLocationName(row.location_id),
          entity: row.entity,
          entityId: row.entity_id,
          details:
            row.meta && Object.keys(row.meta).length > 0 ? JSON.stringify(row.meta) : "",
        };
      }),
    );
    const stamp = new Date().toISOString().slice(0, 10);
    downloadCsv(csv, `audit-log-${stamp}.csv`);
  }

  return (
    <div className="grid gap-5" data-testid="audit-page">
      <PageHeader
        title={t("audit.title")}
        subtitle={t("audit.subtitle")}
        actions={
          <>
            <Button
              variant="outline"
              size="sm"
              onClick={() => void logsQuery.refetch()}
              disabled={logsQuery.isFetching}
              data-testid="audit-refresh"
            >
              <RefreshCw size={15} className={logsQuery.isFetching ? "animate-spin" : ""} />
              {t("audit.refresh")}
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={handleExportCsv}
              disabled={filtered.length === 0}
              data-testid="export-audit-csv"
            >
              <Download size={15} />
              {t("audit.exportCsv")}
            </Button>
          </>
        }
      />

      {/* KPI Summary Strip */}
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Card className="p-4">
          <div className="text-xs font-semibold tracking-wider text-slate-500 uppercase">
            {t("audit.kpiTotal")}
          </div>
          <div className="mt-1 text-2xl font-bold tabular-nums text-slate-900" data-testid="audit-kpi-total">
            {kpis.total}
          </div>
        </Card>
        <Card className="p-4">
          <div className="text-xs font-semibold tracking-wider text-slate-500 uppercase">
            {t("audit.kpiSales")}
          </div>
          <div className="mt-1 text-2xl font-bold tabular-nums text-emerald-700" data-testid="audit-kpi-sales">
            {kpis.sales}
          </div>
        </Card>
        <Card className="p-4">
          <div className="text-xs font-semibold tracking-wider text-slate-500 uppercase">
            {t("audit.kpiStock")}
          </div>
          <div className="mt-1 text-2xl font-bold tabular-nums text-slate-900" data-testid="audit-kpi-stock">
            {kpis.stock}
          </div>
        </Card>
        <Card className="p-4">
          <div className="text-xs font-semibold tracking-wider text-slate-500 uppercase">
            {t("audit.kpiSensitive")}
          </div>
          <div className="mt-1 text-2xl font-bold tabular-nums text-amber-700" data-testid="audit-kpi-sensitive">
            {kpis.sensitive}
          </div>
        </Card>
      </div>

      {/* Filter Bar */}
      <Card className="grid gap-3 p-4">
        <div className="grid gap-3 md:grid-cols-2 lg:grid-cols-5">
          <div className="lg:col-span-2">
            <Field label={t("audit.searchLabel")}>
              <div className="relative">
                <Search size={15} className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-slate-400" />
                <Input
                  value={search}
                  onChange={(e) => {
                    setSearch(e.target.value);
                    setPage(1);
                  }}
                  placeholder={t("audit.searchPlaceholder")}
                  className="pl-9"
                  data-testid="audit-search"
                />
              </div>
            </Field>
          </div>
          <Field label={t("audit.categoryLabel")}>
            <Select
              value={category}
              onChange={(e) => {
                setCategory(e.target.value as "all" | AuditCategory);
                setPage(1);
              }}
              data-testid="audit-category-filter"
            >
              <option value="all">{t("audit.categoryAll")}</option>
              <option value="sales">{t("audit.categories.sales")}</option>
              <option value="stock">{t("audit.categories.stock")}</option>
              <option value="shifts_cash">{t("audit.categories.shifts_cash")}</option>
              <option value="users_settings">{t("audit.categories.users_settings")}</option>
            </Select>
          </Field>
          <Field label={t("audit.locationLabel")}>
            <Select
              value={locationId}
              onChange={(e) => {
                setLocationId(e.target.value);
                setPage(1);
              }}
              data-testid="audit-location-filter"
            >
              <option value="all">{t("audit.locationAll")}</option>
              <option value="global">{t("audit.locationGlobal")}</option>
              {access.locations.map((loc) => (
                <option key={loc.id} value={loc.id}>
                  {loc.name}
                </option>
              ))}
            </Select>
          </Field>
          <Field label={t("audit.actorLabel")}>
            <Select
              value={actorId}
              onChange={(e) => {
                setActorId(e.target.value);
                setPage(1);
              }}
              data-testid="audit-actor-filter"
            >
              <option value="all">{t("audit.actorAll")}</option>
              <option value="system">{t("audit.actorSystem")}</option>
              {actorOptions.map(([id, label]) => (
                <option key={id} value={id}>
                  {label}
                </option>
              ))}
            </Select>
          </Field>
        </div>

        <div className="flex flex-wrap items-end justify-between gap-3 pt-1">
          <div className="flex flex-wrap items-end gap-3">
            <Field label={t("audit.dateFrom")}>
              <Input
                type="date"
                value={dateFrom}
                onChange={(e) => {
                  setDateFrom(e.target.value);
                  setPage(1);
                }}
                className="w-40"
                data-testid="audit-date-from"
              />
            </Field>
            <Field label={t("audit.dateTo")}>
              <Input
                type="date"
                value={dateTo}
                onChange={(e) => {
                  setDateTo(e.target.value);
                  setPage(1);
                }}
                className="w-40"
                data-testid="audit-date-to"
              />
            </Field>
            <Button
              variant={onlySensitive ? "primary" : "outline"}
              size="sm"
              onClick={() => {
                setOnlySensitive((v) => !v);
                setPage(1);
              }}
              className="h-9.5"
              data-testid="audit-sensitive-toggle"
            >
              <ShieldAlert size={15} />
              {t("audit.sensitiveOnly")}
            </Button>
          </div>
          {hasActiveFilters ? (
            <Button variant="ghost" size="sm" onClick={clearAllFilters} data-testid="audit-clear-filters">
              <X size={14} />
              {t("audit.clearFilters")}
            </Button>
          ) : null}
        </div>
      </Card>

      {/* Table / Empty / Error */}
      {logsQuery.isError ? (
        <ErrorState
          message={logsQuery.error instanceof Error ? logsQuery.error.message : String(logsQuery.error)}
          retryLabel={tc("actions.retry")}
          onRetry={() => void logsQuery.refetch()}
        />
      ) : logsQuery.isLoading ? (
        <Card className="p-0">
          <TableSkeleton rows={6} cols={6} />
        </Card>
      ) : filtered.length === 0 ? (
        <EmptyState
          title={t("audit.emptyTitle")}
          hint={t("audit.emptyHint")}
          action={
            hasActiveFilters ? (
              <Button variant="outline" size="sm" onClick={clearAllFilters}>
                {t("audit.clearFilters")}
              </Button>
            ) : undefined
          }
        />
      ) : (
        <div className="grid gap-3">
          <Table data-testid="audit-table">
            <thead>
              <tr>
                <Th>{t("audit.colTimestamp")}</Th>
                <Th>{t("audit.colAction")}</Th>
                <Th>{t("audit.colCategory")}</Th>
                <Th>{t("audit.colActor")}</Th>
                <Th>{t("audit.colLocation")}</Th>
                <Th>{t("audit.colEntity")}</Th>
                <Th>{t("audit.colDetails")}</Th>
                <Th numeric>{t("audit.colInspect")}</Th>
              </tr>
            </thead>
            <tbody>
              {pageRows.map((row) => {
                const cat = classifyAuditCategory(row.action, row.entity);
                const sensitive = isSecuritySensitiveAudit(row.action);
                const summary = summarizeAuditMeta(row.meta);
                return (
                  <tr key={row.id} data-testid={`audit-row-${row.id}`}>
                    <Td className="whitespace-nowrap text-xs text-slate-600 tabular-nums">
                      {formatTimestamp(row.created_at, access.tenant.timezone)}
                    </Td>
                    <Td>
                      <div className="flex flex-wrap items-center gap-1.5">
                        <code className="rounded bg-slate-100 px-1.5 py-0.5 font-mono text-xs font-semibold text-slate-800">
                          {row.action}
                        </code>
                        {sensitive ? <Badge tone="danger">{t("audit.sensitiveBadge")}</Badge> : null}
                      </div>
                    </Td>
                    <Td>
                      <Badge tone={categoryBadgeTone(cat)}>{resolveCategoryLabel(cat)}</Badge>
                    </Td>
                    <Td className="font-medium text-slate-800">{resolveActorName(row.user_id)}</Td>
                    <Td className="text-slate-600">{resolveLocationName(row.location_id)}</Td>
                    <Td className="text-xs text-slate-600">
                      <span className="font-medium text-slate-800">{row.entity}</span>
                      {row.entity_id ? (
                        <span className="ml-1 font-mono text-slate-400">#{row.entity_id.slice(0, 8)}</span>
                      ) : null}
                    </Td>
                    <Td className="max-w-xs truncate text-xs text-slate-500" title={summary}>
                      {summary || "—"}
                    </Td>
                    <Td numeric>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => setSelectedRow(row)}
                        data-testid={`audit-inspect-${row.id}`}
                      >
                        <Eye size={14} />
                        {t("audit.inspectBtn")}
                      </Button>
                    </Td>
                  </tr>
                );
              })}
            </tbody>
          </Table>

          {/* Pagination */}
          <div className="flex flex-wrap items-center justify-between gap-3 px-1 text-xs text-slate-600">
            <span>
              {t("audit.showingCount", {
                from: pageStart + 1,
                to: Math.min(pageStart + PAGE_SIZE, filtered.length),
                total: filtered.length,
              })}
            </span>
            {totalPages > 1 ? (
              <div className="flex items-center gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  disabled={safePage <= 1}
                  onClick={() => setPage((p) => Math.max(1, p - 1))}
                >
                  {t("audit.prevPage")}
                </Button>
                <span className="font-medium tabular-nums">
                  {safePage} / {totalPages}
                </span>
                <Button
                  variant="outline"
                  size="sm"
                  disabled={safePage >= totalPages}
                  onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                >
                  {t("audit.nextPage")}
                </Button>
              </div>
            ) : null}
          </div>
        </div>
      )}

      {/* Detail Inspector Dialog */}
      <Dialog
        open={selectedRow !== null}
        onOpenChange={(open) => {
          if (!open) setSelectedRow(null);
        }}
        title={t("audit.detailTitle")}
        closeLabel={tc("actions.close")}
      >
        {selectedRow ? (
          <div className="grid gap-3 text-sm" data-testid="audit-detail-dialog">
            <div className="grid grid-cols-2 gap-3 rounded-lg border border-slate-200 bg-slate-50 p-3 text-xs">
              <div>
                <div className="font-semibold text-slate-500">{t("audit.detailTimestamp")}</div>
                <div className="mt-0.5 font-medium text-slate-900">
                  {formatTimestamp(selectedRow.created_at, access.tenant.timezone)}
                </div>
              </div>
              <div>
                <div className="font-semibold text-slate-500">{t("audit.detailAction")}</div>
                <div className="mt-0.5 flex items-center gap-1.5">
                  <code className="rounded bg-white px-1.5 py-0.5 font-mono font-semibold text-slate-900">
                    {selectedRow.action}
                  </code>
                  {isSecuritySensitiveAudit(selectedRow.action) ? (
                    <Badge tone="danger">{t("audit.sensitiveBadge")}</Badge>
                  ) : null}
                </div>
              </div>
              <div>
                <div className="font-semibold text-slate-500">{t("audit.detailCategory")}</div>
                <div className="mt-0.5 font-medium text-slate-900">
                  {resolveCategoryLabel(classifyAuditCategory(selectedRow.action, selectedRow.entity))}
                </div>
              </div>
              <div>
                <div className="font-semibold text-slate-500">{t("audit.detailActor")}</div>
                <div className="mt-0.5 font-medium text-slate-900">{resolveActorName(selectedRow.user_id)}</div>
              </div>
              <div>
                <div className="font-semibold text-slate-500">{t("audit.detailLocation")}</div>
                <div className="mt-0.5 font-medium text-slate-900">{resolveLocationName(selectedRow.location_id)}</div>
              </div>
              <div>
                <div className="font-semibold text-slate-500">{t("audit.detailEntity")}</div>
                <div className="mt-0.5 font-mono text-slate-900">
                  {selectedRow.entity}
                  {selectedRow.entity_id ? ` (${selectedRow.entity_id})` : ""}
                </div>
              </div>
            </div>

            <div>
              <div className="mb-1.5 text-xs font-semibold text-slate-600">{t("audit.detailMeta")}</div>
              {selectedRow.meta && Object.keys(selectedRow.meta).length > 0 ? (
                <pre
                  className="max-h-64 overflow-auto rounded-lg border border-slate-200 bg-slate-950 p-3 font-mono text-xs text-slate-100"
                  data-testid="audit-detail-meta"
                >
                  {JSON.stringify(selectedRow.meta, null, 2)}
                </pre>
              ) : (
                <p className="rounded-lg border border-dashed border-slate-200 bg-slate-50 p-3 text-xs text-slate-500">
                  {t("audit.detailNoMeta")}
                </p>
              )}
            </div>
          </div>
        ) : null}
      </Dialog>
    </div>
  );
}
