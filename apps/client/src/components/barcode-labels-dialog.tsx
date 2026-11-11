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
  product?: BarcodeProduct | null;
  products?: BarcodeProduct[] | null;
  currency: string;
  storeName?: string;
  titleOverride?: string;
  subtitleOverride?: string;
  storeLabelOverride?: string;
  skuLabelOverride?: string;
  copiesLabelOverride?: string;
}

export interface BinBarcodeInput {
  code: string;
  zone_code?: string | null;
  aisle?: string | null;
  rack?: string | null;
  shelf?: string | null;
  position?: string | null;
  type: string;
}

/** Converts a warehouse bin row into a Code 128 printable sticker item. */
export function formatBinBarcodeItem(bin: BinBarcodeInput): BarcodeProduct {
  const posParts = [
    bin.aisle ? `A${bin.aisle}` : null,
    bin.rack ? `R${bin.rack}` : null,
    bin.shelf ? `S${bin.shelf}` : null,
    bin.position ? `P${bin.position}` : null,
  ].filter(Boolean);
  const posText = posParts.length > 0 ? posParts.join("-") : bin.type.toUpperCase();
  const labelTitle = [bin.zone_code, posText].filter(Boolean).join(" · ");
  return {
    name: labelTitle || bin.code,
    sku: bin.code,
    barcode: bin.code,
    price: null,
  };
}

export function buildPrintItems(
  items: BarcodeProduct[],
  copies: number,
  currency: string,
  locale = "en",
): { product: BarcodeProduct; code: string; priceDisplay: string }[] {
  const result: { product: BarcodeProduct; code: string; priceDisplay: string }[] = [];
  const safeCopies = Math.max(1, copies);
  for (const item of items) {
    const code = item.barcode?.trim() || item.sku;
    const priceDisplay =
      item.price != null ? formatMoney(money(item.price, currency), locale) : "";
    for (let i = 0; i < safeCopies; i++) {
      result.push({ product: item, code, priceDisplay });
    }
  }
  return result;
}

export function BarcodeLabelsDialog({
  open,
  onClose,
  product,
  products,
  currency,
  storeName = "Store",
  titleOverride,
  subtitleOverride,
  storeLabelOverride,
  skuLabelOverride,
  copiesLabelOverride,
}: BarcodeLabelsDialogProps) {
  const { t, i18n } = useTranslation("admin");
  const [quantity, setQuantity] = useState(1);
  const [copies, setCopies] = useState(1);
  const [format, setFormat] = useState<"roll" | "sheet">("roll");
  const [includePrice, setIncludePrice] = useState(true);
  const [includeStore, setIncludeStore] = useState(true);
  const [includeSku, setIncludeSku] = useState(true);
  const [previewIdx, setPreviewIdx] = useState(0);

  const items: BarcodeProduct[] =
    products && products.length > 0 ? products : product ? [product] : [];

  if (!open || items.length === 0) return null;

  const hasAnyPrice = items.some((item) => item.price != null);
  const isBatch = items.length > 1;
  const currentPreview = items[Math.min(previewIdx, items.length - 1)] ?? items[0]!;
  const previewCode = currentPreview.barcode?.trim() || currentPreview.sku;
  const previewPriceDisplay =
    currentPreview.price != null
      ? formatMoney(money(currentPreview.price, currency), i18n.language)
      : "";

  const handlePrint = () => {
    window.print();
  };

  const count = isBatch ? copies : quantity;
  const printItems = buildPrintItems(items, count, currency, i18n.language);

  const dialogTitle =
    titleOverride ??
    (isBatch
      ? t("barcodeLabels.batchTitle", { count: items.length })
      : t("barcodeLabels.title"));

  return (
    <>
      <Dialog
        open={open}
        onOpenChange={(isOpen) => {
          if (!isOpen) onClose();
        }}
        title={dialogTitle}
        closeLabel={t("barcodeLabels.close")}
      >
        <div className="space-y-6 pt-1" data-testid="barcode-labels-dialog">
          <p className="text-sm text-slate-600">
            {subtitleOverride ?? t("barcodeLabels.subtitle")}
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

            {isBatch ? (
              <Field label={copiesLabelOverride ?? t("barcodeLabels.copiesPerProduct")}>
                <Input
                  type="number"
                  min={1}
                  max={50}
                  value={copies}
                  onChange={(e) => {
                    const val = parseInt(e.target.value, 10);
                    setCopies(isNaN(val) ? 1 : Math.max(1, Math.min(val, 50)));
                  }}
                  data-testid="barcode-copies-input"
                />
              </Field>
            ) : (
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
            )}
          </div>

          {/* Label Options */}
          <div className="rounded-[10px] border border-slate-200 p-4 space-y-3 bg-slate-50">
            {hasAnyPrice ? (
              <label className="flex items-center gap-3 text-sm text-slate-700 cursor-pointer">
                <input
                  type="checkbox"
                  checked={includePrice}
                  onChange={(e) => setIncludePrice(e.target.checked)}
                  className="h-4 w-4 rounded-[4px] border-slate-300 text-brand-600 focus:ring-brand-500"
                  data-testid="include-price-checkbox"
                />
                <span>{t("barcodeLabels.includePrice")}</span>
              </label>
            ) : null}

            <label className="flex items-center gap-3 text-sm text-slate-700 cursor-pointer">
              <input
                type="checkbox"
                checked={includeStore}
                onChange={(e) => setIncludeStore(e.target.checked)}
                className="h-4 w-4 rounded-[4px] border-slate-300 text-brand-600 focus:ring-brand-500"
                data-testid="include-store-checkbox"
              />
              <span>{storeLabelOverride ?? t("barcodeLabels.includeStore")}</span>
            </label>

            <label className="flex items-center gap-3 text-sm text-slate-700 cursor-pointer">
              <input
                type="checkbox"
                checked={includeSku}
                onChange={(e) => setIncludeSku(e.target.checked)}
                className="h-4 w-4 rounded-[4px] border-slate-300 text-brand-600 focus:ring-brand-500"
                data-testid="include-sku-checkbox"
              />
              <span>{skuLabelOverride ?? t("barcodeLabels.includeSku")}</span>
            </label>
          </div>

          {/* Preview Section */}
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <span className="text-xs font-semibold uppercase tracking-wider text-slate-500">
                {t("barcodeLabels.preview")}
              </span>
              {isBatch ? (
                <div className="flex items-center gap-2">
                  <span className="text-xs text-slate-500">
                    {previewIdx + 1} / {items.length}
                  </span>
                  <div className="flex gap-1">
                    <Button
                      variant="ghost"
                      size="sm"
                      disabled={previewIdx <= 0}
                      onClick={() => setPreviewIdx((i) => Math.max(0, i - 1))}
                    >
                      ←
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      disabled={previewIdx >= items.length - 1}
                      onClick={() => setPreviewIdx((i) => Math.min(items.length - 1, i + 1))}
                    >
                      →
                    </Button>
                  </div>
                </div>
              ) : null}
            </div>

            <div className="flex justify-center p-4 bg-slate-100 rounded-[10px] border border-slate-200">
              <div
                className="bg-white text-slate-900 border border-slate-300 rounded-[6px] shadow-sm flex flex-col justify-between items-center text-center p-3 select-none"
                style={{ width: "220px", minHeight: "130px" }}
                data-testid="barcode-label-preview"
              >
                {includeStore ? (
                  <span className="text-xs font-semibold tracking-wider uppercase text-slate-600 max-w-[200px] truncate">
                    {storeName}
                  </span>
                ) : null}

                <span className="text-xs font-semibold text-slate-900 max-w-[200px] truncate">
                  {currentPreview.name}
                </span>

                <div className="w-full my-1 flex justify-center">
                  <BarcodeSvg
                    value={previewCode}
                    height={30}
                    showText={includeSku}
                    className="text-black"
                  />
                </div>

                {hasAnyPrice && includePrice && previewPriceDisplay ? (
                  <span className="text-base font-semibold text-slate-950 tabular-nums">
                    {previewPriceDisplay}
                  </span>
                ) : null}
              </div>
            </div>
          </div>

          {/* Action Buttons */}
          <div className="flex items-center justify-between pt-2">
            <span className="text-xs text-slate-500 tabular-nums">
              {printItems.length} {printItems.length === 1 ? "label" : "labels"} total
            </span>
            <div className="flex items-center gap-3">
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
        </div>
      </Dialog>

      {/* Printable Area (Visible strictly on window.print()) */}
      <div
        className={`printable-barcode-labels format-${format}`}
        aria-hidden="true"
      >
        {printItems.map((pItem, idx) => (
          <div key={idx} className="barcode-label-item">
            {includeStore ? (
              <div style={{ fontSize: "8pt", fontWeight: 600, letterSpacing: "0.5px", textTransform: "uppercase" }}>
                {storeName}
              </div>
            ) : null}

            <div style={{ fontSize: "9pt", fontWeight: 700, margin: "1mm 0" }}>
              {pItem.product.name}
            </div>

            <div style={{ width: "90%", margin: "1mm auto" }}>
              <BarcodeSvg
                value={pItem.code}
                height={26}
                showText={includeSku}
                className="text-black"
              />
            </div>

            {includePrice && pItem.priceDisplay ? (
              <div style={{ fontSize: "12pt", fontWeight: 800, marginTop: "1mm" }}>
                {pItem.priceDisplay}
              </div>
            ) : null}
          </div>
        ))}
      </div>
    </>
  );
}
