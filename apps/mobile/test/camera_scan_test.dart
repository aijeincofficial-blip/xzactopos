import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/core/camera_scanner.dart';

import 'drift_store_test.dart' show pullPage, serverPrice, serverProduct, serverVariant;
import 'flutter_test_config.dart' show NoCamera;
import 'products_test.dart' show leave, openHome;

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';
const _p2 = '0190a000-0000-7000-8000-000000000002';
const _v2 = '0190a000-0000-7000-8000-0000000000a2';

/// Stands in for the phone camera: "reads" the codes it was given, one after another.
class FakeCamera implements CameraScanner {
  FakeCamera({this.one, this.many = const []});
  final String? one;
  final List<String> many;
  final feedback = <ScanFeedback>[];
  int opened = 0;

  @override
  bool get available => true;
  @override
  Future<String?> scanOne(BuildContext context) async {
    opened++;
    return one;
  }

  @override
  Future<void> scanMany(BuildContext context, Future<ScanFeedback> Function(String code) onCode) async {
    opened++;
    for (final c in many) {
      feedback.add(await onCode(c));
    }
  }
}

Future<void> seed(dynamic store) => store.applyPull(pullPage(
      products: [serverProduct(_p1, 'Kape 3-in-1'), serverProduct(_p2, 'Walang Presyo')],
      variants: [serverVariant(_v1, _p1, barcode: '4800016644801'), serverVariant(_v2, _p2, barcode: '4800000000222')],
      prices: [serverPrice(_v1, 1250)],
    ));

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  tearDown(() => cameraScanner = const NoCamera());

  testWidgets('Sell: the camera adds each scanned product, names unknown codes, and stays open for the next', (tester) async {
    final cam = FakeCamera(many: ['4800016644801', '4800016644801', '4809999999999', '4800000000222']);
    cameraScanner = cam;
    final store = await openHome(tester);
    await seed(store);
    await tester.tap(find.byKey(const Key('tile-sell')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('camera-scan')));
    await tester.pumpAndSettle();
    expect(cam.opened, 1);
    expect(cam.feedback.map((f) => f.message), [
      'Added: Kape 3-in-1',
      'Added: Kape 3-in-1',
      'No product has barcode 4809999999999',
      'Set a price for this product first',
    ]);
    expect(cam.feedback.map((f) => f.ok), [true, true, false, false]);
    expect(tester.widget<Text>(find.byKey(const Key('cart-total'))).data, '₱25.00', reason: 'two Kape, nothing else');
    await leave(tester);
  });

  testWidgets('Sell: without a camera there is no camera button (web, tests)', (tester) async {
    final store = await openHome(tester);
    await seed(store);
    await tester.tap(find.byKey(const Key('tile-sell')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('camera-scan')), findsNothing);
    await leave(tester);
  });

  testWidgets('Products: the scan button reads one code with the camera and opens that product', (tester) async {
    cameraScanner = FakeCamera(one: '4800016644801');
    final store = await openHome(tester);
    await seed(store);
    await tester.tap(find.byKey(const Key('tile-products')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scan-button')));
    await tester.pumpAndSettle();
    expect(find.text('Edit product'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Kape 3-in-1'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('Products: an unknown scanned barcode offers to add it', (tester) async {
    cameraScanner = FakeCamera(one: '4801111111111');
    await openHome(tester);
    await tester.tap(find.byKey(const Key('tile-products')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scan-button')));
    await tester.pumpAndSettle();
    expect(find.text('New barcode'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('Products: backing out of the camera does nothing', (tester) async {
    cameraScanner = FakeCamera();
    await openHome(tester);
    await tester.tap(find.byKey(const Key('tile-products')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scan-button')));
    await tester.pumpAndSettle();
    expect(find.text('New barcode'), findsNothing);
    expect(find.text('Edit product'), findsNothing);
    await leave(tester);
  });

  testWidgets('Product form: the camera fills the barcode field', (tester) async {
    cameraScanner = FakeCamera(one: '4807770270017');
    await openHome(tester);
    await tester.tap(find.byKey(const Key('tile-products')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-product')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('barcode-camera')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '4807770270017'), findsOneWidget);
    await leave(tester);
  });
}
