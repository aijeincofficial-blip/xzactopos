import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../core/search.dart';
import 'db.dart';
import 'local_store.dart';
import 'sales_models.dart';

/// Sales, stock and utang on the device (P3-03). Mixed into [DriftStore].
///
/// Stock and utang balances are "server copy + effects made here that the server's copy has not caught up on".
/// An effect stays in `local_movements` / `local_ledger` until a pull has passed the time the server applied its op,
/// so a number never jumps while a sale is in flight (no double count, no gap).
mixin DriftSales implements SalesStore {
  AppDatabase get db;
  String get baseCurrency;
  Future<void> enqueue(String opId, String kind, String entityId, Map<String, dynamic> payload);

  static String _iso(DateTime t) => t.toUtc().toIso8601String();

  // ---------------------------------------------------------------------------
  // The active store (F-01)
  //
  // Kept in `meta` ('active_location_id'), and every scoped query reads it from there ([activeSql]) with `meta` among
  // its tables, so a watched list, total or balance follows a store switch at once. Writes read it in their own
  // transaction ([activeStoreNow]). Rows store the store they belong to; a query shows `x.location_id = active`, or
  // everything when no store is known (no access list: tests and the pre-F-01 behaviour).
  // ---------------------------------------------------------------------------

  static const _activeKey = 'active_location_id';
  static const _storesKey = 'stores';

  /// The active store as an SQL scalar (null when none).
  static const activeSql = "(select am.value from meta am where am.key = 'active_location_id')";

  /// "[col] belongs to the active store" (always true when no store is active).
  static String inActive(String col) => '($activeSql is null or $col = $activeSql)';

  String? _active;
  List<StoreRef> _stores = const [];

  @override
  String? get activeLocationId => _active;

  /// The active store as stored now (use inside writes).
  @override
  Future<String?> activeStoreNow() => meta(_activeKey);

  /// The user's only store, or null (none or several). Pulled rows that name no store (an older server) belong to it.
  String? get _sole => _stores.length == 1 ? _stores.first.id : null;

  @override
  Future<List<StoreRef>> myStores() async {
    if (_stores.isEmpty) {
      final raw = await meta(_storesKey);
      if (raw != null) {
        _stores = [for (final j in (jsonDecode(raw) as List).cast<Map<String, dynamic>>()) StoreRef.fromJson(j)];
      }
    }
    return List.unmodifiable(_stores);
  }

  @override
  Stream<String?> watchActiveStore() => (db.select(db.meta)..where((m) => m.key.equals(_activeKey)))
      .watchSingleOrNull()
      .map((r) => r?.value)
      .distinct();

  @override
  Future<void> setActiveStore(String locationId) async {
    if (!(await myStores()).any((s) => s.id == locationId)) {
      throw ArgumentError('Not one of your stores: $locationId');
    }
    await setMeta(_activeKey, locationId);
    _active = locationId;
  }

  /// Called by `ensureTenant` with the stores the user may work at. Picks the active store: the one chosen before on this
  /// device if still allowed, else [preferred] if allowed, else the first. With exactly one store, rows that do not know
  /// their store yet (made before schema v13, or while no store was known) are given it, so a solo device behaves exactly
  /// as before. With several, such rows wait for the re-pull that brings their store (local ones stay unshown until then).
  Future<void> initStores(List<StoreRef> stores, {String? preferred}) async {
    _stores = List.unmodifiable(stores);
    final saved = await meta(_activeKey);
    bool ok(String? id) => id != null && stores.any((s) => s.id == id);
    final pick = ok(saved) ? saved : (ok(preferred) ? preferred : (stores.isEmpty ? null : stores.first.id));
    await db.transaction(() async {
      await setMeta(_storesKey, stores.isEmpty ? null : jsonEncode([for (final s in stores) s.toJson()]));
      if (pick != saved) await setMeta(_activeKey, pick);
      if (stores.length == 1) await _fillUnknownStore(stores.first.id);
    });
    _active = pick;
  }

  Future<void> _fillUnknownStore(String loc) async {
    final v = [Variable.withString(loc)];
    for (final t in [
      'sales', 'local_movements', 'local_ledger', 'server_ledger', 'local_float_effects', 'expenses', 'day_closes',
      'service_txns', 'conversions',
    ]) {
      await db.customUpdate('update $t set location_id = ?1 where location_id is null', variables: v, updates: _tables(t));
    }
    // expiry rows written with no store: the local (unsent) date wins over a pulled one of the same product
    await db.customUpdate('''
      insert or replace into stock_expiry (variant_id, location_id, expires_on, updated_at)
      select e.variant_id, ?1, e.expires_on, e.updated_at from stock_expiry e
      where e.location_id = '' and (e.updated_at is null or not exists (
        select 1 from stock_expiry x where x.location_id = ?1 and x.variant_id = e.variant_id))''',
        variables: v, updates: {db.stockExpiry});
    await db.customUpdate("delete from stock_expiry where location_id = ''", updates: {db.stockExpiry});
  }

  Set<TableInfo> _tables(String name) => {db.allTables.firstWhere((t) => t.actualTableName == name)};

  // ---------------------------------------------------------------------------
  // Meta
  // ---------------------------------------------------------------------------

  @override
  Future<String?> meta(String key) async =>
      (await (db.select(db.meta)..where((m) => m.key.equals(key))).getSingleOrNull())?.value;

  @override
  Future<void> setMeta(String key, String? value) async {
    if (value == null) {
      await (db.delete(db.meta)..where((m) => m.key.equals(key))).go();
    } else {
      await db.into(db.meta).insertOnConflictUpdate(MetaCompanion.insert(key: key, value: value));
    }
  }

  static const _deviceKey = 'device_id';

  @override
  Future<String> deviceId() => db.transaction(() async {
        final saved = await meta(_deviceKey);
        if (saved != null) return saved;
        final id = const Uuid().v7();
        await setMeta(_deviceKey, id);
        return id;
      });

  // ---------------------------------------------------------------------------
  // Selling
  // ---------------------------------------------------------------------------

  /// `<device>-YYMMDD-NNNN`. The device code is made once per phone; the counter restarts each day.
  Future<String> _nextReceiptNo(DateTime localTime) async {
    var dev = await meta('device_code');
    if (dev == null) {
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      final r = Random.secure();
      dev = List.generate(3, (_) => chars[r.nextInt(chars.length)]).join();
      await setMeta('device_code', dev);
    }
    String two(int n) => n.toString().padLeft(2, '0');
    final day = '${two(localTime.year % 100)}${two(localTime.month)}${two(localTime.day)}';
    final key = 'receipt_$day';
    final n = (int.tryParse(await meta(key) ?? '') ?? 0) + 1;
    await setMeta(key, '$n');
    return '$dev-$day-${n.toString().padLeft(4, '0')}';
  }

  @override
  Future<SaleReceipt> commitSale(SaleDraft d, {required String opId}) {
    if (d.lines.isEmpty) throw ArgumentError('A sale needs at least one item');
    if (d.discount < 0 || d.discount > d.subtotal) throw ArgumentError('Discount is out of range');
    if (d.payments.fold<int>(0, (a, p) => a + p.amount) != d.total) {
      throw ArgumentError('Payments must add up to the total');
    }
    if (d.utang > 0 && d.customerId == null) throw ArgumentError('Utang needs a customer');
    for (final p in d.payments) {
      _checkWallet(p.wallet, p.method == 'ewallet', 'an e-wallet payment');
    }

    return db.transaction(() async {
      final loc = await activeStoreNow();
      // F-02: the provisional number stays per device; the server gives the store's number when the sale reaches it
      final dev = await deviceId();
      final localNo = await _nextReceiptNo(d.soldAt.toLocal());
      final soldAt = _iso(d.soldAt);
      final tax = d.lines.fold<int>(0, (a, l) => a + l.lineTax);
      // cost snapshot: the average cost of this product at this store (the server's, moved by this device's stock-ins and
      // opened packs it has not caught up on, same rule as the server), else the cost on the line
      final eff = await _effectiveStock(loc);
      int costOf(SaleLine l) => eff[l.variantId]?.avg ?? l.unitCost;

      await db.into(db.sales).insert(SalesCompanion.insert(
            id: d.id,
            locationId: Value(loc),
            localNo: localNo,
            subtotal: d.subtotal,
            discount: Value(d.discount),
            tax: Value(tax),
            total: d.total,
            customerId: Value(d.customerId),
            soldAt: soldAt,
            deviceId: Value(dev),
          ));
      for (final l in d.lines) {
        await db.into(db.saleItems).insert(SaleItemsCompanion.insert(
              saleId: d.id,
              variantId: l.variantId,
              name: l.name,
              qty: l.qty,
              unitPrice: l.unitPrice,
              unitCost: Value(costOf(l)),
              tax: Value(l.lineTax),
              lineTotal: l.lineTotal,
              tracked: Value(l.tracked),
            ));
        if (l.tracked) {
          await db.into(db.localMovements).insert(LocalMovementsCompanion.insert(
              opId: opId, variantId: l.variantId, qty: -l.qty, locationId: Value(loc)));
        }
      }
      for (final p in d.payments) {
        await db.into(db.salePayments).insert(SalePaymentsCompanion.insert(
              saleId: d.id,
              method: p.method,
              amount: p.amount,
              tendered: Value(p.method == 'cash' ? (p.tendered ?? p.amount) : null),
              reference: Value(p.reference),
              wallet: Value(p.wallet),
            ));
        // P8-15: the customer paid into the store's wallet
        if (p.wallet != null) {
          await db.into(db.localFloatEffects).insert(LocalFloatEffectsCompanion.insert(
              opId: opId, txnId: d.id, wallet: p.wallet!, amount: p.amount, locationId: Value(loc)));
        }
      }
      if (d.utang > 0) {
        await db.into(db.localLedger).insert(LocalLedgerCompanion.insert(
              opId: opId,
              customerId: d.customerId!,
              kind: 'charge',
              amount: d.utang,
              saleId: Value(d.id),
              occurredAt: soldAt,
              locationId: Value(loc),
            ));
      }

      await enqueue(opId, 'record_sale', d.id, {
        'id': d.id,
        'local_no': localNo,
        'location_id': ?loc,
        'device_id': dev,
        'sold_at': soldAt,
        'subtotal': d.subtotal,
        'discount': d.discount,
        'total': d.total,
        'customer_id': ?d.customerId,
        'items': [
          for (final l in d.lines)
            {
              'variant_id': l.variantId,
              'name': l.name,
              'qty': l.qty,
              'unit_price': l.unitPrice,
              'unit_cost': costOf(l),
              'tax': l.lineTax,
              'line_total': l.lineTotal,
            }
        ],
        'payments': [
          for (final p in d.payments)
            {
              'method': p.method,
              'amount': p.amount,
              if (p.method == 'cash') 'tendered': p.tendered ?? p.amount,
              if (p.reference != null && p.reference!.isNotEmpty) 'reference': p.reference,
              'wallet': ?p.wallet,
            }
        ],
      });
      return SaleReceipt(d.id, localNo);
    });
  }

  /// P8-15: a named wallet must be one of [paymentWallets] and is allowed only where [allowed] (an e-wallet payment or
  /// expense). Null = not named, always fine.
  static void _checkWallet(String? wallet, bool allowed, String what) {
    if (wallet == null) return;
    if (!allowed) throw ArgumentError('Only $what names a wallet');
    if (!paymentWallets.contains(wallet)) throw ArgumentError('Unknown wallet: $wallet');
  }

  @override
  Future<void> voidSale(String saleId, {required String opId, String? reason}) {
    return db.transaction(() async {
      final sale = await (db.select(db.sales)..where((s) => s.id.equals(saleId))).getSingleOrNull();
      if (sale == null) throw StateError('Unknown sale');
      if (sale.status == 'voided') throw StateError('Sale is already cancelled');
      // its effects go back where the sale was made (the active store only for an old row that does not know its store)
      final loc = sale.locationId ?? await activeStoreNow();
      final now = _iso(DateTime.now());
      await (db.update(db.sales)..where((s) => s.id.equals(saleId)))
          .write(SalesCompanion(status: const Value('voided'), voidedAt: Value(now), voidReason: Value(reason)));
      final items = await (db.select(db.saleItems)..where((i) => i.saleId.equals(saleId))).get();
      for (final i in items.where((i) => i.tracked)) {
        await db.into(db.localMovements).insert(
            LocalMovementsCompanion.insert(opId: opId, variantId: i.variantId, qty: i.qty, locationId: Value(loc)));
      }
      final utang = await (db.select(db.salePayments)
            ..where((p) => p.saleId.equals(saleId) & p.method.equals('utang')))
          .get();
      final owed = utang.fold<int>(0, (a, p) => a + p.amount);
      if (owed > 0 && sale.customerId != null) {
        await db.into(db.localLedger).insert(LocalLedgerCompanion.insert(
              opId: opId,
              customerId: sale.customerId!,
              kind: 'adjust',
              amount: -owed,
              saleId: Value(saleId),
              note: const Value('void'),
              occurredAt: now,
              locationId: Value(loc),
            ));
      }
      // P8-15: the e-wallet payments that named a wallet leave its float (the server's sale void does the same)
      final named = await (db.select(db.salePayments)
            ..where((p) => p.saleId.equals(saleId) & p.method.equals('ewallet') & p.wallet.isNotNull())
            ..orderBy([(p) => OrderingTerm.asc(p.id)]))
          .get();
      for (final p in named) {
        await db.into(db.localFloatEffects).insert(LocalFloatEffectsCompanion.insert(
            opId: opId, txnId: saleId, wallet: p.wallet!, amount: -p.amount, locationId: Value(loc)));
      }
      await enqueue(opId, 'void_sale', saleId, {'sale_id': saleId, 'reason': ?reason, 'location_id': ?loc});
    });
  }

  /// Used when a rejected sale is discarded: it never reached the server, so it disappears here too.
  Future<void> deleteSaleRows(String saleId) async {
    await (db.delete(db.saleItems)..where((i) => i.saleId.equals(saleId))).go();
    await (db.delete(db.salePayments)..where((p) => p.saleId.equals(saleId))).go();
    await (db.delete(db.sales)..where((s) => s.id.equals(saleId))).go();
  }

  // ---------------------------------------------------------------------------
  // Customers and utang
  // ---------------------------------------------------------------------------

  @override
  Future<void> saveCustomer({required String id, required String name, String? phone, required String opId}) {
    return db.transaction(() async {
      final p = (phone == null || phone.trim().isEmpty) ? null : phone.trim();
      await db.into(db.customers).insertOnConflictUpdate(CustomersCompanion(
            id: Value(id),
            name: Value(name.trim()),
            phone: Value(p),
            deletedAt: const Value(null),
          ));
      await enqueue(opId, 'upsert_customer', id, {'id': id, 'name': name.trim(), 'phone': ?p});
    });
  }

  @override
  Future<void> recordUtangPayment({
    required String customerId,
    required int amount,
    String? note,
    String method = 'cash',
    required String opId,
  }) {
    if (amount <= 0) throw ArgumentError('Amount must be above zero');
    if (!utangPaymentMethods.contains(method)) throw ArgumentError('Unknown payment method: $method');
    return db.transaction(() async {
      final loc = await activeStoreNow();
      final at = _iso(DateTime.now());
      await db.into(db.localLedger).insert(LocalLedgerCompanion.insert(
            opId: opId,
            customerId: customerId,
            kind: 'payment',
            amount: -amount,
            note: Value(note),
            occurredAt: at,
            locationId: Value(loc),
            method: Value(method),
          ));
      await enqueue(opId, 'record_utang_payment', customerId, {
        'customer_id': customerId,
        'amount': amount,
        if (note != null && note.isNotEmpty) 'note': note,
        'occurred_at': at,
        'location_id': ?loc,
        'method': method,
      });
    });
  }

  @override
  Future<void> adjustUtang({required String customerId, required int amount, String? note, required String opId}) {
    if (amount == 0) throw ArgumentError('Amount must not be zero');
    return db.transaction(() async {
      final loc = await activeStoreNow();
      final at = _iso(DateTime.now());
      await db.into(db.localLedger).insert(LocalLedgerCompanion.insert(
            opId: opId,
            customerId: customerId,
            kind: 'adjust',
            amount: amount,
            note: Value(note),
            occurredAt: at,
            locationId: Value(loc),
          ));
      await enqueue(opId, 'adjust_utang', customerId, {
        'customer_id': customerId,
        'amount': amount,
        if (note != null && note.isNotEmpty) 'note': note,
        'occurred_at': at,
        'location_id': ?loc,
      });
    });
  }

  /// Live customers with their balance (server ledger + this device's entries not yet covered) and sending state.
  static const _customerSql = '''
    select * from (
      select c.id, c.name, c.phone, c.due_on,
             coalesce((select sum(amount) from server_ledger l where l.customer_id = c.id), 0)
           + coalesce((select sum(amount) from local_ledger l where l.customer_id = c.id), 0) as balance,
             exists (select 1 from outbox o where o.entity_id = c.id) as pending
      from customers c
      where c.deleted_at is null
    ) c
  ''';

  CustomerView _customer(QueryRow r) => CustomerView(
        id: r.read<String>('id'),
        name: r.read<String>('name'),
        phone: r.readNullable<String>('phone'),
        balance: r.read<int>('balance'),
        pending: r.read<bool>('pending'),
        dueOn: parseDay(r.readNullable<String>('due_on')),
      );

  @override
  Stream<List<CustomerView>> watchCustomers() {
    return db
        .customSelect(
          '$_customerSql order by (c.balance > 0) desc, c.balance desc, c.name collate nocase',
          readsFrom: {db.customers, db.serverLedger, db.localLedger, db.outbox},
        )
        .watch()
        .map((rows) => rows.map(_customer).toList());
  }

  // ---------------------------------------------------------------------------
  // Utang due dates (P8-10)
  //
  // The date lives on the customer row, like the name: written here and queued (entity = the customer), and the pull
  // leaves the row alone while an op for it is unsent, so the server's copy replaces it once the op has gone (the
  // server moves the row's updated_at when the date changes). Overdue is derived: balance > 0 and due_on < today.
  // ---------------------------------------------------------------------------

  @override
  Future<void> setUtangDue({required String customerId, required DateTime? dueOn, required String opId}) {
    final day = dueOn == null ? null : dateOnly(dueOn);
    if (day != null && daysBetween(DateTime.now(), day).abs() > utangDueMaxDays) {
      throw ArgumentError('A due date must be within $utangDueMaxDays days of today');
    }
    final key = day == null ? null : dayKey(day);
    return db.transaction(() async {
      final c = await (db.select(db.customers)..where((x) => x.id.equals(customerId))).getSingleOrNull();
      if (c == null) throw StateError('Unknown customer');
      await (db.update(db.customers)..where((x) => x.id.equals(customerId))).write(CustomersCompanion(dueOn: Value(key)));
      await enqueue(opId, 'set_utang_due', customerId, {'customer_id': customerId, 'due_on': key});
    });
  }

  Selectable<QueryRow> _overdueQuery(DateTime? today) => db.customSelect(
        '$_customerSql where c.balance > 0 and c.due_on is not null and c.due_on < ?1 '
        'order by c.due_on, c.name collate nocase, c.id',
        variables: [Variable.withString(dayKey(today ?? DateTime.now()))],
        readsFrom: {db.customers, db.serverLedger, db.localLedger, db.outbox},
      );

  @override
  Stream<List<CustomerView>> watchOverdueCustomers({DateTime? today}) =>
      _overdueQuery(today).watch().map((rows) => rows.map(_customer).toList());

  @override
  Future<int> overdueCount({DateTime? today}) async => (await _overdueQuery(today).get()).length;

  @override
  Stream<List<LedgerEntryView>> watchLedger(String customerId) {
    return db
        .customSelect(
          '''
          select kind, amount, note, occurred_at, local_no, pending from (
            select l.kind, l.amount, l.note, l.occurred_at, s.local_no as local_no, 0 as pending
            from server_ledger l left join sales s on s.id = l.sale_id
            where l.customer_id = ?1
            union all
            select l.kind, l.amount, l.note, l.occurred_at, s.local_no as local_no,
                   (l.confirmed_after is null) as pending
            from local_ledger l left join sales s on s.id = l.sale_id
            where l.customer_id = ?1
          ) order by occurred_at desc
          ''',
          variables: [Variable.withString(customerId)],
          readsFrom: {db.serverLedger, db.localLedger, db.sales},
        )
        .watch()
        .map((rows) => [
              for (final r in rows)
                LedgerEntryView(
                  kind: r.read<String>('kind'),
                  amount: r.read<int>('amount'),
                  note: r.readNullable<String>('note'),
                  localNo: r.readNullable<String>('local_no'),
                  at: DateTime.parse(r.read<String>('occurred_at')).toLocal(),
                  pending: r.read<bool>('pending'),
                )
            ]);
  }

  // ---------------------------------------------------------------------------
  // Sales lists and totals
  // ---------------------------------------------------------------------------

  SaleSummary _summary(QueryRow r) => SaleSummary(
        id: r.read<String>('id'),
        localNo: r.read<String>('local_no'),
        status: r.read<String>('status'),
        total: r.read<int>('total'),
        soldAt: DateTime.parse(r.read<String>('sold_at')).toLocal(),
        customerName: r.readNullable<String>('customer_name'),
        pending: r.read<bool>('pending'),
        saleNo: r.readNullable<String>('sale_no'),
      );

  static const _saleSql = '''
    select s.id, s.local_no, s.sale_no, s.status, s.total, s.sold_at,
           (select c.name from customers c where c.id = s.customer_id) as customer_name,
           exists (select 1 from outbox o where o.entity_id = s.id) as pending
    from sales s
  ''';

  /// The active store's sales (all when no store is known).
  @override
  Stream<List<SaleSummary>> watchSales({int limit = 200}) => db
      .customSelect('$_saleSql where ${inActive('s.location_id')} order by s.sold_at desc, s.local_no desc limit ?1',
          variables: [Variable.withInt(limit)], readsFrom: {db.sales, db.customers, db.outbox, db.meta})
      .watch()
      .map((rows) => rows.map(_summary).toList());

  @override
  Future<SaleDetail?> getSale(String saleId) async {
    final rows = await db.customSelect('$_saleSql where s.id = ?1', variables: [Variable.withString(saleId)]).get();
    if (rows.isEmpty) return null;
    final s = await (db.select(db.sales)..where((x) => x.id.equals(saleId))).getSingle();
    final items = await (db.select(db.saleItems)
          ..where((i) => i.saleId.equals(saleId))
          ..orderBy([(i) => OrderingTerm.asc(i.id)]))
        .get();
    final pays = await (db.select(db.salePayments)
          ..where((p) => p.saleId.equals(saleId))
          ..orderBy([(p) => OrderingTerm.asc(p.id)]))
        .get();
    return SaleDetail(
      summary: _summary(rows.first),
      subtotal: s.subtotal,
      discount: s.discount,
      tax: s.tax,
      customerId: s.customerId,
      items: [for (final i in items) SaleItemView(i.name, i.qty, i.unitPrice, i.lineTotal)],
      payments: [for (final p in pays) SalePaymentView(p.method, p.amount, p.tendered, p.reference, wallet: p.wallet)],
    );
  }

  @override
  Stream<SaleDetail?> watchSale(String saleId) => db
      .customSelect('select 1 as watch_sales_sale_items_sale_payments_outbox_customers', readsFrom: {db.sales, db.saleItems, db.salePayments, db.outbox, db.customers})
      .watch()
      .asyncMap((_) => getSale(saleId));

  @override
  Stream<TodayTotals> watchToday() {
    final n = DateTime.now();
    final from = _iso(DateTime(n.year, n.month, n.day));
    final to = _iso(DateTime(n.year, n.month, n.day + 1));
    return db
        .customSelect(
          '''
          select (select count(*) from sales s where s.status = 'completed' and s.sold_at >= ?1 and s.sold_at < ?2
                    and ${inActive('s.location_id')}) as n,
                 coalesce((select sum(s.total) from sales s where s.status = 'completed' and s.sold_at >= ?1 and s.sold_at < ?2
                    and ${inActive('s.location_id')}), 0) as total,
                 coalesce(sum(case when p.method = 'cash' then p.amount end), 0) as cash,
                 coalesce(sum(case when p.method = 'ewallet' then p.amount end), 0) as ewallet,
                 coalesce(sum(case when p.method = 'utang' then p.amount end), 0) as utang
          from sale_payments p join sales s on s.id = p.sale_id
          where s.status = 'completed' and s.sold_at >= ?1 and s.sold_at < ?2 and ${inActive('s.location_id')}
          ''',
          variables: [Variable.withString(from), Variable.withString(to)],
          readsFrom: {db.sales, db.salePayments, db.meta},
        )
        .watchSingle()
        .map((r) => TodayTotals(
              count: r.read<int>('n'),
              total: r.read<int>('total'),
              cash: r.read<int>('cash'),
              ewallet: r.read<int>('ewallet'),
              utang: r.read<int>('utang'),
            ));
  }

  // ---------------------------------------------------------------------------
  // Stock
  // ---------------------------------------------------------------------------

  /// Tingi link columns of a `variants v` row for a ProductView: the piece variant, pieces per pack, the piece's name.
  static const tingiLinkSql = '''
    v.breaks_into_variant_id, v.breaks_into_qty,
    (select pp.name from variants pv join products pp on pp.id = pv.product_id
     where pv.id = v.breaks_into_variant_id and pv.deleted_at is null and pp.deleted_at is null) as piece_name
  ''';

  /// Quantity and average cost per variant as this device sees them: the server's levels plus this device's movements
  /// the server has not caught up on, replayed in order with the server's average-cost rule (stock in with a cost:
  /// [receiptAvgCost]; pieces from an opened pack: [conversionAvgCost]; everything else moves the quantity only).
  /// F-01: at store [loc] (every store when null).
  Future<Map<String, ({double qty, int? avg})>> _effectiveStock(String? loc) async {
    final qty = <String, double>{};
    final avg = <String, int?>{};
    final levels =
        await (db.select(db.stockLevels)..where((x) => loc == null ? const Constant(true) : x.locationId.equals(loc))).get();
    for (final l in levels) {
      qty[l.variantId] = (qty[l.variantId] ?? 0) + l.qty;
      if (l.avgCost != null) avg[l.variantId] = l.avgCost;
    }
    final moves = await (db.select(db.localMovements)
          ..where((x) => loc == null ? const Constant(true) : x.locationId.equals(loc))
          ..orderBy([(m) => OrderingTerm.asc(m.id)]))
        .get();
    for (final m in moves) {
      final q0 = qty[m.variantId] ?? 0;
      if (m.qty > 0 && m.unitCost != null) {
        avg[m.variantId] = receiptAvgCost(oldQty: q0, oldCost: avg[m.variantId], qty: m.qty, unitCost: m.unitCost);
      } else if (m.qty > 0 && m.totalCost != null) {
        avg[m.variantId] =
            conversionAvgCost(oldQty: q0, oldCost: avg[m.variantId], pieces: m.qty.round(), totalCost: m.totalCost);
      }
      qty[m.variantId] = q0 + m.qty;
    }
    return {for (final k in {...qty.keys, ...avg.keys}) k: (qty: qty[k] ?? 0, avg: avg[k])};
  }

  @override
  Future<int?> averageCost(String variantId) async => (await _effectiveStock(await activeStoreNow()))[variantId]?.avg;

  @override
  Stream<Map<String, double>> watchStock() => db
      .customSelect(
        '''
        select variant_id, sum(q) as q from (
          select variant_id, qty as q, counted as c from stock_levels where ${inActive('location_id')}
          union all
          select variant_id, qty as q, counts as c from local_movements where ${inActive('location_id')}
        ) group by variant_id having max(c) = 1
        ''',
        readsFrom: {db.stockLevels, db.localMovements, db.meta},
      )
      .watch()
      .map((rows) => {for (final r in rows) r.read<String>('variant_id'): r.read<double>('q')});

  @override
  Future<void> receiveStock({
    required String variantId,
    required double qty,
    int? cost,
    DateTime? expiresOn,
    required String opId,
  }) {
    if (qty <= 0) throw ArgumentError('Quantity must be above zero');
    final exp = expiresOn == null ? null : _expiryKey(expiresOn);
    return db.transaction(() async {
      final loc = await activeStoreNow();
      if (exp != null) {
        // the server's rule on what this device sees: the earlier date while stock is on hand, else the new one
        final before = await stockLeft(variantId);
        final old = (await _expiryRow(variantId, loc))?.expiresOn;
        final keep = before > 0 && old != null && old.compareTo(exp) < 0;
        await _writeExpiry(variantId, loc, keep ? old : exp);
      }
      await db.into(db.localMovements).insert(LocalMovementsCompanion.insert(
          opId: opId, variantId: variantId, qty: qty, counts: const Value(true), unitCost: Value(cost),
          locationId: Value(loc)));
      await enqueue(opId, 'receive_stock', variantId, {
        'variant_id': variantId,
        'qty': qty,
        'unit_cost': ?cost,
        'location_id': ?loc,
        'expires_on': ?exp,
      });
    });
  }

  // ---------------------------------------------------------------------------
  // Expiry dates (P8-11)
  //
  // One date per variant (the earliest on the shelf), in `stock_expiry`. A local write leaves updated_at null; the pull
  // leaves the row alone while a set_expiry (or a receive_stock with a date) for that variant is unsent, then the server's
  // copy replaces it (the server moves the row's updated_at whenever such an op touches it).
  // ---------------------------------------------------------------------------

  /// 'YYYY-MM-DD' of [d] after checking the range the server accepts.
  static String _expiryKey(DateTime d) {
    final day = dateOnly(d);
    if (day.isBefore(expiryMinDate) || daysBetween(DateTime.now(), day) > expiryMaxDaysAhead) {
      throw ArgumentError('An expiry date must be from 2000 to $expiryMaxDaysAhead days from today');
    }
    return dayKey(day);
  }

  /// The expiry row of [variantId] at store [loc]; with no store known, a local edit first, else any row.
  Future<StockExpiryData?> _expiryRow(String variantId, String? loc) async {
    final rows = await (db.select(db.stockExpiry)
          ..where((e) => e.variantId.equals(variantId) & (loc == null ? const Constant(true) : e.locationId.equals(loc)))
          ..orderBy([(e) => OrderingTerm.asc(e.updatedAt.isNotNull()), (e) => OrderingTerm.asc(e.locationId)]))
        .get();
    return rows.isEmpty ? null : rows.first;
  }

  /// A local (unconfirmed) date for [variantId] at store [loc] ('' = no store known).
  Future<void> _writeExpiry(String variantId, String? loc, String? key) => db.into(db.stockExpiry).insertOnConflictUpdate(
      StockExpiryCompanion.insert(
          variantId: variantId, locationId: Value(loc ?? ''), expiresOn: Value(key), updatedAt: const Value(null)));

  @override
  Future<void> setExpiry({required String variantId, required DateTime? expiresOn, required String opId}) {
    final key = expiresOn == null ? null : _expiryKey(expiresOn);
    return db.transaction(() async {
      if (await (db.select(db.variants)..where((v) => v.id.equals(variantId))).getSingleOrNull() == null) {
        throw StateError('Unknown product');
      }
      final loc = await activeStoreNow();
      await _writeExpiry(variantId, loc, key);
      await enqueue(opId, 'set_expiry', variantId, {'variant_id': variantId, 'expires_on': key, 'location_id': ?loc});
    });
  }

  @override
  Stream<List<StockRow>> watchExpiring({int withinDays = 7, DateTime? today}) => watchStockList().map((rows) {
        final day = dateOnly(today ?? DateTime.now());
        final list = [
          for (final r in rows)
            if ((r.qty ?? 0) > 0 && r.daysLeft(day) != null && r.daysLeft(day)! <= withinDays) r
        ];
        list.sort((a, b) {
          final c = a.expiresOn!.compareTo(b.expiresOn!);
          return c != 0 ? c : a.product.name.toLowerCase().compareTo(b.product.name.toLowerCase());
        });
        return list;
      });

  @override
  Future<int> expiringCount({int withinDays = 7, DateTime? today}) async =>
      (await watchExpiring(withinDays: withinDays, today: today).first).length;

  /// Ops whose payload carries an expiry for their variant (entity): while one is unsent, the pulled row is not applied.
  static bool _carriesExpiry(OutboxData o) =>
      o.kind == 'set_expiry' ||
      (o.kind == 'receive_stock' && (jsonDecode(o.payload) as Map).containsKey('expires_on'));

  /// The store a queued op names (null = none: an op made while no store was known).
  static String? _opLocation(OutboxData o) => (jsonDecode(o.payload) as Map)['location_id'] as String?;

  @override
  Future<void> adjustStock({
    required String variantId,
    required double counted,
    String reason = 'counted',
    required String opId,
  }) {
    if (counted < 0) throw ArgumentError('Count cannot be negative');
    return db.transaction(() async {
      final loc = await activeStoreNow();
      final delta = counted - await stockLeft(variantId);
      if (delta.abs() < 0.0005) return; // already right: the server would write nothing either
      await db.into(db.localMovements).insert(LocalMovementsCompanion.insert(
          opId: opId, variantId: variantId, qty: delta, counts: const Value(true), locationId: Value(loc)));
      await enqueue(opId, 'adjust_stock', variantId, {
        'variant_id': variantId,
        'counted': counted,
        'reason': reason,
        'location_id': ?loc,
      });
    });
  }

  @override
  Stream<List<StockRow>> watchStockList({String query = ''}) {
    final words = searchWords(query);
    final vars = <Variable<Object>>[Variable.withString(baseCurrency)];
    final wordSql = <String>[];
    for (final w in words) {
      vars.add(Variable.withString(w));
      wordSql.add("p.search_name like '%' || ?${vars.length} || '%'");
    }
    final where = wordSql.isEmpty ? '' : ' and (${wordSql.join(' and ')})';
    return db
        .customSelect(
          '''
          select p.id, v.id as variant_id, p.name, p.unit, v.sku, v.barcode, pr.price, p.photo_path, p.active,
                 p.track_stock, p.tax_rate, v.cost, v.reorder_point, $tingiLinkSql,
                 (select min(e.expires_on) from stock_expiry e
                  where e.variant_id = v.id and ${inActive('e.location_id')}) as expires_on,
                 exists (select 1 from outbox o where o.entity_id = p.id or o.entity_id = v.id) as pending,
                 coalesce((select sum(l.qty) from stock_levels l where l.variant_id = v.id and ${inActive('l.location_id')}), 0)
               + coalesce((select sum(m.qty) from local_movements m
                           where m.variant_id = v.id and ${inActive('m.location_id')}), 0) as qty,
                 (coalesce((select max(l.counted) from stock_levels l
                            where l.variant_id = v.id and ${inActive('l.location_id')}), 0)
                  or coalesce((select max(m.counts) from local_movements m
                               where m.variant_id = v.id and ${inActive('m.location_id')}), 0)) as counted
          from products p
          join variants v on v.product_id = p.id and v.is_default = 1 and v.deleted_at is null
          left join prices pr on pr.variant_id = v.id and pr.currency = ?1 and pr.deleted_at is null
          where p.deleted_at is null and p.track_stock = 1$where
          ''',
          variables: vars,
          readsFrom: {
            db.products, db.variants, db.prices, db.stockLevels, db.localMovements, db.outbox, db.stockExpiry, db.meta,
          },
        )
        .watch()
        .map((rows) {
      final list = [
        for (final r in rows)
          StockRow(
            product: ProductView(
              id: r.read<String>('id'),
              variantId: r.read<String>('variant_id'),
              name: r.read<String>('name'),
              unit: r.read<String>('unit'),
              sku: r.read<String>('sku'),
              barcode: r.readNullable<String>('barcode'),
              price: r.readNullable<int>('price'),
              currency: baseCurrency,
              photoPath: r.readNullable<String>('photo_path'),
              active: r.read<bool>('active'),
              pending: false,
              trackStock: true,
              taxRate: r.read<double>('tax_rate'),
              cost: r.read<int>('cost'),
              reorderPoint: r.read<double>('reorder_point'),
              breaksIntoVariantId: r.readNullable<String>('breaks_into_variant_id'),
              piecesPerPack: r.readNullable<int>('breaks_into_qty'),
              pieceName: r.readNullable<String>('piece_name'),
            ),
            qty: r.read<bool>('counted') ? r.read<double>('qty') : null,
            reorderPoint: r.read<double>('reorder_point'),
            pending: r.read<bool>('pending'),
            expiresOn: parseDay(r.readNullable<String>('expires_on')),
          )
      ];
      // low first, then counted by name, then not counted
      int rank(StockRow x) => x.low ? 0 : (x.counted ? 1 : 2);
      list.sort((a, b) {
        final c = rank(a).compareTo(rank(b));
        return c != 0 ? c : a.product.name.toLowerCase().compareTo(b.product.name.toLowerCase());
      });
      return list;
    });
  }

  @override
  Future<double> stockLeft(String variantId) async {
    final r = await db.customSelect(
      '''
      select coalesce((select sum(qty) from stock_levels where variant_id = ?1 and ${inActive('location_id')}), 0)
           + coalesce((select sum(qty) from local_movements where variant_id = ?1 and ${inActive('location_id')}), 0) as q
      ''',
      variables: [Variable.withString(variantId)],
    ).getSingle();
    return r.read<double>('q');
  }

  static const _pinnedKey = 'pinned_variants';

  @override
  Future<Set<String>> pinnedVariants() async {
    final raw = await meta(_pinnedKey);
    if (raw == null || raw.isEmpty) return <String>{};
    return raw.split(',').where((e) => e.isNotEmpty).toSet();
  }

  @override
  Future<void> setPinned(String variantId, bool pinned) async {
    final now = await pinnedVariants();
    pinned ? now.add(variantId) : now.remove(variantId);
    await setMeta(_pinnedKey, now.isEmpty ? null : now.join(','));
  }

  @override
  Future<List<ProductView>> quickItems({int limit = 12}) async {
    final since = _iso(DateTime.now().subtract(const Duration(days: 30)));
    final pinned = (await pinnedVariants()).toList();
    // pinned ids are bound as variables (?4...), never spliced into the SQL
    final pinnedSql = pinned.isEmpty
        ? 'case when 1 = 0 then 1 else 0 end'
        : 'case when v.id in (${[for (var i = 0; i < pinned.length; i++) '?${i + 4}'].join(',')}) then 1 else 0 end';
    final rows = await db.customSelect(
      '''
      select p.id, v.id as variant_id, p.name, p.unit, v.sku, v.barcode, pr.price, p.photo_path, p.active,
             p.track_stock, p.tax_rate, v.cost, v.reorder_point, $tingiLinkSql,
             exists (select 1 from outbox o where o.entity_id = p.id) as pending
      from products p
      join variants v on v.product_id = p.id and v.is_default = 1 and v.deleted_at is null
      left join prices pr on pr.variant_id = v.id and pr.currency = ?1 and pr.deleted_at is null
      left join (
        select i.variant_id, sum(i.qty) as sold
        from sale_items i join sales s on s.id = i.sale_id
        where s.status = 'completed' and s.sold_at >= ?2 and ${inActive('s.location_id')}
        group by i.variant_id
      ) t on t.variant_id = v.id
      where p.deleted_at is null and p.active = 1 and pr.price is not null and v.sku <> '$openAmountSku'
      order by $pinnedSql desc, coalesce(t.sold, 0) desc, coalesce(p.updated_at, '9999') desc, p.search_name
      limit ?3
      ''',
      variables: [
        Variable.withString(baseCurrency),
        Variable.withString(since),
        Variable.withInt(limit),
        for (final id in pinned) Variable.withString(id),
      ],
    ).get();
    return [
      for (final r in rows)
        ProductView(
          id: r.read<String>('id'),
          variantId: r.read<String>('variant_id'),
          name: r.read<String>('name'),
          unit: r.read<String>('unit'),
          sku: r.read<String>('sku'),
          barcode: r.readNullable<String>('barcode'),
          price: r.readNullable<int>('price'),
          currency: baseCurrency,
          photoPath: r.readNullable<String>('photo_path'),
          active: r.read<bool>('active'),
          pending: r.read<bool>('pending'),
          trackStock: r.read<bool>('track_stock'),
          taxRate: r.read<double>('tax_rate'),
          cost: r.read<int>('cost'),
          reorderPoint: r.read<double>('reorder_point'),
          breaksIntoVariantId: r.readNullable<String>('breaks_into_variant_id'),
          piecesPerPack: r.readNullable<int>('breaks_into_qty'),
          pieceName: r.readNullable<String>('piece_name'),
        )
    ];
  }

  // ---------------------------------------------------------------------------
  // Expenses and the day close (P8-02c)
  //
  // An expense or a day close is one row, like a sale: made here and queued, or pulled. The server's copy replaces the
  // local row when it arrives, so nothing is counted twice. "Pending" = the id still has an op in the outbox;
  // "rejected" = that op was refused (status failed) and waits for the user.
  // Supervisors: the approval id comes from Backend.approveSupervisorAction (needs signal); the PIN never comes here.
  // ---------------------------------------------------------------------------

  static const approvalKinds = {'record_expense', 'void_expense', 'close_day', 'record_service_txn', 'void_service_txn'};

  /// [from, to) of the local calendar day of [day], as normalised UTC ISO strings.
  static (String, String) _dayBounds(DateTime day) =>
      (_iso(DateTime(day.year, day.month, day.day)), _iso(DateTime(day.year, day.month, day.day + 1)));

  /// Trimmed, null when empty, at most 200 characters (the server keeps the same).
  static String? _text200(String? s) {
    final t = s?.trim();
    if (t == null || t.isEmpty) return null;
    return t.length > 200 ? t.substring(0, 200) : t;
  }

  static const _pendingSql = '''
    exists (select 1 from outbox o where o.entity_id = x.id) as pending,
    (select o.last_error from outbox o where o.entity_id = x.id and o.status = 'failed' order by o.seq desc limit 1)
      as rejected
  ''';

  @override
  Future<void> recordExpense({
    required String id,
    required int amount,
    required String category,
    String paidFrom = 'cash',
    String? wallet,
    String? note,
    DateTime? spentAt,
    String? approvalId,
    required String opId,
  }) {
    if (amount <= 0) throw ArgumentError('Amount must be above zero');
    if (!expenseCategories.contains(category)) throw ArgumentError('Unknown expense category: $category');
    if (!expensePaidFrom.contains(paidFrom)) throw ArgumentError('Paid from must be cash or ewallet');
    _checkWallet(wallet, paidFrom == 'ewallet', 'an e-wallet expense');
    final n = _text200(note);
    return db.transaction(() async {
      if (await (db.select(db.expenses)..where((e) => e.id.equals(id))).getSingleOrNull() != null) {
        throw StateError('Expense id already used');
      }
      final loc = await activeStoreNow();
      final at = _iso(spentAt ?? DateTime.now());
      await db.into(db.expenses).insert(ExpensesCompanion.insert(
            id: id,
            locationId: Value(loc),
            amount: amount,
            currency: baseCurrency,
            category: category,
            paidFrom: Value(paidFrom),
            wallet: Value(wallet),
            note: Value(n),
            spentAt: at,
          ));
      // P8-15: the money left the named wallet
      if (wallet != null) {
        await db.into(db.localFloatEffects).insert(LocalFloatEffectsCompanion.insert(
            opId: opId, txnId: id, wallet: wallet, amount: -amount, locationId: Value(loc)));
      }
      await enqueue(opId, 'record_expense', id, {
        'id': id,
        'amount': amount,
        'category': category,
        'paid_from': paidFrom,
        'wallet': ?wallet,
        'note': ?n,
        'spent_at': at,
        'location_id': ?loc,
        'approval_id': ?approvalId,
      });
    });
  }

  @override
  Future<void> voidExpense({required String expenseId, String? reason, String? approvalId, required String opId}) {
    return db.transaction(() async {
      final e = await (db.select(db.expenses)..where((x) => x.id.equals(expenseId))).getSingleOrNull();
      if (e == null) throw StateError('Unknown expense');
      if (e.voidedAt != null) throw StateError('Expense is already voided');
      final r = _text200(reason);
      await (db.update(db.expenses)..where((x) => x.id.equals(expenseId)))
          .write(ExpensesCompanion(voidedAt: Value(_iso(DateTime.now())), voidReason: Value(r)));
      // P8-15: the money goes back to the named wallet (the server's void does the same)
      if (e.paidFrom == 'ewallet' && e.wallet != null) {
        await db.into(db.localFloatEffects).insert(LocalFloatEffectsCompanion.insert(
            opId: opId, txnId: expenseId, wallet: e.wallet!, amount: e.amount,
            locationId: Value(e.locationId ?? await activeStoreNow())));
      }
      await enqueue(opId, 'void_expense', expenseId, {'expense_id': expenseId, 'reason': ?r, 'approval_id': ?approvalId});
    });
  }

  ExpenseView _expense(QueryRow r) => ExpenseView(
        id: r.read<String>('id'),
        amount: r.read<int>('amount'),
        category: r.read<String>('category'),
        paidFrom: r.read<String>('paid_from'),
        wallet: r.readNullable<String>('wallet'),
        note: r.readNullable<String>('note'),
        spentAt: DateTime.parse(r.read<String>('spent_at')).toLocal(),
        voidedAt: r.readNullable<String>('voided_at') == null ? null : DateTime.parse(r.read<String>('voided_at')).toLocal(),
        voidReason: r.readNullable<String>('void_reason'),
        approvedBy: r.readNullable<String>('approved_by'),
        pending: r.read<bool>('pending'),
        rejectedHint: r.readNullable<String>('rejected'),
      );

  @override
  Stream<List<ExpenseView>> watchExpenses({required DateTime from, required DateTime to}) => db
      .customSelect(
        '''
        select x.id, x.amount, x.category, x.paid_from, x.wallet, x.note, x.spent_at, x.voided_at, x.void_reason,
               x.approved_by,
               $_pendingSql
        from expenses x
        where x.spent_at >= ?1 and x.spent_at < ?2 and ${inActive('x.location_id')}
        order by x.spent_at desc, x.id desc
        ''',
        variables: [Variable.withString(_iso(from)), Variable.withString(_iso(to))],
        readsFrom: {db.expenses, db.outbox, db.meta},
      )
      .watch()
      .map((rows) => rows.map(_expense).toList());

  @override
  Stream<ExpenseTotals> watchTodayExpenses() {
    final (from, to) = _dayBounds(DateTime.now());
    return db
        .customSelect(
          '''
          select count(*) as n, coalesce(sum(amount), 0) as total,
                 coalesce(sum(case when paid_from = 'cash' then amount end), 0) as cash,
                 coalesce(sum(case when paid_from = 'ewallet' then amount end), 0) as ewallet
          from expenses
          where voided_at is null and spent_at >= ?1 and spent_at < ?2 and ${inActive('location_id')}
          ''',
          variables: [Variable.withString(from), Variable.withString(to)],
          readsFrom: {db.expenses, db.meta},
        )
        .watchSingle()
        .map((r) => ExpenseTotals(
              count: r.read<int>('n'),
              total: r.read<int>('total'),
              cash: r.read<int>('cash'),
              ewallet: r.read<int>('ewallet'),
            ));
  }

  // Server ledger times are kept as the server sent them (any offset), so they are compared through julianday();
  // everything else is stored as normalised UTC ISO text and compared as text (index friendly).
  // F-01: everything is the active store's ([activeSql]; every store when none), and only CASH utang payments taken at
  // that store count (the same rule as the server's day_close_server_expected).
  // ?1 / ?2 = the day's bounds; ?3 = the opening cash asked for (null = the default); ?4 = the day key.
  // Expected cash = the day's cash flow + the opening cash (P8-14).
  static final _expectedCashSql = '''
    select ($_cashFlowSql) + $_openingSql as expected
  ''';

  /// The opening cash: ?3 when given, else the counted cash of the newest close (by closed_at) of an EARLIER day at the
  /// active store (closes without a store count), else 0. Same-day re-counts and later days never count.
  static const _openingSql = '''
    coalesce(?3, (select x.counted_cash from day_closes x
                  where x.day < ?4 and ($activeSql is null or x.location_id is null or x.location_id = $activeSql)
                  order by x.closed_at desc, x.id desc limit 1), 0)
  ''';

  static final _cashFlowSql = '''
      coalesce((select sum(p.amount) from sale_payments p join sales s on s.id = p.sale_id
                where s.status = 'completed' and p.method = 'cash' and s.sold_at >= ?1 and s.sold_at < ?2
                  and ${inActive('s.location_id')}), 0)
    - coalesce((select sum(l.amount) from server_ledger l
                where l.kind = 'payment' and l.method = 'cash' and ${inActive('l.location_id')}
                  and julianday(l.occurred_at) >= julianday(?1) and julianday(l.occurred_at) < julianday(?2)), 0)
    - coalesce((select sum(l.amount) from local_ledger l
                where l.kind = 'payment' and l.method = 'cash' and ${inActive('l.location_id')}
                  and l.occurred_at >= ?1 and l.occurred_at < ?2), 0)
    - coalesce((select sum(e.amount) from expenses e
                where e.voided_at is null and e.paid_from = 'cash' and e.spent_at >= ?1 and e.spent_at < ?2
                  and ${inActive('e.location_id')}), 0)
    + coalesce((select sum($_serviceCashSql) from service_txns t
                where t.voided_at is null and t.txn_at >= ?1 and t.txn_at < ?2 and ${inActive('t.location_id')}), 0)
  ''';

  /// [serviceCashEffect] in SQL, for a `service_txns t` row.
  static const _serviceCashSql = '''
    case t.kind when 'cash_in' then t.amount + t.fee when 'cash_out' then t.fee - t.amount
                when 'load' then coalesce(t.price, t.amount + t.fee)
                when 'float_topup' then -t.amount when 'float_withdraw' then t.amount else 0 end
  ''';

  /// The variables of [_expectedCashSql] / [_openingSql] (see the comment there).
  List<Variable<Object>> _cashVars(DateTime day, int? openingCash) {
    if (openingCash != null && openingCash < 0) throw ArgumentError('Opening cash cannot be negative');
    final (from, to) = _dayBounds(day);
    return [
      Variable.withString(from),
      Variable.withString(to),
      Variable<int>(openingCash),
      Variable.withString(dayKey(day)),
    ];
  }

  Selectable<QueryRow> _expectedCashQuery(DateTime day, int? openingCash) => db.customSelect(_expectedCashSql,
      variables: _cashVars(day, openingCash),
      readsFrom: {
        db.sales, db.salePayments, db.serverLedger, db.localLedger, db.expenses, db.serviceTxns, db.dayCloses, db.meta,
      });

  @override
  Future<int> expectedCash(DateTime day, {int? openingCash}) async =>
      (await _expectedCashQuery(day, openingCash).getSingle()).read<int>('expected');

  @override
  Stream<int> watchExpectedCash(DateTime day, {int? openingCash}) =>
      _expectedCashQuery(day, openingCash).watchSingle().map((r) => r.read<int>('expected'));

  @override
  Future<int> defaultOpeningCash(DateTime day) async => (await db
          .customSelect('select $_openingSql as opening', variables: _cashVars(day, null), readsFrom: {db.dayCloses, db.meta})
          .getSingle())
      .read<int>('opening');

  @override
  Future<void> closeDay({
    required String id,
    required DateTime day,
    required int countedCash,
    int? openingCash,
    String? note,
    String? approvalId,
    required String opId,
  }) {
    if (countedCash < 0) throw ArgumentError('Counted cash cannot be negative');
    if (openingCash != null && openingCash < 0) throw ArgumentError('Opening cash cannot be negative');
    final n = _text200(note);
    return db.transaction(() async {
      if (await (db.select(db.dayCloses)..where((d) => d.id.equals(id))).getSingleOrNull() != null) {
        throw StateError('Day close id already used');
      }
      // one opening for both the stored row and the expected cash, so difference = counted - (flow + opening)
      final loc = await activeStoreNow();
      final opening = openingCash ?? await defaultOpeningCash(day);
      final expected = await expectedCash(day, openingCash: opening);
      final key = dayKey(day);
      final at = _iso(DateTime.now());
      await db.into(db.dayCloses).insert(DayClosesCompanion.insert(
            id: id,
            locationId: Value(loc),
            day: key,
            currency: baseCurrency,
            openingCash: Value(opening),
            expectedCash: expected,
            countedCash: countedCash,
            difference: countedCash - expected,
            note: Value(n),
            closedAt: at,
          ));
      await enqueue(opId, 'close_day', id, {
        'id': id,
        'day': key,
        'opening_cash': opening,
        'expected_cash': expected,
        'counted_cash': countedCash,
        'closed_at': at,
        'note': ?n,
        'location_id': ?loc,
        'approval_id': ?approvalId,
      });
    });
  }

  /// The active store's newest close of the day (closes without a store count, as for the opening cash).
  @override
  Stream<DayCloseView?> watchLatestDayClose(DateTime day) => db
      .customSelect(
        '''
        select x.id, x.day, x.opening_cash, x.expected_cash, x.counted_cash, x.difference, x.server_expected_cash, x.note,
               x.closed_at, x.approved_by, $_pendingSql
        from day_closes x
        where x.day = ?1 and ($activeSql is null or x.location_id is null or x.location_id = $activeSql)
        order by x.closed_at desc, x.id desc
        limit 1
        ''',
        variables: [Variable.withString(dayKey(day))],
        readsFrom: {db.dayCloses, db.outbox, db.meta},
      )
      .watch()
      .map((rows) => rows.isEmpty
          ? null
          : DayCloseView(
              id: rows.first.read<String>('id'),
              day: rows.first.read<String>('day'),
              openingCash: rows.first.read<int>('opening_cash'),
              expectedCash: rows.first.read<int>('expected_cash'),
              countedCash: rows.first.read<int>('counted_cash'),
              difference: rows.first.read<int>('difference'),
              serverExpectedCash: rows.first.readNullable<int>('server_expected_cash'),
              note: rows.first.readNullable<String>('note'),
              closedAt: DateTime.parse(rows.first.read<String>('closed_at')).toLocal(),
              approvedBy: rows.first.readNullable<String>('approved_by'),
              pending: rows.first.read<bool>('pending'),
              rejectedHint: rows.first.readNullable<String>('rejected'),
            ));

  // ---------------------------------------------------------------------------
  // Load / e-wallet services (P8-06)
  //
  // An entry is one row, like an expense (the server's copy replaces it when pulled). The float is NOT summed from the
  // rows (the server's balance covers years of entries and other devices): it is the pulled balance per wallet plus
  // `local_float_effects`, one row per record / void made here, dropped once a pulled balance includes it.
  // P8-15: sales (e-wallet payments that name a wallet, and their cancel) and e-wallet expenses that name a wallet (and
  // their void) add rows there too, under their own op id, so the same confirm / drop / discard rules apply.
  // ---------------------------------------------------------------------------

  @override
  Future<void> recordServiceTxn({
    required String id,
    required String kind,
    required String wallet,
    required int amount,
    int fee = 0,
    int? price,
    String? ref,
    String? note,
    DateTime? txnAt,
    String? approvalId,
    required String opId,
  }) {
    if (!serviceKinds.contains(kind)) throw ArgumentError('Unknown service kind: $kind');
    if (!serviceWallets.contains(wallet)) throw ArgumentError('Unknown wallet: $wallet');
    if ((kind == 'cash_in' || kind == 'cash_out') && wallet == 'load') {
      throw ArgumentError('A cash-in or cash-out uses an e-wallet, not the load wallet');
    }
    if (amount == 0 || (kind != 'float_adjust' && amount < 0)) throw ArgumentError('Amount must be above zero');
    if (fee < 0) throw ArgumentError('Fee cannot be negative');
    var f = fee;
    if (kind == 'load') {
      if (price == null || price < amount) throw ArgumentError('A load needs a price of at least the amount');
      if (fee != 0 && fee != price - amount) throw ArgumentError('A load fee is price - amount');
      f = price - amount;
    } else {
      if (price != null) throw ArgumentError('Only a load has a price');
      if (!customerServiceKinds.contains(kind) && fee != 0) throw ArgumentError('Moving float has no fee');
    }
    final r = _text200(ref);
    final n = _text200(note);
    if (kind == 'float_adjust' && n == null) throw ArgumentError('A float correction needs a note');
    return db.transaction(() async {
      if (await (db.select(db.serviceTxns)..where((t) => t.id.equals(id))).getSingleOrNull() != null) {
        throw StateError('Service entry id already used');
      }
      final loc = await activeStoreNow();
      final at = _iso(txnAt ?? DateTime.now());
      await db.into(db.serviceTxns).insert(ServiceTxnsCompanion.insert(
            id: id,
            locationId: Value(loc),
            kind: kind,
            wallet: wallet,
            amount: amount,
            fee: Value(f),
            price: Value(kind == 'load' ? price : null),
            currency: baseCurrency,
            ref: Value(r),
            note: Value(n),
            txnAt: at,
          ));
      await db.into(db.localFloatEffects).insert(LocalFloatEffectsCompanion.insert(
          opId: opId, txnId: id, wallet: wallet, amount: serviceFloatEffect(kind, amount), locationId: Value(loc)));
      await enqueue(opId, 'record_service_txn', id, {
        'id': id,
        'kind': kind,
        'wallet': wallet,
        'amount': amount,
        'fee': f,
        if (kind == 'load') 'price': price,
        'ref': ?r,
        'note': ?n,
        'txn_at': at,
        'location_id': ?loc,
        'approval_id': ?approvalId,
      });
    });
  }

  @override
  Future<void> voidServiceTxn({required String txnId, String? reason, String? approvalId, required String opId}) {
    return db.transaction(() async {
      final t = await (db.select(db.serviceTxns)..where((x) => x.id.equals(txnId))).getSingleOrNull();
      if (t == null) throw StateError('Unknown service entry');
      if (t.voidedAt != null) throw StateError('Service entry is already voided');
      final r = _text200(reason);
      await (db.update(db.serviceTxns)..where((x) => x.id.equals(txnId)))
          .write(ServiceTxnsCompanion(voidedAt: Value(_iso(DateTime.now())), voidReason: Value(r)));
      await db.into(db.localFloatEffects).insert(LocalFloatEffectsCompanion.insert(
          opId: opId, txnId: txnId, wallet: t.wallet, amount: -serviceFloatEffect(t.kind, t.amount),
          locationId: Value(t.locationId ?? await activeStoreNow())));
      await enqueue(opId, 'void_service_txn', txnId, {'txn_id': txnId, 'reason': ?r, 'approval_id': ?approvalId});
    });
  }

  static DateTime? _localOrNull(String? iso) => iso == null ? null : DateTime.parse(iso).toLocal();

  // ---------------------------------------------------------------------------
  // Tingi / repack (P8-08)
  //
  // The link lives on the pack's variant row (pulled with the catalog). An opening is one `conversions` row plus two
  // `local_movements` (pack out, pieces in with the value they carry) under the op id, so the stock numbers follow the
  // P4-02 rule: counted until the server's levels have caught up, then dropped, never twice.
  // ---------------------------------------------------------------------------

  /// A live variant and its live product, or null.
  Future<(Variant, Product)?> _liveVariant(String variantId) async {
    final v = await (db.select(db.variants)..where((x) => x.id.equals(variantId) & x.deletedAt.isNull())).getSingleOrNull();
    if (v == null) return null;
    final p = await (db.select(db.products)..where((x) => x.id.equals(v.productId) & x.deletedAt.isNull())).getSingleOrNull();
    return p == null ? null : (v, p);
  }

  @override
  Future<void> setTingiLink({required String variantId, String? pieceVariantId, int? piecesPerPack, required String opId}) {
    if (pieceVariantId != null) {
      if (piecesPerPack == null || piecesPerPack < 1 || piecesPerPack > tingiMaxRatio) {
        throw ArgumentError('Pieces per pack must be a whole number from 1 to $tingiMaxRatio');
      }
      if (pieceVariantId == variantId) throw ArgumentError('A pack cannot break into itself');
    }
    return db.transaction(() async {
      final pack = await _liveVariant(variantId);
      if (pack == null) throw StateError('Unknown product');
      final ratio = pieceVariantId == null ? null : piecesPerPack;
      if (pieceVariantId != null) {
        final piece = await _liveVariant(pieceVariantId);
        if (piece == null) throw StateError('Unknown or archived piece product');
        if (!pack.$2.trackStock || !piece.$2.trackStock) throw StateError('Both products must keep a stock count');
        // no chains, like the server: the piece must not be a pack, the pack must not be anyone's piece
        if (piece.$1.breaksIntoVariantId != null) throw StateError('The piece is itself a pack');
        final asPiece = await (db.select(db.variants)
              ..where((x) => x.breaksIntoVariantId.equals(variantId) & x.id.equals(variantId).not() & x.deletedAt.isNull()))
            .get();
        if (asPiece.isNotEmpty) throw StateError('This product is already the piece of another pack');
      }
      await (db.update(db.variants)..where((x) => x.id.equals(variantId)))
          .write(VariantsCompanion(breaksIntoVariantId: Value(pieceVariantId), breaksIntoQty: Value(ratio)));
      await enqueue(opId, 'set_tingi_link', pack.$2.id,
          {'variant_id': variantId, 'piece_variant_id': pieceVariantId, 'pieces_per_pack': ratio});
    });
  }

  @override
  Future<void> clearTingiLink({required String variantId, required String opId}) =>
      setTingiLink(variantId: variantId, opId: opId);

  @override
  Future<ProductView?> tingiPiece(String packVariantId) async {
    final rows = await db.customSelect(
      '''
      select p.id, v.id as variant_id, p.name, p.unit, v.sku, v.barcode, pr.price, p.photo_path, p.active,
             p.track_stock, p.tax_rate, v.cost, v.reorder_point, $tingiLinkSql,
             exists (select 1 from outbox o where o.entity_id = p.id) as pending
      from variants pack
      join variants v on v.id = pack.breaks_into_variant_id and v.deleted_at is null
      join products p on p.id = v.product_id and p.deleted_at is null
      left join prices pr on pr.variant_id = v.id and pr.currency = ?2 and pr.deleted_at is null
      where pack.id = ?1
      ''',
      variables: [Variable.withString(packVariantId), Variable.withString(baseCurrency)],
    ).get();
    if (rows.isEmpty) return null;
    final r = rows.first;
    return ProductView(
      id: r.read<String>('id'),
      variantId: r.read<String>('variant_id'),
      name: r.read<String>('name'),
      unit: r.read<String>('unit'),
      sku: r.read<String>('sku'),
      barcode: r.readNullable<String>('barcode'),
      price: r.readNullable<int>('price'),
      currency: baseCurrency,
      photoPath: r.readNullable<String>('photo_path'),
      active: r.read<bool>('active'),
      pending: r.read<bool>('pending'),
      trackStock: r.read<bool>('track_stock'),
      taxRate: r.read<double>('tax_rate'),
      cost: r.read<int>('cost'),
      reorderPoint: r.read<double>('reorder_point'),
      breaksIntoVariantId: r.readNullable<String>('breaks_into_variant_id'),
      piecesPerPack: r.readNullable<int>('breaks_into_qty'),
      pieceName: r.readNullable<String>('piece_name'),
    );
  }

  @override
  Future<OpenedPack> openPack({
    required String id,
    required String packVariantId,
    required int packs,
    String? note,
    DateTime? at,
    required String opId,
  }) {
    if (packs < 1 || packs > tingiMaxPacks) throw ArgumentError('Packs must be a whole number from 1 to $tingiMaxPacks');
    final n = _text200(note);
    return db.transaction(() async {
      if (await (db.select(db.conversions)..where((c) => c.id.equals(id))).getSingleOrNull() != null) {
        throw StateError('Pack opening id already used');
      }
      final pack = await _liveVariant(packVariantId);
      if (pack == null) throw StateError('Unknown product');
      final pieceId = pack.$1.breaksIntoVariantId;
      final ratio = pack.$1.breaksIntoQty;
      if (pieceId == null || ratio == null) throw StateError('This product is not sold by the piece');
      final piece = await _liveVariant(pieceId);
      if (piece == null) throw StateError('The piece product is archived');
      if (!pack.$2.trackStock || !piece.$2.trackStock) throw StateError('Both products must keep a stock count');
      final pieces = packs * ratio;
      if (pieces > 1000000) throw ArgumentError('Too many pieces at once');

      // the cost rule (P8-08): the pack's average cost at this store, else its variant cost when > 0; packs x that, exact
      final loc = await activeStoreNow();
      final packAvg = (await _effectiveStock(loc))[packVariantId]?.avg;
      final packCost = packAvg ?? (pack.$1.cost > 0 ? pack.$1.cost : null);
      final total = packCost == null ? null : packs * packCost;
      final pieceCost = conversionAvgCost(oldQty: 0, pieces: pieces, totalCost: total);
      final when = _iso(at ?? DateTime.now());

      await db.into(db.conversions).insert(ConversionsCompanion.insert(
            id: id,
            locationId: Value(loc),
            packVariantId: packVariantId,
            pieceVariantId: pieceId,
            packs: packs,
            ratio: ratio,
            pieces: pieces,
            packCost: Value(packCost),
            totalCost: Value(total),
            pieceCost: Value(pieceCost),
            note: Value(n),
            convertedAt: when,
          ));
      await db.into(db.localMovements).insert(LocalMovementsCompanion.insert(
          opId: opId, variantId: packVariantId, qty: -packs.toDouble(), locationId: Value(loc)));
      await db.into(db.localMovements).insert(LocalMovementsCompanion.insert(
          opId: opId, variantId: pieceId, qty: pieces.toDouble(), counts: const Value(true), totalCost: Value(total),
          locationId: Value(loc)));
      await enqueue(opId, 'open_pack', id, {
        'id': id,
        'pack_variant_id': packVariantId,
        'packs': packs,
        // what this phone showed: the server refuses the op (link_changed) if the link is different by then
        'piece_variant_id': pieceId,
        'pieces_per_pack': ratio,
        'note': ?n,
        'at': when,
        'location_id': ?loc,
      });
      return OpenedPack(
        conversionId: id,
        pieceVariantId: pieceId,
        packs: packs,
        pieces: pieces,
        packCost: packCost,
        totalCost: total,
        pieceCost: pieceCost,
      );
    });
  }

  @override
  Future<void> voidOpenPack({required String conversionId, String? reason, required String opId}) {
    return db.transaction(() async {
      final c = await (db.select(db.conversions)..where((x) => x.id.equals(conversionId))).getSingleOrNull();
      if (c == null) throw StateError('Unknown pack opening');
      if (c.voidedAt != null) throw StateError('Pack opening is already voided');
      final r = _text200(reason);
      await (db.update(db.conversions)..where((x) => x.id.equals(conversionId)))
          .write(ConversionsCompanion(voidedAt: Value(_iso(DateTime.now())), voidReason: Value(r)));
      // back at the store where the pack was opened
      final loc = c.locationId ?? await activeStoreNow();
      await db.into(db.localMovements).insert(LocalMovementsCompanion.insert(
          opId: opId, variantId: c.packVariantId, qty: c.packs.toDouble(), locationId: Value(loc)));
      await db.into(db.localMovements).insert(LocalMovementsCompanion.insert(
          opId: opId, variantId: c.pieceVariantId, qty: -c.pieces.toDouble(), locationId: Value(loc)));
      await enqueue(opId, 'void_open_pack', conversionId, {'conversion_id': conversionId, 'reason': ?r});
    });
  }

  @override
  Stream<List<ConversionView>> watchConversions({required DateTime from, required DateTime to}) => db
      .customSelect(
        '''
        select x.id, x.pack_variant_id, x.piece_variant_id, x.packs, x.ratio, x.pieces, x.pack_cost, x.total_cost,
               x.piece_cost, x.note, x.converted_at, x.voided_at, x.void_reason,
               (select p.name from variants v join products p on p.id = v.product_id where v.id = x.pack_variant_id) as pack_name,
               (select p.name from variants v join products p on p.id = v.product_id where v.id = x.piece_variant_id) as piece_name,
               $_pendingSql
        from conversions x
        where x.converted_at >= ?1 and x.converted_at < ?2 and ${inActive('x.location_id')}
        order by x.converted_at desc, x.id desc
        ''',
        variables: [Variable.withString(_iso(from)), Variable.withString(_iso(to))],
        readsFrom: {db.conversions, db.outbox, db.variants, db.products, db.meta},
      )
      .watch()
      .map((rows) => [
            for (final r in rows)
              ConversionView(
                id: r.read<String>('id'),
                packVariantId: r.read<String>('pack_variant_id'),
                pieceVariantId: r.read<String>('piece_variant_id'),
                packName: r.readNullable<String>('pack_name'),
                pieceName: r.readNullable<String>('piece_name'),
                packs: r.read<int>('packs'),
                ratio: r.read<int>('ratio'),
                pieces: r.read<int>('pieces'),
                packCost: r.readNullable<int>('pack_cost'),
                totalCost: r.readNullable<int>('total_cost'),
                pieceCost: r.readNullable<int>('piece_cost'),
                note: r.readNullable<String>('note'),
                convertedAt: DateTime.parse(r.read<String>('converted_at')).toLocal(),
                voidedAt: _localOrNull(r.readNullable<String>('voided_at')),
                voidReason: r.readNullable<String>('void_reason'),
                pending: r.read<bool>('pending'),
                rejectedHint: r.readNullable<String>('rejected'),
              )
          ]);

  @override
  Future<void> applyPullConversions(Map<String, dynamic> response) {
    return db.transaction(() async {
      final rows = ((response['rows'] as List?) ?? const []).cast<Map<String, dynamic>>();
      final unsent = (await db.select(db.outbox).get()).map((o) => o.entityId).toSet();
      for (final r in rows) {
        final id = r['id'] as String;
        var voidedAt = r['voided_at'] == null ? null : _utc(r['voided_at'] as String);
        var voidReason = r['void_reason'] as String?;
        if (voidedAt == null && unsent.contains(id)) {
          // a void made here is still on its way: keep it until the server's voided copy comes
          final local = await (db.select(db.conversions)..where((c) => c.id.equals(id))).getSingleOrNull();
          if (local?.voidedAt != null) {
            voidedAt = local!.voidedAt;
            voidReason = local.voidReason;
          }
        }
        await db.into(db.conversions).insertOnConflictUpdate(ConversionsCompanion.insert(
              id: id,
              locationId: Value(r['location_id'] as String? ?? _sole),
              packVariantId: r['pack_variant_id'] as String,
              pieceVariantId: r['piece_variant_id'] as String,
              packs: (r['packs'] as num).toInt(),
              ratio: (r['ratio'] as num).toInt(),
              pieces: (r['pieces'] as num).toInt(),
              packCost: Value((r['pack_cost'] as num?)?.toInt()),
              totalCost: Value((r['total_cost'] as num?)?.toInt()),
              pieceCost: Value((r['piece_cost'] as num?)?.toInt()),
              note: Value(r['note'] as String?),
              convertedAt: _utc(r['converted_at'] as String),
              createdBy: Value(r['created_by'] as String?),
              voidedAt: Value(voidedAt),
              voidReason: Value(voidReason),
              updatedAt: Value(r['updated_at'] as String?),
            ));
      }
      await _saveCursor('conversions', response['cursor']);
    });
  }

  @override
  Stream<List<ServiceTxnView>> watchServiceTxns({required DateTime from, required DateTime to}) => db
      .customSelect(
        '''
        select x.id, x.kind, x.wallet, x.amount, x.fee, x.price, x.ref, x.note, x.txn_at, x.voided_at, x.void_reason,
               x.approved_by, $_pendingSql
        from service_txns x
        where x.txn_at >= ?1 and x.txn_at < ?2 and ${inActive('x.location_id')}
        order by x.txn_at desc, x.id desc
        ''',
        variables: [Variable.withString(_iso(from)), Variable.withString(_iso(to))],
        readsFrom: {db.serviceTxns, db.outbox, db.meta},
      )
      .watch()
      .map((rows) => [
            for (final r in rows)
              ServiceTxnView(
                id: r.read<String>('id'),
                kind: r.read<String>('kind'),
                wallet: r.read<String>('wallet'),
                amount: r.read<int>('amount'),
                fee: r.read<int>('fee'),
                price: r.readNullable<int>('price'),
                ref: r.readNullable<String>('ref'),
                note: r.readNullable<String>('note'),
                txnAt: DateTime.parse(r.read<String>('txn_at')).toLocal(),
                voidedAt: _localOrNull(r.readNullable<String>('voided_at')),
                voidReason: r.readNullable<String>('void_reason'),
                approvedBy: r.readNullable<String>('approved_by'),
                pending: r.read<bool>('pending'),
                rejectedHint: r.readNullable<String>('rejected'),
              )
          ]);

  @override
  Stream<ServiceTotals> watchTodayServices() {
    final (from, to) = _dayBounds(DateTime.now());
    return db
        .customSelect(
          '''
          select coalesce(sum(t.kind in ('cash_in', 'cash_out', 'load')), 0) as n,
                 coalesce(sum(t.fee), 0) as fees,
                 coalesce(sum(case when t.kind = 'cash_in' then t.amount end), 0) as cash_in,
                 coalesce(sum(case when t.kind = 'cash_out' then t.amount end), 0) as cash_out,
                 coalesce(sum(case when t.kind = 'load' then coalesce(t.price, t.amount + t.fee) end), 0) as load_sales,
                 coalesce(sum($_serviceCashSql), 0) as cash
          from service_txns t
          where t.voided_at is null and t.txn_at >= ?1 and t.txn_at < ?2 and ${inActive('t.location_id')}
          ''',
          variables: [Variable.withString(from), Variable.withString(to)],
          readsFrom: {db.serviceTxns, db.meta},
        )
        .watchSingle()
        .map((r) => ServiceTotals(
              count: r.read<int>('n'),
              fees: r.read<int>('fees'),
              cashIn: r.read<int>('cash_in'),
              cashOut: r.read<int>('cash_out'),
              loadSales: r.read<int>('load_sales'),
              cash: r.read<int>('cash'),
            ));
  }

  @override
  Stream<List<WalletFloatView>> watchWalletFloat() => db
      .customSelect(
        '''
        select wallet, sum(b) as balance, max(p) as pending from (
          select w.wallet, w.balance as b, 0 as p from wallet_float w where ${inActive('w.location_id')}
          union all
          select e.wallet, e.amount as b, 1 as p from local_float_effects e where ${inActive('e.location_id')}
        ) group by wallet
        ''',
        readsFrom: {db.walletFloats, db.localFloatEffects, db.meta},
      )
      .watch()
      .map((rows) {
        final list = [
          for (final r in rows)
            WalletFloatView(wallet: r.read<String>('wallet'), balance: r.read<int>('balance'), pending: r.read<bool>('pending'))
        ];
        int rank(String w) {
          final i = serviceWallets.indexOf(w);
          return i < 0 ? serviceWallets.length : i;
        }

        return list..sort((a, b) => rank(a.wallet).compareTo(rank(b.wallet)));
      });

  @override
  Future<void> applyPullService(Map<String, dynamic> response) {
    return db.transaction(() async {
      final rows = ((response['rows'] as List?) ?? const []).cast<Map<String, dynamic>>();
      final unsent = (await db.select(db.outbox).get()).map((o) => o.entityId).toSet();
      for (final r in rows) {
        final id = r['id'] as String;
        var voidedAt = r['voided_at'] == null ? null : _utc(r['voided_at'] as String);
        var voidReason = r['void_reason'] as String?;
        if (voidedAt == null && unsent.contains(id)) {
          // a void made here is still on its way: keep it until the server's voided copy comes
          final local = await (db.select(db.serviceTxns)..where((t) => t.id.equals(id))).getSingleOrNull();
          if (local?.voidedAt != null) {
            voidedAt = local!.voidedAt;
            voidReason = local.voidReason;
          }
        }
        await db.into(db.serviceTxns).insertOnConflictUpdate(ServiceTxnsCompanion.insert(
              id: id,
              locationId: Value(r['location_id'] as String? ?? _sole),
              kind: r['kind'] as String,
              wallet: r['wallet'] as String,
              amount: (r['amount'] as num).toInt(),
              fee: Value((r['fee'] as num?)?.toInt() ?? 0),
              price: Value((r['price'] as num?)?.toInt()),
              currency: (r['currency'] as String).trim(),
              ref: Value(r['ref'] as String?),
              note: Value(r['note'] as String?),
              txnAt: _utc(r['txn_at'] as String),
              createdBy: Value(r['created_by'] as String?),
              approvedBy: Value(r['approved_by'] as String?),
              voidedAt: Value(voidedAt),
              voidReason: Value(voidReason),
              voidApprovedBy: Value(r['void_approved_by'] as String?),
              updatedAt: Value(r['updated_at'] as String?),
            ));
      }
      final floats = response['floats'];
      final st = response['server_time'];
      if (floats is List && st is String) {
        for (final f in floats.cast<Map<String, dynamic>>()) {
          await db.into(db.walletFloats).insertOnConflictUpdate(WalletFloatsCompanion.insert(
                locationId: f['location_id'] as String,
                wallet: f['wallet'] as String,
                balance: (f['balance'] as num).toInt(),
                txnCount: Value((f['txn_count'] as num?)?.toInt() ?? 0),
                updatedAt: Value(f['updated_at'] as String?),
              ));
        }
        // the balance was read at server_time: every op the server applied before then is in it
        final asOf = DateTime.parse(st);
        for (final e in await (db.select(db.localFloatEffects)..where((x) => x.confirmedAfter.isNotNull())).get()) {
          if (!DateTime.parse(e.confirmedAfter!).isAfter(asOf)) {
            await (db.delete(db.localFloatEffects)..where((x) => x.id.equals(e.id))).go();
          }
        }
      }
      await _saveCursor('service_txns', response['cursor']);
    });
  }

  @override
  Future<void> saveOfflinePins(String locationId, List<Map<String, dynamic>> pins) async {
    await setMeta('offline_pins_$locationId', jsonEncode(pins));
  }

  @override
  Future<List<Map<String, dynamic>>> getOfflinePins({String? locationId}) async {
    final loc = locationId ?? await activeStoreNow() ?? 'global';
    final raw = await meta('offline_pins_$loc');
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> requeueWithApproval({
    required String opId,
    String? approvalId,
    Map<String, dynamic>? offlineApproval,
  }) {
    if (approvalId == null && offlineApproval == null) {
      throw ArgumentError('Either approvalId or offlineApproval must be provided');
    }
    return db.transaction(() async {
      final op = await (db.select(db.outbox)..where((o) => o.opId.equals(opId))).getSingleOrNull();
      if (op == null) throw StateError('Unknown op');
      if (!approvalKinds.contains(op.kind)) throw ArgumentError('${op.kind} does not take an approval');
      if (op.status != 'failed') throw StateError('Only a refused op can be sent again');
      final payload = (jsonDecode(op.payload) as Map).cast<String, dynamic>();
      if (approvalId != null) payload['approval_id'] = approvalId;
      if (offlineApproval != null) payload['offline_approval'] = offlineApproval;
      await (db.update(db.outbox)..where((o) => o.opId.equals(opId))).write(OutboxCompanion(
            payload: Value(jsonEncode(payload)),
            status: const Value('pending'),
            attempts: const Value(0),
            lastError: const Value(null),
          ));
    });
  }

  /// Takes back what a discarded (refused) op did on this device. A refused op left nothing on the server.
  /// (Its stock, utang and float effects are removed by op id in `discardFailed`.)
  Future<void> undoLocalOp(String kind, String entityId, [Map<String, dynamic> payload = const {}]) async {
    if (kind == 'set_expiry' || (kind == 'receive_stock' && payload.containsKey('expires_on'))) {
      // the locally written date at the op's store goes (unless another unsent op still carries one for the variant
      // there); the server's date, if it has one, comes back with the full re-pull that discardFailed forces
      final loc = payload['location_id'] as String? ?? await activeStoreNow() ?? '';
      final others = (await (db.select(db.outbox)..where((o) => o.entityId.equals(entityId))).get())
          .where((o) => _carriesExpiry(o) && (_opLocation(o) == null || _opLocation(o) == loc));
      if (others.isEmpty) {
        await (db.delete(db.stockExpiry)
              ..where((e) => e.variantId.equals(entityId) & e.locationId.equals(loc) & e.updatedAt.isNull()))
            .go();
      }
    }
    switch (kind) {
      case 'record_expense':
        await (db.delete(db.expenses)..where((e) => e.id.equals(entityId) & e.updatedAt.isNull())).go();
      case 'void_expense':
        await (db.update(db.expenses)..where((e) => e.id.equals(entityId)))
            .write(const ExpensesCompanion(voidedAt: Value(null), voidReason: Value(null)));
      case 'close_day':
        await (db.delete(db.dayCloses)..where((d) => d.id.equals(entityId) & d.updatedAt.isNull())).go();
      case 'record_service_txn':
        await (db.delete(db.serviceTxns)..where((t) => t.id.equals(entityId) & t.updatedAt.isNull())).go();
      case 'void_service_txn':
        await (db.update(db.serviceTxns)..where((t) => t.id.equals(entityId)))
            .write(const ServiceTxnsCompanion(voidedAt: Value(null), voidReason: Value(null)));
      case 'open_pack':
        await (db.delete(db.conversions)..where((c) => c.id.equals(entityId) & c.updatedAt.isNull())).go();
      case 'void_open_pack':
        await (db.update(db.conversions)..where((c) => c.id.equals(entityId)))
            .write(const ConversionsCompanion(voidedAt: Value(null), voidReason: Value(null)));
      // set_tingi_link, set_utang_due: nothing to undo here; discardFailed forces a full re-pull, which brings the
      // server's link / due date back (the customer row is no longer held once its op is gone)
    }
  }

  @override
  Future<void> applyPullExpenses(Map<String, dynamic> response) {
    return db.transaction(() async {
      final rows = ((response['rows'] as List?) ?? const []).cast<Map<String, dynamic>>();
      final unsent = (await db.select(db.outbox).get()).map((o) => o.entityId).toSet();
      for (final r in rows) {
        final id = r['id'] as String;
        var voidedAt = r['voided_at'] == null ? null : _utc(r['voided_at'] as String);
        var voidReason = r['void_reason'] as String?;
        if (voidedAt == null && unsent.contains(id)) {
          // a void made here is still on its way: keep it until the server's voided copy comes
          final local = await (db.select(db.expenses)..where((e) => e.id.equals(id))).getSingleOrNull();
          if (local?.voidedAt != null) {
            voidedAt = local!.voidedAt;
            voidReason = local.voidReason;
          }
        }
        await db.into(db.expenses).insertOnConflictUpdate(ExpensesCompanion.insert(
              id: id,
              locationId: Value(r['location_id'] as String? ?? _sole),
              amount: (r['amount'] as num).toInt(),
              currency: (r['currency'] as String).trim(),
              category: r['category'] as String,
              paidFrom: Value(r['paid_from'] as String? ?? 'cash'),
              // absent from a server before P8-15: no wallet named
              wallet: Value(r['wallet'] as String?),
              note: Value(r['note'] as String?),
              spentAt: _utc(r['spent_at'] as String),
              createdBy: Value(r['created_by'] as String?),
              approvedBy: Value(r['approved_by'] as String?),
              voidedAt: Value(voidedAt),
              voidReason: Value(voidReason),
              voidApprovedBy: Value(r['void_approved_by'] as String?),
              updatedAt: Value(r['updated_at'] as String?),
            ));
      }
      await _saveCursor('expenses', response['cursor']);
    });
  }

  @override
  Future<void> applyPullDayCloses(Map<String, dynamic> response) {
    return db.transaction(() async {
      // closes never change on the server: its copy is the local one plus the server's own figures
      for (final r in ((response['rows'] as List?) ?? const []).cast<Map<String, dynamic>>()) {
        await db.into(db.dayCloses).insertOnConflictUpdate(DayClosesCompanion.insert(
              id: r['id'] as String,
              locationId: Value(r['location_id'] as String? ?? _sole),
              day: r['day'] as String,
              currency: (r['currency'] as String).trim(),
              // absent from a server before P8-14: those closes had no opening cash
              openingCash: Value((r['opening_cash'] as num?)?.toInt() ?? 0),
              expectedCash: (r['expected_cash'] as num).toInt(),
              countedCash: (r['counted_cash'] as num).toInt(),
              difference: (r['difference'] as num).toInt(),
              serverExpectedCash: Value((r['server_expected_cash'] as num?)?.toInt()),
              note: Value(r['note'] as String?),
              closedBy: Value(r['closed_by'] as String?),
              approvedBy: Value(r['approved_by'] as String?),
              closedAt: _utc(r['closed_at'] as String),
              updatedAt: Value(r['updated_at'] as String?),
            ));
      }
      await _saveCursor('day_closes', response['cursor']);
    });
  }

  Future<void> _saveCursor(String key, Object? cursor) async {
    if (cursor is Map) {
      await db
          .into(db.syncCursors)
          .insertOnConflictUpdate(SyncCursorsCompanion.insert(tableKey: key, cursorJson: jsonEncode(cursor)));
    }
  }

  // ---------------------------------------------------------------------------
  // Sync
  // ---------------------------------------------------------------------------

  @override
  Future<void> posOpApplied(String opId, String? appliedAt, {Map<String, dynamic>? result}) async {
    // F-02: a confirmed sale learns its server number at once (the sales pull brings it too; whichever comes first)
    final saleNo = result?['sale_no'];
    final saleId = result?['sale_id'];
    if (saleNo is String && saleNo.isNotEmpty && saleId is String) {
      await (db.update(db.sales)..where((s) => s.id.equals(saleId))).write(SalesCompanion(saleNo: Value(saleNo)));
    }
    final at = appliedAt ?? _iso(DateTime.now());
    await (db.update(db.localMovements)..where((m) => m.opId.equals(opId)))
        .write(LocalMovementsCompanion(confirmedAfter: Value(at)));
    await (db.update(db.localLedger)..where((m) => m.opId.equals(opId)))
        .write(LocalLedgerCompanion(confirmedAfter: Value(at)));
    await (db.update(db.localFloatEffects)..where((m) => m.opId.equals(opId)))
        .write(LocalFloatEffectsCompanion(confirmedAfter: Value(at)));
  }

  static String _utc(String iso) => DateTime.parse(iso).toUtc().toIso8601String();

  @override
  Future<void> applyPullSales(Map<String, dynamic> response) {
    return db.transaction(() async {
      final rows = ((response['rows'] as List?) ?? const []).cast<Map<String, dynamic>>();
      final unsent = (await db.select(db.outbox).get()).map((o) => o.entityId).toSet();
      for (final r in rows) {
        final id = r['id'] as String;
        // F-02: absent / null from a server before F-02 or for an old row: never erase a number already stored
        final saleNo = r['sale_no'] is String ? Value(r['sale_no'] as String) : const Value<String?>.absent();
        final deviceId = r['device_id'] is String ? Value(r['device_id'] as String) : const Value<String?>.absent();
        if (unsent.contains(id)) {
          // a local change (e.g. a cancel) is still on its way: keep ours, but take the server's number if we lack it
          if (saleNo.present) {
            await (db.update(db.sales)..where((s) => s.id.equals(id) & s.saleNo.isNull()))
                .write(SalesCompanion(saleNo: saleNo));
          }
          continue;
        }
        await db.into(db.sales).insertOnConflictUpdate(SalesCompanion.insert(
              id: id,
              // F-01: the server names the store; an older server does not (then: the user's only store, if one)
              locationId: Value(r['location_id'] as String? ?? _sole),
              saleNo: saleNo,
              deviceId: deviceId,
              localNo: r['local_no'] as String,
              status: Value(r['status'] as String),
              subtotal: (r['subtotal'] as num).toInt(),
              discount: Value((r['discount'] as num).toInt()),
              tax: Value((r['tax'] as num).toInt()),
              total: (r['total'] as num).toInt(),
              customerId: Value(r['customer_id'] as String?),
              soldAt: _utc(r['sold_at'] as String),
              voidedAt: Value(r['voided_at'] == null ? null : _utc(r['voided_at'] as String)),
              voidReason: Value(r['void_reason'] as String?),
            ));
        await (db.delete(db.saleItems)..where((i) => i.saleId.equals(id))).go();
        await (db.delete(db.salePayments)..where((p) => p.saleId.equals(id))).go();
        for (final i in (r['items'] as List).cast<Map<String, dynamic>>()) {
          await db.into(db.saleItems).insert(SaleItemsCompanion.insert(
                saleId: id,
                variantId: i['variant_id'] as String,
                name: i['name'] as String,
                qty: (i['qty'] as num).toDouble(),
                unitPrice: (i['unit_price'] as num).toInt(),
                unitCost: Value((i['unit_cost'] as num).toInt()),
                discount: Value((i['discount'] as num).toInt()),
                tax: Value((i['tax'] as num).toInt()),
                lineTotal: (i['line_total'] as num).toInt(),
                tracked: Value(i['tracked'] as bool? ?? true),
              ));
        }
        for (final p in (r['payments'] as List).cast<Map<String, dynamic>>()) {
          await db.into(db.salePayments).insert(SalePaymentsCompanion.insert(
                saleId: id,
                method: p['method'] as String,
                amount: (p['amount'] as num).toInt(),
                tendered: Value((p['tendered'] as num?)?.toInt()),
                reference: Value(p['reference'] as String?),
                // absent from a server before P8-15: no wallet named
                wallet: Value(p['wallet'] as String?),
              ));
        }
      }
      final cursor = response['cursor'];
      if (cursor is Map) {
        await db
            .into(db.syncCursors)
            .insertOnConflictUpdate(SyncCursorsCompanion.insert(tableKey: 'sales', cursorJson: jsonEncode(cursor)));
      }
    });
  }

  static const _posTables = ['stock_levels', 'customers', 'customer_ledger', 'stock_expiry'];

  @override
  Future<void> applyPullPos(Map<String, dynamic> response) {
    return db.transaction(() async {
      List<Map<String, dynamic>> rowsOf(String t) =>
          (((response[t] as Map?)?['rows'] as List?) ?? const []).cast<Map<String, dynamic>>();

      for (final r in rowsOf('stock_levels')) {
        await db.into(db.stockLevels).insertOnConflictUpdate(StockLevelsCompanion.insert(
              locationId: r['location_id'] as String,
              variantId: r['variant_id'] as String,
              qty: (r['qty_on_hand'] as num).toDouble(),
              avgCost: Value((r['avg_cost'] as num?)?.toInt()),
              counted: Value(r['counted'] as bool? ?? false),
              updatedAt: r['updated_at'] as String,
            ));
      }
      // customers: keep the local copy while an edit of it is still unsent
      final unsent = (await db.select(db.outbox).get()).map((o) => o.entityId).toSet();
      for (final r in rowsOf('customers')) {
        if (unsent.contains(r['id'])) continue;
        await db.into(db.customers).insertOnConflictUpdate(CustomersCompanion.insert(
              id: r['id'] as String,
              name: r['name'] as String,
              phone: Value(r['phone'] as String?),
              updatedAt: Value(r['updated_at'] as String?),
              deletedAt: Value(r['deleted_at'] as String?),
              dueOn: Value(r['due_on'] as String?),
            ));
      }
      // expiry dates: every store the user can see (F-01; reads use the active store); keep the local date of a store
      // while an op carrying one for that variant there (or naming no store) is unsent
      final expiryOps = [for (final o in await db.select(db.outbox).get()) if (_carriesExpiry(o)) o];
      for (final r in rowsOf('stock_expiry')) {
        final vid = r['variant_id'] as String;
        final loc = r['location_id'] as String? ?? _sole ?? '';
        if (expiryOps.any((o) => o.entityId == vid && (_opLocation(o) == null || _opLocation(o) == loc))) continue;
        await db.into(db.stockExpiry).insertOnConflictUpdate(StockExpiryCompanion.insert(
              variantId: vid,
              locationId: Value(loc),
              expiresOn: Value(r['expires_on'] as String?),
              updatedAt: Value(r['updated_at'] as String?),
            ));
      }
      for (final r in rowsOf('customer_ledger')) {
        await db.into(db.serverLedger).insertOnConflictUpdate(ServerLedgerCompanion.insert(
              id: r['id'] as String,
              customerId: r['customer_id'] as String,
              kind: r['kind'] as String,
              amount: (r['amount'] as num).toInt(),
              saleId: Value(r['sale_id'] as String?),
              note: Value(r['note'] as String?),
              occurredAt: r['occurred_at'] as String,
              createdAt: r['created_at'] as String,
              // F-01; an older server sends neither: the user's only store, cash (what such a row meant)
              locationId: Value(r['location_id'] as String? ?? _sole),
              method: Value(r['method'] as String? ?? 'cash'),
            ));
      }
      for (final t in _posTables) {
        final cursor = (response[t] as Map?)?['cursor'];
        if (cursor is Map) {
          await db
              .into(db.syncCursors)
              .insertOnConflictUpdate(SyncCursorsCompanion.insert(tableKey: t, cursorJson: jsonEncode(cursor)));
        }
      }

      // When the pull is complete, everything the server did up to (server time - 5 s hold-back) is in the
      // local copy, so effects applied before that moment no longer need to be counted separately.
      final more = _posTables.any((t) => (response[t] as Map?)?['has_more'] == true);
      final st = response['server_time'];
      if (!more && st is String) {
        final horizon = DateTime.parse(st).subtract(const Duration(seconds: 5));
        // a stock effect also needs the local level row (of its store) to be at least as new as the op, otherwise a
        // newer change (not returned yet because of the hold-back) would leave the level short for a while. A movement
        // that does not know its store compares with the newest level of the variant at any store.
        final levelAt = <String, DateTime>{};
        void keep(String k, DateTime t) {
          final old = levelAt[k];
          if (old == null || t.isAfter(old)) levelAt[k] = t;
        }
        for (final l in await db.select(db.stockLevels).get()) {
          final t = DateTime.parse(l.updatedAt);
          keep('${l.locationId}|${l.variantId}', t);
          keep('*|${l.variantId}', t);
        }
        for (final m in await (db.select(db.localMovements)..where((x) => x.confirmedAfter.isNotNull())).get()) {
          final at = DateTime.parse(m.confirmedAfter!);
          final lvl = levelAt['${m.locationId ?? '*'}|${m.variantId}'];
          if (!at.isAfter(horizon) && lvl != null && !lvl.isBefore(at)) {
            await (db.delete(db.localMovements)..where((x) => x.id.equals(m.id))).go();
          }
        }
        for (final m in await (db.select(db.localLedger)..where((x) => x.confirmedAfter.isNotNull())).get()) {
          if (!DateTime.parse(m.confirmedAfter!).isAfter(horizon)) {
            await (db.delete(db.localLedger)..where((x) => x.id.equals(m.id))).go();
          }
        }
      }
    });
  }
}
