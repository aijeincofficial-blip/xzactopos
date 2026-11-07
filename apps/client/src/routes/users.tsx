import { useMemo, useState, type FormEvent } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import type { Position, Role } from "@pos/core";
import {
  createUser,
  listAccess,
  listLocations,
  listUsers,
  rpc,
  type AccessRow,
  type LocationRow,
  type UserRow,
} from "../lib/api.ts";
import { createUserSchema, fieldErrors } from "../lib/schemas.ts";
import { useSession } from "../lib/session.tsx";
import { useErrorMessage, useValidationMessage } from "../lib/i18n-helpers.ts";
import { Alert, Badge, Button, Card, Dialog, Field, Input, Select } from "../components/ui.tsx";

const ROLES: Role[] = ["superadmin", "admin", "warehouse", "cashier"];

/** Which location type a role works in. Superadmins have tenant-wide access and no assignments. */
const roleLocationType = (role: Role): LocationRow["type"] | null =>
  role === "warehouse" ? "warehouse" : role === "admin" || role === "cashier" ? "store" : null;

function useUsersData() {
  const users = useQuery({ queryKey: ["users"], queryFn: listUsers });
  const locations = useQuery({ queryKey: ["locations"], queryFn: listLocations });
  const access = useQuery({ queryKey: ["location_access"], queryFn: listAccess });
  return { users, locations, access };
}

export function UsersPage() {
  const { t } = useTranslation(["admin", "common"]);
  const { access: me, can } = useSession();
  const errMsg = useErrorMessage();
  const { users, locations, access } = useUsersData();
  const [creating, setCreating] = useState(false);
  const [managing, setManaging] = useState<string | null>(null);

  const locById = useMemo(() => new Map((locations.data ?? []).map((l) => [l.id, l])), [locations.data]);
  const accessByUser = useMemo(() => {
    const m = new Map<string, AccessRow[]>();
    for (const a of access.data ?? []) m.set(a.user_id, [...(m.get(a.user_id) ?? []), a]);
    return m;
  }, [access.data]);

  const manageable = (u: UserRow): boolean =>
    me.role === "superadmin" || (u.role === "cashier" && (accessByUser.get(u.user_id) ?? []).some((a) => can("users.manage", a.location_id)));

  const error = users.error ?? locations.error ?? access.error;
  const managedUser = users.data?.find((u) => u.user_id === managing) ?? null;

  return (
    <>
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold">{t("users.title")}</h1>
        <Button onClick={() => setCreating(true)}>{t("users.add")}</Button>
      </div>
      {error ? <Alert>{errMsg(error)}</Alert> : null}

      <Card className="overflow-x-auto p-0">
        <table className="w-full text-left text-sm">
          <thead className="border-b border-slate-200 text-xs text-slate-500 uppercase">
            <tr>
              <th className="p-3">{t("users.username")}</th>
              <th className="p-3">{t("users.role")}</th>
              <th className="p-3">{t("users.locations")}</th>
              <th className="p-3" />
            </tr>
          </thead>
          <tbody>
            {(users.data ?? []).map((u) => (
              <tr key={u.user_id} className="border-b border-slate-100 last:border-0" data-testid={`user-${u.username}`}>
                <td className="p-3">
                  <div className="font-medium">{u.username}</div>
                  <div className="text-xs text-slate-500">{u.full_name}</div>
                </td>
                <td className="p-3">
                  {t(`roles.${u.role}`)} {u.active ? null : <Badge tone="warn">{t("users.inactive")}</Badge>}
                </td>
                <td className="p-3">
                  <div className="flex flex-wrap gap-1">
                    {u.role === "superadmin" ? <Badge>{t("users.allLocations")}</Badge> : null}
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
            ))}
          </tbody>
        </table>
      </Card>

      <CreateUserDialog open={creating} onClose={() => setCreating(false)} locations={locations.data ?? []} />
      <ManageUserDialog
        user={managedUser}
        onClose={() => setManaging(null)}
        locations={locations.data ?? []}
        assignments={managedUser ? (accessByUser.get(managedUser.user_id) ?? []) : []}
      />
    </>
  );
}

function CreateUserDialog({ open, onClose, locations }: { open: boolean; onClose: () => void; locations: LocationRow[] }) {
  const { t } = useTranslation(["admin", "common"]);
  const { access: me, can } = useSession();
  const qc = useQueryClient();
  const errMsg = useErrorMessage();
  const vm = useValidationMessage();

  const roles = me.role === "superadmin" ? ROLES : (["cashier"] as Role[]);
  type Form = {
    username: string;
    fullName: string;
    password: string;
    role: Role;
    locationId: string;
    position: Position | "";
  };
  const initial: Form = { username: "", fullName: "", password: "", role: roles[roles.length - 1]!, locationId: "", position: "" };
  const [form, setForm] = useState<Form>(initial);
  const [errors, setErrors] = useState<Record<string, string>>({});

  const type = roleLocationType(form.role);
  const options = locations.filter((l) => l.active && l.type === type && can("users.manage", l.id));

  const create = useMutation({
    mutationFn: () =>
      createUser({
        username: form.username.trim().toLowerCase(),
        password: form.password,
        role: form.role,
        ...(form.fullName.trim() ? { full_name: form.fullName.trim() } : {}),
        ...(form.locationId ? { location_id: form.locationId } : {}),
        ...(form.role === "admin" && form.position ? { position: form.position } : {}),
      }),
    onSuccess: async () => {
      await Promise.all(["users", "location_access"].map((k) => qc.invalidateQueries({ queryKey: [k] })));
      setForm(initial);
      onClose();
    },
  });

  function submit(e: FormEvent) {
    e.preventDefault();
    const r = createUserSchema.safeParse(form);
    if (!r.success) return setErrors(fieldErrors(r.error));
    setErrors({});
    create.mutate();
  }

  const set = <K extends keyof typeof form>(k: K, v: (typeof form)[K]) => setForm((f) => ({ ...f, [k]: v }));

  return (
    <Dialog open={open} onOpenChange={(o) => !o && onClose()} title={t("users.add")} closeLabel={t("common:actions.close")}>
      <form onSubmit={submit} className="grid gap-4" noValidate>
        {create.isError ? <Alert>{errMsg(create.error)}</Alert> : null}
        <Field label={t("users.username")} hint={t("users.usernameHint", { slug: me.tenant.slug })} error={vm(errors["username"])}>
          <Input value={form.username} onChange={(e) => set("username", e.target.value)} autoCapitalize="none" />
        </Field>
        <Field label={t("users.fullName")} error={vm(errors["fullName"])}>
          <Input value={form.fullName} onChange={(e) => set("fullName", e.target.value)} />
        </Field>
        <Field label={t("users.password")} hint={t("users.passwordHint")} error={vm(errors["password"])}>
          <Input type="password" value={form.password} onChange={(e) => set("password", e.target.value)} autoComplete="new-password" />
        </Field>
        <Field label={t("users.role")}>
          <Select
            value={form.role}
            onChange={(e) => setForm((f) => ({ ...f, role: e.target.value as Role, locationId: "", position: "" }))}
          >
            {roles.map((r) => (
              <option key={r} value={r}>
                {t(`roles.${r}`)}
              </option>
            ))}
          </Select>
        </Field>
        {type ? (
          <Field
            label={t(type === "store" ? "users.store" : "users.warehouse")}
            error={vm(errors["locationId"])}
          >
            <Select value={form.locationId} onChange={(e) => set("locationId", e.target.value)}>
              <option value="">{t("users.none")}</option>
              {options.map((l) => (
                <option key={l.id} value={l.id}>
                  {l.code} · {l.name}
                </option>
              ))}
            </Select>
          </Field>
        ) : null}
        {form.role === "admin" && form.locationId ? (
          <Field label={t("users.position")} error={vm(errors["position"])}>
            <Select value={form.position} onChange={(e) => set("position", e.target.value as Position | "")}>
              <option value="">{t("users.none")}</option>
              {(["manager", "supervisor"] as const).map((p) => (
                <option key={p} value={p}>
                  {t(`positions.${p}`)}
                </option>
              ))}
            </Select>
          </Field>
        ) : null}
        <div className="flex justify-end gap-2">
          <Button variant="outline" onClick={onClose}>
            {t("common:actions.cancel")}
          </Button>
          <Button type="submit" disabled={create.isPending}>
            {t("users.create")}
          </Button>
        </div>
      </form>
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

  const refresh = () =>
    Promise.all(["users", "location_access"].map((k) => qc.invalidateQueries({ queryKey: [k] })));

  const run = useMutation({
    mutationFn: (fn: () => Promise<unknown>) => fn(),
    onSuccess: refresh,
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
                <div key={a.location_id} className="flex items-center justify-between rounded-md border border-slate-200 px-3 py-2 text-sm">
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
