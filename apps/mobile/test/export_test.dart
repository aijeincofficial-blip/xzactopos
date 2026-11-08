import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/core/export.dart';
import 'package:xzactopos_mobile/data/sales_models.dart';

import 'products_test.dart' show leave, openHome;
import 'restock_test.dart' show row;

class FakeSharer implements CsvSharer {
  final files = <String, String>{};
  @override
  Future<void> share({required String fileName, required String csv}) async => files[fileName] = csv;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('csv', () {
    test('cells with commas, quotes and line breaks are quoted', () {
      expect(csvCell('plain'), 'plain');
      expect(csvCell('Kape, 3-in-1'), '"Kape, 3-in-1"');
      expect(csvCell('say "hi"'), '"say ""hi"""');
      expect(csvCell('a\nb'), '"a\nb"');
    });

    test('a cell that starts like a formula is defused', () {
      expect(csvCell('=SUM(A1)'), "'=SUM(A1)");
      expect(csvCell('+63917'), "'+63917");
      expect(csvCell('@cmd'), "'@cmd");
    });

    test('sales: both numbers (local and from the server), plain decimals, UTC times, not-sent flag', () {
      final csv = salesCsv([
        SaleSummary(
            id: 's1', localNo: 'A1-0001', saleNo: 'S01-261108-0007', status: 'completed', total: 12550, soldAt: DateTime.utc(2026, 11, 8, 1, 30), customerName: 'Aling, Rosa', pending: false),
        SaleSummary(id: 's2', localNo: 'A1-0002', status: 'voided', total: 500, soldAt: DateTime.utc(2026, 11, 8, 2), pending: true),
      ], 'PHP').split('\r\n');
      expect(csv[0], 'receipt_no,sale_no,sold_at_utc,status,customer,total,not_sent');
      expect(csv[1], 'A1-0001,S01-261108-0007,2026-11-08T01:30:00.000Z,completed,"Aling, Rosa",125.50,no');
      expect(csv[2], 'A1-0002,,2026-11-08T02:00:00.000Z,voided,,5.00,yes', reason: 'no server number yet: the column is empty');
    });

    test('utang keeps negative balances', () {
      final csv = utangCsv([
        const CustomerView(id: 'c1', name: 'Rosa', phone: '0917', balance: 4500, pending: false),
        const CustomerView(id: 'c2', name: 'Ben', balance: -250, pending: false),
      ], 'PHP').split('\r\n');
      expect(csv, ['customer,phone,balance', 'Rosa,0917,45.00', 'Ben,,-2.50']);
    });

    test('stock leaves uncounted quantities empty and flags low items', () {
      final csv = stockCsv([row('a', 4, 5), row('b', null, 5), row('c', 12.5, 0)]).split('\r\n');
      expect(csv[0], 'product,sku,unit,quantity,reorder_point,low');
      expect(csv[1], 'Item a,a,pc,4,5,yes');
      expect(csv[2], 'Item b,b,pc,,5,no');
      expect(csv[3], 'Item c,c,pc,12.5,,no');
    });
  });

  testWidgets('Import & export sends products, sales, utang and stock through the sharer', (tester) async {
    final fake = FakeSharer();
    csvSharer = fake;
    addTearDown(() => csvSharer = const SystemCsvSharer());
    await openHome(tester);
    await tester.tap(find.byKey(const Key('tab-more')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('tile-data')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tile-data')));
    await tester.pumpAndSettle();
    for (final k in ['export-products', 'export-sales', 'export-utang', 'export-stock']) {
      await tester.ensureVisible(find.byKey(Key(k)));
      await tester.tap(find.byKey(Key(k)));
      await tester.pumpAndSettle();
    }
    expect(fake.files.keys.map((f) => f.split('-').first).toSet(), {'products', 'sales', 'utang', 'stock'});
    expect(fake.files.keys.every((f) => f.endsWith('.csv')), isTrue);
    expect(fake.files.values.every((c) => c.contains(',')), isTrue);
    await leave(tester);
  });
}
