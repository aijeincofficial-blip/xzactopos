// Form validation. Messages are i18n keys in the "errors" namespace (validation.*), not display text.
// Patterns mirror the CHECK constraints in the core tenancy migration; the database stays the real gate.
import { z } from "zod";

export const USERNAME_RE = /^[a-z0-9][a-z0-9._-]{1,38}[a-z0-9]$/;
export const SLUG_RE = /^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$/;
export const LOCATION_CODE_RE = /^[A-Za-z0-9][A-Za-z0-9_-]{0,19}$/;

const required = z.string().trim().min(1, "validation.required");

export const slugSchema = z.object({
  slug: z.string().trim().toLowerCase().regex(SLUG_RE, "validation.slug"),
});

export const loginSchema = z.object({
  identifier: required,
  password: z.string().min(1, "validation.required"),
});

export const setupBusinessSchema = z.object({
  name: required.max(120, "validation.max120"),
  baseCurrency: z.string().regex(/^[A-Z]{3}$/, "validation.required"),
  timezone: required.max(64, "validation.max64"),
  taxMode: z.enum(["inclusive", "exclusive", "none"]),
});

export const setupLanguagesSchema = z
  .object({
    locales: z.array(z.enum(["en", "fil"])).min(1, "validation.locales_min"),
    defaultLocale: z.enum(["en", "fil"]),
  })
  .refine((v) => v.locales.includes(v.defaultLocale), {
    path: ["defaultLocale"],
    message: "validation.default_locale_in_list",
  });

export const locationSchema = z.object({
  type: z.enum(["store", "warehouse"]),
  code: z.string().trim().regex(LOCATION_CODE_RE, "validation.location_code"),
  name: required.max(120, "validation.max120"),
  address: z.string().trim().max(300, "validation.max300"),
  binsEnabled: z.boolean(),
});

export const createUserSchema = z
  .object({
    username: z.string().trim().toLowerCase().regex(USERNAME_RE, "validation.username"),
    fullName: z.string().trim().max(120, "validation.max120"),
    password: z.string().min(8, "validation.password").max(72, "validation.password"),
    role: z.enum(["superadmin", "admin", "warehouse", "cashier"]),
    locationId: z.string(),
    position: z.enum(["", "manager", "supervisor"]),
  })
  .superRefine((v, ctx) => {
    if (v.role === "admin" && v.locationId && !v.position) {
      ctx.addIssue({ code: "custom", path: ["position"], message: "validation.position_required" });
    }
    if (v.role === "cashier" && !v.locationId) {
      ctx.addIssue({ code: "custom", path: ["locationId"], message: "validation.location_required" });
    }
  });

export const inviteUserSchema = z
  .object({
    email: z.string().trim().email("validation.email"),
    username: z.string().trim().toLowerCase().regex(USERNAME_RE, "validation.username"),
    fullName: z.string().trim().max(120, "validation.max120"),
    role: z.enum(["superadmin", "admin", "warehouse"]),
    locationId: z.string(),
    position: z.enum(["", "manager", "supervisor"]),
  })
  .superRefine((v, ctx) => {
    if (v.role === "admin" && v.locationId && !v.position) {
      ctx.addIssue({ code: "custom", path: ["position"], message: "validation.position_required" });
    }
  });

export const setPinSchema = z
  .object({
    currentPin: z.string().optional(),
    newPin: z.string().regex(/^\d{4,8}$/, "validation.pin_format"),
    confirmPin: z.string(),
  })
  .refine((v) => v.newPin === v.confirmPin, {
    path: ["confirmPin"],
    message: "validation.pin_match",
  });

export const upgradeSchema = z
  .object({
    warehouse: z.boolean(),
    addLocation: z.boolean(),
    locationType: z.enum(["store", "warehouse"]).optional(),
    locationCode: z.string().trim().optional(),
    locationName: z.string().trim().optional(),
    locationAddress: z.string().trim().max(300, "validation.max300").optional(),
  })
  .superRefine((v, ctx) => {
    if (v.addLocation) {
      if (!v.locationCode || !LOCATION_CODE_RE.test(v.locationCode)) {
        ctx.addIssue({ code: "custom", path: ["locationCode"], message: "validation.location_code" });
      }
      if (!v.locationName || v.locationName.length > 120) {
        ctx.addIssue({ code: "custom", path: ["locationName"], message: "validation.required" });
      }
    }
  });

export const tenantSettingsSchema = z
  .object({
    name: required.max(120, "validation.max120"),
    timezone: required.max(64, "validation.max64"),
    taxMode: z.enum(["inclusive", "exclusive", "none"]),
    defaultLocale: z.enum(["en", "fil"]),
    locales: z.array(z.enum(["en", "fil"])).min(1, "validation.locales_min"),
    offlineSessionDays: z.number().int().min(1, "validation.min1").max(30, "validation.max30"),
    receiptHeader: z.string().trim().max(500, "validation.max500").optional(),
    receiptFooter: z.string().trim().max(500, "validation.max500").optional(),
  })
  .refine((v) => v.locales.includes(v.defaultLocale), {
    path: ["defaultLocale"],
    message: "validation.default_locale_in_list",
  });

export const createTransferSchema = z
  .object({
    fromLocationId: required,
    toLocationId: required,
    notes: z.string().trim().max(1000, "validation.max1000").optional(),
    items: z
      .array(
        z.object({
          variantId: required,
          qty: z.coerce.number().positive("validation.positive_qty"),
        }),
      )
      .min(1, "validation.items_required"),
    shipNow: z.boolean().default(false),
  })
  .refine((v) => v.fromLocationId !== v.toLocationId, {
    path: ["toLocationId"],
    message: "validation.different_locations",
  });

export const receiveTransferSchema = z.object({
  items: z
    .array(
      z.object({
        variantId: required,
        qtyReceived: z.coerce.number().min(0, "validation.non_negative_qty"),
      }),
    )
    .min(1, "validation.items_required"),
});

/** First error message per field path, ready to show next to inputs. */
export function fieldErrors(error: z.ZodError): Record<string, string> {
  const out: Record<string, string> = {};
  for (const issue of error.issues) {
    const key = issue.path.join(".");
    if (!(key in out)) out[key] = issue.message;
  }
  return out;
}
