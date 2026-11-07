import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:xzactopos_mobile/core/money.dart';

// Same cases as packages/core/src/money.test.ts where they apply to the tindera app.
void main() {
  setUpAll(() => initializeDateFormatting());

  group('format', () {
    for (final c in [
      ['PHP', 123456, 'en', '₱1,234.56'],
      ['PHP', 123456, 'fil', '₱1,234.56'],
      ['USD', 123456, 'en', r'$1,234.56'],
      ['JPY', 123456, 'en', '¥123,456'],
      ['PHP', 5, 'fil', '₱0.05'],
    ]) {
      test('${c[0]} ${c[1]} in ${c[2]}', () {
        expect(Money(c[1] as int, c[0] as String).format(c[2] as String), c[3]);
      });
    }
  });

  group('parse', () {
    test('decimal string to minor units', () {
      expect(Money.parse('12.50', 'PHP').amount, 1250);
      expect(Money.parse('12.5', 'PHP').amount, 1250);
      expect(Money.parse('12', 'PHP').amount, 1200);
      expect(Money.parse(' 1,234.56 ', 'PHP').amount, 123456);
      expect(Money.parse('-0.05', 'PHP').amount, -5);
      expect(Money.parse('500', 'JPY').amount, 500);
      expect(Money.parse('1.234', 'KWD').amount, 1234);
    });
    test('refuses too many decimals and junk', () {
      expect(() => Money.parse('1.234', 'PHP'), throwsRangeError);
      expect(() => Money.parse('1.5', 'JPY'), throwsRangeError);
      expect(() => Money.parse('abc', 'PHP'), throwsFormatException);
      expect(() => Money.parse('1.2.3', 'PHP'), throwsFormatException);
      expect(() => Money.parse('', 'PHP'), throwsFormatException);
    });
    test('round-trips through the input string', () {
      for (final a in [0, 5, 50, 1250, 123456, -5]) {
        expect(Money.parse(Money(a, 'PHP').toDecimalString(), 'PHP').amount, a);
      }
      expect(Money(5, 'PHP').toDecimalString(), '0.05');
      expect(Money(500, 'JPY').toDecimalString(), '500');
    });
  });

  group('arithmetic', () {
    test('add, subtract, negate', () {
      expect(Money(1250, 'PHP') + Money(75, 'PHP'), Money(1325, 'PHP'));
      expect(Money(1250, 'PHP') - Money(1300, 'PHP'), Money(-50, 'PHP'));
      expect(-Money(0, 'PHP'), Money(0, 'PHP'));
      expect(() => Money(1, 'PHP') + Money(1, 'USD'), throwsArgumentError);
    });
    test('multiply rounds half away from zero', () {
      expect(Money(1250, 'PHP').multiply(3), Money(3750, 'PHP'));
      expect(Money(5200, 'PHP').multiply(0.25), Money(1300, 'PHP')); // quarter kilo
      expect(Money(1005, 'PHP').multiply(0.5), Money(503, 'PHP'));
      expect(Money(-1005, 'PHP').multiply(0.5), Money(-503, 'PHP'));
      expect(Money(1000, 'PHP').multiply(0.12), Money(120, 'PHP'));
    });
    test('allocate always sums to the original', () {
      expect(Money(100, 'PHP').allocate(3).map((m) => m.amount), [34, 33, 33]);
      expect(Money(-100, 'PHP').allocate(3).map((m) => m.amount), [-34, -33, -33]);
      final parts = Money(1001, 'PHP').allocate(7);
      expect(parts.fold<int>(0, (s, m) => s + m.amount), 1001);
    });
    test('validates construction', () {
      expect(() => Money(1, 'php'), throwsArgumentError);
      expect(() => Money(1, 'XXX').format('en'), throwsArgumentError);
    });
  });
}
