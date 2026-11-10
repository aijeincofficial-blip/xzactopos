import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/data/count_models.dart';

import 'warehouse_home_test.dart' show leave, open, tab;
import 'widget_test.dart' show FakeBackend;

const _w1 = 'w1000000-0000-4000-8000-000000000001';
const _w2 = 'w2000000-0000-4000-8000-000000000002';
const _rice = 'v1000000-0000-4000-8000-000000000001';
const _oil = 'v2000000-0000-4000-8000-000000000002';
const _binA = 'b1000000-0000-4000-8000-000000000001';

/// A server that behaves like F-13e where it matters: one open count per warehouse, a line remembers the system
/// quantity at the moment it was counted, counting again replaces the line, closing applies it.
class CountServer extends FakeBackend implements CountApi {
  CountServer() : super(signedInAtStart: true);

  final system = <String, double>{_rice: 40, _oil: 5};
  final sessions = <String, Map<String, dynamic>>{}; // warehouse id -> open count
  final log = <String>[];
  final recorded = <List<CountEntry>>[];
  final startIds = <String>[];
  final startNotes = <String?>[];
  bool downFlag = false; // the "no signal" switch
  String? refuse; // hint to refuse the next start with
  bool? lastZero;
  int _n = 0;

  void _guard() {
    if (downFlag) throw const CountOffline();
  }

  @override
  Future<CountSession?> openCount(String warehouseId) async {
    log.add('open');
    _guard();
    final s = sessions[warehouseId];
    return s == null ? null : CountSession.fromJson(s);
  }

  @override
  Future<void> startCount({required String id, required String warehouseId, String? binId, String? notes}) async {
    log.add('start');
    _guard();
    startIds.add(id);
    startNotes.add(notes);
    if (refuse != null) throw CountException(refuse!);
    if (sessions.containsKey(warehouseId)) throw const CountException('count_in_progress');
    sessions[warehouseId] = {
      'id': id,
      'count_no': 'CNT-${++_n}',
      'warehouse_id': warehouseId,
      'bin_id': binId,
      'bin': binId == null ? null : {'code': 'A-01'},
      'notes': notes,
      'stock_count_items': <Map<String, dynamic>>[],
    };
  }

  @override
  Future<void> recordCount(String countId, List<CountEntry> items) async {
    log.add('record');
    _guard();
    recorded.add(items);
    final s = sessions.values.firstWhere((x) => x['id'] == countId);
    final lines = s['stock_count_items'] as List;
    for (final i in items) {
      lines.removeWhere((l) => l['variant_id'] == i.variantId && l['bin_id'] == i.binId);
      lines.add({
        'variant_id': i.variantId,
        'bin_id': i.binId,
        'bin': i.binId == null ? null : {'code': 'A-01'},
        'qty_system': system[i.variantId] ?? 0,
        'qty_counted': i.qty,
      });
    }
  }

  @override
  Future<CountResult> closeCount(String countId, {bool zeroUncounted = false}) async {
    log.add('close');
    _guard();
    lastZero = zeroUncounted;
    final key = sessions.keys.firstWhere((k) => sessions[k]!['id'] == countId);
    final lines = sessions.remove(key)!['stock_count_items'] as List;
    final net = lines.fold<double>(0, (a, l) => a + ((l['qty_counted'] as num) - (l['qty_system'] as num)));
    return CountResult(lines: lines.length, corrections: lines.where((l) => l['qty_counted'] != l['qty_system']).length, netVariance: net, zeroed: 0);
  }

  @override
  Future<void> cancelCount(String countId, {String? reason}) async {
    log.add('cancel');
    _guard();
    sessions.removeWhere((_, v) => v['id'] == countId);
  }
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

Future<CountServer> openCount(WidgetTester tester, {bool bins = false, bool two = true, String locale = 'en'}) async {
  late CountServer server;
  await open(tester, bins: bins, two: two, locale: locale, spinnerOk: true, makeBackend: () => server = CountServer());
  await tab(tester, 'tab-count');
  await settle(tester);
  return server;
}

Future<void> startCount(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('count-start')));
  await settle(tester);
}

Future<void> countProduct(WidgetTester tester, String search, String variantId, String qty, {String? binName}) async {
  await tester.enterText(find.byKey(const Key('count-search')), search);
  await settle(tester);
  await tester.tap(find.byKey(Key('count-pick-$variantId')));
  await settle(tester);
  if (binName != null) {
    await tester.tap(find.byKey(const Key('count-bin')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(binName).last);
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byKey(const Key('count-qty')), qty);
  await tester.tap(find.byKey(const Key('count-save')));
  await settle(tester);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('a server count is read into lines with the system quantity and variance', () {
    final s = CountSession.fromJson({
      'id': 'c1', 'count_no': 'CNT-1', 'warehouse_id': _w1, 'bin_id': null, 'notes': null,
      'stock_count_items': [
        {'variant_id': _rice, 'bin_id': _binA, 'bin': {'code': 'A-01'}, 'qty_system': 40, 'qty_counted': 37.5},
      ],
    });
    expect(s.wholeWarehouse, isTrue);
    expect(s.lines.single.binCode, 'A-01');
    expect(s.lines.single.variance, -2.5);
    expect(const CountEntry(variantId: 'v', qty: 2, binId: 'b').toJson(), {'variant_id': 'v', 'qty_counted': 2.0, 'bin_id': 'b'});
    expect(const CountEntry(variantId: 'v', qty: 2).toJson().containsKey('bin_id'), isFalse);
  });

  testWidgets('with no count open the clerk can start one', (tester) async {
    final server = await openCount(tester);
    expect(find.byKey(const Key('count-none')), findsOneWidget);
    await startCount(tester);
    expect(server.sessions.keys, [_w1]);
    expect(find.byKey(const Key('count-header')), findsOneWidget);
    expect(find.textContaining('CNT-1'), findsOneWidget);
    expect(find.byKey(const Key('count-no-lines')), findsOneWidget);
    await leave(tester);
  });

  testWidgets('counting a product shows what the system had and the difference', (tester) async {
    final server = await openCount(tester);
    await startCount(tester);
    await countProduct(tester, 'rice', _rice, '37');
    expect(server.recorded.single.single.qty, 37);
    expect(find.byKey(const Key('count-line-$_rice')), findsOneWidget);
    expect(find.text('system had 40'), findsOneWidget);
    expect(find.text('37'), findsOneWidget);
    expect(find.text('-3'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('picking a product gives the keyboard to the quantity box, and saving clears the search', (tester) async {
    await openCount(tester);
    await startCount(tester);
    await tester.enterText(find.byKey(const Key('count-search')), 'rice');
    await settle(tester);
    await tester.tap(find.byKey(const Key('count-pick-$_rice')));
    await settle(tester);
    final editable = find.descendant(of: find.byKey(const Key('count-qty')), matching: find.byType(EditableText));
    expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue, reason: 'typing a quantity must not land in the search box');
    await tester.enterText(find.byKey(const Key('count-qty')), '37');
    await tester.tap(find.byKey(const Key('count-save')));
    await settle(tester);
    expect(tester.widget<TextField>(find.byKey(const Key('count-search'))).controller!.text, isEmpty);
    await leave(tester);
  });

  testWidgets('counting a product again replaces its line', (tester) async {
    await openCount(tester);
    await startCount(tester);
    await countProduct(tester, 'rice', _rice, '37');
    await tester.tap(find.byKey(const Key('count-line-$_rice')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('count-qty'))).controller!.text, '37', reason: 'starts from the saved count');
    await tester.enterText(find.byKey(const Key('count-qty')), '41');
    await tester.tap(find.byKey(const Key('count-save')));
    await settle(tester);
    expect(find.byKey(const Key('count-line-$_rice')), findsOneWidget);
    expect(find.text('41'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a quantity that is not a number is refused on the phone and nothing is sent', (tester) async {
    final server = await openCount(tester);
    await startCount(tester);
    await countProduct(tester, 'rice', _rice, 'abc');
    expect(find.text('Enter a quantity greater than zero.'), findsOneWidget);
    expect(server.recorded, isEmpty);
    await leave(tester);
  });

  testWidgets('without a connection the clerk is told, and can try again', (tester) async {
    late CountServer server;
    await open(tester, spinnerOk: true, makeBackend: () => server = CountServer()..downFlag = true);
    await tab(tester, 'tab-count');
    await settle(tester);
    expect(find.byKey(const Key('count-offline')), findsOneWidget);
    expect(find.byKey(const Key('count-start')), findsNothing);
    server.downFlag = false;
    await tester.tap(find.byKey(const Key('count-retry')));
    await settle(tester);
    expect(find.byKey(const Key('count-start')), findsOneWidget);
    await leave(tester);
  });

  testWidgets('without a connection the clerk can start an offline count and record lines', (tester) async {
    await open(tester, spinnerOk: true, makeBackend: () => CountServer()..downFlag = true);
    await tab(tester, 'tab-count');
    await settle(tester);
    expect(find.byKey(const Key('count-offline')), findsOneWidget);
    expect(find.byKey(const Key('count-start-offline')), findsOneWidget);

    await tester.tap(find.byKey(const Key('count-start-offline')));
    await settle(tester);

    expect(find.byKey(const Key('count-header')), findsOneWidget);
    expect(find.byKey(const Key('count-offline-banner')), findsOneWidget);
    expect(find.textContaining('CNT-LOCAL-'), findsOneWidget);

    await countProduct(tester, 'rice', _rice, '15');
    expect(find.byKey(const Key('count-line-$_rice')), findsOneWidget);
    expect(find.text('15'), findsOneWidget);

    await tester.tap(find.byKey(const Key('count-finish')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('count-confirm')));
    await settle(tester);
    expect(find.byKey(const Key('count-result')), findsOneWidget);

    await leave(tester);
  });

  testWidgets('losing the connection while saving keeps the clerk on the product with a message', (tester) async {
    final server = await openCount(tester);
    await startCount(tester);
    server.downFlag = true;
    await countProduct(tester, 'rice', _rice, '37');
    expect(find.text('You need a connection to count stock. Check your signal and try again.'), findsOneWidget);
    expect(find.byKey(const Key('count-save')), findsOneWidget, reason: 'the typed count is still there');
    await leave(tester);
  });

  testWidgets('a refusal from the server is shown in plain words', (tester) async {
    final server = await openCount(tester);
    server.refuse = 'count_in_progress';
    await startCount(tester);
    expect(find.text('A count is already open in this warehouse.'), findsOneWidget);
    expect(find.byKey(const Key('count-none')), findsOneWidget);
    await leave(tester);
  });

  testWidgets('finishing asks first, can treat uncounted products as zero, and reports the result', (tester) async {
    final server = await openCount(tester);
    await startCount(tester);
    await countProduct(tester, 'rice', _rice, '37');
    await tester.ensureVisible(find.byKey(const Key('count-finish')));
    await tester.tap(find.byKey(const Key('count-finish')));
    await tester.pumpAndSettle();
    expect(server.log.contains('close'), isFalse, reason: 'nothing happens until the clerk confirms');
    await tester.tap(find.byKey(const Key('count-zero')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('count-confirm')));
    await settle(tester);
    expect(server.lastZero, isTrue);
    expect(find.textContaining('Count finished. 1 correction made.'), findsOneWidget);
    expect(find.byKey(const Key('count-none')), findsOneWidget);
    await leave(tester);
  });

  testWidgets('finishing without ticking the box does not zero anything', (tester) async {
    final server = await openCount(tester);
    await startCount(tester);
    await countProduct(tester, 'rice', _rice, '40');
    await tester.ensureVisible(find.byKey(const Key('count-finish')));
    await tester.tap(find.byKey(const Key('count-finish')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('count-confirm')));
    await settle(tester);
    expect(server.lastZero, isFalse);
    expect(find.textContaining('No corrections.'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('cancelling asks first and drops the count', (tester) async {
    final server = await openCount(tester);
    await startCount(tester);
    await tester.ensureVisible(find.byKey(const Key('count-cancel')));
    await tester.tap(find.byKey(const Key('count-cancel')));
    await tester.pumpAndSettle();
    expect(server.sessions, isNotEmpty);
    await tester.tap(find.byKey(const Key('count-cancel-confirm')));
    await settle(tester);
    expect(server.sessions, isEmpty);
    expect(find.byKey(const Key('count-none')), findsOneWidget);
    await leave(tester);
  });

  testWidgets('in a warehouse with bins a whole-warehouse count needs a bin on every line', (tester) async {
    final server = await openCount(tester, bins: true);
    await startCount(tester);
    await countProduct(tester, 'rice', _rice, '37');
    expect(find.text('Choose the bin where you counted it.'), findsOneWidget);
    expect(server.recorded, isEmpty);
    await tester.tap(find.byKey(const Key('count-bin')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A-01').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('count-save')));
    await settle(tester);
    expect(server.recorded.single.single.binId, _binA);
    await leave(tester);
  });

  testWidgets('a count of one bin sends that bin without asking again', (tester) async {
    final server = await openCount(tester, bins: true);
    await tester.tap(find.byKey(const Key('count-scope')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A-01').last);
    await tester.pumpAndSettle();
    await startCount(tester);
    expect(find.byKey(const Key('count-header')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('count-search')), 'oil');
    await settle(tester);
    await tester.tap(find.byKey(Key('count-pick-$_oil')));
    await settle(tester);
    expect(find.byKey(const Key('count-bin')), findsNothing, reason: 'the count already names its bin');
    await tester.enterText(find.byKey(const Key('count-qty')), '4');
    await tester.tap(find.byKey(const Key('count-save')));
    await settle(tester);
    expect(server.sessions[_w1]!['bin_id'], _binA);
    expect(server.recorded.single.single.binId, _binA, reason: 'the line goes to the bin of the count');
    await leave(tester);
  });

  testWidgets('every new count gets its own id and carries the notes', (tester) async {
    final server = await openCount(tester);
    await tester.enterText(find.byKey(const Key('count-notes')), 'Aisle check');
    await startCount(tester);
    await tester.ensureVisible(find.byKey(const Key('count-cancel')));
    await tester.tap(find.byKey(const Key('count-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('count-cancel-confirm')));
    await settle(tester);
    await startCount(tester);
    expect(server.startIds.toSet(), hasLength(2), reason: 'a finished count must not reuse its id');
    expect(server.startNotes.first, 'Aisle check');
    expect(server.startNotes.last, isNull);
    await leave(tester);
  });

  testWidgets('backing out of the finish or cancel question changes nothing', (tester) async {
    final server = await openCount(tester);
    await startCount(tester);
    await tester.ensureVisible(find.byKey(const Key('count-finish')));
    await tester.tap(find.byKey(const Key('count-finish')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('count-cancel')));
    await tester.tap(find.byKey(const Key('count-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep counting'));
    await settle(tester);
    expect(server.log.contains('close'), isFalse);
    expect(server.log.contains('cancel'), isFalse);
    expect(server.sessions, isNotEmpty);
    await leave(tester);
  });

  testWidgets('a warehouse without bins is counted as a whole, with no scope choice', (tester) async {
    await openCount(tester);
    expect(find.byKey(const Key('count-scope')), findsNothing);
    await leave(tester);
  });


  testWidgets('each warehouse has its own count', (tester) async {
    final server = await openCount(tester);
    await startCount(tester);
    await tester.tap(find.byKey(const Key('warehouse-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('warehouse-$_w2')));
    await settle(tester);
    expect(find.byKey(const Key('count-none')), findsOneWidget, reason: 'nothing is open in the other warehouse');
    expect(server.sessions.keys, [_w1]);
    await leave(tester);
  });

  testWidgets('Filipino labels', (tester) async {
    await openCount(tester, locale: 'fil');
    expect(find.text('Walang kasalukuyang bilang.'), findsOneWidget);
    expect(find.text('Simulan ang pagbibilang'), findsOneWidget);
    await leave(tester);
  });
}
