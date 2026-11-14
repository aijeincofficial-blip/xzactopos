import { supabase } from "./supabase.ts";
import { fetchAllPages, fromRaw, rpc } from "./api.ts";
import type { PoItemPayload, PoStatus } from "./purchasing-math.ts";

export interface Supplier {
  id: string;
  name: string;
  contact_name: string | null;
  phone: string | null;
  email: string | null;
  notes: string | null;
}

export interface VariantOption {
  id: string;
  sku: string;
  product: { name: string; unit: string } | null;
}

export interface PoItemRow {
  id: string;
  po_id: string;
  variant_id: string;
  qty_ordered: number;
  qty_received: number;
  unit_cost: number | null;
  variant: VariantOption | null;
}

export interface PurchaseOrder {
  id: string;
  po_no: string;
  warehouse_id: string;
  supplier_id: string;
  status: PoStatus;
  expected_at: string | null;
  notes: string | null;
  ordered_at: string | null;
  cancelled_at: string | null;
  cancel_reason: string | null;
  short_closed_at: string | null;
  close_reason: string | null;
  created_at: string;
  supplier: { id: string; name: string } | null;
  warehouse: { id: string; code: string; name: string } | null;
  po_items: PoItemRow[];
}

export interface GoodsReceiptItem {
  id: string;
  variant_id: string;
  qty: number;
  unit_cost: number | null;
  qty_remaining_before: number | null;
  over_received: boolean;
  variant: VariantOption | null;
}

export interface GoodsReceipt {
  id: string;
  grn_no: string;
  warehouse_id: string;
  po_id: string | null;
  supplier_id: string | null;
  without_po: boolean;
  delivery_ref: string | null;
  notes: string | null;
  has_discrepancy: boolean;
  received_at: string;
  supplier: { id: string; name: string } | null;
  warehouse: { id: string; code: string; name: string } | null;
  purchase_order: { po_no: string } | null;
  goods_receipt_items: GoodsReceiptItem[];
}

/** What receive_po / receive_without_po answer. */
export interface ReceiptResult {
  grn_id: string;
  grn_no: string;
  po_status: PoStatus | null;
  has_discrepancy: boolean;
  without_po: boolean;
  replay?: boolean;
}

const VARIANT = "variant:product_variants(id, sku, product:products(name, unit))";

// Row-level security limits every read to the warehouses the signed-in user may see.

export async function listSuppliers(): Promise<Supplier[]> {
  const { data, error } = await supabase
    .from("suppliers")
    .select("id, name, contact_name, phone, email, notes")
    .is("deleted_at", null)
    .order("name")
    .limit(500);
  if (error) throw fromRaw(error);
  return (data ?? []) as Supplier[];
}

export async function listVariantOptions(): Promise<VariantOption[]> {
  return await fetchAllPages<VariantOption>((from, to) =>
    supabase
      .from("product_variants")
      .select("id, sku, product:products(name, unit)")
      .is("deleted_at", null)
      .eq("active", true)
      .order("sku")
      .order("id")
      .range(from, to),
  );
}

export async function listPurchaseOrders(): Promise<PurchaseOrder[]> {
  const { data, error } = await supabase
    .from("purchase_orders")
    .select(
      `id, po_no, warehouse_id, supplier_id, status, expected_at, notes, ordered_at, cancelled_at, cancel_reason,
       short_closed_at, close_reason, created_at,
       supplier:suppliers!purchase_orders_supplier_fk(id, name),
       warehouse:locations!purchase_orders_warehouse_fk(id, code, name),
       po_items(id, po_id, variant_id, qty_ordered, qty_received, unit_cost, ${VARIANT})`,
    )
    .order("created_at", { ascending: false })
    .limit(200);
  if (error) throw fromRaw(error);
  return (data ?? []) as unknown as PurchaseOrder[];
}

export async function listGoodsReceipts(): Promise<GoodsReceipt[]> {
  const { data, error } = await supabase
    .from("goods_receipts")
    .select(
      `id, grn_no, warehouse_id, po_id, supplier_id, without_po, delivery_ref, notes, has_discrepancy, received_at,
       supplier:suppliers!goods_receipts_supplier_fk(id, name),
       warehouse:locations!goods_receipts_warehouse_fk(id, code, name),
       purchase_order:purchase_orders!goods_receipts_po_fk(po_no),
       goods_receipt_items(id, variant_id, qty, unit_cost, qty_remaining_before, over_received, ${VARIANT})`,
    )
    .order("received_at", { ascending: false })
    .limit(100);
  if (error) throw fromRaw(error);
  return (data ?? []) as unknown as GoodsReceipt[];
}

export interface SupplierInput {
  id: string;
  name: string;
  contact_name: string;
  phone: string;
  email: string;
  notes: string;
}

const orNull = (s: string) => (s.trim() === "" ? null : s.trim());

export async function upsertSupplier(s: SupplierInput): Promise<string> {
  return await rpc<string>("upsert_supplier", {
    p_id: s.id,
    p_name: s.name,
    p_contact_name: orNull(s.contact_name),
    p_phone: orNull(s.phone),
    p_email: orNull(s.email),
    p_notes: orNull(s.notes),
  });
}

export async function archiveSupplier(id: string): Promise<string> {
  return await rpc<string>("archive_supplier", { p_id: id });
}

export async function createPo(args: {
  id: string;
  warehouseId: string;
  supplierId: string;
  expectedAt: string;
  notes: string;
  items: PoItemPayload[];
}): Promise<string> {
  return await rpc<string>("create_po", {
    p_id: args.id,
    p_warehouse_id: args.warehouseId,
    p_supplier_id: args.supplierId,
    p_expected_at: args.expectedAt === "" ? null : args.expectedAt,
    p_notes: orNull(args.notes),
    p_items: args.items,
  });
}

export async function updatePo(args: {
  poId: string;
  supplierId: string;
  expectedAt: string;
  notes: string;
  items: PoItemPayload[];
}): Promise<string> {
  return await rpc<string>("update_po", {
    p_po_id: args.poId,
    p_supplier_id: args.supplierId,
    p_expected_at: args.expectedAt === "" ? null : args.expectedAt,
    p_notes: orNull(args.notes),
    p_items: args.items,
  });
}

export async function submitPo(poId: string): Promise<string> {
  return await rpc<string>("submit_po", { p_po_id: poId });
}

export async function cancelPo(poId: string, reason: string): Promise<string> {
  return await rpc<string>("cancel_po", { p_po_id: poId, p_reason: orNull(reason) });
}

export async function closePo(poId: string, reason: string): Promise<string> {
  return await rpc<string>("close_po", { p_po_id: poId, p_reason: orNull(reason) });
}

export async function receivePo(args: {
  id: string;
  poId: string;
  items: PoItemPayload[];
  notes: string;
  deliveryRef: string;
}): Promise<ReceiptResult> {
  return await rpc<ReceiptResult>("receive_po", {
    p_id: args.id,
    p_po_id: args.poId,
    p_items: args.items,
    p_notes: orNull(args.notes),
    p_delivery_ref: orNull(args.deliveryRef),
  });
}

export async function receiveWithoutPo(args: {
  id: string;
  warehouseId: string;
  supplierId: string;
  items: PoItemPayload[];
  notes: string;
  deliveryRef: string;
}): Promise<ReceiptResult> {
  return await rpc<ReceiptResult>("receive_without_po", {
    p_id: args.id,
    p_warehouse_id: args.warehouseId,
    p_supplier_id: args.supplierId === "" ? null : args.supplierId,
    p_items: args.items,
    p_notes: orNull(args.notes),
    p_delivery_ref: orNull(args.deliveryRef),
  });
}
