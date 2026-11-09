/// What the phone knows about a warehouse, and how a warehouse clerk's receipts are kept until the server has them.
///
/// Like stock and utang in the store app, every number here is "the server's copy + effects made on this device that the
/// server's copy has not caught up on" (F-13h). A receipt shows at once: the order's remaining quantity falls and the stock
/// rises. The effect is dropped only after a pull has passed the server's own time of the receipt, so a number never dips
/// or counts twice while a receipt is in flight.
library;

class WarehouseView {
  const WarehouseView({required this.id, required this.code, required this.name, required this.binsEnabled});
  final String id;
  final String code;
  final String name;
  final bool binsEnabled;

  @override
  bool operator ==(Object other) =>
      other is WarehouseView && other.id == id && other.code == code && other.name == name && other.binsEnabled == binsEnabled;

  @override
  int get hashCode => Object.hash(id, code, name, binsEnabled);
}

class BinView {
  const BinView({
    required this.id,
    required this.warehouseId,
    required this.code,
    this.aisle,
    this.rack,
    this.shelf,
    this.position,
    this.type = 'shelf',
    this.maxQty,
  });
  final String id;
  final String warehouseId;
  final String code;
  final String? aisle;
  final String? rack;
  final String? shelf;
  final String? position;
  final String type;
  final double? maxQty;
}

class SupplierView {
  const SupplierView({required this.id, required this.name, this.contactName, this.phone, this.email});
  final String id;
  final String name;
  final String? contactName;
  final String? phone;
  final String? email;
}

/// One line of a delivery being received. [unitCost] is the invoice cost in minor units; null lets the server use the
/// order's own cost (or leave the average cost alone for a walk-in).
class ReceiptLine {
  const ReceiptLine({required this.variantId, required this.qty, this.unitCost});
  final String variantId;
  final double qty;
  final int? unitCost;

  Map<String, dynamic> toJson() => {'variant_id': variantId, 'qty': qty, 'unit_cost': ?unitCost};
}

class PoLineView {
  const PoLineView({
    required this.id,
    required this.variantId,
    required this.ordered,
    required this.receivedOnServer,
    required this.pending,
    this.unitCost,
  });
  final String id;
  final String variantId;
  final double ordered;

  /// What the server says was received (as of the last pull).
  final double receivedOnServer;

  /// Received on this device and not yet in the server's copy.
  final double pending;
  final int? unitCost;

  double get received => _round3(receivedOnServer + pending);

  /// Still expected. Over-delivery never makes it negative.
  double get remaining => _round3((ordered - received).clamp(0, double.infinity));
}

class PurchaseOrderView {
  const PurchaseOrderView({
    required this.id,
    required this.poNo,
    required this.warehouseId,
    required this.supplierId,
    this.supplierName,
    required this.status,
    this.expectedAt,
    this.notes,
    required this.items,
  });
  final String id;
  final String poNo;
  final String warehouseId;
  final String supplierId;
  final String? supplierName;

  /// The server's status as of the last pull: `ordered` or `partly_received` for an open order.
  final String status;
  final String? expectedAt;
  final String? notes;
  final List<PoLineView> items;

  double get remainingTotal => _round3(items.fold<double>(0, (s, i) => s + i.remaining));

  /// Nothing more is expected, counting what this device already received.
  bool get completeHere => items.isNotEmpty && remainingTotal == 0;

  /// Something on this order was received here and the server has not confirmed it yet.
  bool get hasPending => items.any((i) => i.pending > 0);
}

/// Stock of one product in a warehouse: the server's level plus what was received here and is not in it yet.
class WhStockRow {
  const WhStockRow({required this.variantId, required this.qty, required this.pending});
  final String variantId;
  final double qty;
  final double pending;
}

class BinStockRow {
  const BinStockRow({required this.binId, required this.binCode, required this.variantId, required this.qty});
  final String binId;
  final String binCode;
  final String variantId;
  final double qty;
}

class WhReceiptView {
  const WhReceiptView({
    required this.opId,
    required this.kind,
    required this.warehouseId,
    this.poId,
    this.poNo,
    this.supplierId,
    this.deliveryRef,
    this.notes,
    required this.createdAt,
    this.grnNo,
    required this.lines,
    required this.confirmed,
  });
  final String opId;

  /// `po` (against an order) or `walkin`.
  final String kind;
  final String warehouseId;
  final String? poId;
  final String? poNo;
  final String? supplierId;
  final String? deliveryRef;
  final String? notes;
  final DateTime createdAt;

  /// The server's receipt number, known once the server has the receipt.
  final String? grnNo;
  final List<ReceiptLine> lines;

  /// The server has applied this receipt.
  final bool confirmed;
}

/// Why a receipt could not be recorded on the device (checked before anything is queued).
class WarehouseReceiptException implements Exception {
  const WarehouseReceiptException(this.code);

  /// unknown_order | order_closed | not_on_order | duplicate_line | qty_invalid | cost_invalid | no_lines | unknown_warehouse
  final String code;
  @override
  String toString() => 'WarehouseReceiptException($code)';
}

/// The warehouse side of the device store. Implemented by the Drift store; screens and the sync engine depend on this.
abstract class WarehouseStore {
  // ---- the warehouse this phone is working in ----
  /// The warehouse the clerk chose (kept on the device), or the first by code when none was chosen or the chosen one is no
  /// longer among the user's warehouses. Null until the first pull has brought a warehouse.
  Stream<WarehouseView?> watchActiveWarehouse();
  Future<WarehouseView?> activeWarehouse();

  /// Remembers [warehouseId] as the one to work in. An id that is not one of the user's warehouses is ignored.
  Future<void> setActiveWarehouse(String warehouseId);

  // ---- reads (work offline) ----
  Stream<List<WarehouseView>> watchWarehouses();
  Stream<List<BinView>> watchBins(String warehouseId);
  Stream<List<SupplierView>> watchSuppliers();

  /// Orders still open (`ordered` or `partly_received` on the server) of one warehouse, oldest first, each with what is
  /// left to receive. An order the device has received in full stays listed (remaining 0) until the server confirms it.
  Stream<List<PurchaseOrderView>> watchOpenPurchaseOrders(String warehouseId);
  Future<PurchaseOrderView?> purchaseOrder(String id);
  Stream<List<WhStockRow>> watchWarehouseStock(String warehouseId);

  /// Per bin (warehouses that use bins). A receipt made here is added to the RECEIVING bin until the server's copy arrives.
  Stream<List<BinStockRow>> watchBinStock(String warehouseId);

  /// Receipts made on this device (newest first), with the server's receipt number once it has them.
  Stream<List<WhReceiptView>> watchReceipts(String warehouseId, {int limit = 30});

  // ---- local writes: applied at once, queued for the server in the same transaction ----
  /// Receives part or all of an open order. Over-delivery is allowed (the server flags it). Throws
  /// [WarehouseReceiptException] when the order is unknown or closed, a product is not on it, a quantity or cost is invalid,
  /// or a product appears twice. [opId] becomes the goods receipt id on the server, so retrying is harmless.
  Future<void> receiveAgainstPo({
    required String poId,
    required List<ReceiptLine> lines,
    String? deliveryRef,
    String? notes,
    required String opId,
  });

  /// A delivery with no order (flagged on the server).
  Future<void> receiveWithoutPo({
    required String warehouseId,
    String? supplierId,
    required List<ReceiptLine> lines,
    String? deliveryRef,
    String? notes,
    required String opId,
  });

  // ---- sync ----
  /// Cursors of sync_pull_warehouse by table name (kept apart from the store pull's cursors).
  Future<Map<String, dynamic>> warehouseCursors();

  /// Applies one sync_pull_warehouse response and its cursors atomically, then settles receipts the server has caught up on.
  Future<void> applyPullWarehouse(Map<String, dynamic> response);

  /// A receipt op was applied by the server: [appliedAt] is the server's time of it ([result] carries `grn_no`).
  Future<void> warehouseOpApplied(String opId, String? appliedAt, {Map<String, dynamic>? result});
}

double _round3(double v) => (v * 1000).round() / 1000;
