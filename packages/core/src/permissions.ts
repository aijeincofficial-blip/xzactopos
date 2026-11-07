/**
 * Permission keys and the plan's §5 permission matrix, as a pure function.
 *
 * The UI uses this to hide what a user cannot do. It is NOT the security boundary:
 * every RPC re-checks role, location and module in Postgres.
 *
 * Location-scoped keys are evaluated per location, so an admin who is manager in Store A and
 * supervisor in Store B gets different answers for A and B. Without a location id the question
 * becomes "can I do this in at least one of my locations?" (useful for menus).
 */

export type Role = "superadmin" | "admin" | "warehouse" | "cashier";
export type Position = "manager" | "supervisor";
export type ModuleName = "inventory" | "pos" | "warehouse";
export type LocationType = "store" | "warehouse";

export interface LocationGrant {
  readonly type: LocationType;
  /** Only admins hold a position. */
  readonly position: Position | null;
}

export interface AccessContext {
  readonly role: Role;
  readonly active: boolean;
  /** false when the tenant is suspended: reads still work, writes do not. */
  readonly tenantActive: boolean;
  readonly modules: Readonly<Record<ModuleName, boolean>>;
  /** Superadmins get every live location of the tenant here. */
  readonly locations: Readonly<Record<string, LocationGrant>>;
}

/** Extra limits the UI must apply (and the RPC enforces) when a permission is conditional. */
export type Condition =
  | "with_pin" // discount above threshold: supervisor enters a PIN
  | "own_only" // cashier: own sale (same shift, below limit) or own shift
  | "cashiers_only" // manager: manage cashiers in own stores only
  | "receive_only" // manager: receive transfers at own store only
  | "cost_and_sku_only" // warehouse: edit cost and SKU only
  | "own_shift_summary"; // cashier: store report limited to own shift

export type DenyReason = "inactive" | "tenant_suspended" | "module_disabled" | "role" | "location";

export type Decision =
  | { readonly allowed: true; readonly condition?: Condition }
  | { readonly allowed: false; readonly reason: DenyReason };

type RoleRule = true | Condition;

interface Rule {
  /** Module that must be enabled. */
  readonly module?: ModuleName;
  /** "tenant" = not tied to a location; "location" = evaluated per assigned location. */
  readonly scope: "tenant" | "location";
  /** Writes are blocked while the tenant is suspended; reads are not. */
  readonly write: boolean;
  readonly superadmin?: RoleRule;
  readonly manager?: RoleRule;
  readonly supervisor?: RoleRule;
  readonly warehouse?: RoleRule;
  readonly cashier?: RoleRule;
}

/** Plan §5 permission matrix. Missing role entry = not allowed. */
export const PERMISSION_RULES = {
  "tenant.settings": { scope: "tenant", write: true, superadmin: true },
  "tenant.modules": { scope: "tenant", write: true, superadmin: true },
  "locations.manage": { scope: "tenant", write: true, superadmin: true },
  "users.manage": { scope: "location", write: true, superadmin: true, manager: "cashiers_only" },
  "catalog.manage": {
    module: "inventory",
    scope: "location",
    write: true,
    superadmin: true,
    manager: true,
    warehouse: "cost_and_sku_only",
  },
  "sale.create": {
    module: "pos",
    scope: "location",
    write: true,
    superadmin: true,
    manager: true,
    supervisor: true,
    cashier: true,
  },
  "discount.override": {
    module: "pos",
    scope: "location",
    write: true,
    superadmin: true,
    manager: true,
    supervisor: "with_pin",
  },
  "sale.void": {
    module: "pos",
    scope: "location",
    write: true,
    superadmin: true,
    manager: true,
    supervisor: true,
    cashier: "own_only",
  },
  "shift.manage": {
    module: "pos",
    scope: "location",
    write: true,
    superadmin: true,
    manager: true,
    supervisor: true,
    cashier: "own_only",
  },
  "stock.adjust_store": { module: "inventory", scope: "location", write: true, superadmin: true, manager: true },
  "stock.adjust_warehouse": { module: "warehouse", scope: "location", write: true, superadmin: true, warehouse: true },
  "purchasing.manage": { module: "warehouse", scope: "location", write: true, superadmin: true, warehouse: true },
  "transfer.manage": {
    module: "warehouse",
    scope: "location",
    write: true,
    superadmin: true,
    warehouse: true,
    manager: "receive_only",
  },
  "stock.count": { module: "inventory", scope: "location", write: true, superadmin: true, manager: true, warehouse: true },
  "reports.store": {
    module: "inventory",
    scope: "location",
    write: false,
    superadmin: true,
    manager: true,
    supervisor: true,
    cashier: "own_shift_summary",
  },
  "reports.warehouse": { module: "warehouse", scope: "location", write: false, superadmin: true, warehouse: true },
  "audit.read": { scope: "location", write: false, superadmin: true, manager: true },
} as const satisfies Record<string, Rule>;

export type PermissionKey = keyof typeof PERMISSION_RULES;
export const PERMISSION_KEYS = Object.keys(PERMISSION_RULES) as PermissionKey[];

const deny = (reason: DenyReason): Decision => ({ allowed: false, reason });
const allow = (rule: RoleRule): Decision =>
  rule === true ? { allowed: true } : { allowed: true, condition: rule };

function ruleFor(rule: Rule, role: Role, grant: LocationGrant | null): RoleRule | undefined {
  if (role === "admin") return grant?.position ? rule[grant.position] : undefined;
  if (role === "superadmin") return rule.superadmin;
  return rule[role];
}

export function check(ctx: AccessContext, key: PermissionKey, locationId?: string): Decision {
  const rule: Rule = PERMISSION_RULES[key];

  if (!ctx.active) return deny("inactive");
  if (rule.write && !ctx.tenantActive) return deny("tenant_suspended");
  if (rule.module && !ctx.modules[rule.module]) return deny("module_disabled");

  if (locationId !== undefined && !ctx.locations[locationId]) return deny("location");

  if (ctx.role === "superadmin") {
    return rule.superadmin ? allow(rule.superadmin) : deny("role");
  }

  if (rule.scope === "tenant") {
    const r = ruleFor(rule, ctx.role, null);
    return r ? allow(r) : deny("role");
  }

  const grants = locationId !== undefined ? [ctx.locations[locationId]!] : Object.values(ctx.locations);

  // An unconditional allow at any candidate location beats a conditional one.
  let best: RoleRule | undefined;
  for (const grant of grants) {
    const r = ruleFor(rule, ctx.role, grant);
    if (r === true) return allow(true);
    best ??= r;
  }
  if (best) return allow(best);
  return deny(grants.length === 0 ? "location" : "role");
}

export function can(ctx: AccessContext, key: PermissionKey, locationId?: string): boolean {
  return check(ctx, key, locationId).allowed;
}

/** Shape returned by the `get_my_access()` RPC. */
export interface MyAccessPayload {
  role: Role;
  tenant: { status: "active" | "suspended" | "archived" };
  modules: Record<ModuleName, boolean>;
  locations: Array<{ id: string; type: LocationType; position: Position | null }>;
}

/** Build an AccessContext from `get_my_access()`. The RPC only answers for active users. */
export function contextFromAccess(payload: MyAccessPayload): AccessContext {
  return {
    role: payload.role,
    active: true,
    tenantActive: payload.tenant.status === "active",
    modules: { inventory: payload.modules.inventory, pos: payload.modules.pos, warehouse: payload.modules.warehouse },
    locations: Object.fromEntries(
      payload.locations.map((l) => [l.id, { type: l.type, position: l.position }]),
    ),
  };
}
