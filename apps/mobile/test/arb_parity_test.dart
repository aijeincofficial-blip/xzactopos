import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/l10n/app_localizations.dart';

Set<String> keys(String path) => (jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>)
    .keys
    .where((k) => !k.startsWith('@'))
    .toSet();

void main() {
  test('Filipino plurals print the real count (fil "one" covers 1, 2, 3, 5, ...)', () {
    final fil = lookupAppLocalizations(const Locale('fil'));
    expect(fil.productsOnDevice(3), '3 produkto sa phone na ito');
    expect(fil.productsOnDevice(1), '1 produkto sa phone na ito');
    expect(fil.productsOnDevice(0), 'Wala pang produkto sa phone na ito');
    expect(fil.syncPending(2), '2 naghihintay ipadala');
    expect(fil.syncNeedsAttention(5), '5 kailangang ayusin');
    expect(fil.syncOfflinePending(3), 'Walang signal, 3 naka-save sa phone');
  });

  test('every plural message uses {count}, never a literal number', () {
    for (final f in ['lib/l10n/app_en.arb', 'lib/l10n/app_fil.arb']) {
      // an "=1{...}" branch with the digit 1 typed in it (fil uses this branch for 2, 3, 5, ... too)
      expect(RegExp(r'=1\{[^{}]*\b1\b').hasMatch(File(f).readAsStringSync()), isFalse, reason: f);
    }
  });

  test('English and Filipino have the same keys', () {
    final en = keys('lib/l10n/app_en.arb');
    final fil = keys('lib/l10n/app_fil.arb');
    expect(fil.difference(en), isEmpty, reason: 'keys only in fil');
    expect(en.difference(fil), isEmpty, reason: 'keys only in en');
  });
}
