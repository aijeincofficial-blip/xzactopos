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
import { signOut } from "./lib/api.ts";
import { HomePage, LoginPage } from "./routes/public.tsx";
import { AppLayout, DashboardPage, ForbiddenPage } from "./routes/app-layout.tsx";
import { SetupPage } from "./routes/setup.tsx";
import { LocationsPage } from "./routes/locations.tsx";
import { UsersPage } from "./routes/users.tsx";
import { ModulesPage } from "./routes/modules.tsx";

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
      <AppLayout />
    </SessionProvider>
  ),
});

/** UI guard only (the RPCs and RLS are the real gate): send users without the permission to the dashboard. */
const requires =
  (perm: PermissionKey) =>
  ({ context }: { context: { access: Parameters<typeof contextFromAccess>[0] } }) => {
    if (!can(contextFromAccess(context.access), perm)) throw redirect({ to: "/app" });
  };

const dashboard = createRoute({ getParentRoute: () => app, path: "/", component: DashboardPage });
const setup = createRoute({ getParentRoute: () => app, path: "/setup", beforeLoad: requires("tenant.settings"), component: SetupPage });
const locations = createRoute({ getParentRoute: () => app, path: "/locations", beforeLoad: requires("locations.manage"), component: LocationsPage });
const users = createRoute({ getParentRoute: () => app, path: "/users", beforeLoad: requires("users.manage"), component: UsersPage });
const modules = createRoute({ getParentRoute: () => app, path: "/modules", beforeLoad: requires("tenant.modules"), component: ModulesPage });
const forbidden = createRoute({ getParentRoute: () => app, path: "/forbidden", component: ForbiddenPage });

const routeTree = root.addChildren([
  home,
  login,
  app.addChildren([dashboard, setup, locations, users, modules, forbidden]),
]);

export function makeRouter(queryClient: QueryClient) {
  return createRouter({ routeTree, context: { queryClient }, defaultPreload: false });
}

declare module "@tanstack/react-router" {
  interface Register {
    router: ReturnType<typeof makeRouter>;
  }
}
