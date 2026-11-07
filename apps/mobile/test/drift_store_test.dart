import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/db.dart';
import 'package:xzactopos_mobile/data/drift_store.dart';
import 'package:xzactopos_mobile/data/local_store.dart';

const _p1 = '0190a000-0000-7000-8000-000000000001';
const _v1 = '0190a000-0000-7000-8000-0000000000a1';
const _p2 = '0190a000-0000-7000-8000-000000000002';
const _v2 = '0190a000-0000-7000-8000-0000000000a2';

Map<String, dynamic> pullPage({
  List<Map<String, dynamic>> products = const [],
  List<Map<String, dynamic>> variants = const [],
  List<Map<String, dynamic>> prices = const [],
  bool more = false,
}) {
  Map<String, dynamic> t(List rows, String k) => {
        'rows': rows,
        'cursor': rows.isEmpty ? null : {'ts': '2026-11-08T00:00:00.000001+00:00', 'k': k},
        'has_more': more,
      };
  return {
    'server_time': '2026-11-08T00:00:10+00:00',
    'categories': t(const [], ''),
    'products': t(products, 'p'),
    'product_variants': t(variants, 'v'),
    'variant_prices': t(prices, 'pr'),
  };
}

Map<String, dynamic> serverProduct(String id, String name, {String? deletedAt}) => {
      'id': id, 'category_id': null, 'name': name, 'unit': 'pc', 'tax_rate': 0, 'track_stock': true,
      'active': true, 'photo_path': null, 'updated_at': '2026-11-08T00:00:00.000001+00:00', 'deleted_at': deletedAt,
    };
Map<String, dynamic> serverVariant(String id, String productId, {String? barcode}) => {
      'id': id, 'product_id': productId, 'sku': 'SKU-$id'.substring(0, 12), 'barcode': barcode, 'is_default': true,
      'cost': 0, 'reorder_point': 0, 'active': true, 'updated_at': '2026-11-08T00:00:00+00:00', 'deleted_at': null,
    };
Map<String, dynamic> serverPrice(String variantId, int price) => {
      'variant_id': variantId, 'currency': 'PHP', 'price': price,
      'updated_at': '2026-11-08T00:00:00+00:00', 'deleted_at': null,
    };

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late DriftStore store;

  setUp(() async {
    store = DriftStore(AppDatabase(NativeDatabase.memory()));
    await store.ensureTenant('tenant-a', baseCurrency: 'PHP');
  });
  tearDown(() => store.close());

  test('a local save is readable at once and queued for the server', () async {
    await store.saveProduct(
      const ProductDraft(id: _p1, variantId: _v1, name: ' Kape ', price: 1250, barcode: '4800000000011', openingQty: 24),
      opId: 'op-1',
    );
    final list = await store.watchProducts().first;
    expect(list, hasLength(1));
    expect(list.single.name, 'Kape');
    expect(list.single.price, 1250);
    expect(list.single.pending, isTrue);
    expect(list.single.sku, startsWith('P-'));
    expect((await store.findByBarcode('4800000000011'))?.id, _p1);

    final ops = await store.nextOps();
    expect(ops.first.opId, 'op-1');
    expect(ops.first.kind, 'upsert_product');
    expect(ops.first.payload['price'], 1250);
    expect((ops.first.payload['variant'] as Map)['id'], _v1);
    // opening stock is a real op after the product op, and shows as stock left at once
    expect(ops.map((o) => o.kind), ['upsert_product', 'post_opening_stock']);
    expect(ops.last.payload, {'variant_id': _v1, 'qty': 24.0});
    expect(await store.stockLeft(_v1), 24);
  });

  test('search by name, barcode and SKU', () async {
    await store.applyPull(pullPage(
      products: [serverProduct(_p1, 'Kape 3-in-1'), serverProduct(_p2, 'Asukal')],
      variants: [serverVariant(_v1, _p1, barcode: '111'), serverVariant(_v2, _p2)],
      prices: [serverPrice(_v1, 1500), serverPrice(_v2, 4500)],
    ));
    expect((await store.watchProducts(query: 'kape').first).map((p) => p.id), [_p1]);
    expect((await store.watchProducts(query: '111').first).map((p) => p.id), [_p1]);
    expect((await store.watchProducts().first).map((p) => p.name), ['Asukal', 'Kape 3-in-1']);
  });

  test('pull applies rows and cursors; tombstones hide products', () async {
    await store.applyPull(pullPage(
      products: [serverProduct(_p1, 'Kape')],
      variants: [serverVariant(_v1, _p1)],
      prices: [serverPrice(_v1, 1500)],
    ));
    expect(await store.productCount(), 1);
    expect((await store.cursors())['products'], {'ts': '2026-11-08T00:00:00.000001+00:00', 'k': 'p'});

    await store.applyPull(pullPage(products: [serverProduct(_p1, 'Kape', deletedAt: '2026-11-08T01:00:00+00:00')]));
    expect(await store.productCount(), 0);
    expect(await store.watchProducts().first, isEmpty);
  });

  test('pull does not overwrite a product with unsent local changes', () async {
    await store.applyPull(pullPage(
      products: [serverProduct(_p1, 'Old name')],
      variants: [serverVariant(_v1, _p1)],
      prices: [serverPrice(_v1, 1000)],
    ));
    await store.saveProduct(const ProductDraft(id: _p1, variantId: _v1, name: 'New name', price: 1200), opId: 'op-2');
    await store.applyPull(pullPage(
      products: [serverProduct(_p1, 'Old name')],
      variants: [serverVariant(_v1, _p1)],
      prices: [serverPrice(_v1, 1000)],
    ));
    final p = (await store.watchProducts().first).single;
    expect(p.name, 'New name');
    expect(p.price, 1200);
  });

  test('archive hides the product locally and queues the op', () async {
    await store.saveProduct(const ProductDraft(id: _p1, variantId: _v1, name: 'Kape', price: 1, barcode: '9'), opId: 'a');
    await store.archiveProduct(_p1, opId: 'b');
    expect(await store.watchProducts().first, isEmpty);
    expect(await store.findByBarcode('9'), isNull);
    expect((await store.nextOps()).map((o) => o.kind), ['upsert_product', 'archive_product']);
  });

  test('failed ops are counted, and discarding a never-synced create removes it', () async {
    await store.applyPull(pullPage(products: [serverProduct(_p2, 'Asukal')], variants: [serverVariant(_v2, _p2)]));
    await store.saveProduct(const ProductDraft(id: _p1, variantId: _v1, name: 'Dup', price: 1), opId: 'op-x');
    await store.opFailed('op-x', 'duplicate_barcode');
    expect(await store.watchOutboxCounts().first, isA<OutboxCounts>().having((c) => c.failed, 'failed', 1));
    expect(await store.nextOps(), isEmpty);
    expect((await store.failedOps()).single.lastError, 'duplicate_barcode');

    await store.discardFailed('op-x');
    expect((await store.watchProducts().first).map((p) => p.id), [_p2]);
    expect(await store.cursors(), isEmpty, reason: 'forces a full re-pull');
  });

  test('switching to another business clears the device data', () async {
    await store.saveProduct(const ProductDraft(id: _p1, variantId: _v1, name: 'Kape', price: 1), opId: 'a');
    expect(await store.ensureTenant('tenant-a', baseCurrency: 'PHP'), isFalse);
    expect(await store.productCount(), 1);
    expect(await store.ensureTenant('tenant-b', baseCurrency: 'PHP'), isTrue);
    expect(await store.productCount(), 0);
    expect(await store.nextOps(), isEmpty);
  });
}
