import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { useSession } from "./session.tsx";

export interface ActiveLocation {
  id: string;
  type: "store" | "warehouse";
  code: string;
  name: string;
}

export interface LocationContextValue {
  activeStoreId: string | null;
  activeStore: ActiveLocation | null;
  stores: ActiveLocation[];
  warehouses: ActiveLocation[];
  allLocations: ActiveLocation[];
  setActiveStoreId: (id: string) => void;
}

export function resolveActiveStore(savedId: string | null, stores: ActiveLocation[]): ActiveLocation | null {
  if (stores.length === 0) return null;
  if (savedId) {
    const match = stores.find((s) => s.id === savedId);
    if (match) return match;
  }
  return stores[0] ?? null;
}

const LocationContext = createContext<LocationContextValue | null>(null);

const STORAGE_KEY = "pos.activeStoreId";

export function LocationProvider({ children }: { children: ReactNode }) {
  const { access } = useSession();

  const stores = access.locations.filter((l) => l.type === "store");
  const warehouses = access.locations.filter((l) => l.type === "warehouse");
  const allLocations = access.locations;

  const [activeStoreId, setActiveStoreIdState] = useState<string | null>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      return resolveActiveStore(saved, stores)?.id ?? null;
    } catch {
      return stores[0]?.id ?? null;
    }
  });

  useEffect(() => {
    if (activeStoreId && !stores.some((s) => s.id === activeStoreId)) {
      const fallback = resolveActiveStore(null, stores)?.id ?? null;
      setActiveStoreIdState(fallback);
      if (fallback) {
        try {
          localStorage.setItem(STORAGE_KEY, fallback);
        } catch {
          // ignore
        }
      }
    } else if (!activeStoreId && stores.length > 0) {
      const first = stores[0]!.id;
      setActiveStoreIdState(first);
      try {
        localStorage.setItem(STORAGE_KEY, first);
      } catch {
        // ignore
      }
    }
  }, [stores, activeStoreId]);

  function setActiveStoreId(id: string) {
    if (!stores.some((s) => s.id === id)) return;
    setActiveStoreIdState(id);
    try {
      localStorage.setItem(STORAGE_KEY, id);
    } catch {
      // ignore
    }
  }

  const activeStore = resolveActiveStore(activeStoreId, stores);

  return (
    <LocationContext.Provider
      value={{
        activeStoreId: activeStore?.id ?? null,
        activeStore,
        stores,
        warehouses,
        allLocations,
        setActiveStoreId,
      }}
    >
      {children}
    </LocationContext.Provider>
  );
}

export function useActiveLocation(): LocationContextValue {
  const ctx = useContext(LocationContext);
  if (!ctx) throw new Error("useActiveLocation must be used within LocationProvider");
  return ctx;
}
