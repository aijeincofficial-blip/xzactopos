import 'dart:typed_data';

import 'sales_models.dart';
import 'warehouse_models.dart';

/// The device's copy of the catalog plus the outbox. Screens and the sync engine depend on this
/// interface only (CLAUDE.md: local store behind a `LocalStore` interface); Drift implements it.
abstract class LocalStore implements SalesStore, WarehouseStore {
  /// Clears everything when the device is used for a different business. Returns true if it cleared.
  /// Throws [UnsentChangesException] instead when that would throw away changes never sent to the server,
  /// unless [discardUnsent] is true.
  ///
  /// F-01: [stores] = the stores the user may work at (access payload); the active store becomes the one chosen before on
  /// this device if it is still allowed, else [locationId] if allowed, else the first store (the only one for a solo
  /// owner). [stores] null = just [locationId] when given (one store; how tests and older callers name it).
  Future<bool> ensureTenant(String tenantId,
      {required String baseCurrency, String? locationId, List<StoreRef>? stores, bool discardUnsent = false});
  String get baseCurrency;

  // ---- reads (work offline) ----
  Stream<List<ProductView>> watchProducts({String query = ''});
  Future<ProductView?> findByBarcode(String barcode);

  /// The hidden "open amount" product behind the Sell keypad (a typed amount, no stock count). Made on first use,
  /// named [name] (in the current language); the same product afterwards.
  Future<ProductView> openAmountProduct({required String name});
  Future<int> productCount();

  // ---- local writes: applied at once, queued for the server in the same transaction ----
  Future<void> saveProduct(ProductDraft draft, {required String opId});
  Future<void> archiveProduct(String productId, {required String opId});

  // ---- photos ----
  /// Attaches a JPEG to a product: shown at once from the device, uploaded later by an `upload_photo` op.
  /// Returns the storage path `<tenant>/<product>/<op>.jpg`.
  Future<String> setPhoto(String productId, String variantId, Uint8List jpeg, {required String opId});

  /// The product's photo if this device has it for [path] (null = not downloaded yet).
  Future<Uint8List?> cachedPhoto(String productId, String path);
  Future<void> cachePhoto(String productId, String path, Uint8List bytes);

  /// Bytes waiting for the upload_photo op [opId]; removed by [photoUploaded].
  Future<Uint8List?> pendingPhoto(String opId);
  Future<void> photoUploaded(String opId);

  // ---- sync ----
  Future<Map<String, dynamic>> cursors();

  /// Applies one sync_pull_catalog response and its cursors atomically. Rows for products with
  /// unsent local changes are skipped; the server copy arrives again after the push succeeds.
  Future<void> applyPull(Map<String, dynamic> response);
  Future<List<OutboxOp>> nextOps({int limit = 50});
  Future<void> opDone(String opId);
  Future<void> opFailed(String opId, String error);
  Future<void> opRetryLater(String opId, String error);
  Stream<OutboxCounts> watchOutboxCounts();
  Future<List<OutboxOp>> failedOps();

  /// Drops a rejected op, removes a never-synced product it created, and forces a full re-pull.
  Future<void> discardFailed(String opId);

  Future<void> close();
}

/// A different business signed in on this phone while changes of the previous one were still unsent.
class UnsentChangesException implements Exception {
  const UnsentChangesException(this.count);
  final int count;
  @override
  String toString() => 'UnsentChangesException($count)';
}

/// SKU of the hidden open-amount product (see [LocalStore.openAmountProduct]); left out of quick tiles and search.
const openAmountSku = 'OPEN-AMOUNT';

class ProductView {
  const ProductView({
    required this.id,
    required this.variantId,
    required this.name,
    required this.unit,
    required this.sku,
    this.barcode,
    this.price,
    required this.currency,
    this.photoPath,
    required this.active,
    required this.pending,
    this.trackStock = true,
    this.taxRate = 0,
    this.cost = 0,
    this.reorderPoint = 0,
    this.breaksIntoVariantId,
    this.piecesPerPack,
    this.pieceName,
  });

  final String id;
  final String variantId;
  final String name;
  final String unit;
  final String sku;
  final String? barcode;

  /// Base-currency minor units; null if no price row yet.
  final int? price;
  final String currency;
  final String? photoPath;
  final bool active;

  /// Has local changes the server has not confirmed yet.
  final bool pending;

  /// The product keeps a stock count.
  final bool trackStock;

  /// Price already includes this tax (0.12 = 12%).
  final double taxRate;

  /// Base-currency minor units, copied onto each sale line for margins.
  final int cost;

  /// Warn when stock is at or below this (0 = no warning).
  final double reorderPoint;

  /// Tingi: this product is a pack that breaks into [piecesPerPack] of the piece variant [breaksIntoVariantId]
  /// (the piece product is named [pieceName]). All null when it is not sold by the piece.
  final String? breaksIntoVariantId;
  final int? piecesPerPack;
  final String? pieceName;

  /// A pack that can be opened into pieces ([SalesStore.openPack]).
  bool get sellsByPiece => breaksIntoVariantId != null && piecesPerPack != null;

  /// The same product at another price (the keypad adds typed amounts onto one line).
  ProductView withPrice(int newPrice) => ProductView(
        id: id,
        variantId: variantId,
        name: name,
        unit: unit,
        sku: sku,
        barcode: barcode,
        price: newPrice,
        currency: currency,
        photoPath: photoPath,
        active: active,
        pending: pending,
        trackStock: trackStock,
        taxRate: taxRate,
        cost: cost,
        reorderPoint: reorderPoint,
        breaksIntoVariantId: breaksIntoVariantId,
        piecesPerPack: piecesPerPack,
        pieceName: pieceName,
      );
}

class ProductDraft {
  const ProductDraft({
    required this.id,
    required this.variantId,
    required this.name,
    required this.price,
    this.unit = 'pc',
    this.sku,
    this.barcode,
    this.cost,
    this.openingQty,
    this.reorderPoint,
    this.trackStock,
  });

  final String id;
  final String variantId;
  final String name;

  /// Base-currency minor units.
  final int price;
  final String unit;
  final String? sku;
  final String? barcode;
  final int? cost;
  final double? openingQty;

  /// Warn when stock is at or below this; null keeps the current value.
  final double? reorderPoint;

  /// false = no stock count for this product; null keeps the current value (new products count stock).
  final bool? trackStock;

  /// Payload for the upsert_product RPC.
  Map<String, dynamic> toPayload() => {
        'id': id,
        'name': name,
        'price': price,
        'unit': unit,
        'variant': {
          'id': variantId,
          if (sku != null && sku!.isNotEmpty) 'sku': sku,
          'barcode': (barcode == null || barcode!.isEmpty) ? null : barcode,
          if (cost != null) 'cost': cost,
          'reorder_point': ?reorderPoint,
        },
        'track_stock': ?trackStock,
      };
}

class OutboxOp {
  const OutboxOp({
    required this.opId,
    required this.kind,
    required this.entityId,
    required this.payload,
    required this.attempts,
    this.lastError,
  });

  final String opId;
  final String kind; // upsert_product | archive_product | upload_photo
  final String entityId;
  final Map<String, dynamic> payload;
  final int attempts;
  final String? lastError;
}

class OutboxCounts {
  const OutboxCounts(this.pending, this.failed);
  final int pending;
  final int failed;
}
