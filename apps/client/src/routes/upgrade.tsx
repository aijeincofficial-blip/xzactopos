import { useState, type FormEvent } from "react";
import { useTranslation } from "react-i18next";
import { useNavigate } from "@tanstack/react-router";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { uuidv7 } from "@pos/core";
import { rpc } from "../lib/api.ts";
import { fieldErrors, upgradeSchema } from "../lib/schemas.ts";
import { accessQuery, useSession } from "../lib/session.tsx";
import { tenantMode } from "../lib/mode.ts";
import { useErrorMessage, useValidationMessage } from "../lib/i18n-helpers.ts";
import { Alert, Badge, Button, Card, Field, Input, Select } from "../components/ui.tsx";

export function UpgradePage() {
  const { t } = useTranslation(["admin", "common"]);
  const { access } = useSession();
  const qc = useQueryClient();
  const navigate = useNavigate();
  const errMsg = useErrorMessage();
  const vm = useValidationMessage();
  const mode = tenantMode(access);

  const [step, setStep] = useState<"explain" | "configure" | "confirm" | "done">("explain");
  const [warehouse, setWarehouse] = useState(true);
  const [addLocation, setAddLocation] = useState(false);
  const [locationType, setLocationType] = useState<"warehouse" | "store">("warehouse");
  const [locationCode, setLocationCode] = useState("");
  const [locationName, setLocationName] = useState("");
  const [locationAddress, setLocationAddress] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});

  const upgrade = useMutation({
    mutationFn: async () => {
      // 1. Enable modules (POS stays true, warehouse enabled if chosen)
      await rpc("set_modules", { p_pos: true, p_warehouse: warehouse });

      // 2. Optionally add an initial location (if warehouse, module must be on first which step 1 just did!)
      if (addLocation && locationCode.trim() && locationName.trim()) {
        await rpc("upsert_location", {
          p_id: uuidv7(),
          p_type: locationType,
          p_code: locationCode.trim().toUpperCase(),
          p_name: locationName.trim(),
          p_address: locationAddress.trim() || null,
          p_bins_enabled: false,
        });
      }
    },
    onSuccess: async () => {
      await qc.invalidateQueries({ queryKey: accessQuery.queryKey });
      await qc.invalidateQueries({ queryKey: ["locations"] });
      setStep("done");
    },
  });

  if (mode === "full" && step !== "done") {
    return (
      <Card className="grid gap-4">
        <div className="flex items-center gap-3">
          <Badge tone="good">{t("upgrade.badgeActive")}</Badge>
          <h1 className="text-xl font-semibold">{t("upgrade.alreadyFullTitle")}</h1>
        </div>
        <p className="text-sm text-slate-600">{t("upgrade.alreadyFullText")}</p>
        <div className="flex flex-wrap gap-2 pt-2">
          <Button onClick={() => navigate({ to: "/app/locations" })}>{t("nav.locations")}</Button>
          <Button onClick={() => navigate({ to: "/app/users" })} variant="outline">
            {t("nav.users")}
          </Button>
          <Button onClick={() => navigate({ to: "/app/modules" })} variant="outline">
            {t("nav.modules")}
          </Button>
        </div>
      </Card>
    );
  }

  if (step === "done") {
    return (
      <Card className="grid gap-4 text-center py-8">
        <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-emerald-100 text-2xl text-emerald-600">
          ✓
        </div>
        <div className="space-y-1">
          <h1 className="text-2xl font-bold text-slate-900">{t("upgrade.successTitle")}</h1>
          <p className="text-sm text-slate-600 max-w-md mx-auto">{t("upgrade.successText")}</p>
        </div>
        <div className="pt-4 flex justify-center gap-3">
          <Button onClick={() => navigate({ to: "/app" })}>{t("upgrade.goToDashboard")}</Button>
          <Button onClick={() => navigate({ to: "/app/users" })} variant="outline">
            {t("nav.users")}
          </Button>
        </div>
      </Card>
    );
  }

  function handleConfigureNext(e: FormEvent) {
    e.preventDefault();
    const r = upgradeSchema.safeParse({
      warehouse,
      addLocation,
      locationType,
      locationCode,
      locationName,
      locationAddress,
    });
    if (!r.success) {
      setErrors(fieldErrors(r.error));
      return;
    }
    setErrors({});
    setStep("confirm");
  }

  return (
    <div className="grid gap-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">{t("upgrade.title")}</h1>
        <p className="text-sm text-slate-500">{t("upgrade.subtitle")}</p>
      </div>

      {upgrade.isError ? <Alert>{errMsg(upgrade.error)}</Alert> : null}

      {step === "explain" ? (
        <Card className="grid gap-6">
          <div className="space-y-2">
            <h2 className="text-lg font-semibold">{t("upgrade.whyUpgrade")}</h2>
            <div className="grid gap-3 sm:grid-cols-2">
              <div className="rounded-lg border border-slate-200 p-4 bg-slate-50/50">
                <div className="font-medium text-slate-900">{t("upgrade.features.multiStoreTitle")}</div>
                <p className="mt-1 text-xs text-slate-600">{t("upgrade.features.multiStoreDesc")}</p>
              </div>
              <div className="rounded-lg border border-slate-200 p-4 bg-slate-50/50">
                <div className="font-medium text-slate-900">{t("upgrade.features.warehouseTitle")}</div>
                <p className="mt-1 text-xs text-slate-600">{t("upgrade.features.warehouseDesc")}</p>
              </div>
              <div className="rounded-lg border border-slate-200 p-4 bg-slate-50/50">
                <div className="font-medium text-slate-900">{t("upgrade.features.staffTitle")}</div>
                <p className="mt-1 text-xs text-slate-600">{t("upgrade.features.staffDesc")}</p>
              </div>
              <div className="rounded-lg border border-slate-200 p-4 bg-slate-50/50">
                <div className="font-medium text-slate-900">{t("upgrade.features.shiftsTitle")}</div>
                <p className="mt-1 text-xs text-slate-600">{t("upgrade.features.shiftsDesc")}</p>
              </div>
            </div>
          </div>

          <div className="rounded-lg border border-emerald-200 bg-emerald-50/60 p-4">
            <div className="flex items-start gap-2">
              <span className="text-emerald-700 font-bold">🛡️</span>
              <div>
                <h3 className="font-semibold text-emerald-900">{t("upgrade.dataSafetyTitle")}</h3>
                <p className="mt-1 text-xs text-emerald-800 leading-relaxed">
                  {t("upgrade.dataSafetyNote")}
                </p>
              </div>
            </div>
          </div>

          <div className="flex justify-end gap-3 pt-2">
            <Button onClick={() => setStep("configure")}>{t("upgrade.proceedToConfig")}</Button>
          </div>
        </Card>
      ) : null}

      {step === "configure" ? (
        <form onSubmit={handleConfigureNext}>
          <Card className="grid gap-6">
            <h2 className="text-lg font-semibold">{t("upgrade.configTitle")}</h2>

            <div className="space-y-3">
              <div className="font-medium text-sm text-slate-800">{t("upgrade.moduleOptions")}</div>
              <label className="flex items-start gap-3 rounded-lg border border-slate-200 p-3 hover:bg-slate-50 cursor-pointer">
                <input
                  type="checkbox"
                  checked={warehouse}
                  onChange={(e) => setWarehouse(e.target.checked)}
                  className="mt-1 h-4 w-4 rounded border-slate-300 text-indigo-600"
                />
                <div>
                  <div className="font-medium text-sm text-slate-900">{t("upgrade.enableWarehouse")}</div>
                  <div className="text-xs text-slate-500">{t("upgrade.enableWarehouseDesc")}</div>
                </div>
              </label>
            </div>

            <div className="space-y-3 border-t border-slate-200 pt-4">
              <div className="flex items-center justify-between">
                <div>
                  <div className="font-medium text-sm text-slate-800">{t("upgrade.addLocationPrompt")}</div>
                  <div className="text-xs text-slate-500">{t("upgrade.addLocationHint")}</div>
                </div>
                <input
                  type="checkbox"
                  checked={addLocation}
                  onChange={(e) => {
                    const nextVal = e.target.checked;
                    setAddLocation(nextVal);
                    if (nextVal && !locationCode) {
                      setLocationCode(locationType === "warehouse" ? "WH01" : "S02");
                      setLocationName(locationType === "warehouse" ? "Central Warehouse" : "Branch 2");
                    }
                  }}
                  className="h-4 w-4 rounded border-slate-300 text-indigo-600"
                />
              </div>

              {addLocation ? (
                <div className="grid gap-4 rounded-lg bg-slate-50 p-4 border border-slate-200 mt-2">
                  <Field label={t("locations.typeLabel")}>
                    <Select
                      value={locationType}
                      onChange={(e) => {
                        const nextType = e.target.value as "warehouse" | "store";
                        setLocationType(nextType);
                        if (!locationCode || locationCode === "WH01" || locationCode === "S02") {
                          setLocationCode(nextType === "warehouse" ? "WH01" : "S02");
                        }
                        if (!locationName || locationName === "Central Warehouse" || locationName === "Branch 2") {
                          setLocationName(nextType === "warehouse" ? "Central Warehouse" : "Branch 2");
                        }
                      }}
                    >
                      <option value="warehouse">{t("locations.type.warehouse")}</option>
                      <option value="store">{t("locations.type.store")}</option>
                    </Select>
                  </Field>

                  <Field label={t("locations.code")} error={vm(errors["locationCode"])}>
                    <Input
                      value={locationCode}
                      onChange={(e) => setLocationCode(e.target.value.toUpperCase())}
                      placeholder={locationType === "warehouse" ? "WH01" : "S02"}
                    />
                  </Field>

                  <Field label={t("locations.name")} error={vm(errors["locationName"])}>
                    <Input
                      value={locationName}
                      onChange={(e) => setLocationName(e.target.value)}
                      placeholder={locationType === "warehouse" ? "Central Warehouse" : "Branch 2"}
                    />
                  </Field>

                  <Field label={t("locations.address")}>
                    <Input
                      value={locationAddress}
                      onChange={(e) => setLocationAddress(e.target.value)}
                      placeholder="e.g. 123 Rizal St."
                    />
                  </Field>
                </div>
              ) : null}
            </div>

            <div className="flex justify-between gap-3 pt-2">
              <Button type="button" variant="outline" onClick={() => setStep("explain")}>
                {t("common:actions.back")}
              </Button>
              <Button type="submit">{t("upgrade.reviewConfirm")}</Button>
            </div>
          </Card>
        </form>
      ) : null}

      {step === "confirm" ? (
        <Card className="grid gap-6">
          <h2 className="text-lg font-semibold">{t("upgrade.confirmTitle")}</h2>

          <div className="rounded-lg border border-slate-200 divide-y divide-slate-100 text-sm">
            <div className="flex justify-between p-3">
              <span className="text-slate-500">{t("upgrade.business")}</span>
              <span className="font-medium text-slate-900">{access.tenant.name}</span>
            </div>
            <div className="flex justify-between p-3">
              <span className="text-slate-500">{t("upgrade.currentMode")}</span>
              <Badge tone="warn">{t("upgrade.modeSolo")}</Badge>
            </div>
            <div className="flex justify-between p-3">
              <span className="text-slate-500">{t("upgrade.targetMode")}</span>
              <Badge tone="good">{t("upgrade.modeFull")}</Badge>
            </div>
            <div className="flex justify-between p-3">
              <span className="text-slate-500">{t("upgrade.modulesEnabled")}</span>
              <span className="font-medium text-slate-900">
                POS{warehouse ? `, ${t("modules.warehouse")}` : ""}
              </span>
            </div>
            {addLocation ? (
              <div className="flex justify-between p-3">
                <span className="text-slate-500">{t("upgrade.newLocation")}</span>
                <span className="font-medium text-slate-900">
                  {locationCode} · {locationName} ({t(`locations.type.${locationType}`)})
                </span>
              </div>
            ) : null}
            <div className="flex justify-between p-3">
              <span className="text-slate-500">{t("upgrade.dataRetention")}</span>
              <span className="font-medium text-emerald-700">{t("upgrade.allDataRetained")}</span>
            </div>
          </div>

          <div className="flex justify-between gap-3 pt-2">
            <Button
              type="button"
              variant="outline"
              disabled={upgrade.isPending}
              onClick={() => setStep("configure")}
            >
              {t("common:actions.back")}
            </Button>
            <Button
              type="button"
              disabled={upgrade.isPending}
              onClick={() => upgrade.mutate()}
            >
              {upgrade.isPending ? t("upgrade.upgrading") : t("upgrade.confirmAction")}
            </Button>
          </div>
        </Card>
      ) : null}
    </div>
  );
}
