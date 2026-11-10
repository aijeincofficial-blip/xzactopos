/// Stock counts on the phone (F-13h H6). Counting needs a connection in this version: a count is measured against the
/// system quantity at the moment each line is counted, and only the server knows that moment. So these calls go straight to
/// the server and are never queued.
library;

/// One counted line: what the clerk counted, and the system quantity when it was counted (the server's answer).
class CountLine {
  const CountLine({required this.variantId, this.binId, this.binCode, required this.qtySystem, required this.qtyCounted});
  final String variantId;
  final String? binId;
  final String? binCode;
  final double qtySystem;
  final double qtyCounted;

  /// Counted minus what the system held at that moment.
  double get variance => _round3(qtyCounted - qtySystem);

  factory CountLine.fromJson(Map<String, dynamic> j) => CountLine(
        variantId: j['variant_id'] as String,
        binId: j['bin_id'] as String?,
        binCode: (j['bin'] as Map?)?['code'] as String?,
        qtySystem: (j['qty_system'] as num).toDouble(),
        qtyCounted: (j['qty_counted'] as num).toDouble(),
      );
}

/// The open count of a warehouse.
class CountSession {
  const CountSession({
    required this.id,
    required this.countNo,
    required this.warehouseId,
    this.binId,
    this.binCode,
    this.notes,
    required this.lines,
    this.isLocal = false,
  });
  final String id;
  final String countNo;
  final String warehouseId;

  /// Set when only one bin is counted.
  final String? binId;
  final String? binCode;
  final String? notes;
  final List<CountLine> lines;
  final bool isLocal;

  bool get wholeWarehouse => binId == null;

  factory CountSession.fromJson(Map<String, dynamic> j) => CountSession(
        id: j['id'] as String,
        countNo: j['count_no'] as String,
        warehouseId: j['warehouse_id'] as String,
        binId: j['bin_id'] as String?,
        binCode: (j['bin'] as Map?)?['code'] as String?,
        notes: j['notes'] as String?,
        isLocal: (j['is_local'] as bool?) ?? false,
        lines: [for (final l in (j['stock_count_items'] as List? ?? const [])) CountLine.fromJson((l as Map).cast<String, dynamic>())],
      );
}

/// What one line of a record call says, including the device snapshot of system quantity when offline.
class CountEntry {
  const CountEntry({required this.variantId, required this.qty, this.binId, this.qtySystem});
  final String variantId;
  final double qty;
  final String? binId;
  final double? qtySystem;

  Map<String, dynamic> toJson() => {
        'variant_id': variantId,
        'qty_counted': qty,
        'bin_id': ?binId,
        'qty_system': ?qtySystem,
      };
}

class CountResult {
  const CountResult({required this.lines, required this.corrections, required this.netVariance, required this.zeroed});
  final int lines;
  final int corrections;
  final double netVariance;
  final int zeroed;

  factory CountResult.fromJson(Map<String, dynamic> j) => CountResult(
        lines: (j['lines'] as num?)?.toInt() ?? 0,
        corrections: (j['corrections'] as num?)?.toInt() ?? 0,
        netVariance: (j['net_variance'] as num?)?.toDouble() ?? 0,
        zeroed: (j['zeroed'] as num?)?.toInt() ?? 0,
      );
}

/// The server said no. [hint] is the server's machine-readable reason (`count_in_progress`, `bin_required`, ...).
class CountException implements Exception {
  const CountException(this.hint);
  final String hint;
  @override
  String toString() => 'CountException($hint)';
}

/// No connection (or the server could not be reached): nothing was changed.
class CountOffline implements Exception {
  const CountOffline();
  @override
  String toString() => 'CountOffline()';
}

/// Count calls. Kept apart from the sync API like `WarehouseApi`: only a phone used in a warehouse needs it.
abstract class CountApi {
  /// The open count of a warehouse with its lines, or null when none is open.
  Future<CountSession?> openCount(String warehouseId);

  /// Opens a count. [id] is generated on the phone, so a retry opens the same count.
  Future<void> startCount({required String id, required String warehouseId, String? binId, String? notes});

  /// Saves counted quantities (1 to 500 lines). Counting a product again replaces its line. Stock does not move yet.
  Future<void> recordCount(String countId, List<CountEntry> items);

  /// Applies the differences. With [zeroUncounted], stock in scope that has no line counts as zero.
  Future<CountResult> closeCount(String countId, {bool zeroUncounted = false});

  Future<void> cancelCount(String countId, {String? reason});
}

double _round3(double v) => (v * 1000).round() / 1000;
