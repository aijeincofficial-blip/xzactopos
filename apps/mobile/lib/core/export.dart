import 'dart:convert';

import 'package:share_plus/share_plus.dart';

import '../data/sales_models.dart';
import 'money.dart';

/// One CSV cell: quoted when it holds a comma, quote or line break, and guarded against spreadsheet
/// formulas (a cell starting with = + - @ would run as a formula when opened in Excel or Sheets).
String csvCell(String value) {
  var v = value;
  if (v.isNotEmpty && '=+@'.contains(v[0])) v = "'$v";
  if (v.contains(RegExp(r'[",\r\n]'))) v = '"${v.replaceAll('"', '""')}"';
  return v;
}

String csvRow(Iterable<String> cells) => cells.map(csvCell).join(',');

String _plain(int amount, String currency) => Money(amount, currency).toDecimalString();

/// Sales (newest first): receipt number, when (UTC), status, customer, total, still waiting to be sent.
String salesCsv(List<SaleSummary> sales, String currency) => [
      csvRow(['receipt_no', 'sold_at_utc', 'status', 'customer', 'total', 'not_sent']),
      for (final s in sales)
        csvRow([
          s.localNo,
          s.soldAt.toUtc().toIso8601String(),
          s.status,
          s.customerName ?? '',
          _plain(s.total, currency),
          s.pending ? 'yes' : 'no',
        ]),
    ].join('\r\n');

/// Who owes what (a negative balance means the customer paid ahead).
String utangCsv(List<CustomerView> customers, String currency) => [
      csvRow(['customer', 'phone', 'balance']),
      for (final c in customers) csvRow([c.name, c.phone ?? '', _plain(c.balance, currency)]),
    ].join('\r\n');

/// Stock per product; quantity is empty when the product was never counted.
String stockCsv(List<StockRow> rows) => [
      csvRow(['product', 'sku', 'unit', 'quantity', 'reorder_point', 'low']),
      for (final r in rows)
        csvRow([
          r.product.name,
          r.product.sku,
          r.product.unit,
          r.qty == null ? '' : _qty(r.qty!),
          r.reorderPoint > 0 ? _qty(r.reorderPoint) : '',
          r.low ? 'yes' : 'no',
        ]),
    ].join('\r\n');

String _qty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toString();

/// Where an exported file goes. The default opens the system share sheet; tests replace it.
abstract class CsvSharer {
  Future<void> share({required String fileName, required String csv});
}

class SystemCsvSharer implements CsvSharer {
  const SystemCsvSharer();
  @override
  Future<void> share({required String fileName, required String csv}) async {
    // a byte-order mark so Excel reads the Filipino and other non-ASCII text correctly
    final bytes = utf8.encode('﻿$csv');
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'text/csv')],
      fileNameOverrides: [fileName],
    ));
  }
}

CsvSharer csvSharer = const SystemCsvSharer();

/// Where plain text (an utang statement) goes: the system share sheet; tests replace it.
abstract class TextSharer {
  Future<void> shareText(String text);
}

class SystemTextSharer implements TextSharer {
  const SystemTextSharer();
  @override
  Future<void> shareText(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }
}

TextSharer textSharer = const SystemTextSharer();
