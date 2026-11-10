import 'package:intl/intl.dart';

/// Money = integer minor units + ISO currency code. Never doubles in storage.
/// Port of packages/core/src/money.ts; the exponent table mirrors the `currencies` DB table.
const Map<String, int> defaultExponents = {
  'PHP': 2,
  'USD': 2,
  'EUR': 2,
  'GBP': 2,
  'SGD': 2,
  'JPY': 0,
  'KRW': 0,
  'KWD': 3,
  'BHD': 3,
};

int exponentOf(String currency, [Map<String, int> table = defaultExponents]) {
  final e = table[currency];
  if (e == null) throw ArgumentError('Unknown currency: $currency');
  return e;
}

/// JS-safe integer range, so values stay identical to the TypeScript client and Postgres bigint usage.
const int _maxSafe = 9007199254740991;

class Money {
  Money(this.amount, this.currency) {
    if (amount.abs() > _maxSafe) {
      throw RangeError('Money amount must be a safe integer of minor units, got $amount');
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      throw ArgumentError('Invalid currency code: $currency');
    }
  }

  /// Integer minor units (centavos for PHP).
  final int amount;
  final String currency;

  /// Parses "12.50" into 1250 without touching doubles. Accepts an optional leading minus and thousands commas.
  factory Money.parse(String value, String currency, [Map<String, int> table = defaultExponents]) {
    final exp = exponentOf(currency, table);
    final m = RegExp(r'^(-)?(\d+)(?:\.(\d+))?$').firstMatch(value.trim().replaceAll(',', ''));
    if (m == null) throw FormatException('Invalid decimal amount: $value');
    final whole = m.group(2)!;
    final frac = m.group(3) ?? '';
    if (frac.length > exp) {
      throw RangeError('$currency allows at most $exp decimal places, got "$value"');
    }
    final minor = int.parse(whole + frac.padRight(exp, '0'));
    return Money(m.group(1) != null ? -minor : minor, currency);
  }

  Money operator +(Money other) {
    _same(other);
    return Money(amount + other.amount, currency);
  }

  Money operator -(Money other) {
    _same(other);
    return Money(amount - other.amount, currency);
  }

  Money operator -() => Money(amount == 0 ? 0 : -amount, currency);

  /// Multiplies by a quantity or rate (3, 0.25 kg, 0.12 tax) and rounds half away from zero.
  Money multiply(num factor) {
    if (!factor.isFinite) throw ArgumentError('Factor must be finite');
    return Money(roundHalfUp(amount * factor), currency);
  }

  /// Splits into near-equal parts that always sum to the original; the remainder goes to the first parts.
  List<Money> allocate(int parts) {
    if (parts < 1) throw ArgumentError('parts must be a positive integer');
    final base = amount ~/ parts;
    var rem = amount - base * parts;
    final step = rem < 0 ? -1 : 1;
    return List.generate(parts, (_) {
      final extra = rem != 0 ? step : 0;
      rem -= extra;
      return Money(base + extra, currency);
    });
  }

  /// Display only, e.g. ₱1,234.56. Do not parse or store the result.
  String format(String locale, [Map<String, int> table = defaultExponents]) {
    final exp = exponentOf(currency, table);
    final f = NumberFormat.simpleCurrency(locale: locale, name: currency, decimalDigits: exp);
    return f.format(amount / _pow10(exp));
  }

  /// Plain decimal string for input fields: 1250 -> "12.50".
  String toDecimalString([Map<String, int> table = defaultExponents]) {
    final exp = exponentOf(currency, table);
    final neg = amount < 0;
    final digits = amount.abs().toString().padLeft(exp + 1, '0');
    final whole = digits.substring(0, digits.length - exp);
    final frac = digits.substring(digits.length - exp);
    return '${neg ? '-' : ''}$whole${exp > 0 ? '.$frac' : ''}';
  }

  /// Currency symbol according to locale or currency name, e.g. ₱, $, €.
  String get currencySymbol => NumberFormat.simpleCurrency(name: currency).currencySymbol;

  void _same(Money other) {
    if (other.currency != currency) {
      throw ArgumentError('Currency mismatch: $currency vs ${other.currency}');
    }
  }

  @override
  bool operator ==(Object other) => other is Money && other.amount == amount && other.currency == currency;

  @override
  int get hashCode => Object.hash(amount, currency);

  @override
  String toString() => 'Money($amount $currency)';
}

int _pow10(int e) {
  var r = 1;
  for (var i = 0; i < e; i++) {
    r *= 10;
  }
  return r;
}

/// Half away from zero, tolerant of double noise around .5 (same rule as the TS roundToInt).
int roundHalfUp(num x) {
  const eps = 1e-9;
  final sign = x < 0 ? -1 : 1;
  final abs = x.abs();
  final floor = abs.floor();
  final r = (abs - floor) >= 0.5 - eps ? floor + 1 : floor;
  return sign * r == 0 ? 0 : sign * r;
}
