import 'dart:convert';

import 'package:drift/drift.dart';

import 'db.dart';
import 'drift_sales.dart';
import 'shift_models.dart';

/// Cashier shifts on the device (F-05m). Mixed into [DriftStore]. Like every local write, opening and closing a shift is applied
/// at once and queued for the server in the same transaction (`open_shift`, `close_shift`).
mixin DriftShifts implements ShiftStore {
  AppDatabase get db;
  String get baseCurrency;
  Future<void> enqueue(String opId, String kind, String entityId, Map<String, dynamic> payload);
  Future<String?> activeStoreNow();
  Future<String> deviceId();

  static String _iso(DateTime t) => t.toUtc().toIso8601String();
  static const _cursorKey = 'shifts';

  /// [serviceCashEffect] in SQL, for a `service_txns t` row (the same rule as the day close).
  static const _serviceCashSql = '''
    case t.kind when 'cash_in' then t.amount + t.fee when 'cash_out' then t.fee - t.amount
                when 'load' then coalesce(t.price, t.amount + t.fee)
                when 'float_topup' then -t.amount when 'float_withdraw' then t.amount else 0 end
  ''';

  static const _pendingSql = '''
    exists (select 1 from outbox o where o.entity_id = x.id) as pending,
    (select o.last_error from outbox o where o.entity_id = x.id and o.status = 'failed' order by o.seq desc limit 1) as rejected
  ''';

  static const _cols = '''
    x.id, x.location_id, x.cashier_id, x.currency, x.opening_cash, x.opened_at, x.closed_at, x.expected_cash,
    x.server_expected_cash, x.counted_cash, x.difference, x.note, x.closed_by
  ''';

  static ShiftView _view(QueryRow r) => ShiftView(
        id: r.read<String>('id'),
        locationId: r.readNullable<String>('location_id'),
        cashierId: r.readNullable<String>('cashier_id'),
        currency: r.read<String>('currency'),
        openingCash: r.read<int>('opening_cash'),
        openedAt: DateTime.parse(r.read<String>('opened_at')).toLocal(),
        closedAt: r.readNullable<String>('closed_at') == null ? null : DateTime.parse(r.read<String>('closed_at')).toLocal(),
        expectedCash: r.readNullable<int>('expected_cash'),
        serverExpectedCash: r.readNullable<int>('server_expected_cash'),
        countedCash: r.readNullable<int>('counted_cash'),
        difference: r.readNullable<int>('difference'),
        note: r.readNullable<String>('note'),
        closedBy: r.readNullable<String>('closed_by'),
        pending: r.read<bool>('pending'),
        rejectedHint: r.readNullable<String>('rejected'),
      );

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  Selectable<QueryRow> _openQuery(String cashierId) => db.customSelect(
        'select $_cols, $_pendingSql from shifts x where x.cashier_id = ?1 and x.closed_at is null order by x.opened_at desc limit 1',
        variables: [Variable.withString(cashierId)],
        readsFrom: {db.shifts, db.outbox},
      );

  @override
  Stream<ShiftView?> watchOpenShift(String cashierId) =>
      _openQuery(cashierId).watch().map((rows) => rows.isEmpty ? null : _view(rows.first));

  @override
  Future<ShiftView?> openShift(String cashierId) async {
    final rows = await _openQuery(cashierId).get();
    return rows.isEmpty ? null : _view(rows.first);
  }

  Selectable<QueryRow> _listQuery(int limit) => db.customSelect(
        'select $_cols, $_pendingSql from shifts x where ${DriftSales.inActive('x.location_id')} '
        'order by x.opened_at desc, x.id desc limit ?1',
        variables: [Variable.withInt(limit)],
        readsFrom: {db.shifts, db.outbox, db.meta},
      );

  @override
  Stream<List<ShiftView>> watchShifts({int limit = 30}) => _listQuery(limit).watch().map((rows) => [for (final r in rows) _view(r)]);

  @override
  Future<ShiftView?> shift(String id) async {
    final rows = await db
        .customSelect('select $_cols, $_pendingSql from shifts x where x.id = ?1',
            variables: [Variable.withString(id)], readsFrom: {db.shifts, db.outbox})
        .get();
    return rows.isEmpty ? null : _view(rows.first);
  }

  /// The X reading. Cash sales count only sales made on THIS device (or from before devices were numbered): the phone cannot
  /// tell another cashier's pulled sales from this cashier's. Entries without a device (utang payments, expenses, load) count
  /// for the whole store at this phone; the server's own figure (per cashier) is what the close shows when online.
  Future<XReading?> _reading(Shift s, String device) async {
    final to = s.closedAt ?? _iso(DateTime.now());
    final a = DriftSales.inActive;
    final row = await db.customSelect('''
      select
        coalesce((select sum(p.amount) from sale_payments p join sales s on s.id = p.sale_id
                  where s.status = 'completed' and p.method = 'cash' and s.sold_at >= ?1 and s.sold_at <= ?2
                    and ${a('s.location_id')} and (s.device_id is null or s.device_id = ?3)), 0) as cash_sales,
        coalesce((select sum(p.amount) from sale_payments p join sales s on s.id = p.sale_id
                  where s.status = 'completed' and p.method = 'ewallet' and s.sold_at >= ?1 and s.sold_at <= ?2
                    and ${a('s.location_id')} and (s.device_id is null or s.device_id = ?3)), 0) as ewallet_sales,
        coalesce((select sum(p.amount) from sale_payments p join sales s on s.id = p.sale_id
                  where s.status = 'completed' and p.method = 'utang' and s.sold_at >= ?1 and s.sold_at <= ?2
                    and ${a('s.location_id')} and (s.device_id is null or s.device_id = ?3)), 0) as utang_sales,
        coalesce((select count(*) from sales s where s.status = 'completed' and s.sold_at >= ?1 and s.sold_at <= ?2
                    and ${a('s.location_id')} and (s.device_id is null or s.device_id = ?3)), 0) as sales_count,
        coalesce((select sum(s.total) from sales s where s.status = 'completed' and s.sold_at >= ?1 and s.sold_at <= ?2
                    and ${a('s.location_id')} and (s.device_id is null or s.device_id = ?3)), 0) as gross,
        coalesce((select -sum(l.amount) from server_ledger l
                  where l.kind = 'payment' and l.method = 'cash' and ${a('l.location_id')}
                    and julianday(l.occurred_at) >= julianday(?1) and julianday(l.occurred_at) <= julianday(?2)), 0)
        + coalesce((select -sum(l.amount) from local_ledger l
                  where l.kind = 'payment' and l.method = 'cash' and ${a('l.location_id')}
                    and l.occurred_at >= ?1 and l.occurred_at <= ?2), 0) as utang_cash,
        coalesce((select sum(e.amount) from expenses e
                  where e.voided_at is null and e.paid_from = 'cash' and e.spent_at >= ?1 and e.spent_at <= ?2
                    and ${a('e.location_id')}), 0) as expenses_cash,
        coalesce((select sum($_serviceCashSql) from service_txns t
                  where t.voided_at is null and t.txn_at >= ?1 and t.txn_at <= ?2 and ${a('t.location_id')}), 0) as service_cash
      ''',
        variables: [Variable.withString(s.openedAt), Variable.withString(to), Variable.withString(device)],
        readsFrom: {db.sales, db.salePayments, db.serverLedger, db.localLedger, db.expenses, db.serviceTxns, db.meta}).getSingle();
    return XReading(
      from: DateTime.parse(s.openedAt).toLocal(),
      to: DateTime.parse(to).toLocal(),
      openingCash: s.openingCash,
      cashSales: row.read<int>('cash_sales'),
      utangCash: row.read<int>('utang_cash'),
      expensesCash: row.read<int>('expenses_cash'),
      serviceCash: row.read<int>('service_cash'),
      salesCount: row.read<int>('sales_count'),
      grossSales: row.read<int>('gross'),
      ewalletSales: row.read<int>('ewallet_sales'),
      utangSales: row.read<int>('utang_sales'),
    );
  }

  @override
  Future<XReading?> xReading(String shiftId) async {
    final s = await (db.select(db.shifts)..where((x) => x.id.equals(shiftId))).getSingleOrNull();
    if (s == null) return null;
    return _reading(s, await deviceId());
  }

  @override
  Stream<XReading?> watchXReading(String shiftId) => db
      .customSelect('select 1 as watch_shift_x', readsFrom: {
        db.shifts, db.sales, db.salePayments, db.serverLedger, db.localLedger, db.expenses, db.serviceTxns, db.meta,
      })
      .watch()
      .asyncMap((_) => xReading(shiftId));

  // ---------------------------------------------------------------------------
  // Writes: applied at once, queued in the same transaction
  // ---------------------------------------------------------------------------

  @override
  Future<void> startShift({required String id, required String cashierId, int openingCash = 0, required String opId, DateTime? at}) {
    if (openingCash < 0) throw ArgumentError('Opening cash cannot be negative');
    return db.transaction(() async {
      if (await (db.select(db.shifts)..where((x) => x.id.equals(id))).getSingleOrNull() != null) {
        throw const ShiftException('id_used');
      }
      final open = await (db.select(db.shifts)..where((x) => x.cashierId.equals(cashierId) & x.closedAt.isNull())).get();
      if (open.isNotEmpty) throw const ShiftException('shift_already_open');
      final loc = await activeStoreNow();
      final opened = _iso(at ?? DateTime.now());
      await db.into(db.shifts).insert(ShiftsCompanion.insert(
            id: id,
            locationId: Value(loc),
            cashierId: Value(cashierId),
            currency: baseCurrency,
            openingCash: Value(openingCash),
            openedAt: opened,
          ));
      await enqueue(opId, 'open_shift', id, {
        'id': id,
        'location_id': ?loc,
        'opening_cash': openingCash,
        'opened_at': opened,
      });
    });
  }

  static String? _text200(String? s) {
    final t = s?.trim();
    if (t == null || t.isEmpty) return null;
    return t.length > 200 ? t.substring(0, 200) : t;
  }

  @override
  Future<void> closeShift({
    required String id,
    required int countedCash,
    required int expectedCash,
    String? note,
    String? closedBy,
    required String opId,
    DateTime? at,
  }) {
    if (countedCash < 0) throw ArgumentError('Counted cash cannot be negative');
    final n = _text200(note);
    final closer = closedBy != null && closedBy.trim().isNotEmpty ? closedBy.trim() : null;
    return db.transaction(() async {
      final s = await (db.select(db.shifts)..where((x) => x.id.equals(id))).getSingleOrNull();
      if (s == null) throw const ShiftException('shift_not_found');
      if (s.closedAt != null) throw const ShiftException('shift_closed');
      final closed = _iso(at ?? DateTime.now());
      await (db.update(db.shifts)..where((x) => x.id.equals(id))).write(ShiftsCompanion(
        closedAt: Value(closed),
        expectedCash: Value(expectedCash),
        countedCash: Value(countedCash),
        difference: Value(countedCash - expectedCash),
        note: Value(n),
        closedBy: closer == null ? const Value.absent() : Value(closer),
      ));
      await enqueue(opId, 'close_shift', id, {
        'id': id,
        'counted_cash': countedCash,
        'expected_cash': expectedCash,
        'closed_at': closed,
        'note': ?n,
      });
    });
  }

  // ---------------------------------------------------------------------------
  // Sync
  // ---------------------------------------------------------------------------

  @override
  Future<Map<String, dynamic>?> shiftCursor() async {
    final c = await (db.select(db.syncCursors)..where((x) => x.tableKey.equals(_cursorKey))).getSingleOrNull();
    if (c == null) return null;
    final v = jsonDecode(c.cursorJson);
    return v is Map ? v.cast<String, dynamic>() : null;
  }

  static String _utc(String iso) => DateTime.parse(iso).toUtc().toIso8601String();

  @override
  Future<void> applyPullShifts(Map<String, dynamic> response) {
    return db.transaction(() async {
      final unsent = (await db.select(db.outbox).get()).map((o) => o.entityId).toSet();
      for (final r in ((response['rows'] as List?) ?? const []).cast<Map<String, dynamic>>()) {
        final id = r['id'] as String;
        if (unsent.contains(id)) continue; // a change made here is still on its way: the server's copy is older
        final closedAt = r['closed_at'] as String?;
        await db.into(db.shifts).insertOnConflictUpdate(ShiftsCompanion.insert(
              id: id,
              locationId: Value(r['location_id'] as String?),
              cashierId: Value(r['cashier_id'] as String?),
              currency: (r['currency'] as String).trim(),
              openingCash: Value((r['opening_cash'] as num).toInt()),
              openedAt: _utc(r['opened_at'] as String),
              closedAt: Value(closedAt == null ? null : _utc(closedAt)),
              expectedCash: Value((r['expected_cash'] as num?)?.toInt()),
              serverExpectedCash: Value((r['server_expected_cash'] as num?)?.toInt()),
              countedCash: Value((r['counted_cash'] as num?)?.toInt()),
              difference: Value((r['difference'] as num?)?.toInt()),
              note: Value(r['note'] as String?),
              closedBy: Value(r['closed_by'] as String?),
              updatedAt: Value(r['updated_at'] as String?),
            ));
      }
      final cursor = response['cursor'];
      if (cursor is Map) {
        await db
            .into(db.syncCursors)
            .insertOnConflictUpdate(SyncCursorsCompanion.insert(tableKey: _cursorKey, cursorJson: jsonEncode(cursor)));
      }
    });
  }

  @override
  Future<void> shiftOpApplied(String opId, String? appliedAt, {Map<String, dynamic>? result}) async {
    final id = result?['shift_id'];
    final server = (result?['server_expected_cash'] as num?)?.toInt();
    if (id is String && server != null) {
      await (db.update(db.shifts)..where((x) => x.id.equals(id))).write(ShiftsCompanion(serverExpectedCash: Value(server)));
    }
  }
}
