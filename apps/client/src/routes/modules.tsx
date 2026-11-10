import { useState } from "react";
import { useTranslation } from "react-i18next";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { rpc } from "../lib/api.ts";
import { accessQuery, useSession } from "../lib/session.tsx";
import { useErrorMessage } from "../lib/i18n-helpers.ts";
import { Alert, Button, Card, useToast } from "../components/ui.tsx";
import { ModuleChoice } from "../components/ModuleChoice.tsx";

export function ModulesPage() {
  const { t } = useTranslation(["admin", "common"]);
  const { access } = useSession();
  const qc = useQueryClient();
  const errMsg = useErrorMessage();
  const toast = useToast();
  const [pos, setPos] = useState(access.modules.pos);
  const [warehouse, setWarehouse] = useState(access.modules.warehouse);

  const save = useMutation({
    mutationFn: () => rpc("set_modules", { p_pos: pos, p_warehouse: warehouse }),
    onSuccess: () => {
      toast.good(t("common:saved"));
      return qc.invalidateQueries({ queryKey: accessQuery.queryKey });
    },
    onError: (e) => toast.error(errMsg(e)),
  });
  const dirty = pos !== access.modules.pos || warehouse !== access.modules.warehouse;
  const turningOff = (access.modules.pos && !pos) || (access.modules.warehouse && !warehouse);

  return (
    <Card className="grid gap-4">
      <h1 className="text-xl font-semibold">{t("modulesForm.title")}</h1>
      {save.isError ? <Alert>{errMsg(save.error)}</Alert> : null}
      {save.isSuccess && !dirty ? <Alert tone="info">{t("common:saved")}</Alert> : null}
      <ModuleChoice pos={pos} warehouse={warehouse} onPos={setPos} onWarehouse={setWarehouse} />
      {turningOff ? <Alert tone="info">{t("modulesForm.offWarning")}</Alert> : null}
      <div>
        <Button disabled={!dirty || save.isPending} onClick={() => save.mutate()}>
          {t("common:actions.save")}
        </Button>
      </div>
    </Card>
  );
}
