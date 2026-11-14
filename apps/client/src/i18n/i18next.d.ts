import type { I18nResourcesSchema } from "./resources-type.ts";

declare module "i18next" {
  interface CustomTypeOptions {
    defaultNS: "common";
    resources: I18nResourcesSchema;
  }
}
