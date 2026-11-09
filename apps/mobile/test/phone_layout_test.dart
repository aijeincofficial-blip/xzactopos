import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/app.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/local_store.dart';

import 'products_test.dart' show leave;
import 'widget_test.dart' show FakeBackend;

/// No signal: every server call fails.
class OfflineBackend extends FakeBackend {
  OfflineBackend() : super(signedInAtStart: true);
  @override
  Future<Map<String, dynamic>> pullCatalog(Map<String, dynamic> cursors, {int limit = 500}) =>
      Future.error(Exception('no signal'));
  @override
  Future<void> upsertProduct(String opId, Map<String, dynamic> payload) => Future.error(Exception('no signal'));
}

/// A Pixel 4 is 1080 x 2280 px at 2.625x, about 411 logical px wide; small Android phones are 360.
/// The worst case seen on the emulator: Filipino, offline, changes waiting -> the longest badge sentence.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  for (final width in [360.0, 411.0]) {
    testWidgets('Home and Products fit a $width px phone, Filipino, offline with changes waiting', (tester) async {
      tester.view.physicalSize = Size(width * 3, 869 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final store = DriftStore(AppDatabase(NativeDatabase.memory()));
      final backend = OfflineBackend()
        ..access = {
          'tenant': {'id': 't1', 'name': 'Sari-Sari ni Aling Rosa', 'base_currency': 'PHP'},
        };
      await tester.pumpWidget(App(backend: backend, openStore: ({bool safeMode = false}) => store, initialLocale: 'fil'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await store.saveProduct(
            ProductDraft(id: '0190a000-0000-7000-8000-00000000000$i', variantId: '0190a000-0000-7000-9000-00000000000$i',
                name: 'P$i', price: 100),
            opId: 'op$i');
      }
      await tester.pump(const Duration(seconds: 20)); // sync fails -> offline, 3 waiting
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Home app bar must not overflow');
      expect(find.byTooltip('Walang signal, 3 naka-save sa phone'), findsOneWidget,
          reason: 'the full sentence is still available as a tooltip');

      await tester.tap(find.byKey(const Key('tab-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tile-products')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Products app bar must not overflow');
      await leave(tester);
    });
  }
}
