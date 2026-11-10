import { useMemo, useState, type FormEvent } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import type { Position, Role } from "@pos/core";
import {
  clearUserPin,
  createUser,
  getTenantLimits,
  inviteUser,
  listAccess,
  listLocations,
  listUsers,
  rpc,
  setMyPin,
  type AccessRow,
  type LocationRow,
  type UserRow,
} from "../lib/api.ts";
import {
  createUserSchema,
  fieldErrors,
  inviteUserSchema,
  setPinSchema,
} from "../lib/schemas.ts";
import { useSession } from "../lib/session.tsx";
import { useErrorMessage, useValidationMessage } from "../lib/i18n-helpers.ts";
import { Alert, Badge, Button, Card, Dialog, EmptyState, ErrorState, Field, Input, PageHeader, Select, Table } from "../components/ui.tsx";

const ROLES: Role[] = ["superadmin", "admin", "warehouse", "cashier"];

/** Which location type a role works in. Superadmins have tenant-wide access and no assignments. */
const roleLocationType = (role: Role): LocationRow["type"] | null =>
  role === "warehouse" ? "warehouse" : role === "admin" || role === "cashier" ? "store" : null;

function useUsersData() {
  const users = useQuery({ queryKey: ["users"], queryFn: listUsers });
  const locations = useQuery({ queryKey: ["locations"], queryFn: listLocations });
  const access = useQuery({ queryKey: ["location_access"], queryFn: listAccess });
  const limits = useQuery({ queryKey: ["tenant_limits"], queryFn: getTenantLimits });
  return { users, locations, access, limits };
}

export function UsersPage() {
  const { t } = useTranslation(["admin", "common"]);
  const { access: me, can } = useSession();
  const errMsg = useErrorMessage();
  const { users, locations, access, limits } = useUsersData();

  const [addMode, setAddMode] = useState<"cashier" | "invite" | null>(null);
  const [managing, setManaging] = useState<string | null>(null);
  const [pinOpen, setPinOpen] = useState(false);

  const [search, setSearch] = useState("");
  const [roleFilter, setRoleFilter] = useState("all");
  const [locationFilter, setLocationFilter] = useState("all");
  const [statusFilter, setStatusFilter] = useState("all");

  const locById = useMemo(() => new Map((locations.data ?? []).map((l) => [l.id, l])), [locations.data]);
  const accessByUser = useMemo(() => {
    const m = new Map<string, AccessRow[]>();
    for (const a of access.data ?? []) m.set(a.user_id, [...(m.get(a.user_id) ?? []), a]);
    return m;
  }, [access.data]);

  const manageable = (u: UserRow): boolean =>
    me.role === "superadmin" ||
    (u.role === "cashier" && (accessByUser.get(u.user_id) ?? []).some((a) => can("users.manage", a.location_id)));

  const totalUsers = users.data?.length ?? 0;
  const maxUsers = limits.data?.max_users ?? 100;
  const isQuotaFull = totalUsers >= maxUsers;

  const filteredUsers = useMemo(() => {
    return (users.data ?? []).filter((u) => {
      if (search.trim()) {
        const q = search.trim().toLowerCase();
        const matchName = u.full_name?.toLowerCase().includes(q);
        const matchUsername = u.username.toLowerCase().includes(q);
        if (!matchName && !matchUsername) return false;
      }
      if (roleFilter !== "all" && u.role !== roleFilter) return false;
      if (statusFilter === "active" && !u.active) return false;
      if (statusFilter === "inactive" && u.active) return false;

      if (locationFilter !== "all") {
        if (u.role === "superadmin") return true;
        const userLocs = accessByUser.get(u.user_id) ?? [];
        if (!userLocs.some((a) => a.location_id === locationFilter)) return false;
      }
      return true;
    });
  }, [users.data, search, roleFilter, locationFilter, statusFilter, accessByUser]);

  const error = users.error ?? locations.error ?? access.error;
  const managedUser = users.data?.find((u) => u.user_id === managing) ?? null;

  return (
    <div className="grid gap-5">
      <PageHeader
        title={t("users.title")}
        subtitle={t("users.quota", { count: totalUsers, max: maxUsers })}
        actions={
          <>
            <Button variant="outline" onClick={() => setPinOpen(true)}>
              {t("users.changeMyPin")}
            </Button>
            {me.role === "superadmin" ? (
              <Button
                variant="outline"
                disabled={isQuotaFull}
                onClick={() => setAddMode("invite")}
              >
                {t("users.invite")}
              </Button>
            ) : null}
            <Button disabled={isQuotaFull} onClick={() => setAddMode("cashier")}>
              {t("users.addCashier")}
            </Button>
          </>
        }
      />

      {isQuotaFull ? (
        <Alert tone="info">
          {t("users.quotaFull", { max: maxUsers })}
        </Alert>
      ) : null}

      {error ? <ErrorState message={errMsg(error)} onRetry={() => { void users.refetch(); void locations.refetch(); void access.refetch(); }} retryLabel={t("common:actions.retry")} /> : null}

      {/* Filter and Search Bar */}
      <Card className="p-4 grid gap-3 sm:grid-cols-4">
        <div className="sm:col-span-1">
          <Input
            placeholder={t("users.searchPlaceholder")}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
        <div>
          <Select value={roleFilter} onChange={(e) => setRoleFilter(e.target.value)}>
            <option value="all">{t("users.allRoles")}</option>
            {ROLES.map((r) => (
              <option key={r} value={r}>
                {t(`roles.${r}`)}
              </option>
            ))}
          </Select>
        </div>
        <div>
          <Select value={locationFilter} onChange={(e) => setLocationFilter(e.target.value)}>
            <option value="all">{t("users.allLocationsFilter")}</option>
            {(locations.data ?? []).map((l) => (
              <option key={l.id} value={l.id}>
                {l.code} · {l.name}
              </option>
            ))}
          </Select>
        </div>
        <div>
          <Select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
            <option value="all">{t("users.allStatuses")}</option>
            <option value="active">{t("users.activeOnly")}</option>
            <option value="inactive">{t("users.inactiveOnly")}</option>
          </Select>
        </div>
      </Card>

      {/* Staff Table */}
      <Card className="overflow-x-auto p-0">
        <Table bare>
          <thead className="border-b border-slate-200 text-xs text-slate-500 uppercase bg-slate-50/50">
            <tr>
              <th className="p-3">{t("users.username")}</th>
              <th className="p-3">{t("users.role")}</th>
              <th className="p-3">{t("users.locations")}</th>
              <th className="p-3 text-right" />
            </tr>
          </thead>
          <tbody>
            {filteredUsers.length === 0 ? (
              <tr>
                <td colSpan={4} className="p-8 text-center">
                  <EmptyState title={t("users.emptyFiltered")} />
                </td>
              </tr>
            ) : (
              filteredUsers.map((u) => (
                <tr
                  key={u.user_id}
                  className="border-b border-slate-100 last:border-0 hover:bg-slate-50/40"
                  data-testid={`user-${u.username}`}
                >
                  <td className="p-3">
                    <div className="font-medium text-slate-900">{u.username}</div>
                    {u.full_name ? <div className="text-xs text-slate-500">{u.full_name}</div> : null}
                  </td>
                  <td className="p-3">
                    <div className="flex items-center gap-1.5">
                      <span>{t(`roles.${u.role}`)}</span>
                      {u.active ? null : <Badge tone="warn">{t("users.inactive")}</Badge>}
                    </div>
                  </td>
                  <td className="p-3">
                    <div className="flex flex-wrap gap-1">
                      {u.role === "superadmin" ? <Badge tone="neutral">{t("users.allLocations")}</Badge> : null}
                      {(accessByUser.get(u.user_id) ?? []).map((a) => (
                        <Badge key={a.location_id}>
                          {locById.get(a.location_id)?.code ?? "?"}
                          {a.position ? ` · ${t(`positions.${a.position}`)}` : ""}
                        </Badge>
                      ))}
                    </div>
                  </td>
                  <td className="p-3 text-right">
                    {manageable(u) ? (
                      <Button size="sm" variant="outline" onClick={() => setManaging(u.user_id)}>
                        {t("users.manage")}
                      </Button>
                    ) : null}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </Table>
      </Card>

      {/* Add / Invite Dialog */}
      {addMode ? (
        <CreateOrInviteUserDialog
          mode={addMode}
          onClose={() => setAddMode(null)}
          locations={locations.data ?? []}
        />
      ) : null}

      {/* Manage User Dialog */}
      <ManageUserDialog
        user={managedUser}
        onClose={() => setManaging(null)}
        locations={locations.data ?? []}
        assignments={managedUser ? (accessByUser.get(managedUser.user_id) ?? []) : []}
      />

      {/* Set / Change My PIN Dialog */}
      {pinOpen ? <MyPinDialog onClose={() => setPinOpen(false)} /> : null}
    </div>
  );
}

function CreateOrInviteUserDialog({
  mode: initialMode,
  onClose,
  locations,
}: {
  mode: "cashier" | "invite";
  onClose: () => void;
  locations: LocationRow[];
}) {
  const { t } = useTranslation(["admin", "common"]);
  const { access: me, can } = useSession();
  const qc = useQueryClient();
  const errMsg = useErrorMessage();
  const vm = useValidationMessage();

  const isSuperadmin = me.role === "superadmin";
  const [tab, setTab] = useState<"cashier" | "invite">(initialMode);

  // Cashier form state
  const [cashierForm, setCashierForm] = useState({
    username: "",
    fullName: "",
    password: "",
    locationId: "",
  });

  // Invite form state
  const [inviteForm, setInviteForm] = useState({
    email: "",
    username: "",
    fullName: "",
    role: "admin" as "superadmin" | "admin" | "warehouse",
    locationId: "",
    position: "" as Position | "",
  });

  const [errors, setErrors] = useState<Record<string, string>>({});
  const [inviteSuccessMsg, setInviteSuccessMsg] = useState<string | null>(null);

  const storeOptions = locations.filter((l) => l.active && l.type === "store" && can("users.manage", l.id));
  const inviteLocationType = roleLocationType(inviteForm.role);
  const inviteLocationOptions = locations.filter(
    (l) => l.active && l.type === inviteLocationType && can("users.manage", l.id),
  );

  const createCashier = useMutation({
    mutationFn: () =>
      createUser({
        username: cashierForm.username.trim().toLowerCase(),
        password: cashierForm.password,
        role: "cashier",
        ...(cashierForm.fullName.trim() ? { full_name: cashierForm.fullName.trim() } : {}),
        location_id: cashierForm.locationId,
      }),
    onSuccess: async () => {
      await Promise.all(["users", "location_access", "tenant_limits"].map((k) => qc.invalidateQueries({ queryKey: [k] })));
      onClose();
    },
  });

  const sendInvitation = useMutation({
    mutationFn: () =>
      inviteUser({
        email: inviteForm.email.trim().toLowerCase(),
        username: inviteForm.username.trim().toLowerCase(),
        role: inviteForm.role,
        ...(inviteForm.fullName.trim() ? { full_name: inviteForm.fullName.trim() } : {}),
        ...(inviteForm.locationId ? { location_id: inviteForm.locationId } : {}),
        ...(inviteForm.role === "admin" && inviteForm.position ? { position: inviteForm.position } : {}),
      }),
    onSuccess: async () => {
      await Promise.all(["users", "location_access", "tenant_limits"].map((k) => qc.invalidateQueries({ queryKey: [k] })));
      setInviteSuccessMsg(t("users.inviteSuccess", { email: inviteForm.email }));
      setTimeout(() => {
        onClose();
      }, 2500);
    },
  });

  function handleCashierSubmit(e: FormEvent) {
    e.preventDefault();
    const r = createUserSchema.safeParse({
      username: cashierForm.username,
      fullName: cashierForm.fullName,
      password: cashierForm.password,
      role: "cashier",
      locationId: cashierForm.locationId,
      position: "",
    });
    if (!r.success) return setErrors(fieldErrors(r.error));
    setErrors({});
    createCashier.mutate();
  }

  function handleInviteSubmit(e: FormEvent) {
    e.preventDefault();
    const r = inviteUserSchema.safeParse({
      email: inviteForm.email,
      username: inviteForm.username,
      fullName: inviteForm.fullName,
      role: inviteForm.role,
      locationId: inviteForm.locationId,
      position: inviteForm.position,
    });
    if (!r.success) return setErrors(fieldErrors(r.error));
    setErrors({});
    sendInvitation.mutate();
  }

  return (
    <Dialog
      open
      onOpenChange={(o) => !o && onClose()}
      title={tab === "invite" ? t("users.invite") : t("users.addCashier")}
      closeLabel={t("common:actions.close")}
    >
      {isSuperadmin ? (
        <div className="flex border-b border-slate-200 mb-4">
          <button
            type="button"
            onClick={() => {
              setTab("cashier");
              setErrors({});
            }}
            className={`px-4 py-2 text-sm font-medium border-b-2 -mb-px transition-colors ${
              tab === "cashier" ? "border-slate-900 text-slate-900" : "border-transparent text-slate-500 hover:text-slate-700"
            }`}
          >
            {t("users.cashierTab")}
          </button>
          <button
            type="button"
            onClick={() => {
              setTab("invite");
              setErrors({});
            }}
            className={`px-4 py-2 text-sm font-medium border-b-2 -mb-px transition-colors ${
              tab === "invite" ? "border-slate-900 text-slate-900" : "border-transparent text-slate-500 hover:text-slate-700"
            }`}
          >
            {t("users.inviteTab")}
          </button>
        </div>
      ) : null}

      {inviteSuccessMsg ? (
        <Alert tone="info">{inviteSuccessMsg}</Alert>
      ) : tab === "cashier" ? (
        <form onSubmit={handleCashierSubmit} className="grid gap-4" noValidate>
          {createCashier.isError ? <Alert>{errMsg(createCashier.error)}</Alert> : null}
          <Field
            label={t("users.username")}
            hint={t("users.usernameHint", { slug: me.tenant.slug })}
            error={vm(errors["username"])}
          >
            <Input
              value={cashierForm.username}
              onChange={(e) => setCashierForm((f) => ({ ...f, username: e.target.value }))}
              autoCapitalize="none"
              placeholder="e.g. ana"
            />
          </Field>
          <Field label={t("users.fullName")} error={vm(errors["fullName"])}>
            <Input
              value={cashierForm.fullName}
              onChange={(e) => setCashierForm((f) => ({ ...f, fullName: e.target.value }))}
              placeholder="e.g. Ana Reyes"
            />
          </Field>
          <Field label={t("users.password")} hint={t("users.passwordHint")} error={vm(errors["password"])}>
            <Input
              type="password"
              value={cashierForm.password}
              onChange={(e) => setCashierForm((f) => ({ ...f, password: e.target.value }))}
              autoComplete="new-password"
            />
          </Field>
          <Field label={t("users.store")} error={vm(errors["locationId"])}>
            <Select
              value={cashierForm.locationId}
              onChange={(e) => setCashierForm((f) => ({ ...f, locationId: e.target.value }))}
            >
              <option value="">{t("users.none")}</option>
              {storeOptions.map((l) => (
                <option key={l.id} value={l.id}>
                  {l.code} · {l.name}
                </option>
              ))}
            </Select>
          </Field>
          <div className="flex justify-end gap-2 pt-2">
            <Button variant="outline" onClick={onClose}>
              {t("common:actions.cancel")}
            </Button>
            <Button type="submit" disabled={createCashier.isPending}>
              {createCashier.isPending ? t("users.saving") : t("users.create")}
            </Button>
          </div>
        </form>
      ) : (
        <form onSubmit={handleInviteSubmit} className="grid gap-4" noValidate>
          <p className="text-xs text-slate-500">{t("users.inviteDesc")}</p>
          {sendInvitation.isError ? <Alert>{errMsg(sendInvitation.error)}</Alert> : null}
          <Field label={t("users.email")} hint={t("users.emailHint")} error={vm(errors["email"])}>
            <Input
              type="email"
              value={inviteForm.email}
              onChange={(e) => setInviteForm((f) => ({ ...f, email: e.target.value }))}
              placeholder="name@company.com"
            />
          </Field>
          <Field
            label={t("users.username")}
            hint={t("users.usernameHint", { slug: me.tenant.slug })}
            error={vm(errors["username"])}
          >
            <Input
              value={inviteForm.username}
              onChange={(e) => setInviteForm((f) => ({ ...f, username: e.target.value }))}
              autoCapitalize="none"
              placeholder="e.g. maria_mgr"
            />
          </Field>
          <Field label={t("users.fullName")} error={vm(errors["fullName"])}>
            <Input
              value={inviteForm.fullName}
              onChange={(e) => setInviteForm((f) => ({ ...f, fullName: e.target.value }))}
              placeholder="e.g. Maria Santos"
            />
          </Field>
          <Field label={t("users.role")}>
            <Select
              value={inviteForm.role}
              onChange={(e) =>
                setInviteForm((f) => ({
                  ...f,
                  role: e.target.value as "superadmin" | "admin" | "warehouse",
                  locationId: "",
                  position: "",
                }))
              }
            >
              <option value="admin">{t("roles.admin")}</option>
              <option value="warehouse">{t("roles.warehouse")}</option>
              <option value="superadmin">{t("roles.superadmin")}</option>
            </Select>
          </Field>
          {inviteLocationType ? (
            <Field
              label={t(inviteLocationType === "store" ? "users.store" : "users.warehouse")}
              error={vm(errors["locationId"])}
            >
              <Select
                value={inviteForm.locationId}
                onChange={(e) => setInviteForm((f) => ({ ...f, locationId: e.target.value }))}
              >
                <option value="">{t("users.none")}</option>
                {inviteLocationOptions.map((l) => (
                  <option key={l.id} value={l.id}>
                    {l.code} · {l.name}
                  </option>
                ))}
              </Select>
            </Field>
          ) : null}
          {inviteForm.role === "admin" && inviteForm.locationId ? (
            <Field label={t("users.position")} error={vm(errors["position"])}>
              <Select
                value={inviteForm.position}
                onChange={(e) => setInviteForm((f) => ({ ...f, position: e.target.value as Position | "" }))}
              >
                <option value="">{t("users.none")}</option>
                {(["manager", "supervisor"] as const).map((p) => (
                  <option key={p} value={p}>
                    {t(`positions.${p}`)}
                  </option>
                ))}
              </Select>
            </Field>
          ) : null}
          <div className="flex justify-end gap-2 pt-2">
            <Button variant="outline" onClick={onClose}>
              {t("common:actions.cancel")}
            </Button>
            <Button type="submit" disabled={sendInvitation.isPending}>
              {sendInvitation.isPending ? t("users.sending") : t("users.sendInvite")}
            </Button>
          </div>
        </form>
      )}
    </Dialog>
  );
}

function ManageUserDialog({
  user,
  onClose,
  locations,
  assignments,
}: {
  user: UserRow | null;
  onClose: () => void;
  locations: LocationRow[];
  assignments: AccessRow[];
}) {
  const { t } = useTranslation(["admin", "common"]);
  const { access: me, can } = useSession();
  const qc = useQueryClient();
  const errMsg = useErrorMessage();

  const [newLoc, setNewLoc] = useState("");
  const [newPos, setNewPos] = useState<Position | "">("");
  const [pinResetNotice, setPinResetNotice] = useState(false);

  const refresh = () =>
    Promise.all(["users", "location_access"].map((k) => qc.invalidateQueries({ queryKey: [k] })));

  const run = useMutation({
    mutationFn: (fn: () => Promise<unknown>) => fn(),
    onSuccess: refresh,
  });

  const clearPin = useMutation({
    mutationFn: async () => {
      if (!user) return;
      await clearUserPin(user.user_id);
    },
    onSuccess: () => {
      setPinResetNotice(true);
      setTimeout(() => setPinResetNotice(false), 4000);
    },
  });

  if (!user) return null;

  const isSuper = me.role === "superadmin";
  const type = roleLocationType(user.role);
  const assigned = new Set(assignments.map((a) => a.location_id));
  const options = locations.filter(
    (l) => l.active && l.type === type && !assigned.has(l.id) && can("users.manage", l.id),
  );
  const locName = (id: string) => locations.find((l) => l.id === id);
  const needsPosition = user.role === "admin";

  return (
    <Dialog
      open
      onOpenChange={(o) => !o && onClose()}
      title={`${t("users.manage")}: ${user.username}`}
      closeLabel={t("common:actions.close")}
    >
      <div className="grid gap-5">
        {run.isError ? <Alert>{errMsg(run.error)}</Alert> : null}
        {clearPin.isError ? <Alert>{errMsg(clearPin.error)}</Alert> : null}
        {pinResetNotice ? <Alert tone="info">{t("users.pinCleared")}</Alert> : null}

        {isSuper ? (
          <Field label={t("users.role")} hint={t("users.roleChangeHint")}>
            <Select
              value={user.role}
              onChange={(e) => run.mutate(() => rpc("set_user_role", { p_user: user.user_id, p_role: e.target.value }))}
            >
              {ROLES.map((r) => (
                <option key={r} value={r}>
                  {t(`roles.${r}`)}
                </option>
              ))}
            </Select>
          </Field>
        ) : null}

        {type ? (
          <section className="grid gap-2">
            <h3 className="text-sm font-medium">{t("users.locations")}</h3>
            {assignments.length === 0 ? <p className="text-sm text-slate-500">{t("users.noAssignments")}</p> : null}
            {assignments.map((a) => {
              const loc = locName(a.location_id);
              const mayRevoke = isSuper || can("users.manage", a.location_id);
              return (
                <div
                  key={a.location_id}
                  className="flex items-center justify-between rounded-md border border-slate-200 px-3 py-2 text-sm"
                >
                  <span>
                    {loc ? `${loc.code} · ${loc.name}` : a.location_id}
                    {a.position ? ` · ${t(`positions.${a.position}`)}` : ""}
                  </span>
                  {mayRevoke ? (
                    <Button
                      size="sm"
                      variant="ghost"
                      disabled={run.isPending}
                      onClick={() => run.mutate(() => rpc("revoke_location", { p_user: user.user_id, p_location: a.location_id }))}
                    >
                      {t("users.revoke")}
                    </Button>
                  ) : null}
                </div>
              );
            })}
            {options.length > 0 ? (
              <div className="flex flex-wrap items-end gap-2">
                <div className="min-w-40 flex-1">
                  <Select aria-label={t("users.addLocation")} value={newLoc} onChange={(e) => setNewLoc(e.target.value)}>
                    <option value="">{t("users.addLocation")}</option>
                    {options.map((l) => (
                      <option key={l.id} value={l.id}>
                        {l.code} · {l.name}
                      </option>
                    ))}
                  </Select>
                </div>
                {needsPosition ? (
                  <Select
                    aria-label={t("users.position")}
                    className="w-auto"
                    value={newPos}
                    onChange={(e) => setNewPos(e.target.value as Position | "")}
                  >
                    <option value="">{t("users.position")}</option>
                    {(["manager", "supervisor"] as const).map((p) => (
                      <option key={p} value={p}>
                        {t(`positions.${p}`)}
                      </option>
                    ))}
                  </Select>
                ) : null}
                <Button
                  disabled={!newLoc || (needsPosition && !newPos) || run.isPending}
                  onClick={() =>
                    run.mutate(async () => {
                      await rpc("assign_location", {
                        p_user: user.user_id,
                        p_location: newLoc,
                        p_position: needsPosition ? newPos : null,
                      });
                      setNewLoc("");
                      setNewPos("");
                    })
                  }
                >
                  {t("users.assign")}
                </Button>
              </div>
            ) : null}
          </section>
        ) : null}

        {/* PIN Security Section */}
        {isSuper ? (
          <section className="border-t border-slate-200 pt-4 grid gap-2">
            <h3 className="text-sm font-medium">{t("users.pinSection")}</h3>
            <p className="text-xs text-slate-500">{t("users.clearPinHint")}</p>
            <div>
              <Button
                variant="outline"
                size="sm"
                disabled={clearPin.isPending}
                onClick={() => {
                  if (window.confirm(t("users.clearPinConfirm", { username: user.username }))) {
                    clearPin.mutate();
                  }
                }}
              >
                {t("users.clearPin")}
              </Button>
            </div>
          </section>
        ) : null}

        <section className="flex items-center justify-between border-t border-slate-200 pt-4">
          <span className="text-sm">{user.active ? t("users.activeNow") : t("users.inactive")}</span>
          {user.user_id === me.user_id ? (
            <span className="text-xs text-slate-500">{t("users.itsYou")}</span>
          ) : (
            <Button
              variant={user.active ? "danger" : "outline"}
              disabled={run.isPending}
              onClick={() => run.mutate(() => rpc("set_user_active", { p_user: user.user_id, p_active: !user.active }))}
            >
              {user.active ? t("users.deactivate") : t("users.activate")}
            </Button>
          )}
        </section>
      </div>
    </Dialog>
  );
}

function MyPinDialog({ onClose }: { onClose: () => void }) {
  const { t } = useTranslation(["admin", "common"]);
  const errMsg = useErrorMessage();
  const vm = useValidationMessage();

  const [currentPin, setCurrentPin] = useState("");
  const [newPin, setNewPin] = useState("");
  const [confirmPin, setConfirmPin] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [success, setSuccess] = useState(false);

  const savePin = useMutation({
    mutationFn: async () => {
      await setMyPin(newPin, currentPin || undefined);
    },
    onSuccess: () => {
      setSuccess(true);
      setTimeout(() => {
        onClose();
      }, 2000);
    },
  });

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    const r = setPinSchema.safeParse({
      currentPin: currentPin || undefined,
      newPin,
      confirmPin,
    });
    if (!r.success) return setErrors(fieldErrors(r.error));
    setErrors({});
    savePin.mutate();
  }

  return (
    <Dialog
      open
      onOpenChange={(o) => !o && onClose()}
      title={t("users.myPinTitle")}
      closeLabel={t("common:actions.close")}
    >
      <form onSubmit={handleSubmit} className="grid gap-4" noValidate>
        <p className="text-xs text-slate-500">{t("users.myPinDesc")}</p>

        {savePin.isError ? <Alert>{errMsg(savePin.error)}</Alert> : null}
        {success ? <Alert tone="info">{t("users.pinUpdated")}</Alert> : null}

        <Field
          label={t("users.currentPin")}
          hint={t("users.currentPinHint")}
          error={vm(errors["currentPin"])}
        >
          <Input
            type="password"
            maxLength={8}
            value={currentPin}
            onChange={(e) => setCurrentPin(e.target.value)}
            autoComplete="current-password"
            placeholder="••••"
          />
        </Field>

        <Field label={t("users.newPin")} error={vm(errors["newPin"])}>
          <Input
            type="password"
            maxLength={8}
            value={newPin}
            onChange={(e) => setNewPin(e.target.value)}
            autoComplete="new-password"
            placeholder="••••"
          />
        </Field>

        <Field label={t("users.confirmPin")} error={vm(errors["confirmPin"])}>
          <Input
            type="password"
            maxLength={8}
            value={confirmPin}
            onChange={(e) => setConfirmPin(e.target.value)}
            autoComplete="new-password"
            placeholder="••••"
          />
        </Field>

        <div className="flex justify-end gap-2 pt-2">
          <Button variant="outline" onClick={onClose}>
            {t("common:actions.cancel")}
          </Button>
          <Button type="submit" disabled={savePin.isPending || success}>
            {savePin.isPending ? t("users.saving") : t("common:actions.save")}
          </Button>
        </div>
      </form>
    </Dialog>
  );
}
