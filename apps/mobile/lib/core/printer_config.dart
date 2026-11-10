import 'package:shared_preferences/shared_preferences.dart';

import 'esc_pos_printer.dart';
import 'receipt_printer.dart';
import 'shift_printer.dart';
import '../data/sales_models.dart';
import '../data/shift_models.dart';
import '../l10n/app_localizations.dart';

enum PrinterEngineType {
  systemPdf,
  networkEscPos,
}

class PrinterConfig {
  const PrinterConfig({
    this.engine = PrinterEngineType.systemPdf,
    this.ipAddress = '192.168.1.100',
    this.port = 9100,
    this.paperWidth = PaperWidth.mm58,
    this.drawerKick = true,
    this.autoPrint = false,
  });

  final PrinterEngineType engine;
  final String ipAddress;
  final int port;
  final PaperWidth paperWidth;
  final bool drawerKick;
  final bool autoPrint;

  PrinterConfig copyWith({
    PrinterEngineType? engine,
    String? ipAddress,
    int? port,
    PaperWidth? paperWidth,
    bool? drawerKick,
    bool? autoPrint,
  }) =>
      PrinterConfig(
        engine: engine ?? this.engine,
        ipAddress: ipAddress ?? this.ipAddress,
        port: port ?? this.port,
        paperWidth: paperWidth ?? this.paperWidth,
        drawerKick: drawerKick ?? this.drawerKick,
        autoPrint: autoPrint ?? this.autoPrint,
      );

  static const _keyEngine = 'printer_engine';
  static const _keyIp = 'printer_ip';
  static const _keyPort = 'printer_port';
  static const _keyWidth = 'printer_paper_width';
  static const _keyDrawer = 'printer_drawer_kick';
  static const _keyAutoPrint = 'printer_auto_print';

  static Future<PrinterConfig> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final engineStr = p.getString(_keyEngine) ?? 'systemPdf';
      final engine = engineStr == 'networkEscPos' ? PrinterEngineType.networkEscPos : PrinterEngineType.systemPdf;
      final ip = p.getString(_keyIp) ?? '192.168.1.100';
      final port = p.getInt(_keyPort) ?? 9100;
      final widthStr = p.getString(_keyWidth) ?? 'mm58';
      final paperWidth = widthStr == 'mm80' ? PaperWidth.mm80 : PaperWidth.mm58;
      final drawer = p.getBool(_keyDrawer) ?? true;
      final auto = p.getBool(_keyAutoPrint) ?? false;
      return PrinterConfig(
        engine: engine,
        ipAddress: ip,
        port: port,
        paperWidth: paperWidth,
        drawerKick: drawer,
        autoPrint: auto,
      );
    } catch (_) {
      return const PrinterConfig();
    }
  }

  Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_keyEngine, engine == PrinterEngineType.networkEscPos ? 'networkEscPos' : 'systemPdf');
      await p.setString(_keyIp, ipAddress);
      await p.setInt(_keyPort, port);
      await p.setString(_keyWidth, paperWidth == PaperWidth.mm80 ? 'mm80' : 'mm58');
      await p.setBool(_keyDrawer, drawerKick);
      await p.setBool(_keyAutoPrint, autoPrint);
    } catch (_) {}
  }
}

/// Active config holder.
PrinterConfig activePrinterConfig = const PrinterConfig();

/// EscPos implementation of [ReceiptPrinter].
class EscPosReceiptPrinter implements ReceiptPrinter {
  const EscPosReceiptPrinter(this.config, {this.transport});

  final PrinterConfig config;
  final EscPosTransport? transport;

  @override
  bool get available => true;

  EscPosTransport _resolveTransport() =>
      transport ?? NetworkEscPosTransport(host: config.ipAddress, port: config.port);

  @override
  Future<void> print(
    SaleDetail sale, {
    required String storeName,
    required String currency,
    required String locale,
    required ReceiptLabels labels,
  }) async {
    final t = _resolveTransport();
    final bytes = encodeReceipt(
      sale,
      storeName: storeName,
      currency: currency,
      locale: locale,
      labels: labels,
      paperWidth: config.paperWidth,
      openCashDrawer: config.drawerKick,
    );
    await t.send(bytes);
  }

  @override
  Future<void> share(
    SaleDetail sale, {
    required String storeName,
    required String currency,
    required String locale,
    required ReceiptLabels labels,
  }) async {
    // Sharing always generates PDF
    await const PdfReceiptPrinter().share(
      sale,
      storeName: storeName,
      currency: currency,
      locale: locale,
      labels: labels,
    );
  }
}

/// EscPos implementation of [ShiftPrinter].
class EscPosShiftPrinter implements ShiftPrinter {
  const EscPosShiftPrinter(this.config, {this.transport});

  final PrinterConfig config;
  final EscPosTransport? transport;

  @override
  bool get available => true;

  EscPosTransport _resolveTransport() =>
      transport ?? NetworkEscPosTransport(host: config.ipAddress, port: config.port);

  @override
  Future<void> printShift({
    required String storeName,
    required String currency,
    required String locale,
    required ShiftView shift,
    XReading? xReading,
    required AppLocalizations t,
  }) async {
    final trans = _resolveTransport();
    final title = shift.isOpen ? t.shiftTitle : t.shiftZTitle;
    final cashier = shift.cashierId != null && shift.cashierId!.isNotEmpty
        ? shift.cashierId!.substring(0, 8)
        : '';
    final bytes = encodeShiftSlip(
      storeName: storeName,
      shiftTitle: title,
      cashier: cashier,
      openedAt: shift.openedAt,
      closedAt: shift.closedAt,
      openingCash: shift.openingCash,
      expectedCash: xReading?.expected ?? shift.expectedCash,
      countedCash: shift.countedCash,
      difference: shift.difference,
      serverExpectedCash: shift.serverExpectedCash,
      note: shift.note,
      closedBy: shift.closedBy,
      currency: currency,
      locale: locale,
      paperWidth: config.paperWidth,
      openCashDrawer: false,
    );
    await trans.send(bytes);
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
    // Sharing always generates PDF
    await const PdfShiftPrinter().shareShiftPdf(
      storeName: storeName,
      currency: currency,
      locale: locale,
      shift: shift,
      xReading: xReading,
      t: t,
    );
  }
}

/// Applies [PrinterConfig] by wiring the active [receiptPrinter] and [shiftPrinter] globals.
void applyPrinterConfig(PrinterConfig config, {EscPosTransport? customTransport}) {
  activePrinterConfig = config;
  if (config.engine == PrinterEngineType.networkEscPos) {
    receiptPrinter = EscPosReceiptPrinter(config, transport: customTransport);
    shiftPrinter = EscPosShiftPrinter(config, transport: customTransport);
  } else {
    receiptPrinter = const PdfReceiptPrinter();
    shiftPrinter = const PdfShiftPrinter();
  }
}

/// Sends a test thermal slip and kicks drawer if configured.
Future<void> printTestSlip({
  required PrinterConfig config,
  required String storeName,
  EscPosTransport? transport,
}) async {
  final encoder = EscPosEncoder(paperWidth: config.paperWidth);
  encoder.init();
  encoder.setAlignCenter();
  encoder.setTextSize(doubleHeight: true, doubleWidth: true);
  encoder.setBold(true);
  encoder.line(storeName);
  encoder.setTextSize();
  encoder.setBold(false);
  encoder.line('ESC/POS Thermal Printer');
  encoder.divider();
  encoder.setBold(true);
  encoder.line('TEST PRINT OK');
  encoder.setBold(false);
  encoder.line(DateTime.now().toLocal().toString().split('.').first);
  encoder.divider();
  encoder.setAlignLeft();
  encoder.line('IP: ${config.ipAddress}:${config.port}');
  encoder.line('Roll: ${config.paperWidth == PaperWidth.mm80 ? "80mm" : "58mm"}');
  encoder.line('Drawer: ${config.drawerKick ? "Enabled" : "Disabled"}');
  encoder.feed(3);
  if (config.drawerKick) {
    encoder.drawerKick();
  }
  encoder.cut();
  final t = transport ?? NetworkEscPosTransport(host: config.ipAddress, port: config.port);
  await t.send(encoder.toBytes());
}
