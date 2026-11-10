import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/shift_models.dart';
import '../l10n/app_localizations.dart';
import 'money.dart';
import 'receipt_printer.dart';

/// Where a shift slip goes besides the screen.
abstract class ShiftPrinter {
  bool get available;

  /// Opens the system print dialog (thermal printer or "save as PDF").
  Future<void> printShift({
    required String storeName,
    required String currency,
    required String locale,
    required ShiftView shift,
    XReading? xReading,
    required AppLocalizations t,
  });

  /// Shares the shift report as a PDF file.
  Future<void> shareShiftPdf({
    required String storeName,
    required String currency,
    required String locale,
    required ShiftView shift,
    XReading? xReading,
    required AppLocalizations t,
  });
}

/// No output (tests; platforms without printing).
class NoShiftPrinter implements ShiftPrinter {
  const NoShiftPrinter();

  @override
  bool get available => false;

  @override
  Future<void> printShift({
    required String storeName,
    required String currency,
    required String locale,
    required ShiftView shift,
    XReading? xReading,
    required AppLocalizations t,
  }) async {}

  @override
  Future<void> shareShiftPdf({
    required String storeName,
    required String currency,
    required String locale,
    required ShiftView shift,
    XReading? xReading,
    required AppLocalizations t,
  }) async {}
}

/// Replaced in tests.
ShiftPrinter shiftPrinter = const PdfShiftPrinter();

/// 58 mm roll PDF for X and Z shift reports.
class PdfShiftPrinter implements ShiftPrinter {
  const PdfShiftPrinter();

  @override
  bool get available => true;

  @override
  Future<void> printShift({
    required String storeName,
    required String currency,
    required String locale,
    required ShiftView shift,
    XReading? xReading,
    required AppLocalizations t,
  }) async {
    final bytes = await buildShiftPdf(
      shift: shift,
      xReading: xReading,
      storeName: storeName,
      currency: currency,
      locale: locale,
      t: t,
    );
    final title = shift.isOpen ? 'X-Report' : 'Z-Report';
    await Printing.layoutPdf(
      name: '$title-${shift.id.substring(0, 8)}',
      format: receiptPageFormat,
      onLayout: (_) async => bytes,
    );
  }

  @override
  Future<void> shareShiftPdf({
    required String storeName,
    required String currency,
    required String locale,
    required ShiftView shift,
    XReading? xReading,
    required AppLocalizations t,
  }) async {
    final bytes = await buildShiftPdf(
      shift: shift,
      xReading: xReading,
      storeName: storeName,
      currency: currency,
      locale: locale,
      t: t,
    );
    final prefix = shift.isOpen ? 'x_reading' : 'z_reading';
    final filename = '${prefix}_${shift.id.substring(0, 8)}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}

/// Builds a 58mm thermal-roll PDF slip for an X-reading or Z-reading shift report.
Future<Uint8List> buildShiftPdf({
  required ShiftView shift,
  XReading? xReading,
  required String storeName,
  required String currency,
  required String locale,
  required AppLocalizations t,
}) async {
  String money(int a) => Money(a, currency).format(locale).replaceAll('₱', 'P');
  String when(DateTime d) => DateFormat.yMMMd(locale).add_jm().format(d);

  pw.Widget row(String l, String r, {bool bold = false, double size = 8}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                l,
                style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
              ),
            ),
            pw.Text(
              r,
              style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
            ),
          ],
        ),
      );

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: receiptPageFormat,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            storeName,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            shift.isOpen ? t.shiftTitle : t.shiftZTitle,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            t.shiftOpenedLine(when(shift.openedAt)),
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 8),
          ),
          if (shift.closedAt != null)
            pw.Text(
              t.shiftClosedLine(when(shift.closedAt!)),
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8),
            ),
          if (shift.cashierId != null && shift.cashierId!.isNotEmpty)
            pw.Text(
              t.shiftCashierLabel(shift.cashierId!.substring(0, 8)),
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8),
            ),
          pw.Divider(thickness: 0.5),
          row(t.shiftOpeningLabel, money(shift.openingCash)),
          if (xReading != null) ...[
            row(t.shiftCashSales, money(xReading.cashSales)),
            if (xReading.utangCash > 0) row(t.shiftUtangTaken, money(xReading.utangCash)),
            if (xReading.expensesCash > 0) row(t.shiftPaidOut, '-${money(xReading.expensesCash)}'),
            if (xReading.serviceCash > 0) row(t.shiftLoadCash, money(xReading.serviceCash)),
          ],
          pw.Divider(thickness: 0.5),
          if (shift.isOpen) ...[
            if (xReading != null) row(t.dayCloseExpected, money(xReading.expected), bold: true, size: 9),
          ] else ...[
            row(t.dayCloseExpected, money(shift.expectedCash ?? 0)),
            row(t.dayCloseCounted, money(shift.countedCash ?? 0), bold: true, size: 9),
            pw.SizedBox(height: 2),
            () {
              final d = shift.difference ?? 0;
              final diffLabel = d == 0
                  ? t.dayCloseExact
                  : (d < 0 ? t.dayCloseShort(money(-d)) : t.dayCloseOver(money(d)));
              return pw.Text(
                diffLabel,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              );
            }(),
          ],
          if (xReading != null) ...[
            pw.Divider(thickness: 0.5),
            pw.Text(
              t.shiftSalesLine(xReading.salesCount, money(xReading.grossSales)),
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              t.shiftOtherTenders(money(xReading.ewalletSales), money(xReading.utangSales)),
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
          if (shift.note != null && shift.note!.isNotEmpty) ...[
            pw.Divider(thickness: 0.5),
            pw.Text(shift.note!, style: const pw.TextStyle(fontSize: 8)),
          ],
          if (shift.serverDisagrees) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              t.shiftServerDiffers(money(shift.serverExpectedCash!)),
              style: const pw.TextStyle(fontSize: 7),
            ),
          ],
          pw.SizedBox(height: 6),
          pw.Text(
            DateFormat.yMMMd(locale).add_jms().format(DateTime.now()),
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}
