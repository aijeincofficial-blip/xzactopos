import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:xzactopos_mobile/core/esc_pos_printer.dart';
import 'package:xzactopos_mobile/core/receipt_printer.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';

void main() {
  setUpAll(() => initializeDateFormatting());
  group('EscPosEncoder', () {
    test('initializes and formats basic columns and dividers', () {
      final enc = EscPosEncoder(paperWidth: PaperWidth.mm58);
      enc.init();
      enc.divider();
      enc.column2('Item', 'P100.00');

      final bytes = enc.toBytes();
      expect(bytes, isNotEmpty);
      expect(bytes.sublist(0, 2), EscPosCommands.init);

      final text = latin1.decode(bytes);
      expect(text, contains('--------------------------------'));
      expect(text, contains('Item'));
      expect(text, contains('P100.00'));
    });

    test('supports 80mm roll width (48 columns)', () {
      final enc = EscPosEncoder(paperWidth: PaperWidth.mm80);
      enc.divider('=');
      final text = latin1.decode(enc.toBytes());
      expect(text, contains('=' * 48));
    });

    test('applies text styling commands (bold, size, alignment)', () {
      final enc = EscPosEncoder();
      enc.setAlignCenter();
      enc.setBold(true);
      enc.setTextSize(doubleHeight: true, doubleWidth: true);
      enc.line('HEADER');
      enc.setTextSize();
      enc.setBold(false);
      enc.setAlignLeft();
      enc.drawerKick();
      enc.cut();

      final bytes = enc.toBytes();
      expect(bytes, containsAllInOrder(EscPosCommands.alignCenter));
      expect(bytes, containsAllInOrder(EscPosCommands.boldOn));
      expect(bytes, containsAllInOrder(EscPosCommands.textDoubleSize));
      expect(bytes, containsAllInOrder(EscPosCommands.drawerKickPin2));
      expect(bytes, containsAllInOrder(EscPosCommands.feedAndCut));
    });
  });

  group('encodeReceipt', () {
    final sale = SaleDetail(
      summary: SaleSummary(
        id: 'sale-001',
        localNo: 'D1-0001',
        saleNo: 'S01-20261110-0001',
        status: 'completed',
        pending: false,
        soldAt: DateTime(2026, 11, 10, 10, 30),
        total: 15000, // P150.00
      ),
      subtotal: 16000,
      discount: 1000,
      tax: 0,
      items: const [
        SaleItemView('Rice 1kg', 2, 5000, 10000),
        SaleItemView('Instant Noodles', 3, 2000, 6000),
      ],
      payments: const [
        SalePaymentView('cash', 15000, 20000, null),
        SalePaymentView('card', 0, 0, 'AUTH-999'),
      ],
    );

    final labels = ReceiptLabels(
      number: (no) => 'Receipt: $no',
      subtotal: 'Subtotal',
      discount: 'Discount',
      total: 'TOTAL',
      cashReceived: 'Cash Received',
      ewallet: 'E-Wallet',
      change: 'Change',
      onUtang: 'Utang',
      cancelled: 'Cancelled',
      thanks: 'Maraming Salamat!',
    );

    test('generates valid ESC/POS receipt stream with drawer kick and cut', () {
      final bytes = encodeReceipt(
        sale,
        storeName: 'Sari-Sari Store Central',
        currency: 'PHP',
        locale: 'en',
        labels: labels,
        openCashDrawer: true,
      );

      expect(bytes, isNotEmpty);
      expect(bytes, containsAllInOrder(EscPosCommands.drawerKickPin2));
      expect(bytes, containsAllInOrder(EscPosCommands.feedAndCut));

      final text = latin1.decode(bytes);
      expect(text, contains('Sari-Sari Store Central'));
      expect(text, contains('S01-20261110-0001'));
      expect(text, contains('Rice 1kg'));
      expect(text, contains('Instant Noodles'));
      expect(text, contains('TOTAL'));
      expect(text, contains('Maraming Salamat!'));
    });

    test('prints store address, custom receipt header, and custom receipt footer lines', () {
      final brandedLabels = ReceiptLabels(
        number: (no) => 'Receipt: $no',
        subtotal: 'Subtotal',
        discount: 'Discount',
        total: 'TOTAL',
        cashReceived: 'Cash Received',
        ewallet: 'E-Wallet',
        change: 'Change',
        onUtang: 'Utang',
        cancelled: 'Cancelled',
        thanks: 'Default Thanks',
        storeAddress: '123 Rizal St, Poblacion',
        receiptHeader: 'TIN 123-456-789\nVAT REG',
        receiptFooter: 'Salamat suki!\nKeep receipt for exchange.',
      );

      final bytes = encodeReceipt(
        sale,
        storeName: 'Nena Main Store',
        currency: 'PHP',
        locale: 'en',
        labels: brandedLabels,
      );

      final text = latin1.decode(bytes);
      expect(text, contains('Nena Main Store'));
      expect(text, contains('123 Rizal St, Poblacion'));
      expect(text, contains('TIN 123-456-789'));
      expect(text, contains('VAT REG'));
      expect(text, contains('Salamat suki!'));
      expect(text, contains('Keep receipt for exchange.'));
      expect(text, isNot(contains('Default Thanks')));
    });
  });

  group('encodeShiftSlip', () {
    test('encodes X-reading shift slip', () {
      final bytes = encodeShiftSlip(
        storeName: 'Xzacto Store',
        shiftTitle: 'X-READING (INTERIM)',
        cashier: 'Juan Dela Cruz',
        openedAt: DateTime(2026, 11, 10, 8, 0),
        openingCash: 50000, // P500.00
        expectedCash: 125000, // P1250.00
        serverExpectedCash: 125000,
        currency: 'PHP',
        locale: 'en',
      );

      final text = latin1.decode(bytes);
      expect(text, contains('Xzacto Store'));
      expect(text, contains('X-READING (INTERIM)'));
      expect(text, contains('Juan Dela Cruz'));
      expect(text, contains('Opening cash'));
      expect(text, contains('Expected cash'));
      expect(bytes, containsAllInOrder(EscPosCommands.feedAndCut));
    });

    test('encodes Z-reading shift slip with variance, note and warning', () {
      final bytes = encodeShiftSlip(
        storeName: 'Xzacto Store',
        shiftTitle: 'Z-READING (FINAL)',
        cashier: 'Juan Dela Cruz',
        openedAt: DateTime(2026, 11, 10, 8, 0),
        closedAt: DateTime(2026, 11, 10, 16, 0),
        closedBy: 'Supervisor Maria',
        openingCash: 50000,
        expectedCash: 125000,
        countedCash: 120000,
        difference: -5000, // Short P50.00
        serverExpectedCash: 126000, // Mismatch
        note: 'Shortage noted by supervisor',
        currency: 'PHP',
        locale: 'en',
      );

      final text = latin1.decode(bytes);
      expect(text, contains('Z-READING (FINAL)'));
      expect(text, contains('Supervisor Maria'));
      expect(text, contains('Short'));
      expect(text, contains('! WARNING !'));
      expect(text, contains('Shortage noted by supervisor'));
    });
  });

  group('FakeEscPosTransport', () {
    test('captures and accumulates sent packets', () async {
      final transport = FakeEscPosTransport();
      final packet = Uint8List.fromList([0x1b, 0x40, 0x0a]);
      await transport.send(packet);

      expect(transport.packets.length, 1);
      expect(transport.packets.first, packet);
    });
  });
}
