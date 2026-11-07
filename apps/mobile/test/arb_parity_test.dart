import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Set<String> keys(String path) => (jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>)
    .keys
    .where((k) => !k.startsWith('@'))
    .toSet();

void main() {
  test('English and Filipino have the same keys', () {
    final en = keys('lib/l10n/app_en.arb');
    final fil = keys('lib/l10n/app_fil.arb');
    expect(fil.difference(en), isEmpty, reason: 'keys only in fil');
    expect(en.difference(fil), isEmpty, reason: 'keys only in en');
  });
}
