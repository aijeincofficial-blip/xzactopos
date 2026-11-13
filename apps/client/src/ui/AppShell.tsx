import type { ReactNode } from "react";
import type { LucideIcon } from "lucide-react";
import { cn } from "../lib/utils.ts";
import { SyncChip, type SyncChipState } from "./SyncChip.tsx";

export interface AppShellNavItem {
  id: string;
  label: string;
  icon: LucideIcon;
  /** Visible only when role & enabled module allow it (design.md §10: hide, never disable). */
  visible?: boolean;
  onSelect: () => void;
}

/**
 * Shared night-market AppShell (design.md §7 + §12):
 * - ≥ 1024px: 88px --ink icon rail + --sand main area + top bar
 * - < 1024px: bottom --ink tab bar (up to 5 items) + top bar
 */
export function AppShell({
  title,
  eyebrow,
  storeName,
  navItems,
  activeNavId,
  syncState = "synced",
  syncQueuedCount = 0,
  onSyncClick,
  topRight,
  footerSlot,
  contained = false,
  children,
}: {
  title: string;
  eyebrow?: string;
  storeName?: string;
  navItems: ReadonlyArray<AppShellNavItem>;
  activeNavId: string;
  syncState?: SyncChipState;
  syncQueuedCount?: number;
  onSyncClick?: () => void;
  topRight?: ReactNode;
  footerSlot?: ReactNode;
  /** When true (e.g. /dev/ui preview), scopes layout inside its parent container instead of 100vh viewport. */
  contained?: boolean;
  children: ReactNode;
}) {
  const visibleItems = navItems.filter((item) => item.visible !== false);

  return (
    <div
      className={cn(
        "flex flex-col bg-sand text-text-on-light lg:flex-row",
        contained ? "min-h-[420px] overflow-hidden rounded-[24px] border-[1.5px] border-sand-line" : "min-h-screen",
      )}
    >
      {/* Desktop Left Icon Rail (88px) */}
      <aside className="hidden w-[88px] shrink-0 flex-col items-center justify-between bg-ink py-5 lg:flex">
        <div className="flex flex-col items-center gap-4">
          <img
            src="/brand/xzacto-mark.svg"
            alt="xzacto"
            width={40}
            height={40}
            className="h-10 w-10"
          />
          <nav className="mt-2 flex flex-col items-center gap-2.5">
            {visibleItems.map((item) => {
              const Icon = item.icon;
              const active = item.id === activeNavId;
              return (
                <button
                  key={item.id}
                  type="button"
                  aria-label={item.label}
                  title={item.label}
                  onClick={item.onSelect}
                  className={cn(
                    "flex h-[52px] w-[52px] cursor-pointer items-center justify-center rounded-2xl transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-lime",
                    active
                      ? "bg-lime text-ink"
                      : "text-muted-on-dark hover:bg-ink-2 hover:text-text-on-dark",
                  )}
                >
                  <Icon size={22} strokeWidth={2} aria-hidden />
                </button>
              );
            })}
          </nav>
        </div>
        {footerSlot ? <div className="px-2">{footerSlot}</div> : null}
      </aside>

      {/* Main Column */}
      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex flex-wrap items-center justify-between gap-3 border-b-[1.5px] border-sand-line bg-paper px-5 py-4 sm:px-7">
          <div className="min-w-0">
            {eyebrow || storeName ? (
              <div className="font-mono text-xs tracking-[0.08em] text-muted-on-light uppercase">
                {[storeName, eyebrow].filter(Boolean).join(" · ")}
              </div>
            ) : null}
            <h1 className="font-display text-[26px] font-extrabold leading-tight tracking-[-0.02em] text-text-on-light sm:text-[30px]">
              {title}
            </h1>
          </div>
          <div className="flex flex-wrap items-center gap-2.5">
            {topRight}
            <SyncChip state={syncState} queuedCount={syncQueuedCount} onClick={onSyncClick} />
          </div>
        </header>

        <div className={cn("flex-1 p-5 sm:p-7", contained ? "" : "pb-24 lg:pb-7")}>{children}</div>
      </div>

      {/* Tablet / Phone Bottom Tab Bar (< 1024px) */}
      <nav
        className={cn(
          "flex items-center justify-around gap-1 border-t-[1.5px] border-ink-line bg-ink px-2 py-2 lg:hidden",
          contained ? "" : "sticky bottom-0 z-30",
        )}
      >
        {visibleItems.slice(0, 5).map((item) => {
          const Icon = item.icon;
          const active = item.id === activeNavId;
          return (
            <button
              key={item.id}
              type="button"
              onClick={item.onSelect}
              className="flex min-h-[44px] min-w-0 flex-1 cursor-pointer flex-col items-center justify-center gap-1 rounded-xl px-1 py-1 text-center focus-visible:outline-2 focus-visible:outline-lime"
            >
              <span
                className={cn(
                  "flex h-7 w-11 items-center justify-center rounded-full transition-colors",
                  active ? "bg-lime text-ink" : "text-muted-on-dark",
                )}
              >
                <Icon size={18} strokeWidth={2} aria-hidden />
              </span>
              <span
                className={cn(
                  "max-w-full truncate text-[11px] font-semibold leading-tight",
                  active ? "text-text-on-dark" : "text-muted-on-dark",
                )}
              >
                {item.label}
              </span>
            </button>
          );
        })}
      </nav>
    </div>
  );
}
