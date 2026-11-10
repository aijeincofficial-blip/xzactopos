import { supabase } from "./supabase.ts";
import { fromRaw, rpc } from "./api.ts";

export type TransferStatus = "draft" | "shipped" | "received" | "cancelled";

export interface TransferItemRow {
  id: string;
  transfer_id: string;
  variant_id: string;
  qty_shipped: number;
  qty_received: number | null;
  created_at: string;
  variant?: {
    id: string;
    sku: string;
    product?: {
      name: string;
      unit: string;
    };
  };
}

export interface TransferRow {
  id: string;
  transfer_no: string;
  from_location_id: string;
  to_location_id: string;
  status: TransferStatus;
  notes: string | null;
  shipped_at: string | null;
  shipped_by: string | null;
  received_at: string | null;
  received_by: string | null;
  cancelled_at: string | null;
  cancelled_by: string | null;
  has_discrepancy: boolean;
  created_by: string | null;
  created_at: string;
  updated_at: string;
  from_location?: {
    id: string;
    code: string;
    name: string;
    type: "store" | "warehouse";
    address: string | null;
  };
  to_location?: {
    id: string;
    code: string;
    name: string;
    type: "store" | "warehouse";
    address: string | null;
  };
  transfer_items?: TransferItemRow[];
}

export async function listTransfers(filters?: {
  status?: string;
  locationId?: string;
}): Promise<TransferRow[]> {
  let query = supabase
    .from("transfers")
    .select(
      `
      *,
      from_location:locations!transfers_from_location_fk(id, code, name, type, address),
      to_location:locations!transfers_to_location_fk(id, code, name, type, address),
      transfer_items(
        id, transfer_id, variant_id, qty_shipped, qty_received, created_at,
        variant:product_variants(id, sku, product:products(name, unit))
      )
    `,
    )
    .order("created_at", { ascending: false });

  if (filters?.status && filters.status !== "all") {
    query = query.eq("status", filters.status);
  }

  if (filters?.locationId && filters.locationId !== "all") {
    query = query.or(
      `from_location_id.eq.${filters.locationId},to_location_id.eq.${filters.locationId}`,
    );
  }

  const { data, error } = await query;
  if (error) throw fromRaw(error);
  return (data as TransferRow[]) ?? [];
}

export async function createTransfer(payload: {
  fromLocationId: string;
  toLocationId: string;
  notes?: string;
  items: Array<{ variantId: string; qty: number }>;
  shipNow?: boolean;
}): Promise<string> {
  const itemsJson = payload.items.map((i) => ({
    variant_id: i.variantId,
    qty: i.qty,
  }));
  return rpc<string>("create_transfer", {
    p_from_location_id: payload.fromLocationId,
    p_to_location_id: payload.toLocationId,
    p_notes: payload.notes || null,
    p_items: itemsJson,
    p_ship_now: payload.shipNow ?? false,
  });
}

export async function shipTransfer(transferId: string): Promise<string> {
  return rpc<string>("ship_transfer", { p_transfer_id: transferId });
}

export async function receiveTransfer(
  transferId: string,
  items: Array<{ variantId: string; qtyReceived: number }>,
): Promise<string> {
  const itemsJson = items.map((i) => ({
    variant_id: i.variantId,
    qty_received: i.qtyReceived,
  }));
  return rpc<string>("receive_transfer", {
    p_transfer_id: transferId,
    p_items: itemsJson,
  });
}

export async function cancelTransfer(transferId: string, reason?: string): Promise<string> {
  return rpc<string>("cancel_transfer", {
    p_transfer_id: transferId,
    p_reason: reason || null,
  });
}

export interface PickListItem {
  id: string;
  pick_list_id: string;
  variant_id: string;
  sku: string;
  product_name: string;
  bin_id: string;
  bin_code: string;
  location_info: string;
  qty_requested: number;
  qty_picked: number;
  short_reason: string | null;
}

export interface PickListSummary {
  id: string;
  warehouse_id: string;
  transfer_id: string;
  pick_list_no: string;
  status: "pending" | "in_progress" | "completed" | "cancelled";
  created_at: string;
  items: PickListItem[];
}

export async function generatePickList(transferId: string): Promise<string> {
  return await rpc<string>("generate_pick_list", { p_transfer_id: transferId });
}

export async function getPickListForTransfer(transferId: string): Promise<PickListSummary | null> {
  return await rpc<PickListSummary | null>("get_pick_list_for_transfer", {
    p_transfer_id: transferId,
  });
}

export async function confirmPickItem(args: {
  pickListId: string;
  itemId: string;
  qtyPicked: number;
  shortReason?: string;
}): Promise<void> {
  await rpc("confirm_pick_item", {
    p_pick_list_id: args.pickListId,
    p_item_id: args.itemId,
    p_qty_picked: args.qtyPicked,
    p_short_reason: args.shortReason || null,
  });
}
