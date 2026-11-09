import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/core/theme.dart';

double _ratio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final palette in AppPalette.values) {
    for (final b in Brightness.values) {
      test('${palette.name} ${b.name}: text pairs are readable (4.5:1 or better)', () {
        final s = buildTheme(palette, b).colorScheme;
        expect(s.brightness, b);
        final pairs = {
          'onSurface/surface': [s.onSurface, s.surface],
          'onPrimary/primary': [s.onPrimary, s.primary],
          'onSecondary/secondary': [s.onSecondary, s.secondary],
          'onPrimaryContainer/primaryContainer': [s.onPrimaryContainer, s.primaryContainer],
          'onSecondaryContainer/secondaryContainer': [s.onSecondaryContainer, s.secondaryContainer],
          'onTertiary/tertiary': [s.onTertiary, s.tertiary],
          'onError/error': [s.onError, s.error],
        };
        pairs.forEach((name, c) {
          expect(_ratio(c[0], c[1]), greaterThanOrEqualTo(4.5), reason: name);
        });
      });
    }
  }
}
