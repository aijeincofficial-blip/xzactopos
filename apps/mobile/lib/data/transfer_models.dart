class TransferItem {
  const TransferItem({
    required this.id,
    required this.transferId,
    required this.variantId,
    required this.productName,
    this.barcode,
    this.sku,
    required this.unit,
    required this.qtyShipped,
    this.qtyReceived,
  });

  final String id;
  final String transferId;
  final String variantId;
  final String productName;
  final String? barcode;
  final String? sku;
  final String unit;
  final double qtyShipped;
  final double? qtyReceived;

  bool get hasDiscrepancy => qtyReceived != null && qtyReceived != qtyShipped;

  factory TransferItem.fromJson(Map<String, dynamic> json) {
    final v = json['variant'] as Map<String, dynamic>?;
    final p = v?['product'] as Map<String, dynamic>?;
    return TransferItem(
      id: json['id'] as String,
      transferId: json['transfer_id'] as String,
      variantId: json['variant_id'] as String,
      productName: p?['name'] as String? ?? v?['sku'] as String? ?? 'Item',
      barcode: v?['barcode'] as String?,
      sku: v?['sku'] as String?,
      unit: p?['unit'] as String? ?? 'pc',
      qtyShipped: (json['qty_shipped'] as num?)?.toDouble() ?? 0.0,
      qtyReceived: (json['qty_received'] as num?)?.toDouble(),
    );
  }
}

class TransferHeader {
  const TransferHeader({
    required this.id,
    required this.transferNo,
    required this.fromLocationId,
    required this.fromLocationName,
    required this.toLocationId,
    required this.toLocationName,
    required this.status,
    this.notes,
    this.shippedAt,
    this.receivedAt,
    this.hasDiscrepancy = false,
    this.itemCount = 0,
    this.items = const [],
  });

  final String id;
  final String transferNo;
  final String fromLocationId;
  final String fromLocationName;
  final String toLocationId;
  final String toLocationName;
  final String status;
  final String? notes;
  final DateTime? shippedAt;
  final DateTime? receivedAt;
  final bool hasDiscrepancy;
  final int itemCount;
  final List<TransferItem> items;

  bool get isShipped => status == 'shipped';
  bool get isReceived => status == 'received';

  factory TransferHeader.fromJson(Map<String, dynamic> json) {
    final fromLoc = json['from_location'] as Map<String, dynamic>?;
    final toLoc = json['to_location'] as Map<String, dynamic>?;
    final rawItems = (json['transfer_items'] as List<dynamic>?) ?? [];
    final items = rawItems
        .map((i) => TransferItem.fromJson(i as Map<String, dynamic>))
        .toList();

    return TransferHeader(
      id: json['id'] as String,
      transferNo: json['transfer_no'] as String? ?? '',
      fromLocationId: json['from_location_id'] as String? ?? '',
      fromLocationName: fromLoc?['name'] as String? ?? 'Origin',
      toLocationId: json['to_location_id'] as String? ?? '',
      toLocationName: toLoc?['name'] as String? ?? 'Destination',
      status: json['status'] as String? ?? 'draft',
      notes: json['notes'] as String?,
      shippedAt: json['shipped_at'] != null ? DateTime.parse(json['shipped_at'] as String) : null,
      receivedAt: json['received_at'] != null ? DateTime.parse(json['received_at'] as String) : null,
      hasDiscrepancy: json['has_discrepancy'] as bool? ?? false,
      itemCount: items.isNotEmpty ? items.length : ((json['item_count'] as num?)?.toInt() ?? 0),
      items: items,
    );
  }
}
