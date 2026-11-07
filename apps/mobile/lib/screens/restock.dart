import '../data/sales_models.dart';

/// One line of the shopping list: what to buy to get a running-low product back up.
class RestockLine {
  const RestockLine({required this.row, required this.suggested});
  final StockRow row;

  /// How many to buy, a whole number of units.
  final int suggested;

  /// Estimated cost in centavos (the product's cost times [suggested]); 0 when no cost is known.
  int get estimate => row.product.cost * suggested;
}

/// Products at or below their reorder point, with a suggested quantity that brings them back to twice the
/// reorder point (at least 1). Emptiest first, so the most urgent items head the list.
List<RestockLine> buildRestock(List<StockRow> rows) {
  final low = rows.where((r) => r.low).toList()..sort((a, b) => a.qty!.compareTo(b.qty!));
  return [
    for (final r in low) RestockLine(row: r, suggested: _suggest(r.reorderPoint, r.qty!)),
  ];
}

int _suggest(double reorderPoint, double qty) {
  final need = (reorderPoint * 2 - qty).ceil();
  return need < 1 ? 1 : need;
}
