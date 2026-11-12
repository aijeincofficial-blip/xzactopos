import { rpc } from "./api.ts";

export interface StoreApprover {
  user_id: string;
  full_name: string;
  role: string;
  position: string | null;
}

/** Fetches active supervisors and managers eligible to approve actions at `locationId`. */
export async function fetchStoreApprovers(locationId?: string): Promise<StoreApprover[]> {
  return await rpc<StoreApprover[]>("list_store_approvers", {
    p_location_id: locationId || null,
  });
}

export interface SupervisorApprovalResult {
  ok: boolean;
  approval_id?: string;
  approved_by?: string;
  expires_at?: string;
  hint?: string;
}

export type ApprovalAction =
  | "sale_discount"
  | "void_sale"
  | "record_expense"
  | "void_expense"
  | "close_day"
  | "record_service_txn"
  | "void_service_txn";

/**
 * Requests a supervisor approval using the supervisor's PIN.
 * Returns { ok: true, approval_id, ... } or { ok: false, hint: "pin_wrong" | "pin_locked" | "pin_not_set" }.
 */
export async function approveSupervisorAction(
  action: ApprovalAction,
  refId: string,
  pin: string,
  locationId?: string,
  approverId?: string,
): Promise<SupervisorApprovalResult> {
  return await rpc<SupervisorApprovalResult>("approve_supervisor_action", {
    p_action: action,
    p_ref_id: refId,
    p_pin: pin,
    p_location_id: locationId || null,
    p_approver_id: approverId || null,
  });
}
