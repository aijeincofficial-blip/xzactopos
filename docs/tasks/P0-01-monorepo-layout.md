# P0-01 Monorepo layout and tooling
Goal: match plan section 11 layout; shared TS, ESLint, Vitest config.
Do: `apps/client`, `packages/core` (`@pos/core`), `packages/sync` (`@pos/sync`, stub), root tsconfig base, ESLint flat config.
Done when: `pnpm lint`, `pnpm typecheck`, `pnpm test` run real packages and pass.
