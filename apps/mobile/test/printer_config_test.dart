import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzactopos_mobile/core/esc_pos_printer.dart';
import 'package:xzactopos_mobile/core/printer_config.dart';
import 'package:xzactopos_mobile/core/receipt_printer.dart';
import 'package:xzactopos_mobile/core/shift_printer.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('PrinterConfig loads default settings when empty', () async {
    final cfg = await PrinterConfig.load();
    expect(cfg.engine, PrinterEngineType.systemPdf);
    expect(cfg.ipAddress, '192.168.1.100');
    expect(cfg.port, 9100);
    expect(cfg.paperWidth, PaperWidth.mm58);
    expect(cfg.drawerKick, true);
    expect(cfg.autoPrint, false);
  });

  test('PrinterConfig saves and reloads customized settings', () async {
    const custom = PrinterConfig(
      engine: PrinterEngineType.networkEscPos,
      ipAddress: '10.0.0.55',
      port: 9200,
      paperWidth: PaperWidth.mm80,
      drawerKick: false,
      autoPrint: true,
    );
    await custom.save();

    final reloaded = await PrinterConfig.load();
    expect(reloaded.engine, PrinterEngineType.networkEscPos);
    expect(reloaded.ipAddress, '10.0.0.55');
    expect(reloaded.port, 9200);
    expect(reloaded.paperWidth, PaperWidth.mm80);
    expect(reloaded.drawerKick, false);
    expect(reloaded.autoPrint, true);
  });

  test('applyPrinterConfig sets global receiptPrinter and shiftPrinter', () async {
    final fakeTransport = FakeEscPosTransport();
    const config = PrinterConfig(
      engine: PrinterEngineType.networkEscPos,
      ipAddress: '192.168.1.200',
      paperWidth: PaperWidth.mm58,
    );

    applyPrinterConfig(config, customTransport: fakeTransport);

    expect(receiptPrinter, isA<EscPosReceiptPrinter>());
    expect(shiftPrinter, isA<EscPosShiftPrinter>());

    // Test print through receiptPrinter
    final sale = SaleDetail(
      summary: SaleSummary(
        id: 's-1',
        localNo: 'L-001',
        saleNo: 'S-001',
        soldAt: DateTime.utc(2026, 11, 10, 10, 30),
        total: 10000,
        status: 'completed',
        pending: false,
      ),
      subtotal: 10000,
      discount: 0,
      tax: 0,
      items: const [
        SaleItemView('Item A', 1.0, 10000, 10000),
      ],
      payments: const [
        SalePaymentView('cash', 10000, 10000, null),
      ],
    );

    await receiptPrinter.print(
      sale,
      storeName: 'Sari-Sari Store',
      currency: 'PHP',
      locale: 'en',
      labels: ReceiptLabels(
        number: (n) => 'No. $n',
        subtotal: 'Subtotal',
        discount: 'Discount',
        total: 'TOTAL',
        cashReceived: 'Cash',
        ewallet: 'E-Wallet',
        change: 'Change',
        onUtang: 'Utang',
        cancelled: 'VOIDED',
        thanks: 'Salamat po!',
      ),
    );

    expect(fakeTransport.packets.length, 1);
    expect(fakeTransport.packets.first.isNotEmpty, true);

    // Switch back to system
    applyPrinterConfig(const PrinterConfig(engine: PrinterEngineType.systemPdf));
    expect(receiptPrinter, isA<PdfReceiptPrinter>());
    expect(shiftPrinter, isA<PdfShiftPrinter>());
  });

  test('printTestSlip generates valid ESC/POS byte sequence', () async {
    final fakeTransport = FakeEscPosTransport();
    const config = PrinterConfig(
      engine: PrinterEngineType.networkEscPos,
      ipAddress: '192.168.1.150',
      port: 9100,
      paperWidth: PaperWidth.mm80,
      drawerKick: true,
    );

    await printTestSlip(
      config: config,
      storeName: 'Downtown Store',
      transport: fakeTransport,
    );

    expect(fakeTransport.packets.length, 1);
    final bytes = fakeTransport.packets.first;
    expect(bytes.isNotEmpty, true);
    // Should include drawer kick and cut commands
    expect(bytes, containsAllInOrder(EscPosCommands.drawerKickPin2));
    expect(bytes, containsAllInOrder(EscPosCommands.feedAndCut));
  });
}
