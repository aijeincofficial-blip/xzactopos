import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/core/product_import.dart';

void main() {
  test('commas, tabs (pasted from a sheet) and semicolons all split', () {
    expect(splitCsv('a,b,c'), [['a', 'b', 'c']]);
    expect(splitCsv('a\tb\tc\n1\t2\t3'), [['a', 'b', 'c'], ['1', '2', '3']]);
    expect(splitCsv('a;b;c'), [['a', 'b', 'c']]);
  });

  test('quoted cells keep commas, quotes and line breaks', () {
    expect(splitCsv('"Kape, 3-in-1",12.5\n"say ""hi""",1'), [['Kape, 3-in-1', '12.5'], ['say "hi"', '1']]);
    expect(splitCsv('"a\nb",2'), [['a\nb', '2']]);
  });

  test('with a header (English or Filipino) columns are found by name, in any order', () {
    final r = parseProductCsv('presyo,pangalan,stock\n12.50,Kape,10\n5,Asukal,', 'PHP');
    expect(r.errors, isEmpty);
    expect(r.rows.map((e) => (e.name, e.price, e.stock)), [('Kape', 1250, 10.0), ('Asukal', 500, null)]);
    expect(r.rows.first.line, 2, reason: 'line numbers count the header');
  });

  test('without a header the order is name, price, barcode, cost, stock', () {
    final r = parseProductCsv('Kape 3-in-1,12.50,4800016644801,9.25,24', 'PHP');
    final e = r.rows.single;
    expect((e.name, e.price, e.barcode, e.cost, e.stock), ('Kape 3-in-1', 1250, '4800016644801', 925, 24.0));
  });

  test('money may carry a peso sign, PHP or thousands commas', () {
    final r = parseProductCsv('name,price\nTV,"₱1,250.00"\nRadio,PHP 99\nFan,  45 ', 'PHP');
    expect(r.rows.map((e) => e.price), [125000, 9900, 4500]);
  });

  test('bad rows are reported with their line and reason; good rows still come through', () {
    final r = parseProductCsv('name,price,cost,stock\nKape,12,,5\n,10,,\nAsukal,abc,,\nGatas,30,x,\nSabon,8,,-2\nItlog,9,,', 'PHP');
    expect(r.rows.map((e) => e.name), ['Kape', 'Itlog']);
    expect(r.errors.map((e) => (e.line, e.problem)), [
      (3, ImportProblem.nameMissing),
      (4, ImportProblem.priceInvalid),
      (5, ImportProblem.costInvalid),
      (6, ImportProblem.stockInvalid),
    ]);
  });

  test('blank lines are skipped, and an empty paste gives nothing', () {
    expect(parseProductCsv('', 'PHP').rows, isEmpty);
    expect(parseProductCsv('\n\n  \n', 'PHP').rows, isEmpty);
    expect(parseProductCsv('name,price\n\nKape,5\n\n', 'PHP').rows, hasLength(1));
  });

  test('only the first $importMaxRows rows are read', () {
    final text = ['name,price', for (var i = 0; i < importMaxRows + 20; i++) 'P$i,1'].join('\n');
    final r = parseProductCsv(text, 'PHP');
    expect(r.rows, hasLength(importMaxRows));
    expect(r.tooMany, isTrue);
  });
}
