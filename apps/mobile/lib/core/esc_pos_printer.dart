import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/sales_models.dart';
import 'money.dart';
import 'receipt_printer.dart';

/// Standard paper roll width in columns.
enum PaperWidth {
  mm58(32),
  mm80(48);

  const PaperWidth(this.columns);
  final int columns;
}

/// Standard ESC/POS binary control command bytes.
class EscPosCommands {
  static const init = [0x1b, 0x40]; // ESC @
  static const alignLeft = [0x1b, 0x61, 0x00]; // ESC a 0
  static const alignCenter = [0x1b, 0x61, 0x01]; // ESC a 1
  static const alignRight = [0x1b, 0x61, 0x02]; // ESC a 2
  static const boldOn = [0x1b, 0x45, 0x01]; // ESC E 1
  static const boldOff = [0x1b, 0x45, 0x00]; // ESC E 0
  static const underlineOn = [0x1b, 0x2d, 0x01]; // ESC - 1
  static const underlineOff = [0x1b, 0x2d, 0x00]; // ESC - 0
  static const textNormal = [0x1d, 0x21, 0x00]; // GS ! 0
  static const textDoubleHeight = [0x1d, 0x21, 0x01]; // GS ! 1
  static const textDoubleWidth = [0x1d, 0x21, 0x10]; // GS ! 16
  static const textDoubleSize = [0x1d, 0x21, 0x11]; // GS ! 17
  static const cutPartial = [0x1d, 0x56, 0x01]; // GS V 1
  static const cutFull = [0x1d, 0x56, 0x00]; // GS V 0
  static const feedAndCut = [0x1d, 0x56, 0x42, 0x03]; // GS V 66 3
  static const drawerKickPin2 = [0x1b, 0x70, 0x00, 0x19, 0xfa]; // ESC p 0 25 250
  static const drawerKickPin5 = [0x1b, 0x70, 0x01, 0x19, 0xfa]; // ESC p 1 25 250
  static const lineFeed = [0x0a];
}

/// Byte builder and line formatter for ESC/POS thermal printers.
class EscPosEncoder {
  EscPosEncoder({this.paperWidth = PaperWidth.mm58});

  final PaperWidth paperWidth;
  final BytesBuilder _buffer = BytesBuilder();

  int get columns => paperWidth.columns;

  void raw(List<int> bytes) => _buffer.add(bytes);

  static List<int> _sanitize(String s) {
    final normalized = s
        .replaceAll('\u202F', ' ')
        .replaceAll('\u00A0', ' ')
        .replaceAll('₱', 'P');
    final units = normalized.codeUnits.map((c) => c <= 255 ? c : 0x3f).toList();
    return Uint8List.fromList(units);
  }

  void text(String text) {
    _buffer.add(_sanitize(text));
  }

  void line([String text = '']) {
    if (text.isNotEmpty) _buffer.add(_sanitize(text));
    _buffer.add(EscPosCommands.lineFeed);
  }

  void init() => raw(EscPosCommands.init);
  void feed([int lines = 1]) {
    for (var i = 0; i < lines; i++) {
      raw(EscPosCommands.lineFeed);
    }
  }

  void cut() => raw(EscPosCommands.feedAndCut);
  void drawerKick() => raw(EscPosCommands.drawerKickPin2);

  void setAlignLeft() => raw(EscPosCommands.alignLeft);
  void setAlignCenter() => raw(EscPosCommands.alignCenter);
  void setAlignRight() => raw(EscPosCommands.alignRight);

  void setBold(bool enable) => raw(enable ? EscPosCommands.boldOn : EscPosCommands.boldOff);

  void setTextSize({bool doubleHeight = false, bool doubleWidth = false}) {
    if (doubleHeight && doubleWidth) {
      raw(EscPosCommands.textDoubleSize);
    } else if (doubleHeight) {
      raw(EscPosCommands.textDoubleHeight);
    } else if (doubleWidth) {
      raw(EscPosCommands.textDoubleWidth);
    } else {
      raw(EscPosCommands.textNormal);
    }
  }

  void divider([String char = '-']) {
    line(char * columns);
  }

  void column2(String left, String right) {
    final available = columns - right.length;
    if (available <= 0) {
      line('$left $right');
      return;
    }
    final truncatedLeft = left.length > available - 1 ? left.substring(0, available - 1) : left;
    final spaces = columns - truncatedLeft.length - right.length;
    line('$truncatedLeft${' ' * (spaces > 0 ? spaces : 1)}$right');
  }

  Uint8List toBytes() => _buffer.toBytes();
}

/// Formats a money amount using ASCII representation (P instead of ₱ for thermal codepage compatibility).
String _escPosFmt(int minor, String currency, String locale) {
  return Money(minor, currency).format(locale).replaceAll('₱', 'P');
}

String _escPosQty(double q) => q == q.roundToDouble() ? '${q.toInt()}' : '$q';

/// Encodes a sale receipt into ESC/POS binary stream for thermal roll printing.
Uint8List encodeReceipt(
  SaleDetail sale, {
  required String storeName,
  required String currency,
  required String locale,
  required ReceiptLabels labels,
  PaperWidth paperWidth = PaperWidth.mm58,
  bool openCashDrawer = false,
}) {
  final enc = EscPosEncoder(paperWidth: paperWidth);
  enc.init();

  if (openCashDrawer) {
    enc.drawerKick();
  }

  // Header
  enc.setAlignCenter();
  enc.setTextSize(doubleHeight: true, doubleWidth: true);
  enc.setBold(true);
  enc.line(storeName);
  enc.setTextSize();
  enc.setBold(false);

  final address = labels.storeAddress?.trim();
  if (address != null && address.isNotEmpty) {
    for (final ln in address.split(RegExp(r'\r?\n'))) {
      if (ln.trim().isNotEmpty) enc.line(ln.trim());
    }
  }
  final header = labels.receiptHeader?.trim();
  if (header != null && header.isNotEmpty) {
    for (final ln in header.split(RegExp(r'\r?\n'))) {
      if (ln.trim().isNotEmpty) enc.line(ln.trim());
    }
  }

  enc.line(labels.number(sale.displayNo));
  enc.line(DateFormat.yMMMd(locale).add_jm().format(sale.summary.soldAt));
  if (sale.summary.voided) {
    enc.setBold(true);
    enc.line('*** ${labels.cancelled.toUpperCase()} ***');
    enc.setBold(false);
  }
  enc.line();

  // Line items
  enc.setAlignLeft();
  enc.divider();
  for (final it in sale.items) {
    final qtyUnit = '${_escPosQty(it.qty)} x ${it.name}';
    final lineTot = _escPosFmt(it.lineTotal, currency, locale);
    enc.column2(qtyUnit, lineTot);
  }
  enc.divider();

  // Totals
  if (sale.discount > 0) {
    enc.column2(labels.subtotal, _escPosFmt(sale.subtotal, currency, locale));
    enc.column2(labels.discount, '-${_escPosFmt(sale.discount, currency, locale)}');
  }

  enc.setBold(true);
  enc.setTextSize(doubleHeight: true);
  enc.column2(labels.total, _escPosFmt(sale.summary.total, currency, locale));
  enc.setTextSize();
  enc.setBold(false);
  enc.divider();

  // Tenders
  final cash = sale.payments.where((p) => p.method == 'cash').fold<int>(0, (a, p) => a + (p.tendered ?? p.amount));
  final ewallet = sale.payments.where((p) => p.method == 'ewallet').fold<int>(0, (a, p) => a + p.amount);
  final card = sale.payments.where((p) => p.method == 'card').fold<int>(0, (a, p) => a + p.amount);

  if (cash > 0) {
    enc.column2(labels.cashReceived, _escPosFmt(cash, currency, locale));
    if (sale.change > 0) {
      enc.column2(labels.change, _escPosFmt(sale.change, currency, locale));
    }
  }
  if (ewallet > 0) {
    enc.column2(labels.ewallet, _escPosFmt(ewallet, currency, locale));
  }
  if (card > 0) {
    enc.column2(labels.card, _escPosFmt(card, currency, locale));
  }
  if (sale.utang > 0) {
    enc.column2(labels.onUtang, _escPosFmt(sale.utang, currency, locale));
  }

  enc.divider();
  enc.setAlignCenter();
  final footer = labels.receiptFooter?.trim();
  if (footer != null && footer.isNotEmpty) {
    for (final ln in footer.split(RegExp(r'\r?\n'))) {
      if (ln.trim().isNotEmpty) enc.line(ln.trim());
    }
  } else {
    enc.line(labels.thanks);
  }
  enc.feed(3);
  enc.cut();

  return enc.toBytes();
}

/// Encodes an X-Reading or Z-Reading shift slip into ESC/POS binary stream.
Uint8List encodeShiftSlip({
  required String storeName,
  required String shiftTitle,
  required String cashier,
  required DateTime openedAt,
  DateTime? closedAt,
  required int openingCash,
  int? expectedCash,
  int? countedCash,
  int? difference,
  int? serverExpectedCash,
  String? note,
  String? closedBy,
  required String currency,
  required String locale,
  PaperWidth paperWidth = PaperWidth.mm58,
  bool openCashDrawer = false,
}) {
  final enc = EscPosEncoder(paperWidth: paperWidth);
  enc.init();

  if (openCashDrawer) {
    enc.drawerKick();
  }

  // Header
  enc.setAlignCenter();
  enc.setTextSize(doubleHeight: true, doubleWidth: true);
  enc.setBold(true);
  enc.line(storeName);
  enc.setTextSize();
  enc.setBold(false);

  enc.setBold(true);
  enc.line('*** $shiftTitle ***');
  enc.setBold(false);

  enc.line('Cashier: $cashier');
  enc.line('Opened: ${DateFormat.yMMMd(locale).add_jm().format(openedAt)}');
  if (closedAt != null) {
    enc.line('Closed: ${DateFormat.yMMMd(locale).add_jm().format(closedAt)}');
  }
  if (closedBy != null) {
    enc.line('Closed by: $closedBy');
  }

  enc.divider();
  enc.setAlignLeft();
  enc.column2('Opening cash', _escPosFmt(openingCash, currency, locale));

  if (expectedCash != null) {
    enc.column2('Expected cash', _escPosFmt(expectedCash, currency, locale));
  }
  if (serverExpectedCash != null) {
    enc.column2('Server expected', _escPosFmt(serverExpectedCash, currency, locale));
  }
  if (countedCash != null) {
    enc.setBold(true);
    enc.column2('Counted cash', _escPosFmt(countedCash, currency, locale));
    enc.setBold(false);
  }
  if (difference != null) {
    final diffSign = difference >= 0 ? '+' : '';
    final diffLabel = difference >= 0 ? 'Over' : 'Short';
    enc.setBold(true);
    enc.column2(diffLabel, '$diffSign${_escPosFmt(difference, currency, locale)}');
    enc.setBold(false);
  }

  if (serverExpectedCash != null && expectedCash != null && serverExpectedCash != expectedCash) {
    enc.divider();
    enc.setAlignCenter();
    enc.line('! WARNING !');
    enc.line('Server expected mismatch');
    enc.setAlignLeft();
  }

  if (note != null && note.isNotEmpty) {
    enc.divider();
    enc.line('Note: $note');
  }

  enc.divider();
  enc.feed(3);
  enc.cut();

  return enc.toBytes();
}

/// Abstract transport for sending ESC/POS bytes to printers (Bluetooth, Network, USB).
abstract class EscPosTransport {
  Future<void> send(Uint8List bytes);
}

/// Fake in-memory transport for unit testing.
class FakeEscPosTransport implements EscPosTransport {
  final List<Uint8List> packets = [];

  @override
  Future<void> send(Uint8List bytes) async {
    packets.add(bytes);
  }
}

/// Direct network socket transport for ESC/POS LAN/WiFi thermal printers on port 9100.
class NetworkEscPosTransport implements EscPosTransport {
  NetworkEscPosTransport({
    required this.host,
    this.port = 9100,
    this.timeout = const Duration(seconds: 5),
  });

  final String host;
  final int port;
  final Duration timeout;

  @override
  Future<void> send(Uint8List bytes) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    try {
      socket.add(bytes);
      await socket.flush();
    } finally {
      await socket.close();
    }
  }
}

/// Paired classic Bluetooth (SPP / RFCOMM) thermal printer descriptor.
class BluetoothPrinterDevice {
  const BluetoothPrinterDevice({
    required this.name,
    required this.address,
  });

  final String name;
  final String address;
}

/// Platform adapter for enumerating bonded Bluetooth printers and writing RFCOMM bytes.
abstract class BluetoothEscPosAdapter {
  Future<List<BluetoothPrinterDevice>> getBondedDevices();
  Future<void> sendBytes(String address, Uint8List bytes);
}

/// Production Android RFCOMM SPP adapter backed by MainActivity MethodChannel.
class MethodChannelBluetoothAdapter implements BluetoothEscPosAdapter {
  const MethodChannelBluetoothAdapter();

  static const MethodChannel _channel =
      MethodChannel('com.xzactopos.mobile/bluetooth_printer');

  @override
  Future<List<BluetoothPrinterDevice>> getBondedDevices() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('getBondedDevices');
    if (raw == null) return const [];
    return raw.map((entry) {
      final map = Map<String, dynamic>.from(entry as Map);
      return BluetoothPrinterDevice(
        name: (map['name'] as String?)?.trim().isNotEmpty == true
            ? (map['name'] as String).trim()
            : 'Bluetooth Printer',
        address: (map['address'] as String? ?? '').trim(),
      );
    }).where((d) => d.address.isNotEmpty).toList();
  }

  @override
  Future<void> sendBytes(String address, Uint8List bytes) async {
    await _channel.invokeMethod<void>('sendBytes', <String, dynamic>{
      'address': address.trim(),
      'bytes': bytes,
    });
  }
}

/// Deterministic in-memory Bluetooth adapter for unit and widget tests.
class FakeBluetoothEscPosAdapter implements BluetoothEscPosAdapter {
  FakeBluetoothEscPosAdapter({List<BluetoothPrinterDevice>? devices})
      : devices = devices ?? const [];

  final List<BluetoothPrinterDevice> devices;
  final Map<String, List<Uint8List>> sentByAddress = {};

  @override
  Future<List<BluetoothPrinterDevice>> getBondedDevices() async => devices;

  @override
  Future<void> sendBytes(String address, Uint8List bytes) async {
    sentByAddress.putIfAbsent(address, () => []).add(bytes);
  }
}

/// Swappable global Bluetooth adapter (overridable in tests).
BluetoothEscPosAdapter activeBluetoothAdapter = const MethodChannelBluetoothAdapter();

/// Classic Bluetooth SPP transport for router-less market stalls & sari-sari stores.
class BluetoothEscPosTransport implements EscPosTransport {
  BluetoothEscPosTransport({
    required this.address,
    this.adapter,
  });

  final String address;
  final BluetoothEscPosAdapter? adapter;

  @override
  Future<void> send(Uint8List bytes) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) {
      throw StateError('Bluetooth printer MAC address is not configured.');
    }
    final resolved = adapter ?? activeBluetoothAdapter;
    await resolved.sendBytes(trimmed, bytes);
  }
}
