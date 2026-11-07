/**
 * Money = integer minor units + ISO currency code. Never floats in storage.
 * The exponent table mirrors the `currencies` DB table (JPY 0, USD 2, KWD 3).
 */

export interface Money {
  readonly amount: number; // integer minor units (e.g. cents)
  readonly currency: string; // ISO 4217 code, upper case
}

export type ExponentTable = Readonly<Record<string, number>>;

export const DEFAULT_EXPONENTS: ExponentTable = {
  PHP: 2,
  USD: 2,
  EUR: 2,
  GBP: 2,
  SGD: 2,
  JPY: 0,
  KRW: 0,
  KWD: 3,
  BHD: 3,
};

export type RoundingMode = "half-up" | "half-even" | "floor" | "ceil";

export function exponentOf(currency: string, table: ExponentTable = DEFAULT_EXPONENTS): number {
  const e = table[currency];
  if (e === undefined) throw new RangeError(`Unknown currency: ${currency}`);
  return e;
}

export function money(amount: number, currency: string): Money {
  if (!Number.isSafeInteger(amount)) {
    throw new RangeError(`Money amount must be a safe integer of minor units, got ${amount}`);
  }
  if (!/^[A-Z]{3}$/.test(currency)) throw new RangeError(`Invalid currency code: ${currency}`);
  return { amount, currency };
}

/** Parse a decimal string like "12.34" into minor units without touching floats. */
export function fromMajor(
  value: string,
  currency: string,
  table: ExponentTable = DEFAULT_EXPONENTS,
): Money {
  const exp = exponentOf(currency, table);
  const m = /^(-)?(\d+)(?:\.(\d+))?$/.exec(value.trim());
  if (!m) throw new SyntaxError(`Invalid decimal amount: ${value}`);
  const [, sign, whole = "0", frac = ""] = m;
  if (frac.length > exp) {
    throw new RangeError(`${currency} allows at most ${exp} decimal places, got "${value}"`);
  }
  const minor = Number(whole + frac.padEnd(exp, "0"));
  return money(sign ? -minor : minor, currency);
}

/** Display-only conversion. Do not store the result. */
export function toMajorNumber(m: Money, table: ExponentTable = DEFAULT_EXPONENTS): number {
  return m.amount / 10 ** exponentOf(m.currency, table);
}

function sameCurrency(a: Money, b: Money): void {
  if (a.currency !== b.currency) {
    throw new TypeError(`Currency mismatch: ${a.currency} vs ${b.currency}`);
  }
}

export function add(a: Money, b: Money): Money {
  sameCurrency(a, b);
  return money(a.amount + b.amount, a.currency);
}

export function sub(a: Money, b: Money): Money {
  sameCurrency(a, b);
  return money(a.amount - b.amount, a.currency);
}

export function negate(a: Money): Money {
  return money(a.amount === 0 ? 0 : -a.amount, a.currency);
}

export function roundToInt(x: number, mode: RoundingMode = "half-up"): number {
  const sign = x < 0 ? -1 : 1;
  const abs = Math.abs(x);
  const floor = Math.floor(abs);
  const diff = abs - floor;
  // tolerate float noise around .5
  const EPS = 1e-9;
  let r: number;
  switch (mode) {
    case "floor":
      return Math.floor(x);
    case "ceil":
      return Math.ceil(x);
    case "half-even":
      if (Math.abs(diff - 0.5) < EPS) r = floor % 2 === 0 ? floor : floor + 1;
      else r = Math.round(abs);
      break;
    default: // half-up: halves go away from zero
      r = diff >= 0.5 - EPS ? floor + 1 : floor;
  }
  const out = sign * r;
  return out === 0 ? 0 : out;
}

/** Multiply by a quantity or percentage factor (e.g. 3, or 0.12 for tax) and round to minor units. */
export function multiply(a: Money, factor: number, mode: RoundingMode = "half-up"): Money {
  if (!Number.isFinite(factor)) throw new RangeError("Factor must be finite");
  return money(roundToInt(a.amount * factor, mode), a.currency);
}

/**
 * Convert to another currency using a major-unit rate (1 unit of `a.currency` = `rate` units of `to`).
 * The sale must snapshot `rate` as `fx_rate`; never reuse today's rate on past transactions.
 */
export function convert(
  a: Money,
  to: string,
  rate: number,
  mode: RoundingMode = "half-up",
  table: ExponentTable = DEFAULT_EXPONENTS,
): Money {
  if (!(rate > 0) || !Number.isFinite(rate)) throw new RangeError("Rate must be a positive number");
  const from = exponentOf(a.currency, table);
  const target = exponentOf(to, table);
  return money(roundToInt((a.amount * rate * 10 ** target) / 10 ** from, mode), to);
}

/** Split into `parts` near-equal shares that always sum to the original (remainder goes to first shares). */
export function allocate(a: Money, parts: number): Money[] {
  if (!Number.isInteger(parts) || parts < 1) throw new RangeError("parts must be a positive integer");
  const base = Math.trunc(a.amount / parts);
  let rem = a.amount - base * parts;
  const step = rem < 0 ? -1 : 1;
  return Array.from({ length: parts }, () => {
    const extra = rem !== 0 ? step : 0;
    rem -= extra;
    return money(base + extra, a.currency);
  });
}

export function formatMoney(
  m: Money,
  locale: string,
  table: ExponentTable = DEFAULT_EXPONENTS,
): string {
  const exp = exponentOf(m.currency, table);
  return new Intl.NumberFormat(locale, {
    style: "currency",
    currency: m.currency,
    minimumFractionDigits: exp,
    maximumFractionDigits: exp,
  }).format(m.amount / 10 ** exp);
}
