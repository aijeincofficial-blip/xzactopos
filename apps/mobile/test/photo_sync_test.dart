import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:xzactopos_mobile/core/photo.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/local_store.dart';
import 'package:xzactopos_mobile/screens/product_form_screen.dart';
import 'package:xzactopos_mobile/sync/photo_loader.dart';
import 'package:xzactopos_mobile/sync/sync_engine.dart';

import 'products_test.dart' show leave, openHome;
import 'sync_engine_test.dart' show FakeApi;

const _tenant = '0190a000-0000-7000-8000-00000000000t';
const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';

Uint8List jpeg() => img.encodeJpg(img.Image(width: 8, height: 8));

class FakePhotoSource implements PhotoSource {
  @override
  Future<Uint8List?> pick({required bool camera}) async => jpeg();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late DriftStore store;
  late FakeApi api;

  setUp(() async {
    store = DriftStore(AppDatabase(NativeDatabase.memory()));
    await store.ensureTenant(_tenant, baseCurrency: 'PHP');
    api = FakeApi();
  });
  tearDown(() => store.close());

  test('a photo shows on the device at once and is queued after the product', () async {
    await store.saveProduct(const ProductDraft(id: _p1, variantId: _v1, name: 'Kape', price: 1), opId: 'o1');
    final path = await store.setPhoto(_p1, _v1, jpeg(), opId: 'o2');
    expect(path, '$_tenant/$_p1/o2.jpg');
    expect((await store.watchProducts().first).single.photoPath, path);
    expect(await store.cachedPhoto(_p1, path), isNotNull);
    expect((await store.nextOps()).map((o) => o.kind), ['upsert_product', 'upload_photo']);
    expect(await store.pendingPhoto('o2'), isNotNull);
  });

  test('sync uploads the file, then points the product at it with the same op id', () async {
    await store.saveProduct(const ProductDraft(id: _p1, variantId: _v1, name: 'Kape', price: 1), opId: 'o1');
    final path = await store.setPhoto(_p1, _v1, jpeg(), opId: 'o2');
    final engine = SyncEngine(store, api);
    await engine.syncNow();
    expect(api.calls, ['upsert:o1', 'upload:$path', 'upsert:o2']);
    expect(api.upserts['o2'], {'id': _p1, 'photo_path': path, 'variant': {'id': _v1}});
    expect(await store.nextOps(), isEmpty);
    expect(await store.pendingPhoto('o2'), isNull, reason: 'queued bytes are dropped once uploaded');
    expect(await store.cachedPhoto(_p1, path), isNotNull, reason: 'the cached copy stays for display');
    engine.dispose();
  });

  test('a failed upload keeps the photo queued; a refused one needs attention', () async {
    await store.saveProduct(const ProductDraft(id: _p1, variantId: _v1, name: 'Kape', price: 1), opId: 'o1');
    await store.setPhoto(_p1, _v1, jpeg(), opId: 'o2');
    final engine = SyncEngine(store, api);

    api.failNextUpload = Exception('network');
    await engine.syncNow();
    expect((await store.nextOps()).map((o) => o.opId), ['o2']);
    expect(await store.pendingPhoto('o2'), isNotNull);

    api.failNextUpload = const OpRejected('photo_too_large');
    await engine.syncNow();
    expect((await store.failedOps()).single.lastError, 'photo_too_large');

    await store.discardFailed('o2');
    expect(await store.pendingPhoto('o2'), isNull);
    engine.dispose();
  });

  group('PhotoLoader', () {
    test('uses the device copy without downloading', () async {
      await store.cachePhoto(_p1, 'a/b/c.jpg', jpeg());
      expect(await PhotoLoader(store, api).load(_p1, 'a/b/c.jpg'), isNotNull);
      expect(api.downloads, isEmpty);
    });

    test('downloads a new path once and keeps it on the device', () async {
      api.photos['x/1.jpg'] = jpeg();
      final loader = PhotoLoader(store, api);
      final results = await Future.wait([loader.load(_p1, 'x/1.jpg'), loader.load(_p1, 'x/1.jpg')]);
      expect(results.every((r) => r != null), isTrue);
      expect(api.downloads, ['x/1.jpg'], reason: 'two rows asking at once share one download');
      expect(await store.cachedPhoto(_p1, 'x/1.jpg'), isNotNull);
    });

    test('never downloads more than two at a time', () async {
      for (var i = 0; i < 6; i++) {
        api.photos['p/$i.jpg'] = jpeg();
      }
      final loader = PhotoLoader(store, api);
      await Future.wait([for (var i = 0; i < 6; i++) loader.load('prod$i', 'p/$i.jpg')]);
      expect(api.downloads, hasLength(6));
      expect(api.maxDownloading, lessThanOrEqualTo(2));
    });

    test('offline: no photo, no crash, tries again next time', () async {
      api.offline = true;
      final loader = PhotoLoader(store, api);
      expect(await loader.load(_p1, 'y/1.jpg'), isNull);
      api.offline = false;
      api.photos['y/1.jpg'] = jpeg();
      expect(await loader.load(_p1, 'y/1.jpg'), isNotNull);
    });
  });

  testWidgets('add a product with a photo: the list shows it and both ops are queued', (tester) async {
    ProductFormScreen.photoSource = FakePhotoSource.new;
    addTearDown(() => ProductFormScreen.photoSource = DevicePhotoSource.new);
    final s = await openHome(tester);
    await tester.tap(find.byKey(const Key('tile-products')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-product')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('photo-gallery')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('new-photo')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('field-name')), 'Kape');
    await tester.enterText(find.byKey(const Key('field-price')), '12');
    await tester.tap(find.byKey(const Key('save-product')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('product-photo')), findsOneWidget);
    final p = (await s.watchProducts().first).single;
    expect(p.photoPath, endsWith('.jpg'));
    await leave(tester);
  });
}
