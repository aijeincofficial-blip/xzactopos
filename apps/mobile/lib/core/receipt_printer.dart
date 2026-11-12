import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/sales_models.dart';
import 'money.dart';

/// Words printed on a receipt (already translated by the caller).
class ReceiptLabels {
  const ReceiptLabels({
    required this.number,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.cashReceived,
    required this.ewallet,
    this.card = 'Card',
    required this.change,
    required this.onUtang,
    required this.cancelled,
    required this.thanks,
    this.storeAddress,
    this.receiptHeader,
    this.receiptFooter,
  });

  /// "Receipt no. {no}" with the number already filled in by [number(no)].
  final String Function(String no) number;
  final String subtotal;
  final String discount;
  final String total;
  final String cashReceived;
  final String ewallet;
  final String card;
  final String change;
  final String onUtang;
  final String cancelled;
  final String thanks;
  final String? storeAddress;
  final String? receiptHeader;
  final String? receiptFooter;
}

/// Where a finished receipt goes besides the screen.
abstract class ReceiptPrinter {
  bool get available;

  /// Opens the system print dialog (any printer the phone knows, or "save as PDF").
  Future<void> print(SaleDetail sale,
      {required String storeName, required String currency, required String locale, required ReceiptLabels labels});

  /// Shares the receipt as a PDF (messages, email, ...).
  Future<void> share(SaleDetail sale,
      {required String storeName, required String currency, required String locale, required ReceiptLabels labels});
}

/// No output (tests; platforms without printing).
class NoPrinter implements ReceiptPrinter {
  const NoPrinter();
  @override
  bool get available => false;
  @override
  Future<void> print(SaleDetail sale,
      {required String storeName, required String currency, required String locale, required ReceiptLabels labels}) async {}
  @override
  Future<void> share(SaleDetail sale,
      {required String storeName, required String currency, required String locale, required ReceiptLabels labels}) async {}
}

/// Replaced in tests.
ReceiptPrinter receiptPrinter = const PdfReceiptPrinter();

/// 58 mm roll PDF through the system print and share sheets (works on Android and in the browser).
/// Direct Bluetooth ESC/POS printing can be added as another [ReceiptPrinter] once a printer model is chosen.
class PdfReceiptPrinter implements ReceiptPrinter {
  const PdfReceiptPrinter();

  @override
  bool get available => true;

  @override
  Future<void> print(SaleDetail sale,
      {required String storeName, required String currency, required String locale, required ReceiptLabels labels}) async {
    final bytes = await buildReceiptPdf(sale, storeName: storeName, currency: currency, locale: locale, labels: labels);
    await Printing.layoutPdf(name: sale.displayNo, format: receiptPageFormat, onLayout: (_) async => bytes);
  }

  @override
  Future<void> share(SaleDetail sale,
      {required String storeName, required String currency, required String locale, required ReceiptLabels labels}) async {
    final bytes = await buildReceiptPdf(sale, storeName: storeName, currency: currency, locale: locale, labels: labels);
    await Printing.sharePdf(bytes: bytes, filename: '${sale.displayNo}.pdf');
  }
}

/// Paper roll 58 mm wide, as long as the receipt needs.
final receiptPageFormat = PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 3 * PdfPageFormat.mm);

/// The receipt as a PDF. The built-in PDF font has no peso sign, so "₱" is printed as "P".
Future<Uint8List> buildReceiptPdf(
  SaleDetail d, {
  required String storeName,
  required String currency,
  required String locale,
  required ReceiptLabels labels,
}) async {
  String money(int a) => Money(a, currency).format(locale).replaceAll('₱', 'P');
  String qty(double q) => q == q.roundToDouble() ? '${q.toInt()}' : '$q';
  final s = d.summary;
  final cash = d.payments.where((p) => p.method == 'cash').fold<int>(0, (a, p) => a + (p.tendered ?? p.amount));
  final ewallet = d.payments.where((p) => p.method == 'ewallet').fold<int>(0, (a, p) => a + p.amount);
  final card = d.payments.where((p) => p.method == 'card').fold<int>(0, (a, p) => a + p.amount);
  final address = labels.storeAddress?.trim();
  final header = labels.receiptHeader?.trim();
  final footer = labels.receiptFooter?.trim();

  pw.Widget row(String l, String r, {bool bold = false, double size = 8}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: pw.Text(l, style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
          pw.Text(r, style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ]),
      );

  final doc = pw.Document();
  doc.addPage(pw.Page(
    pageFormat: receiptPageFormat,
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Text(storeName, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      if (address != null && address.isNotEmpty)
        pw.Text(address, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7.5)),
      if (header != null && header.isNotEmpty) ...[
        pw.SizedBox(height: 1.5),
        pw.Text(header, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7.5)),
      ],
      pw.SizedBox(height: 2),
      pw.Text(labels.number(d.displayNo), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)),
      pw.Text(DateFormat.yMMMd(locale).add_jm().format(s.soldAt), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)),
      if (s.voided)
        pw.Text(labels.cancelled, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      pw.Divider(thickness: 0.5),
      for (final i in d.items) row('${qty(i.qty)} x ${i.name}', money(i.lineTotal)),
      pw.Divider(thickness: 0.5),
      if (d.discount > 0) ...[row(labels.subtotal, money(d.subtotal)), row(labels.discount, '-${money(d.discount)}')],
      row(labels.total, money(s.total), bold: true, size: 10),
      pw.SizedBox(height: 3),
      if (cash > 0) row(labels.cashReceived, money(cash)),
      if (ewallet > 0) row(labels.ewallet, money(ewallet)),
      if (card > 0) row(labels.card, money(card)),
      if (d.change > 0) row(labels.change, money(d.change)),
      if (d.utang > 0) row(labels.onUtang, money(d.utang)),
      pw.SizedBox(height: 6),
      pw.Text(
        footer != null && footer.isNotEmpty ? footer : labels.thanks,
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(fontSize: 8.5),
      ),
    ]),
  ));
  return doc.save();
}
