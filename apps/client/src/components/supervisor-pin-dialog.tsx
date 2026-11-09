import { useEffect, useState, type FormEvent } from "react";
import { useQuery } from "@tanstack/react-query";
import { useTranslation } from "react-i18next";
import { Alert, Button, Dialog, Field, Input, Select } from "./ui.tsx";
import { approveSupervisorAction, fetchStoreApprovers } from "../lib/approvals-api.ts";
import {
  pullOfflinePins,
  getCachedOfflinePins,
  verifyOfflineSupervisorPin,
  type OfflineApprovalPayload,
} from "../lib/offline-pin-api.ts";
import { useDynamicT } from "../lib/i18n-helpers.ts";

export interface SupervisorPinDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  locationId: string;
  action: "sale_discount" | "void_sale";
  refId: string;
  title?: string;
  description?: string;
  onApproved: (approvalId: string, offlineApproval?: OfflineApprovalPayload) => void;
}

export function SupervisorPinDialog({
  open,
  onOpenChange,
  locationId,
  action,
  refId,
  title,
  description,
  onApproved,
}: SupervisorPinDialogProps) {
  const { t } = useTranslation(["admin", "common"]);
  const tr = useDynamicT();
  const [approverId, setApproverId] = useState("");
  const [pin, setPin] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const approversQuery = useQuery({
    queryKey: ["store-approvers", locationId],
    queryFn: async () => {
      try {
        const [approvers] = await Promise.all([
          fetchStoreApprovers(locationId),
          pullOfflinePins(locationId).catch(() => []),
        ]);
        return approvers;
      } catch (err) {
        const cached = getCachedOfflinePins(locationId);
        if (cached.length > 0) {
          return cached.map((c) => ({
            user_id: c.user_id,
            full_name: c.full_name || c.username,
            role: c.role,
            position: c.position,
          }));
        }
        throw err;
      }
    },
    enabled: open && Boolean(locationId),
  });

  const approvers = approversQuery.data ?? [];

  useEffect(() => {
    if (approvers.length > 0 && !approverId) {
      setApproverId(approvers[0]!.user_id);
    }
  }, [approvers, approverId]);

  useEffect(() => {
    if (!open) {
      setPin("");
      setError(null);
      setLoading(false);
    }
  }, [open]);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (!pin || pin.length < 4 || pin.length > 8) {
      setError(tr("errors", "pin_invalid", "pin_invalid"));
      return;
    }

    setLoading(true);
    setError(null);

    try {
      let res;
      try {
        res = await approveSupervisorAction(
          action,
          refId,
          pin,
          locationId,
          approverId || undefined,
        );
      } catch {
        // Fallback to offline verification if network fails
        const offlineRes = await verifyOfflineSupervisorPin(
          approverId,
          pin,
          action,
          refId,
          locationId,
        );
        if (offlineRes.ok && offlineRes.offlineApproval) {
          onApproved("", offlineRes.offlineApproval);
          onOpenChange(false);
          return;
        }
        setError(tr("errors", offlineRes.hint ?? "pin_wrong", "pin_wrong"));
        setLoading(false);
        return;
      }

      if (!res.ok) {
        setError(tr("errors", res.hint ?? "pin_wrong", "pin_wrong"));
        setLoading(false);
        return;
      }

      if (res.approval_id) {
        onApproved(res.approval_id);
        onOpenChange(false);
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      setError(msg);
    } finally {
      setLoading(false);
    }
  }

  const defaultTitle = action === "sale_discount" ? t("supervisor.discountTitle") : t("supervisor.voidTitle");
  const defaultDesc = action === "sale_discount" ? t("supervisor.discountDesc") : t("supervisor.voidDesc");

  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={title || defaultTitle}
      closeLabel={t("common:actions.cancel")}
    >
      <form onSubmit={handleSubmit} className="grid gap-4">
        <p className="text-xs text-slate-500">{description || defaultDesc}</p>

        {error ? <Alert>{error}</Alert> : null}

        {approversQuery.isPending ? (
          <p className="text-sm text-slate-500">{t("supervisor.authorizing")}</p>
        ) : approvers.length === 0 ? (
          <Alert tone="info">{t("supervisor.noApprovers")}</Alert>
        ) : (
          <>
            <Field label={t("supervisor.approver")}>
              <Select value={approverId} onChange={(e) => setApproverId(e.target.value)}>
                {approvers.map((a) => (
                  <option key={a.user_id} value={a.user_id}>
                    {a.full_name || a.role} ({a.position ? tr("admin", `positions.${a.position}`, a.position) : tr("admin", `roles.${a.role}`, a.role)})
                  </option>
                ))}
              </Select>
            </Field>

            <Field label={t("supervisor.pin")} hint={t("supervisor.pinHint")}>
              <Input
                type="password"
                inputMode="numeric"
                autoFocus
                maxLength={8}
                value={pin}
                onChange={(e) => setPin(e.target.value.replace(/\D/g, ""))}
                placeholder="••••"
              />
            </Field>

            <div className="flex justify-end gap-2 pt-2">
              <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
                {t("common:actions.cancel")}
              </Button>
              <Button type="submit" disabled={loading || !pin || approvers.length === 0}>
                {loading ? t("supervisor.authorizing") : t("supervisor.authorize")}
              </Button>
            </div>
          </>
        )}
      </form>
    </Dialog>
  );
}
