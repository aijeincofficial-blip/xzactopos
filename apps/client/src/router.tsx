import {
  createRootRouteWithContext,
  createRoute,
  createRouter,
  Outlet,
  redirect,
} from "@tanstack/react-router";
import type { QueryClient } from "@tanstack/react-query";
import type { PermissionKey } from "@pos/core";
import { can, contextFromAccess } from "@pos/core";
import { hasSession, loadAccess, SessionProvider } from "./lib/session.tsx";
import { LocationProvider } from "./lib/location-context.tsx";
import { signOut } from "./lib/api.ts";
import { HomePage, LoginPage } from "./routes/public.tsx";
import { AppLayout, DashboardPage, ForbiddenPage } from "./routes/app-layout.tsx";
import { TodayPage } from "./routes/today.tsx";
import { SellPage } from "./routes/sell.tsx";
import { SalesPage } from "./routes/sales.tsx";
import { ProductsPage } from "./routes/products.tsx";
import { UtangPage } from "./routes/utang.tsx";
import { ExpensesPage } from "./routes/expenses.tsx";
import { DayClosePage } from "./routes/day-close.tsx";
import { UpgradePage } from "./routes/upgrade.tsx";
import { SettingsPage } from "./routes/settings.tsx";
import { TransfersPage } from "./routes/transfers.tsx";
import { BinsPage } from "./routes/bins.tsx";
import { ReportsPage } from "./routes/reports.tsx";
import { tenantMode } from "./lib/mode.ts";
import { useSession } from "./lib/session.tsx";
import { SetupPage } from "./routes/setup.tsx";
import { LocationsPage } from "./routes/locations.tsx";
import { UsersPage } from "./routes/users.tsx";
import { ModulesPage } from "./routes/modules.tsx";
import { PlatformPage } from "./routes/platform.tsx";

export interface RouterContext {
  queryClient: QueryClient;
}

const root = createRootRouteWithContext<RouterContext>()({ component: Outlet });

const home = createRoute({
  getParentRoute: () => root,
  path: "/",
  beforeLoad: async ({ context }) => {
    if (await loadAccess(context.queryClient)) throw redirect({ to: "/app" });
  },
  component: HomePage,
});

const login = createRoute({
  getParentRoute: () => root,
  path: "/t/$slug",
  beforeLoad: async ({ context }) => {
    if (await loadAccess(context.queryClient)) throw redirect({ to: "/app" });
  },
  component: LoginPage,
});

/** Everything under /app needs a usable account. The guard also decides setup vs. normal screens. */
const app = createRoute({
  getParentRoute: () => root,
  path: "/app",
  beforeLoad: async ({ context, location }) => {
    const access = await loadAccess(context.queryClient);
    if (!access) {
      // Signed in but no usable account (deactivated, archived): drop the session so login can retry.
      if (await hasSession()) await signOut();
      throw redirect({ to: "/" });
    }
    const onSetup = location.pathname.startsWith("/app/setup");
    if (!access.tenant.setup_completed && access.role === "superadmin" && !onSetup) throw redirect({ to: "/app/setup" });
    if (access.tenant.setup_completed && onSetup) throw redirect({ to: "/app" });
    return { access };
  },
  component: () => (
    <SessionProvider>
      <LocationProvider>
        <AppLayout />
      </LocationProvider>
    </SessionProvider>
  ),
});

/** UI guard only (the RPCs and RLS are the real gate): send users without the permission to the dashboard. */
const requires =
  (perm: PermissionKey) =>
  ({ context }: { context: { access: Parameters<typeof contextFromAccess>[0] } }) => {
    if (!can(contextFromAccess(context.access), perm)) throw redirect({ to: "/app" });
  };

const requiresAny =
  (...perms: PermissionKey[]) =>
  ({ context }: { context: { access: Parameters<typeof contextFromAccess>[0] } }) => {
    const ctx = contextFromAccess(context.access);
    if (!perms.some((p) => can(ctx, p))) throw redirect({ to: "/app" });
  };

/** Home: Solo owners see Today; every Full-mode user sees the dashboard of locations and permissions. */
function HomeRoute() {
  const { access } = useSession();
  return tenantMode(access) === "solo" ? <TodayPage /> : <DashboardPage />;
}

const dashboard = createRoute({ getParentRoute: () => app, path: "/", component: HomeRoute });
const setup = createRoute({ getParentRoute: () => app, path: "/setup", beforeLoad: requires("tenant.settings"), component: SetupPage });
const locations = createRoute({ getParentRoute: () => app, path: "/locations", beforeLoad: requires("locations.manage"), component: LocationsPage });
const users = createRoute({ getParentRoute: () => app, path: "/users", beforeLoad: requires("users.manage"), component: UsersPage });
const modules = createRoute({ getParentRoute: () => app, path: "/modules", beforeLoad: requires("tenant.modules"), component: ModulesPage });
const sell = createRoute({ getParentRoute: () => app, path: "/sell", beforeLoad: requires("sale.create"), component: SellPage });
const sales = createRoute({ getParentRoute: () => app, path: "/sales", beforeLoad: requires("sale.create"), component: SalesPage });
const products = createRoute({ getParentRoute: () => app, path: "/products", beforeLoad: requires("catalog.manage"), component: ProductsPage });
const utang = createRoute({ getParentRoute: () => app, path: "/utang", beforeLoad: requires("sale.create"), component: UtangPage });
const expenses = createRoute({ getParentRoute: () => app, path: "/expenses", beforeLoad: requires("shift.manage"), component: ExpensesPage });
const dayClose = createRoute({ getParentRoute: () => app, path: "/day-close", beforeLoad: requires("shift.manage"), component: DayClosePage });
const upgrade = createRoute({ getParentRoute: () => app, path: "/upgrade", beforeLoad: requires("tenant.modules"), component: UpgradePage });
const settings = createRoute({ getParentRoute: () => app, path: "/settings", beforeLoad: requires("tenant.settings"), component: SettingsPage });
const transfers = createRoute({ getParentRoute: () => app, path: "/transfers", beforeLoad: requiresAny("transfer.manage", "stock.adjust_store"), component: TransfersPage });
const bins = createRoute({ getParentRoute: () => app, path: "/bins", beforeLoad: requiresAny("transfer.manage", "stock.adjust_store", "locations.manage"), component: BinsPage });
const reports = createRoute({ getParentRoute: () => app, path: "/reports", beforeLoad: requiresAny("reports.store", "reports.warehouse"), component: ReportsPage });
const platform = createRoute({
  getParentRoute: () => app,
  path: "/platform",
  beforeLoad: ({ context }) => {
    if (!context.access.is_platform_admin) throw redirect({ to: "/app" });
  },
  component: PlatformPage,
});
const forbidden = createRoute({ getParentRoute: () => app, path: "/forbidden", component: ForbiddenPage });

const routeTree = root.addChildren([
  home,
  login,
  app.addChildren([dashboard, setup, sell, sales, products, utang, expenses, dayClose, upgrade, settings, transfers, bins, reports, locations, users, modules, platform, forbidden]),
]);

export function makeRouter(queryClient: QueryClient) {
  return createRouter({ routeTree, context: { queryClient }, defaultPreload: false });
}

declare module "@tanstack/react-router" {
  interface Register {
    router: ReturnType<typeof makeRouter>;
  }
}
