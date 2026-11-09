import { useState, type FormEvent } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { uuidv7 } from "@pos/core";
import { listLocations, rpc, type LocationRow } from "../lib/api.ts";
import { fieldErrors, locationSchema } from "../lib/schemas.ts";
import { accessQuery, useSession } from "../lib/session.tsx";
import { useErrorMessage, useValidationMessage } from "../lib/i18n-helpers.ts";
import { Alert, Badge, Button, Card, Dialog, Field, Input, Select, Table } from "../components/ui.tsx";

interface Draft {
  id: string;
  isNew: boolean;
  type: "store" | "warehouse";
  code: string;
  name: string;
  address: string;
  binsEnabled: boolean;
}

const blank = (): Draft => ({ id: uuidv7(), isNew: true, type: "store", code: "", name: "", address: "", binsEnabled: false });

export function LocationsPage() {
  const { t } = useTranslation(["admin", "common"]);
  const { access } = useSession();
  const qc = useQueryClient();
  const errMsg = useErrorMessage();
  const vm = useValidationMessage();
  const q = useQuery({ queryKey: ["locations"], queryFn: listLocations });
  const [draft, setDraft] = useState<Draft | null>(null);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [archiving, setArchiving] = useState<LocationRow | null>(null);

  const refresh = async () => {
    await qc.invalidateQueries({ queryKey: ["locations"] });
    await qc.invalidateQueries({ queryKey: accessQuery.queryKey });
  };

  const save = useMutation({
    mutationFn: (d: Draft) =>
      rpc("upsert_location", {
        p_id: d.id,
        p_type: d.type,
        p_code: d.code.trim(),
        p_name: d.name.trim(),
        p_address: d.address.trim() || null,
        p_bins_enabled: d.type === "warehouse" && d.binsEnabled,
      }),
    onSuccess: async () => {
      setDraft(null);
      await refresh();
    },
  });
  const archive = useMutation({
    mutationFn: (id: string) => rpc("archive_location", { p_id: id }),
    onSuccess: async () => {
      setArchiving(null);
      await refresh();
    },
  });

  function submit(e: FormEvent) {
    e.preventDefault();
    if (!draft) return;
    const r = locationSchema.safeParse(draft);
    if (!r.success) return setErrors(fieldErrors(r.error));
    setErrors({});
    save.mutate(draft);
  }

  const open = (d: Draft | null) => {
    save.reset();
    setErrors({});
    setDraft(d);
  };

  return (
    <>
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold">{t("locations.title")}</h1>
        <Button onClick={() => open(blank())}>{t("locations.add")}</Button>
      </div>

      {q.isError ? <Alert>{errMsg(q.error)}</Alert> : null}
      <Card className="overflow-x-auto p-0">
        <Table bare>
          <thead className="border-b border-slate-200 text-xs text-slate-500 uppercase">
            <tr>
              <th className="p-3">{t("locations.code")}</th>
              <th className="p-3">{t("locations.name")}</th>
              <th className="p-3">{t("locations.typeLabel")}</th>
              <th className="p-3" />
            </tr>
          </thead>
          <tbody>
            {(q.data ?? []).map((l) => (
              <tr key={l.id} className="border-b border-slate-100 last:border-0">
                <td className="p-3 font-mono">{l.code}</td>
                <td className="p-3">
                  {l.name}
                  {l.address ? <div className="text-xs text-slate-500">{l.address}</div> : null}
                </td>
                <td className="p-3">
                  <Badge>{t(`locations.type.${l.type}`)}</Badge>{" "}
                  {l.bins_enabled ? <Badge tone="warn">{t("locations.bins")}</Badge> : null}
                </td>
                <td className="flex justify-end gap-2 p-3">
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() =>
                      open({
                        id: l.id,
                        isNew: false,
                        type: l.type,
                        code: l.code,
                        name: l.name,
                        address: l.address ?? "",
                        binsEnabled: l.bins_enabled,
                      })
                    }
                  >
                    {t("common:actions.edit")}
                  </Button>
                  <Button size="sm" variant="ghost" onClick={() => setArchiving(l)}>
                    {t("locations.archive")}
                  </Button>
                </td>
              </tr>
            ))}
            {q.data?.length === 0 ? (
              <tr>
                <td colSpan={4} className="p-4 text-center text-slate-500">
                  {t("locations.empty")}
                </td>
              </tr>
            ) : null}
          </tbody>
        </Table>
      </Card>

      <Dialog
        open={draft !== null}
        onOpenChange={(o) => !o && setDraft(null)}
        title={draft?.isNew ? t("locations.add") : t("locations.edit")}
        closeLabel={t("common:actions.close")}
      >
        {draft ? (
          <form onSubmit={submit} className="grid gap-4" noValidate>
            {save.isError ? <Alert>{errMsg(save.error)}</Alert> : null}
            <Field label={t("locations.typeLabel")} hint={draft.isNew ? undefined : t("locations.typeLocked")}>
              <Select
                value={draft.type}
                disabled={!draft.isNew}
                onChange={(e) => setDraft({ ...draft, type: e.target.value as Draft["type"] })}
              >
                <option value="store">{t("locations.type.store")}</option>
                {access.modules.warehouse || draft.type === "warehouse" ? (
                  <option value="warehouse">{t("locations.type.warehouse")}</option>
                ) : null}
              </Select>
            </Field>
            <Field label={t("locations.code")} error={vm(errors["code"])}>
              <Input value={draft.code} onChange={(e) => setDraft({ ...draft, code: e.target.value })} />
            </Field>
            <Field label={t("locations.name")} error={vm(errors["name"])}>
              <Input value={draft.name} onChange={(e) => setDraft({ ...draft, name: e.target.value })} />
            </Field>
            <Field label={t("locations.address")} error={vm(errors["address"])}>
              <Input value={draft.address} onChange={(e) => setDraft({ ...draft, address: e.target.value })} />
            </Field>
            {draft.type === "warehouse" ? (
              <label className="flex items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  checked={draft.binsEnabled}
                  onChange={(e) => setDraft({ ...draft, binsEnabled: e.target.checked })}
                />
                {t("locations.binsEnabled")}
              </label>
            ) : null}
            <div className="flex justify-end gap-2">
              <Button variant="outline" onClick={() => setDraft(null)}>
                {t("common:actions.cancel")}
              </Button>
              <Button type="submit" disabled={save.isPending}>
                {t("common:actions.save")}
              </Button>
            </div>
          </form>
        ) : null}
      </Dialog>

      <Dialog
        open={archiving !== null}
        onOpenChange={(o) => !o && setArchiving(null)}
        title={t("locations.archive")}
        closeLabel={t("common:actions.close")}
      >
        <div className="grid gap-4">
          {archive.isError ? <Alert>{errMsg(archive.error)}</Alert> : null}
          <p className="text-sm">{t("locations.archiveConfirm", { name: archiving?.name ?? "" })}</p>
          <div className="flex justify-end gap-2">
            <Button variant="outline" onClick={() => setArchiving(null)}>
              {t("common:actions.cancel")}
            </Button>
            <Button variant="danger" disabled={archive.isPending} onClick={() => archiving && archive.mutate(archiving.id)}>
              {t("locations.archive")}
            </Button>
          </div>
        </div>
      </Dialog>
    </>
  );
}
