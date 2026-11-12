import {
  createRootRouteWithContext,
  createRoute,
  createRouter,
  lazyRouteComponent,
  Outlet,
  redirect,
} from "@tanstack/react-router";
import type { QueryClient } from "@tanstack/react-query";
import type { PermissionKey } from "@pos/core";
import { can, contextFromAccess } from "@pos/core";
import { hasSession, loadAccess, SessionProvider, useSession } from "./lib/session.tsx";
import { LocationProvider } from "./lib/location-context.tsx";
import { signOut } from "./lib/api.ts";
import { tenantMode } from "./lib/mode.ts";
import { readStoredPortal, resolveRoleLandingPath } from "./lib/portal.ts";

const HomePage = lazyRouteComponent(() => import("./routes/public.tsx"), "HomePage");
const LoginPage = lazyRouteComponent(() => import("./routes/public.tsx"), "LoginPage");
const ResetPasswordPage = lazyRouteComponent(() => import("./routes/public.tsx"), "ResetPasswordPage");
const SoloSignUpPage = lazyRouteComponent(() => import("./routes/public.tsx"), "SoloSignUpPage");
const WarehousePortalLoginPage = lazyRouteComponent(() => import("./routes/public.tsx"), "WarehousePortalLoginPage");
const AppLayout = lazyRouteComponent(() => import("./routes/app-layout.tsx"), "AppLayout");
const DashboardPage = lazyRouteComponent(() => import("./routes/app-layout.tsx"), "DashboardPage");
const ForbiddenPage = lazyRouteComponent(() => import("./routes/app-layout.tsx"), "ForbiddenPage");
const TodayPage = lazyRouteComponent(() => import("./routes/today.tsx"), "TodayPage");
const SellPage = lazyRouteComponent(() => import("./routes/sell.tsx"), "SellPage");
const ReceiveStockPage = lazyRouteComponent(() => import("./routes/receive-stock.tsx"), "ReceiveStockPage");
const SalesPage = lazyRouteComponent(() => import("./routes/sales.tsx"), "SalesPage");
const InventoryPage = lazyRouteComponent(() => import("./routes/inventory.tsx"), "InventoryPage");
const ProductsPage = lazyRouteComponent(() => import("./routes/products.tsx"), "ProductsPage");
const UtangPage = lazyRouteComponent(() => import("./routes/utang.tsx"), "UtangPage");
const ServicesPage = lazyRouteComponent(() => import("./routes/services.tsx"), "ServicesPage");
const ExpensesPage = lazyRouteComponent(() => import("./routes/expenses.tsx"), "ExpensesPage");
const DayClosePage = lazyRouteComponent(() => import("./routes/day-close.tsx"), "DayClosePage");
const UpgradePage = lazyRouteComponent(() => import("./routes/upgrade.tsx"), "UpgradePage");
const SettingsPage = lazyRouteComponent(() => import("./routes/settings.tsx"), "SettingsPage");
const TransfersPage = lazyRouteComponent(() => import("./routes/transfers.tsx"), "TransfersPage");
const BinsPage = lazyRouteComponent(() => import("./routes/bins.tsx"), "BinsPage");
const PurchasingPage = lazyRouteComponent(() => import("./routes/purchasing.tsx"), "PurchasingPage");
const CountsPage = lazyRouteComponent(() => import("./routes/counts.tsx"), "CountsPage");
const OverviewPage = lazyRouteComponent(() => import("./routes/overview.tsx"), "OverviewPage");
const ReportsPage = lazyRouteComponent(() => import("./routes/reports.tsx"), "ReportsPage");
const SetupPage = lazyRouteComponent(() => import("./routes/setup.tsx"), "SetupPage");
const LocationsPage = lazyRouteComponent(() => import("./routes/locations.tsx"), "LocationsPage");
const UsersPage = lazyRouteComponent(() => import("./routes/users.tsx"), "UsersPage");
const ModulesPage = lazyRouteComponent(() => import("./routes/modules.tsx"), "ModulesPage");
const PlatformPage = lazyRouteComponent(() => import("./routes/platform.tsx"), "PlatformPage");

export interface RouterContext {
  queryClient: QueryClient;
}

const root = createRootRouteWithContext<RouterContext>()({ component: Outlet });

const home = createRoute({
  getParentRoute: () => root,
  path: "/",
  beforeLoad: async ({ context }) => {
    if (typeof window !== "undefined" && window.location.hash.includes("type=recovery")) {
      throw redirect({ to: "/reset-password" });
    }
    if (await loadAccess(context.queryClient)) throw redirect({ to: "/app" });
  },
  component: HomePage,
});

const signup = createRoute({
  getParentRoute: () => root,
  path: "/signup",
  beforeLoad: async ({ context }) => {
    if (await loadAccess(context.queryClient)) throw redirect({ to: "/app" });
  },
  component: SoloSignUpPage,
});

const resetPassword = createRoute({
  getParentRoute: () => root,
  path: "/reset-password",
  component: ResetPasswordPage,
});

const warehouseLogin = createRoute({
  getParentRoute: () => root,
  path: "/warehouse",
  beforeLoad: async ({ context }) => {
    const access = await loadAccess(context.queryClient);
    if (access) {
      const target = resolveRoleLandingPath(access, tenantMode(access), "warehouse");
      throw redirect({ to: target });
    }
  },
  component: WarehousePortalLoginPage,
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

const dashboard = createRoute({
  getParentRoute: () => app,
  path: "/",
  beforeLoad: ({ context }) => {
    const mode = tenantMode(context.access);
    const target = resolveRoleLandingPath(context.access, mode, readStoredPortal());
    if (target !== "/app") throw redirect({ to: target });
  },
  component: HomeRoute,
});
const setup = createRoute({ getParentRoute: () => app, path: "/setup", beforeLoad: requires("tenant.settings"), component: SetupPage });
const locations = createRoute({ getParentRoute: () => app, path: "/locations", beforeLoad: requires("locations.manage"), component: LocationsPage });
const users = createRoute({ getParentRoute: () => app, path: "/users", beforeLoad: requires("users.manage"), component: UsersPage });
const modules = createRoute({ getParentRoute: () => app, path: "/modules", beforeLoad: requires("tenant.modules"), component: ModulesPage });
const sell = createRoute({ getParentRoute: () => app, path: "/sell", beforeLoad: requires("sale.create"), component: SellPage });
const receiveStock = createRoute({ getParentRoute: () => app, path: "/receive-stock", beforeLoad: requires("sale.create"), component: ReceiveStockPage });
const sales = createRoute({ getParentRoute: () => app, path: "/sales", beforeLoad: requires("sale.create"), component: SalesPage });
const inventory = createRoute({
  getParentRoute: () => app,
  path: "/inventory",
  beforeLoad: requiresAny(
    "sale.create",
    "catalog.manage",
    "stock.adjust_store",
    "stock.adjust_warehouse",
    "reports.warehouse",
    "transfer.manage",
  ),
  component: InventoryPage,
});
const products = createRoute({ getParentRoute: () => app, path: "/products", beforeLoad: requires("catalog.manage"), component: ProductsPage });
const utang = createRoute({ getParentRoute: () => app, path: "/utang", beforeLoad: requires("sale.create"), component: UtangPage });
const services = createRoute({ getParentRoute: () => app, path: "/services", beforeLoad: requires("sale.create"), component: ServicesPage });
const expenses = createRoute({ getParentRoute: () => app, path: "/expenses", beforeLoad: requires("shift.manage"), component: ExpensesPage });
const dayClose = createRoute({ getParentRoute: () => app, path: "/day-close", beforeLoad: requires("shift.manage"), component: DayClosePage });
const upgrade = createRoute({ getParentRoute: () => app, path: "/upgrade", beforeLoad: requires("tenant.modules"), component: UpgradePage });
const settings = createRoute({ getParentRoute: () => app, path: "/settings", beforeLoad: requires("tenant.settings"), component: SettingsPage });
const transfers = createRoute({ getParentRoute: () => app, path: "/transfers", beforeLoad: requiresAny("transfer.manage", "stock.adjust_store"), component: TransfersPage });
const bins = createRoute({ getParentRoute: () => app, path: "/bins", beforeLoad: requiresAny("transfer.manage", "stock.adjust_store", "locations.manage"), component: BinsPage });
const purchasing = createRoute({ getParentRoute: () => app, path: "/purchasing", beforeLoad: requires("purchasing.manage"), component: PurchasingPage });
const counts = createRoute({ getParentRoute: () => app, path: "/counts", beforeLoad: requires("stock.adjust_warehouse"), component: CountsPage });
const overview = createRoute({ getParentRoute: () => app, path: "/warehouses", beforeLoad: requires("reports.warehouse"), component: OverviewPage });
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
  signup,
  resetPassword,
  warehouseLogin,
  login,
  app.addChildren([dashboard, setup, sell, receiveStock, sales, inventory, products, utang, services, expenses, dayClose, upgrade, settings, transfers, bins, purchasing, counts, overview, reports, locations, users, modules, platform, forbidden]),
]);

export function makeRouter(queryClient: QueryClient) {
  return createRouter({ routeTree, context: { queryClient }, defaultPreload: false });
}

declare module "@tanstack/react-router" {
  interface Register {
    router: ReturnType<typeof makeRouter>;
  }
}
