import type enAdmin from "../locales/en/admin.json";
import type enAuth from "../locales/en/auth.json";
import type enCommon from "../locales/en/common.json";
import type enErrors from "../locales/en/errors.json";
import type enShell from "../locales/en/shell.json";

export interface I18nResourcesSchema {
  common: typeof enCommon;
  auth: typeof enAuth;
  shell: typeof enShell;
  admin: typeof enAdmin;
  errors: typeof enErrors;
}
