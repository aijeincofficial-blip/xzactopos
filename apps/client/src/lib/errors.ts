import { isOnline } from "./network.ts";

export const ACCESS_CACHE_PREFIX = "pos.access.v1:";

/** Error with a stable key the UI maps to an i18n message (`errors:<key>`). */
export class ApiError extends Error {
  constructor(
    readonly key: string,
    message: string,
    readonly field?: string,
  ) {
    super(message);
  }
}

export function isNetworkFailure(err: unknown): boolean {
  if (!isOnline()) return true;
  if (err instanceof TypeError) return true;
  if (err instanceof ApiError) {
    if (err.key === "temporary") return true;
    if (
      err.key === "unknown" &&
      /failed to fetch|network|offline|load failed|timeout|connection|econnrefused|502|503|504/i.test(err.message)
    ) {
      return true;
    }
    return false;
  }
  if (err instanceof Error) {
    return /failed to fetch|network|offline|load failed|timeout|connection/i.test(err.message);
  }
  return false;
}
