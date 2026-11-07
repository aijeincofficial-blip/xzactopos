import { useState, type FormEvent } from "react";
import { useTranslation } from "react-i18next";
import { useNavigate, useParams } from "@tanstack/react-router";
import { useQueryClient } from "@tanstack/react-query";
import { signIn, signOut, ApiError } from "../lib/api.ts";
import { loginSchema, slugSchema, fieldErrors } from "../lib/schemas.ts";
import { accessQuery, lastSlug, rememberSlug } from "../lib/session.tsx";
import { useErrorMessage, useValidationMessage } from "../lib/i18n-helpers.ts";
import { Alert, Button, Card, Field, Input } from "../components/ui.tsx";
import { LanguageSelect } from "../components/LanguageSelect.tsx";

function Shell({ children }: { children: React.ReactNode }) {
  const { t } = useTranslation("common");
  return (
    <main className="mx-auto grid min-h-screen w-full max-w-md content-center gap-4 px-4 py-8">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold">{t("appName")}</h1>
        <LanguageSelect />
      </div>
      {children}
    </main>
  );
}

/** "/" : ask for the business code (tenant slug), then go to its sign-in page. */
export function HomePage() {
  const { t } = useTranslation("auth");
  const navigate = useNavigate();
  const vm = useValidationMessage();
  const [slug, setSlug] = useState(lastSlug() ?? "");
  const [error, setError] = useState<string>();

  function submit(e: FormEvent) {
    e.preventDefault();
    const parsed = slugSchema.safeParse({ slug });
    if (!parsed.success) return setError(vm(fieldErrors(parsed.error)["slug"]));
    void navigate({ to: "/t/$slug", params: { slug: parsed.data.slug } });
  }

  return (
    <Shell>
      <Card>
        <form onSubmit={submit} className="grid gap-4" noValidate>
          <h2 className="text-lg font-medium">{t("home.title")}</h2>
          <Field label={t("home.slug")} hint={t("home.slugHint")} error={error}>
            <Input value={slug} onChange={(e) => setSlug(e.target.value)} autoFocus autoCapitalize="none" />
          </Field>
          <Button type="submit">{t("home.continue")}</Button>
        </form>
      </Card>
    </Shell>
  );
}

/** "/t/<slug>" : sign in with username (cashiers) or email (invited users). */
export function LoginPage() {
  const { t } = useTranslation("auth");
  const { slug } = useParams({ from: "/t/$slug" });
  const navigate = useNavigate();
  const qc = useQueryClient();
  const errMsg = useErrorMessage();
  const vm = useValidationMessage();
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string>();
  const [busy, setBusy] = useState(false);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setFormError(undefined);
    const parsed = loginSchema.safeParse({ identifier, password });
    if (!parsed.success) return setErrors(fieldErrors(parsed.error));
    setErrors({});
    setBusy(true);
    try {
      await signIn(slug, parsed.data.identifier, parsed.data.password);
      const access = await qc.fetchQuery({ ...accessQuery, staleTime: 0 });
      // An email sign-in is not tied to the slug in the URL: make sure they match.
      if (access.tenant.slug !== slug) {
        await signOut();
        qc.clear();
        throw new ApiError("wrong_tenant", "tenant mismatch");
      }
      rememberSlug(slug);
      await navigate({ to: "/app" });
    } catch (err) {
      setFormError(errMsg(err instanceof ApiError && err.key === "forbidden" ? new ApiError("no_account", "") : err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Shell>
      <Card>
        <form onSubmit={(e) => void submit(e)} className="grid gap-4" noValidate>
          <div>
            <h2 className="text-lg font-medium">{t("login.title")}</h2>
            <p className="text-sm text-slate-500">{t("login.business", { slug })}</p>
          </div>
          {formError ? <Alert>{formError}</Alert> : null}
          <Field label={t("login.identifier")} hint={t("login.identifierHint")} error={vm(errors["identifier"])}>
            <Input
              value={identifier}
              onChange={(e) => setIdentifier(e.target.value)}
              autoComplete="username"
              autoCapitalize="none"
              autoFocus
            />
          </Field>
          <Field label={t("login.password")} error={vm(errors["password"])}>
            <Input type="password" value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="current-password" />
          </Field>
          <Button type="submit" disabled={busy}>
            {busy ? t("login.signingIn") : t("login.submit")}
          </Button>
          <a href="/" className="text-center text-sm text-slate-600 underline">
            {t("login.otherBusiness")}
          </a>
        </form>
      </Card>
    </Shell>
  );
}
