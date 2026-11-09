import 'money.dart';

/// Most rows read in one import (a phone, a free-tier backend: add big catalogs in batches).
const importMaxRows = 500;

enum ImportProblem { nameMissing, priceInvalid, costInvalid, stockInvalid }

class ImportRow {
  const ImportRow({
    required this.line,
    required this.name,
    required this.price,
    this.barcode,
    this.cost,
    this.stock,
    this.unit,
  });

  /// Line number in the pasted text (1 = first line, header included).
  final int line;
  final String name;

  /// Centavos.
  final int price;
  final String? barcode;
  final int? cost;
  final double? stock;
  final String? unit;
}

class ImportError {
  const ImportError(this.line, this.problem);
  final int line;
  final ImportProblem problem;
}

class ImportParse {
  const ImportParse({required this.rows, required this.errors, required this.tooMany});
  final List<ImportRow> rows;
  final List<ImportError> errors;

  /// More than [importMaxRows] data lines were pasted; the rest were not read.
  final bool tooMany;
}

/// Splits pasted spreadsheet text into cells. Handles tabs (copied from a sheet), commas or semicolons, and quoted cells.
List<List<String>> splitCsv(String text) {
  final src = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final firstLine = src.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
  String delim = ',';
  if (firstLine.contains('\t')) {
    delim = '\t';
  } else if (';'.allMatches(firstLine).length > ','.allMatches(firstLine).length) {
    delim = ';';
  }
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  void endCell() {
    row.add(cell.toString().trim());
    cell.clear();
  }

  void endRow() {
    endCell();
    rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < src.length; i++) {
    final c = src[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < src.length && src[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(c);
      }
    } else if (c == '"' && cell.isEmpty) {
      quoted = true;
    } else if (c == delim) {
      endCell();
    } else if (c == '\n') {
      endRow();
    } else {
      cell.write(c);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

const _headerNames = {
  'name': ['name', 'product', 'item', 'pangalan', 'produkto'],
  'price': ['price', 'presyo', 'selling price'],
  'barcode': ['barcode', 'code', 'sku'],
  'cost': ['cost', 'puhunan', 'capital'],
  'stock': ['stock', 'qty', 'quantity', 'bilang'],
  'unit': ['unit'],
};

/// Reads pasted product rows. A header line is optional (found by column names in English or Filipino); without one the
/// order is name, price, barcode, cost, stock. Blank lines are skipped. Prices and costs may carry ₱, PHP or commas.
ImportParse parseProductCsv(String text, String currency) {
  final all = splitCsv(text).where((r) => r.any((c) => c.isNotEmpty)).toList();
  if (all.isEmpty) return const ImportParse(rows: [], errors: [], tooMany: false);

  var cols = {'name': 0, 'price': 1, 'barcode': 2, 'cost': 3, 'stock': 4};
  var start = 0;
  final head = all.first.map((c) => c.toLowerCase()).toList();
  final found = <String, int>{};
  for (final e in _headerNames.entries) {
    final i = head.indexWhere((h) => e.value.contains(h));
    if (i >= 0) found[e.key] = i;
  }
  if (found.containsKey('name') && found.containsKey('price')) {
    cols = found;
    start = 1;
  }

  String? cell(List<String> r, String key) {
    final i = cols[key];
    if (i == null || i >= r.length) return null;
    final v = r[i].trim();
    return v.isEmpty ? null : v;
  }

  int? money(String? v) {
    if (v == null) return null;
    final cleaned = v.replaceAll(RegExp(r'[₱\s]|php', caseSensitive: false), '');
    try {
      final m = Money.parse(cleaned, currency).amount;
      return m < 0 ? null : m;
    } catch (_) {
      return null;
    }
  }

  final rows = <ImportRow>[];
  final errors = <ImportError>[];
  var tooMany = false;
  for (var i = start; i < all.length; i++) {
    if (rows.length + errors.length >= importMaxRows) {
      tooMany = true;
      break;
    }
    final r = all[i];
    final line = i + 1;
    final name = cell(r, 'name');
    if (name == null) {
      errors.add(ImportError(line, ImportProblem.nameMissing));
      continue;
    }
    final price = money(cell(r, 'price'));
    if (price == null) {
      errors.add(ImportError(line, ImportProblem.priceInvalid));
      continue;
    }
    final costText = cell(r, 'cost');
    final cost = money(costText);
    if (costText != null && cost == null) {
      errors.add(ImportError(line, ImportProblem.costInvalid));
      continue;
    }
    final stockText = cell(r, 'stock');
    final stock = stockText == null ? null : double.tryParse(stockText.replaceAll(',', '.'));
    if (stockText != null && (stock == null || stock < 0)) {
      errors.add(ImportError(line, ImportProblem.stockInvalid));
      continue;
    }
    rows.add(ImportRow(
      line: line,
      name: name,
      price: price,
      barcode: cell(r, 'barcode'),
      cost: cost,
      stock: stock,
      unit: cell(r, 'unit'),
    ));
  }
  return ImportParse(rows: rows, errors: errors, tooMany: tooMany);
}
