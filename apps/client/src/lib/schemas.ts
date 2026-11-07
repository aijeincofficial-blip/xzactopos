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

/** First error message per field path, ready to show next to inputs. */
export function fieldErrors(error: z.ZodError): Record<string, string> {
  const out: Record<string, string> = {};
  for (const issue of error.issues) {
    const key = issue.path.join(".");
    if (!(key in out)) out[key] = issue.message;
  }
  return out;
}
