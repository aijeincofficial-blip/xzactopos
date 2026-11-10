import { useState } from "react";
import { useTranslation } from "react-i18next";
import { formatMoney, money } from "@pos/core";
import { Button, Dialog, Field, Input, Select } from "./ui.tsx";
import { BarcodeSvg } from "../lib/barcode-svg.tsx";

export interface BarcodeProduct {
  name: string;
  sku: string;
  barcode?: string | null;
  price?: number | null;
}

export interface BarcodeLabelsDialogProps {
  open: boolean;
  onClose: () => void;
  product: BarcodeProduct | null;
  currency: string;
  storeName?: string;
}

export function BarcodeLabelsDialog({
  open,
  onClose,
  product,
  currency,
  storeName = "Store",
}: BarcodeLabelsDialogProps) {
  const { t, i18n } = useTranslation("admin");
  const [quantity, setQuantity] = useState(1);
  const [format, setFormat] = useState<"roll" | "sheet">("roll");
  const [includePrice, setIncludePrice] = useState(true);
  const [includeStore, setIncludeStore] = useState(true);
  const [includeSku, setIncludeSku] = useState(true);

  if (!open || !product) return null;

  const code = product.barcode?.trim() || product.sku;
  const priceDisplay =
    product.price != null ? formatMoney(money(product.price, currency), i18n.language) : "";

  const handlePrint = () => {
    window.print();
  };

  const labelCount = Math.max(1, Math.min(quantity, 200));
  const printItems = Array.from({ length: labelCount }, (_, i) => i);

  return (
    <>
      <Dialog
        open={open}
        onOpenChange={(isOpen) => {
          if (!isOpen) onClose();
        }}
        title={t("barcodeLabels.title")}
        closeLabel={t("barcodeLabels.close")}
      >
        <div className="space-y-6 pt-1" data-testid="barcode-labels-dialog">
          <p className="text-sm text-slate-600">
            {t("barcodeLabels.subtitle")}
          </p>

          {/* Form Controls */}
          <div className="grid grid-cols-2 gap-4">
            <Field label={t("barcodeLabels.format")}>
              <Select
                value={format}
                onChange={(e) => setFormat(e.target.value as "roll" | "sheet")}
                data-testid="barcode-format-select"
              >
                <option value="roll">{t("barcodeLabels.formatRoll")}</option>
                <option value="sheet">{t("barcodeLabels.formatSheet")}</option>
              </Select>
            </Field>

            <Field label={t("barcodeLabels.quantity")}>
              <Input
                type="number"
                min={1}
                max={200}
                value={quantity}
                onChange={(e) => {
                  const val = parseInt(e.target.value, 10);
                  setQuantity(isNaN(val) ? 1 : Math.max(1, Math.min(val, 200)));
                }}
                data-testid="barcode-qty-input"
              />
            </Field>
          </div>

          {/* Label Options */}
          <div className="rounded-[10px] border border-slate-200 p-4 space-y-3 bg-slate-50/50">
            <label className="flex items-center gap-2.5 text-sm font-medium text-slate-700 cursor-pointer">
              <input
                type="checkbox"
                checked={includePrice}
                onChange={(e) => setIncludePrice(e.target.checked)}
                className="h-4 w-4 rounded-[4px] border-slate-300 text-brand-600 focus:ring-brand-500"
                data-testid="include-price-checkbox"
              />
              <span>{t("barcodeLabels.includePrice")}</span>
            </label>

            <label className="flex items-center gap-2.5 text-sm font-medium text-slate-700 cursor-pointer">
              <input
                type="checkbox"
                checked={includeStore}
                onChange={(e) => setIncludeStore(e.target.checked)}
                className="h-4 w-4 rounded-[4px] border-slate-300 text-brand-600 focus:ring-brand-500"
                data-testid="include-store-checkbox"
              />
              <span>{t("barcodeLabels.includeStore")}</span>
            </label>

            <label className="flex items-center gap-2.5 text-sm font-medium text-slate-700 cursor-pointer">
              <input
                type="checkbox"
                checked={includeSku}
                onChange={(e) => setIncludeSku(e.target.checked)}
                className="h-4 w-4 rounded-[4px] border-slate-300 text-brand-600 focus:ring-brand-500"
                data-testid="include-sku-checkbox"
              />
              <span>{t("barcodeLabels.includeSku")}</span>
            </label>
          </div>

          {/* Preview Section */}
          <div className="space-y-2">
            <span className="text-xs font-semibold uppercase tracking-wider text-slate-500">
              {t("barcodeLabels.preview")}
            </span>
            <div className="flex justify-center p-4 bg-slate-100 rounded-[10px] border border-slate-200">
              <div
                className="bg-white text-slate-900 border border-slate-300 rounded-[6px] shadow-sm flex flex-col justify-between items-center text-center p-3 select-none"
                style={{ width: "220px", minHeight: "130px" }}
                data-testid="barcode-label-preview"
              >
                {includeStore ? (
                  <span className="text-[10px] font-semibold tracking-wider uppercase text-slate-600 max-w-[200px] truncate">
                    {storeName}
                  </span>
                ) : null}

                <span className="text-xs font-semibold text-slate-900 max-w-[200px] truncate">
                  {product.name}
                </span>

                <div className="w-full my-1 flex justify-center">
                  <BarcodeSvg
                    value={code}
                    height={30}
                    showText={includeSku}
                    className="text-black"
                  />
                </div>

                {includePrice && priceDisplay ? (
                  <span className="text-base font-bold text-slate-950 tabular-nums">
                    {priceDisplay}
                  </span>
                ) : null}
              </div>
            </div>
          </div>

          {/* Action Buttons */}
          <div className="flex items-center justify-end gap-3 pt-2">
            <Button
              variant="outline"
              onClick={onClose}
              data-testid="close-barcode-dialog"
            >
              {t("barcodeLabels.close")}
            </Button>
            <Button
              variant="primary"
              onClick={handlePrint}
              data-testid="print-labels-action"
            >
              {t("barcodeLabels.print")}
            </Button>
          </div>
        </div>
      </Dialog>

      {/* Printable Area (Visible strictly on window.print()) */}
      <div
        className={`printable-barcode-labels format-${format}`}
        aria-hidden="true"
      >
        {printItems.map((idx) => (
          <div key={idx} className="barcode-label-item">
            {includeStore ? (
              <div style={{ fontSize: "8pt", fontWeight: 600, letterSpacing: "0.5px", textTransform: "uppercase" }}>
                {storeName}
              </div>
            ) : null}

            <div style={{ fontSize: "9pt", fontWeight: 700, margin: "1mm 0" }}>
              {product.name}
            </div>

            <div style={{ width: "90%", margin: "1mm auto" }}>
              <BarcodeSvg
                value={code}
                height={26}
                showText={includeSku}
                className="text-black"
              />
            </div>

            {includePrice && priceDisplay ? (
              <div style={{ fontSize: "12pt", fontWeight: 800, marginTop: "1mm" }}>
                {priceDisplay}
              </div>
            ) : null}
          </div>
        ))}
      </div>
    </>
  );
}
