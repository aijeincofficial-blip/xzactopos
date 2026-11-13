import { useMemo, useState, type FormEvent } from "react";
import { useTranslation } from "react-i18next";
import { Link, useNavigate, useParams } from "@tanstack/react-router";
import { useQueryClient } from "@tanstack/react-query";
import { KeyRound, Moon, Monitor, Store, Sun, Warehouse } from "lucide-react";
import {
  ApiError,
  provisionSoloStore,
  sendPasswordReset,
  signIn,
  signInWithEmail,
  signOut,
  signUpSolo,
  updatePassword,
} from "../lib/api.ts";
import {
  emailSignInSchema,
  fieldErrors,
  forgotPasswordSchema,
  loginSchema,
  resetPasswordSchema,
  slugSchema,
  soloSignUpSchema,
  storeNameOnlySchema,
} from "../lib/schemas.ts";
import { accessQuery, hasSession, lastSlug, rememberSlug } from "../lib/session.tsx";
import { saveStoredPortal } from "../lib/portal.ts";
import { useErrorMessage, useValidationMessage } from "../lib/i18n-helpers.ts";
import { applyTheme, nextTheme, readTheme, type ThemeChoice } from "../lib/theme.ts";
import { Alert, Button, Dialog, Field, Input, TabPanel, Tabs, useToast } from "../components/ui.tsx";
import { LanguageSelect } from "../components/LanguageSelect.tsx";
import { Receipt, ReceiptDash } from "../ui/Receipt.tsx";

export function ThemeCycleButton() {
  const { t } = useTranslation("common");
  const [choice, setChoice] = useState<ThemeChoice>(() => readTheme());
  const Icon = choice === "dark" ? Moon : choice === "light" ? Sun : Monitor;
  return (
    <Button
      variant="ghost"
      size="sm"
      className="px-2.5 text-muted-on-dark hover:bg-ink-2 hover:text-lime"
      aria-label={`${t("theme.label")}: ${t(`theme.${choice}`)}`}
      title={`${t("theme.label")}: ${t(`theme.${choice}`)}`}
      onClick={() => {
        const next = nextTheme(choice);
        applyTheme(next);
        setChoice(next);
      }}
    >
      <Icon size={16} aria-hidden />
    </Button>
  );
}

function Shell({
  children,
  portal = "pos",
}: {
  children: React.ReactNode;
  portal?: "pos" | "warehouse";
}) {
  const { t } = useTranslation("auth");
  const isWh = portal === "warehouse";
  return (
    <div className="min-h-screen w-full bg-ink text-text-on-dark">
      <main className="mx-auto grid min-h-screen w-full max-w-md content-center gap-6 px-4 py-10">
        <header className="flex flex-wrap items-center justify-between gap-3">
          <Link to="/" className="grid gap-1.5">
            <div className="flex items-center gap-2.5">
              <img
                src="/brand/xzacto-logo-on-dark.svg"
                alt="xzacto"
                width={118}
                height={32}
                className="h-8 w-auto"
              />
              <span
                className={
                  isWh
                    ? "rounded-full bg-sw-pastry px-2.5 py-0.5 font-mono text-[11px] font-semibold tracking-[0.06em] text-sw-pastry-fg uppercase"
                    : "rounded-full bg-lime px-2.5 py-0.5 font-mono text-[11px] font-semibold tracking-[0.06em] text-ink uppercase"
                }
              >
                {isWh ? t("warehouse.badge") : "POS"}
              </span>
            </div>
            <p className="text-xs text-muted-on-dark">
              {isWh ? t("warehouse.tagline") : t("brand.tagline")}
            </p>
          </Link>
          <div className="flex items-center gap-2 [&_select]:min-h-[38px] [&_select]:h-9.5 [&_select]:rounded-full [&_select]:border-[1.5px] [&_select]:border-ink-line-2 [&_select]:bg-ink-2 [&_select]:px-3 [&_select]:text-xs [&_select]:font-medium [&_select]:text-text-on-dark">
            <LanguageSelect />
          </div>
        </header>
        <Receipt className="receipt-float paper-surface px-6 py-7 sm:px-7">
          {children}
        </Receipt>
      </main>
    </div>
  );
}

function ForgotPasswordDialog({
  open,
  onOpenChange,
  initialEmail = "",
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  initialEmail?: string;
}) {
  const { t } = useTranslation("auth");
  const { t: tc } = useTranslation("common");
  const vm = useValidationMessage();
  const [email, setEmail] = useState(initialEmail);
  const [error, setError] = useState<string>();
  const [sent, setSent] = useState(false);
  const [busy, setBusy] = useState(false);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setError(undefined);
    const parsed = forgotPasswordSchema.safeParse({ email });
    if (!parsed.success) {
      setError(vm(fieldErrors(parsed.error)["email"]));
      return;
    }
    setBusy(true);
    try {
      const redirectTo = typeof window !== "undefined" ? `${window.location.origin}/reset-password` : undefined;
      await sendPasswordReset(parsed.data.email, redirectTo);
    } catch {
      // Anti-enumeration: always display the same confirmation whether the email exists or not.
    } finally {
      setBusy(false);
      setSent(true);
    }
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        if (!next) {
          setError(undefined);
          setSent(false);
        }
        onOpenChange(next);
      }}
      title={t("forgot.title")}
      closeLabel={tc("actions.close")}
    >
      {sent ? (
        <div className="grid gap-4">
          <Alert tone="good">{t("forgot.sent")}</Alert>
          <div className="flex justify-end">
            <Button variant="outline" onClick={() => onOpenChange(false)} data-testid="forgot-close-btn">
              {tc("actions.close")}
            </Button>
          </div>
        </div>
      ) : (
        <form onSubmit={(e) => void submit(e)} className="grid gap-4" noValidate>
          <p className="text-sm text-slate-700">{t("forgot.description")}</p>
          <Field label={t("forgot.email")} error={error}>
            <Input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              autoComplete="email"
              autoCapitalize="none"
              autoFocus
              data-testid="forgot-email-input"
            />
          </Field>
          <div className="flex justify-end gap-2">
            <Button variant="outline" onClick={() => onOpenChange(false)}>
              {tc("actions.cancel")}
            </Button>
            <Button type="submit" disabled={busy} data-testid="forgot-send-btn">
              {busy ? t("forgot.sending") : t("forgot.send")}
            </Button>
          </div>
        </form>
      )}
    </Dialog>
  );
}

/** "/" : find your branch by business code, or sign in directly with owner email, or launch Solo sign-up. */
export function HomePage() {
  const { t, i18n } = useTranslation("auth");
  const navigate = useNavigate();
  const qc = useQueryClient();
  const vm = useValidationMessage();
  const errMsg = useErrorMessage();

  const [tab, setTab] = useState<"branch" | "email">("branch");
  const [slug, setSlug] = useState(lastSlug() ?? "");
  const [slugError, setSlugError] = useState<string>();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [emailErrors, setEmailErrors] = useState<Record<string, string>>({});
  const [emailFormError, setEmailFormError] = useState<string>();
  const [busy, setBusy] = useState(false);
  const [forgotOpen, setForgotOpen] = useState(false);

  // If an email-confirmed user signed in but has no tenant yet, finish provisioning right here.
  const [needsStoreName, setNeedsStoreName] = useState(false);
  const [storeName, setStoreName] = useState("");
  const [storeError, setStoreError] = useState<string>();
  const ids = useMemo(() => ({ tenantId: crypto.randomUUID(), locationId: crypto.randomUUID() }), []);

  function submitBranch(e: FormEvent) {
    e.preventDefault();
    const parsed = slugSchema.safeParse({ slug });
    if (!parsed.success) return setSlugError(vm(fieldErrors(parsed.error)["slug"]));
    void navigate({ to: "/t/$slug", params: { slug: parsed.data.slug } });
  }

  async function submitEmail(e: FormEvent) {
    e.preventDefault();
    setEmailFormError(undefined);
    const parsed = emailSignInSchema.safeParse({ email, password });
    if (!parsed.success) return setEmailErrors(fieldErrors(parsed.error));
    setEmailErrors({});
    setBusy(true);
    try {
      await signInWithEmail(parsed.data.email, parsed.data.password);
      try {
        const access = await qc.fetchQuery({ ...accessQuery, staleTime: 0 });
        rememberSlug(access.tenant.slug);
        await navigate({ to: "/app" });
      } catch (accessErr) {
        if (accessErr instanceof ApiError && accessErr.key === "forbidden") {
          setNeedsStoreName(true);
          return;
        }
        throw accessErr;
      }
    } catch (err) {
      setEmailFormError(errMsg(err));
    } finally {
      setBusy(false);
    }
  }

  async function submitPendingStore(e: FormEvent) {
    e.preventDefault();
    setStoreError(undefined);
    const parsed = storeNameOnlySchema.safeParse({ storeName });
    if (!parsed.success) return setStoreError(vm(fieldErrors(parsed.error)["storeName"]));
    setBusy(true);
    try {
      const locale = i18n.language === "fil" ? "fil" : "en";
      await provisionSoloStore({
        tenantId: ids.tenantId,
        locationId: ids.locationId,
        storeName: parsed.data.storeName,
        locale,
      });
      const access = await qc.fetchQuery({ ...accessQuery, staleTime: 0 });
      rememberSlug(access.tenant.slug);
      await navigate({ to: "/app" });
    } catch (err) {
      if (err instanceof ApiError && err.key === "user_has_tenant") {
        const access = await qc.fetchQuery({ ...accessQuery, staleTime: 0 });
        rememberSlug(access.tenant.slug);
        await navigate({ to: "/app" });
        return;
      }
      setStoreError(errMsg(err));
    } finally {
      setBusy(false);
    }
  }

  if (needsStoreName) {
    return (
      <Shell>
        <form onSubmit={(e) => void submitPendingStore(e)} className="grid gap-4" noValidate>
          <div>
            <h1 className="font-display text-2xl font-extrabold tracking-[-0.02em] text-text-on-light">
              {t("signup.finishTitle")}
            </h1>
            <p className="mt-1 text-sm text-muted-on-light">{t("signup.finishSubtitle")}</p>
          </div>
          <Field label={t("signup.storeName")} error={storeError}>
            <Input
              value={storeName}
              onChange={(e) => setStoreName(e.target.value)}
              placeholder={t("signup.storeNamePlaceholder")}
              autoFocus
            />
          </Field>
          <Button type="submit" disabled={busy}>
            {busy ? t("signup.submitting") : t("signup.finishSubmit")}
          </Button>
        </form>
      </Shell>
    );
  }

  return (
    <Shell>
      <div className="grid gap-5">
        <Tabs
          value={tab}
          onValueChange={(v) => setTab(v as "branch" | "email")}
          label={t("login.title")}
          tabs={[
            { value: "branch", label: t("home.tabBranch"), testId: "auth-tab-branch" },
            { value: "email", label: t("home.tabEmail"), testId: "auth-tab-email" },
          ]}
        >
          <TabPanel value="branch">
            <form onSubmit={submitBranch} className="grid gap-4" noValidate>
              <div>
                <h1 className="font-display text-2xl font-extrabold tracking-[-0.02em] text-text-on-light">
                  {t("home.title")}
                </h1>
              </div>
              <Field label={t("home.slug")} hint={t("home.slugHint")} error={slugError}>
                <Input
                  value={slug}
                  onChange={(e) => setSlug(e.target.value)}
                  autoFocus
                  autoCapitalize="none"
                  data-testid="home-slug-input"
                />
              </Field>
              <Button type="submit" data-testid="home-continue-btn">
                {t("home.continue")}
              </Button>
            </form>
          </TabPanel>

          <TabPanel value="email">
            <form onSubmit={(e) => void submitEmail(e)} className="grid gap-4" noValidate>
              <div>
                <h1 className="font-display text-2xl font-extrabold tracking-[-0.02em] text-text-on-light">
                  {t("home.emailTitle")}
                </h1>
                <p className="mt-1 text-sm text-muted-on-light">{t("home.emailSubtitle")}</p>
              </div>
              {emailFormError ? <Alert>{emailFormError}</Alert> : null}
              <Field label={t("home.email")} error={vm(emailErrors["email"])}>
                <Input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  autoComplete="email"
                  autoCapitalize="none"
                  data-testid="home-email-input"
                />
              </Field>
              <Field label={t("login.password")} error={vm(emailErrors["password"])}>
                <Input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  autoComplete="current-password"
                  data-testid="home-password-input"
                />
              </Field>
              <Button type="submit" disabled={busy} data-testid="home-email-submit">
                {busy ? t("login.signingIn") : t("login.submit")}
              </Button>
              <div className="flex justify-center">
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setForgotOpen(true)}
                  data-testid="home-forgot-btn"
                >
                  {t("login.forgotLink")}
                </Button>
              </div>
            </form>
          </TabPanel>
        </Tabs>

        <ReceiptDash className="my-1" />

        <div className="grid gap-3">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div className="flex items-center gap-2 text-sm text-text-on-light">
              <Warehouse size={16} className="shrink-0 text-muted-on-light" aria-hidden />
              <span>{t("home.warehousePrompt")}</span>
            </div>
            <Link to="/warehouse">
              <Button variant="outline" size="sm" data-testid="go-warehouse-portal">
                {t("home.warehouseCta")}
              </Button>
            </Link>
          </div>
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div className="flex items-center gap-2 text-sm text-text-on-light">
              <Store size={16} className="shrink-0 text-muted-on-light" aria-hidden />
              <span>{t("home.soloPrompt")}</span>
            </div>
            <Link to="/signup">
              <Button variant="outline" size="sm" data-testid="go-solo-signup">
                {t("home.soloCta")}
              </Button>
            </Link>
          </div>
        </div>
      </div>

      <ForgotPasswordDialog open={forgotOpen} onOpenChange={setForgotOpen} initialEmail={email} />
    </Shell>
  );
}

/** "/warehouse" : dedicated Warehouse Staff Portal sign-in. */
export function WarehousePortalLoginPage() {
  const { t } = useTranslation("auth");
  const navigate = useNavigate();
  const qc = useQueryClient();
  const errMsg = useErrorMessage();
  const vm = useValidationMessage();

  const [slug, setSlug] = useState(lastSlug() ?? "");
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string>();
  const [busy, setBusy] = useState(false);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setFormError(undefined);
    const nextErrors: Record<string, string> = {};
    const slugParsed = slugSchema.safeParse({ slug });
    if (!slugParsed.success) {
      Object.assign(nextErrors, fieldErrors(slugParsed.error));
    }
    const loginParsed = loginSchema.safeParse({ identifier, password });
    if (!loginParsed.success) {
      Object.assign(nextErrors, fieldErrors(loginParsed.error));
    }
    if (Object.keys(nextErrors).length > 0) {
      setErrors(nextErrors);
      return;
    }
    setErrors({});
    setBusy(true);
    try {
      const cleanSlug = slugParsed.data!.slug;
      await signIn(cleanSlug, loginParsed.data!.identifier, loginParsed.data!.password);
      const access = await qc.fetchQuery({ ...accessQuery, staleTime: 0 });
      if (access.tenant.slug !== cleanSlug) {
        await signOut();
        qc.clear();
        throw new ApiError("wrong_tenant", "tenant mismatch");
      }
      rememberSlug(cleanSlug);
      saveStoredPortal("warehouse");
      await navigate({ to: "/app/warehouses" });
    } catch (err) {
      setFormError(
        errMsg(err instanceof ApiError && err.key === "forbidden" ? new ApiError("no_account", "") : err),
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <Shell portal="warehouse">
      <form onSubmit={(e) => void submit(e)} className="grid gap-4" noValidate>
        <div className="flex items-start gap-3">
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[12px] bg-sw-pastry text-sw-pastry-fg">
            <Warehouse size={20} aria-hidden />
          </div>
          <div>
            <h1 className="font-display text-2xl font-extrabold tracking-[-0.02em] text-text-on-light">
              {t("warehouse.title")}
            </h1>
            <p className="mt-0.5 text-sm text-muted-on-light">{t("warehouse.subtitle")}</p>
          </div>
        </div>

        {formError ? <Alert>{formError}</Alert> : null}

        <Field label={t("warehouse.slug")} hint={t("warehouse.slugHint")} error={vm(errors["slug"])}>
          <Input
            value={slug}
            onChange={(e) => setSlug(e.target.value)}
            autoCapitalize="none"
            autoFocus={!slug}
            data-testid="wh-login-slug"
          />
        </Field>

        <Field label={t("warehouse.identifier")} error={vm(errors["identifier"])}>
          <Input
            value={identifier}
            onChange={(e) => setIdentifier(e.target.value)}
            autoComplete="username"
            autoCapitalize="none"
            autoFocus={Boolean(slug)}
            data-testid="wh-login-identifier"
          />
        </Field>

        <Field label={t("warehouse.password")} error={vm(errors["password"])}>
          <Input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            data-testid="wh-login-password"
          />
        </Field>

        <Button type="submit" disabled={busy} data-testid="wh-login-submit">
          {busy ? t("login.signingIn") : t("warehouse.submit")}
        </Button>

        <ReceiptDash className="my-1" />

        <div className="text-center">
          <Link to="/login" className="text-sm font-medium text-muted-on-light hover:text-text-on-light">
            {t("warehouse.posLink")}
          </Link>
        </div>
      </form>
    </Shell>
  );
}

/** "/signup" : self-serve Solo store registration (email + password + store name -> provision_solo_store). */
export function SoloSignUpPage() {
  const { t, i18n } = useTranslation("auth");
  const navigate = useNavigate();
  const qc = useQueryClient();
  const vm = useValidationMessage();
  const errMsg = useErrorMessage();

  const [storeName, setStoreName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string>();
  const [checkEmailNotice, setCheckEmailNotice] = useState(false);
  const [busy, setBusy] = useState(false);
  const ids = useMemo(() => ({ tenantId: crypto.randomUUID(), locationId: crypto.randomUUID() }), []);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setFormError(undefined);
    const parsed = soloSignUpSchema.safeParse({ storeName, email, password });
    if (!parsed.success) return setErrors(fieldErrors(parsed.error));
    setErrors({});
    setBusy(true);
    try {
      const { hasSession: signedInNow } = await signUpSolo(parsed.data.email, parsed.data.password);
      if (!signedInNow) {
        setCheckEmailNotice(true);
        return;
      }
      const locale = i18n.language === "fil" ? "fil" : "en";
      await provisionSoloStore({
        tenantId: ids.tenantId,
        locationId: ids.locationId,
        storeName: parsed.data.storeName,
        locale,
      });
      const access = await qc.fetchQuery({ ...accessQuery, staleTime: 0 });
      rememberSlug(access.tenant.slug);
      await navigate({ to: "/app" });
    } catch (err) {
      setFormError(errMsg(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Shell>
      <form onSubmit={(e) => void submit(e)} className="grid gap-4" noValidate>
        <div>
          <h1 className="font-display text-2xl font-extrabold tracking-[-0.02em] text-text-on-light">
            {t("signup.title")}
          </h1>
          <p className="mt-1 text-sm text-muted-on-light">{t("signup.subtitle")}</p>
        </div>
        {formError ? <Alert>{formError}</Alert> : null}
        {checkEmailNotice ? (
          <Alert tone="good">{t("signup.checkEmail")}</Alert>
        ) : (
          <>
            <Field label={t("signup.storeName")} error={vm(errors["storeName"])}>
              <Input
                value={storeName}
                onChange={(e) => setStoreName(e.target.value)}
                placeholder={t("signup.storeNamePlaceholder")}
                autoFocus
                data-testid="signup-store-name"
              />
            </Field>
            <Field label={t("signup.email")} error={vm(errors["email"])}>
              <Input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                autoComplete="email"
                autoCapitalize="none"
                data-testid="signup-email"
              />
            </Field>
            <Field label={t("signup.password")} hint={t("signup.passwordHint")} error={vm(errors["password"])}>
              <Input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="new-password"
                data-testid="signup-password"
              />
            </Field>
            <Button type="submit" disabled={busy} data-testid="signup-submit">
              {busy ? t("signup.submitting") : t("signup.submit")}
            </Button>
          </>
        )}
        <ReceiptDash className="my-1" />
        <div className="text-center">
          <Link to="/login" className="text-sm font-medium text-muted-on-light hover:text-text-on-light">
            {t("signup.haveAccount")}
          </Link>
        </div>
      </form>
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
  const [forgotOpen, setForgotOpen] = useState(false);

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
      <form onSubmit={(e) => void submit(e)} className="grid gap-4" noValidate>
        <div>
          <h1 className="font-display text-2xl font-extrabold tracking-[-0.02em] text-text-on-light">
            {t("login.title")}
          </h1>
          <p className="mt-1 font-mono text-xs font-semibold text-muted-on-light">{t("login.business", { slug })}</p>
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
        <div className="flex flex-wrap items-center justify-between gap-2 pt-1">
          <Button
            variant="ghost"
            size="sm"
            onClick={() => setForgotOpen(true)}
            data-testid="login-forgot-btn"
          >
            {t("login.forgotLink")}
          </Button>
          <Link to="/login" className="text-sm font-medium text-muted-on-light hover:text-text-on-light">
            {t("login.otherBusiness")}
          </Link>
        </div>
      </form>

      <ForgotPasswordDialog
        open={forgotOpen}
        onOpenChange={setForgotOpen}
        initialEmail={identifier.includes("@") ? identifier : ""}
      />
    </Shell>
  );
}

/** "/reset-password" : set a new password after opening a password recovery link. */
export function ResetPasswordPage() {
  const { t } = useTranslation("auth");
  const navigate = useNavigate();
  const qc = useQueryClient();
  const vm = useValidationMessage();
  const errMsg = useErrorMessage();
  const toast = useToast();

  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string>();
  const [busy, setBusy] = useState(false);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setFormError(undefined);
    const parsed = resetPasswordSchema.safeParse({ password, confirmPassword });
    if (!parsed.success) return setErrors(fieldErrors(parsed.error));
    setErrors({});
    setBusy(true);
    try {
      await updatePassword(parsed.data.password);
      toast.good(t("reset.saved"));
      if (await hasSession()) {
        try {
          const access = await qc.fetchQuery({ ...accessQuery, staleTime: 0 });
          rememberSlug(access.tenant.slug);
          await navigate({ to: "/app" });
          return;
        } catch {
          // Signed in without tenant or expired recovery session: fall back to sign-in screen.
        }
      }
      await navigate({ to: "/login" });
    } catch (err) {
      setFormError(errMsg(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Shell>
      <form onSubmit={(e) => void submit(e)} className="grid gap-4" noValidate>
        <div className="flex items-start gap-3">
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[12px] bg-ink text-lime">
            <KeyRound size={20} aria-hidden />
          </div>
          <div>
            <h1 className="font-display text-2xl font-extrabold tracking-[-0.02em] text-text-on-light">
              {t("reset.title")}
            </h1>
            <p className="mt-0.5 text-sm text-muted-on-light">{t("reset.subtitle")}</p>
          </div>
        </div>
        {formError ? <Alert>{formError}</Alert> : null}
        <Field label={t("reset.newPassword")} error={vm(errors["password"])}>
          <Input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="new-password"
            autoFocus
            data-testid="reset-new-password"
          />
        </Field>
        <Field label={t("reset.confirmPassword")} error={vm(errors["confirmPassword"])}>
          <Input
            type="password"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            autoComplete="new-password"
            data-testid="reset-confirm-password"
          />
        </Field>
        <Button type="submit" disabled={busy} data-testid="reset-submit">
          {busy ? t("reset.saving") : t("reset.submit")}
        </Button>
        <ReceiptDash className="my-1" />
        <div className="text-center">
          <Link to="/login" className="text-sm font-medium text-muted-on-light hover:text-text-on-light">
            {t("reset.backToSignIn")}
          </Link>
        </div>
      </form>
    </Shell>
  );
}
