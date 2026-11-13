import { useTranslation } from "react-i18next";

/** Inventory is the always-on core: shown ticked and locked. POS and Warehouse are add-ons. */
export function ModuleChoice({
  pos,
  warehouse,
  onPos,
  onWarehouse,
}: {
  pos: boolean;
  warehouse: boolean;
  onPos: (v: boolean) => void;
  onWarehouse: (v: boolean) => void;
}) {
  const { t } = useTranslation("admin");
  const rows = [
    { key: "inventory", checked: true, locked: true, set: () => undefined },
    { key: "pos", checked: pos, locked: false, set: onPos },
    { key: "warehouse", checked: warehouse, locked: false, set: onWarehouse },
  ] as const;

  return (
    <fieldset className="grid gap-3">
      <legend className="mb-1 text-sm font-medium">{t("modulesForm.legend")}</legend>
      {rows.map((r) => (
        <label
          key={r.key}
          className={`flex items-start gap-3 rounded-[18px] border-[1.5px] p-4 transition-colors ${
            r.locked ? "cursor-default" : "cursor-pointer"
          } ${
            r.checked
              ? "border-ink bg-lime/20"
              : "border-sand-line bg-paper hover:border-ink"
          }`}
        >
          <input
            type="checkbox"
            className="mt-1 h-4 w-4 accent-ink"
            checked={r.checked}
            disabled={r.locked}
            onChange={(e) => r.set(e.target.checked)}
          />
          <span>
            <span className="font-display block text-sm font-bold text-text-on-light">
              {t(`modules.${r.key}`)}
            </span>
            <span className="block text-xs text-muted-on-light">{t(`modulesForm.desc.${r.key}`)}</span>
          </span>
        </label>
      ))}
    </fieldset>
  );
}
