import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { useSession } from "./session.tsx";

export interface ActiveLocation {
  id: string;
  type: "store" | "warehouse";
  code: string;
  name: string;
  address?: string | null;
}

export interface LocationContextValue {
  activeStoreId: string | null;
  activeStore: ActiveLocation | null;
  activeWarehouseId: string | null;
  activeWarehouse: ActiveLocation | null;
  stores: ActiveLocation[];
  warehouses: ActiveLocation[];
  allLocations: ActiveLocation[];
  setActiveStoreId: (id: string) => void;
  setActiveWarehouseId: (id: string) => void;
}

export function resolveActiveStore(savedId: string | null, stores: ActiveLocation[]): ActiveLocation | null {
  if (stores.length === 0) return null;
  if (savedId) {
    const match = stores.find((s) => s.id === savedId);
    if (match) return match;
  }
  return stores[0] ?? null;
}

export function resolveActiveWarehouse(
  savedId: string | null,
  warehouses: ActiveLocation[],
): ActiveLocation | null {
  if (warehouses.length === 0) return null;
  if (savedId) {
    const match = warehouses.find((w) => w.id === savedId);
    if (match) return match;
  }
  return warehouses[0] ?? null;
}

const LocationContext = createContext<LocationContextValue | null>(null);

const STORAGE_KEY = "pos.activeStoreId";
const WAREHOUSE_STORAGE_KEY = "pos.activeWarehouseId";

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

  const [activeWarehouseId, setActiveWarehouseIdState] = useState<string | null>(() => {
    try {
      const saved = localStorage.getItem(WAREHOUSE_STORAGE_KEY);
      return resolveActiveWarehouse(saved, warehouses)?.id ?? null;
    } catch {
      return warehouses[0]?.id ?? null;
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

  useEffect(() => {
    if (activeWarehouseId && !warehouses.some((w) => w.id === activeWarehouseId)) {
      const fallback = resolveActiveWarehouse(null, warehouses)?.id ?? null;
      setActiveWarehouseIdState(fallback);
      if (fallback) {
        try {
          localStorage.setItem(WAREHOUSE_STORAGE_KEY, fallback);
        } catch {
          // ignore
        }
      }
    } else if (!activeWarehouseId && warehouses.length > 0) {
      const first = warehouses[0]!.id;
      setActiveWarehouseIdState(first);
      try {
        localStorage.setItem(WAREHOUSE_STORAGE_KEY, first);
      } catch {
        // ignore
      }
    }
  }, [warehouses, activeWarehouseId]);

  function setActiveStoreId(id: string) {
    if (!stores.some((s) => s.id === id)) return;
    setActiveStoreIdState(id);
    try {
      localStorage.setItem(STORAGE_KEY, id);
    } catch {
      // ignore
    }
  }

  function setActiveWarehouseId(id: string) {
    if (!warehouses.some((w) => w.id === id)) return;
    setActiveWarehouseIdState(id);
    try {
      localStorage.setItem(WAREHOUSE_STORAGE_KEY, id);
    } catch {
      // ignore
    }
  }

  const activeStore = resolveActiveStore(activeStoreId, stores);
  const activeWarehouse = resolveActiveWarehouse(activeWarehouseId, warehouses);

  return (
    <LocationContext.Provider
      value={{
        activeStoreId: activeStore?.id ?? null,
        activeStore,
        activeWarehouseId: activeWarehouse?.id ?? null,
        activeWarehouse,
        stores,
        warehouses,
        allLocations,
        setActiveStoreId,
        setActiveWarehouseId,
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
