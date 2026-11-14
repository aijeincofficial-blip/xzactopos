import { supabase } from "./supabase.ts";

export interface TableSizeMetric {
  table_name: string;
  estimated_rows: number;
  total_bytes: number;
  formatted_size: string;
}

export interface TenantRowStats {
  products: number;
  sales: number;
  stock_movements: number;
  customers: number;
  expenses: number;
  processed_ops: number;
  audit_log: number;
}

export interface StorageMetrics {
  ok: boolean;
  scope?: "global" | "tenant";
  total_bytes: number | null;
  limit_bytes: number | null;
  used_mb: number | null;
  limit_mb: number | null;
  percent_used: number | null;
  status: "healthy" | "warning" | "critical";
  tables: TableSizeMetric[];
  tenant_stats: TenantRowStats;
}

export interface ArchiveResult {
  ok: boolean;
  ops_deleted: number;
  approvals_deleted: number;
  days_retained: number;
}

export interface HealthPingResult {
  ok: boolean;
  status: string;
  timestamp: string;
  database?: string;
  version: string;
}

export async function fetchStorageMetrics(): Promise<StorageMetrics> {
  const { data, error } = await supabase.rpc("get_storage_metrics");
  if (error) throw error;
  return data as unknown as StorageMetrics;
}

export async function runArchiveMaintenance(daysToKeep: number = 30): Promise<ArchiveResult> {
  const { data, error } = await supabase.rpc("archive_processed_ops", {
    p_days_to_keep: daysToKeep,
  });
  if (error) throw error;
  return data as unknown as ArchiveResult;
}

export async function checkHealthPing(): Promise<HealthPingResult> {
  const { data, error } = await supabase.rpc("health_ping");
  if (error) throw error;
  return data as unknown as HealthPingResult;
}
