class WarehouseBin {
  const WarehouseBin({
    required this.id,
    required this.code,
    this.zoneId,
    this.zoneCode,
    this.zoneName,
    this.zoneType,
    this.aisle,
    this.rack,
    this.shelf,
    this.position,
    this.type = 'shelf',
    this.maxQty,
    this.active = true,
    this.itemCount = 0,
    this.totalQty = 0,
  });

  final String id;
  final String code;
  final String? zoneId;
  final String? zoneCode;
  final String? zoneName;
  final String? zoneType;
  final String? aisle;
  final String? rack;
  final String? shelf;
  final String? position;
  final String type;
  final double? maxQty;
  final bool active;
  final int itemCount;
  final double totalQty;

  String get locationLabel {
    final parts = <String>[];
    if (zoneName != null && zoneName!.isNotEmpty) parts.add(zoneName!);
    if (aisle != null && aisle!.isNotEmpty) parts.add('Aisle $aisle');
    if (rack != null && rack!.isNotEmpty) parts.add('Rack $rack');
    if (shelf != null && shelf!.isNotEmpty) parts.add('Shelf $shelf');
    if (position != null && position!.isNotEmpty) parts.add('Pos $position');
    if (parts.isEmpty) return code;
    return '$code (${parts.join(' - ')})';
  }

  factory WarehouseBin.fromJson(Map<String, dynamic> json) {
    return WarehouseBin(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      zoneId: json['zone_id'] as String?,
      zoneCode: json['zone_code'] as String?,
      zoneName: json['zone_name'] as String?,
      zoneType: json['zone_type'] as String?,
      aisle: json['aisle'] as String?,
      rack: json['rack'] as String?,
      shelf: json['shelf'] as String?,
      position: json['position'] as String?,
      type: json['type'] as String? ?? 'shelf',
      maxQty: json['max_qty'] != null ? (json['max_qty'] as num).toDouble() : null,
      active: json['active'] as bool? ?? true,
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
      totalQty: (json['total_qty'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ReceivingStockItem {
  const ReceivingStockItem({
    required this.binId,
    required this.binCode,
    required this.variantId,
    required this.sku,
    required this.productName,
    required this.qtyOnHand,
    this.updatedAt,
  });

  final String binId;
  final String binCode;
  final String variantId;
  final String sku;
  final String productName;
  final double qtyOnHand;
  final String? updatedAt;

  factory ReceivingStockItem.fromJson(Map<String, dynamic> json) {
    return ReceivingStockItem(
      binId: json['bin_id'] as String? ?? '',
      binCode: json['bin_code'] as String? ?? '',
      variantId: json['variant_id'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      productName: json['product_name'] as String? ?? '',
      qtyOnHand: (json['qty_on_hand'] as num?)?.toDouble() ?? 0.0,
      updatedAt: json['updated_at'] as String?,
    );
  }
}
