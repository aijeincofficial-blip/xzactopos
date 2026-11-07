import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

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

  @override
  String? locationId;

  static String _iso(DateTime t) => t.toUtc().toIso8601String();

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

    return db.transaction(() async {
      final localNo = await _nextReceiptNo(d.soldAt.toLocal());
      final soldAt = _iso(d.soldAt);
      final tax = d.lines.fold<int>(0, (a, l) => a + l.lineTax);
      // cost snapshot: the average cost the server reported for this product, else the cost on the line
      final avgCost = <String, int>{
        for (final r in await db.select(db.stockLevels).get())
          if (r.avgCost != null) r.variantId: r.avgCost!
      };
      int costOf(SaleLine l) => avgCost[l.variantId] ?? l.unitCost;

      await db.into(db.sales).insert(SalesCompanion.insert(
            id: d.id,
            localNo: localNo,
            subtotal: d.subtotal,
            discount: Value(d.discount),
            tax: Value(tax),
            total: d.total,
            customerId: Value(d.customerId),
            soldAt: soldAt,
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
          await db.into(db.localMovements).insert(
              LocalMovementsCompanion.insert(opId: opId, variantId: l.variantId, qty: -l.qty));
        }
      }
      for (final p in d.payments) {
        await db.into(db.salePayments).insert(SalePaymentsCompanion.insert(
              saleId: d.id,
              method: p.method,
              amount: p.amount,
              tendered: Value(p.method == 'cash' ? (p.tendered ?? p.amount) : null),
              reference: Value(p.reference),
            ));
      }
      if (d.utang > 0) {
        await db.into(db.localLedger).insert(LocalLedgerCompanion.insert(
              opId: opId,
              customerId: d.customerId!,
              kind: 'charge',
              amount: d.utang,
              saleId: Value(d.id),
              occurredAt: soldAt,
            ));
      }

      await enqueue(opId, 'record_sale', d.id, {
        'id': d.id,
        'local_no': localNo,
        'location_id': ?locationId,
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
            }
        ],
      });
      return SaleReceipt(d.id, localNo);
    });
  }

  @override
  Future<void> voidSale(String saleId, {required String opId, String? reason}) {
    return db.transaction(() async {
      final sale = await (db.select(db.sales)..where((s) => s.id.equals(saleId))).getSingleOrNull();
      if (sale == null) throw StateError('Unknown sale');
      if (sale.status == 'voided') throw StateError('Sale is already cancelled');
      final now = _iso(DateTime.now());
      await (db.update(db.sales)..where((s) => s.id.equals(saleId)))
          .write(SalesCompanion(status: const Value('voided'), voidedAt: Value(now), voidReason: Value(reason)));
      final items = await (db.select(db.saleItems)..where((i) => i.saleId.equals(saleId))).get();
      for (final i in items.where((i) => i.tracked)) {
        await db.into(db.localMovements).insert(
            LocalMovementsCompanion.insert(opId: opId, variantId: i.variantId, qty: i.qty));
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
            ));
      }
      await enqueue(opId, 'void_sale', saleId, {'sale_id': saleId, 'reason': ?reason});
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
    required String opId,
  }) {
    if (amount <= 0) throw ArgumentError('Amount must be above zero');
    return db.transaction(() async {
      final at = _iso(DateTime.now());
      await db.into(db.localLedger).insert(LocalLedgerCompanion.insert(
            opId: opId,
            customerId: customerId,
            kind: 'payment',
            amount: -amount,
            note: Value(note),
            occurredAt: at,
          ));
      await enqueue(opId, 'record_utang_payment', customerId, {
        'customer_id': customerId,
        'amount': amount,
        if (note != null && note.isNotEmpty) 'note': note,
        'occurred_at': at,
      });
    });
  }

  @override
  Stream<List<CustomerView>> watchCustomers() {
    return db
        .customSelect(
          '''
          select c.id, c.name, c.phone,
                 coalesce((select sum(amount) from server_ledger l where l.customer_id = c.id), 0)
               + coalesce((select sum(amount) from local_ledger l where l.customer_id = c.id), 0) as balance,
                 exists (select 1 from outbox o where o.entity_id = c.id) as pending
          from customers c
          where c.deleted_at is null
          order by (balance > 0) desc, balance desc, c.name collate nocase
          ''',
          readsFrom: {db.customers, db.serverLedger, db.localLedger, db.outbox},
        )
        .watch()
        .map((rows) => [
              for (final r in rows)
                CustomerView(
                  id: r.read<String>('id'),
                  name: r.read<String>('name'),
                  phone: r.readNullable<String>('phone'),
                  balance: r.read<int>('balance'),
                  pending: r.read<bool>('pending'),
                )
            ]);
  }

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
      );

  static const _saleSql = '''
    select s.id, s.local_no, s.status, s.total, s.sold_at,
           (select c.name from customers c where c.id = s.customer_id) as customer_name,
           exists (select 1 from outbox o where o.entity_id = s.id) as pending
    from sales s
  ''';

  @override
  Stream<List<SaleSummary>> watchSales({int limit = 200}) => db
      .customSelect('$_saleSql order by s.sold_at desc, s.local_no desc limit ?1',
          variables: [Variable.withInt(limit)], readsFrom: {db.sales, db.customers, db.outbox})
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
      payments: [for (final p in pays) SalePaymentView(p.method, p.amount, p.tendered, p.reference)],
    );
  }

  @override
  Stream<SaleDetail?> watchSale(String saleId) => db
      .customSelect('select 1', readsFrom: {db.sales, db.saleItems, db.salePayments, db.outbox, db.customers})
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
          select (select count(*) from sales s where s.status = 'completed' and s.sold_at >= ?1 and s.sold_at < ?2) as n,
                 coalesce((select sum(s.total) from sales s where s.status = 'completed' and s.sold_at >= ?1 and s.sold_at < ?2), 0) as total,
                 coalesce(sum(case when p.method = 'cash' then p.amount end), 0) as cash,
                 coalesce(sum(case when p.method = 'ewallet' then p.amount end), 0) as ewallet,
                 coalesce(sum(case when p.method = 'utang' then p.amount end), 0) as utang
          from sale_payments p join sales s on s.id = p.sale_id
          where s.status = 'completed' and s.sold_at >= ?1 and s.sold_at < ?2
          ''',
          variables: [Variable.withString(from), Variable.withString(to)],
          readsFrom: {db.sales, db.salePayments},
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

  @override
  Stream<Map<String, double>> watchStock() => db
      .customSelect(
        '''
        select variant_id, sum(q) as q from (
          select variant_id, qty as q, counted as c from stock_levels
          union all
          select variant_id, qty as q, counts as c from local_movements
        ) group by variant_id having max(c) = 1
        ''',
        readsFrom: {db.stockLevels, db.localMovements},
      )
      .watch()
      .map((rows) => {for (final r in rows) r.read<String>('variant_id'): r.read<double>('q')});

  @override
  Future<void> receiveStock({required String variantId, required double qty, int? cost, required String opId}) {
    if (qty <= 0) throw ArgumentError('Quantity must be above zero');
    return db.transaction(() async {
      await db.into(db.localMovements).insert(
          LocalMovementsCompanion.insert(opId: opId, variantId: variantId, qty: qty, counts: const Value(true)));
      await enqueue(opId, 'receive_stock', variantId, {
        'variant_id': variantId,
        'qty': qty,
        'unit_cost': ?cost,
        'location_id': ?locationId,
      });
    });
  }

  @override
  Future<void> adjustStock({
    required String variantId,
    required double counted,
    String reason = 'counted',
    required String opId,
  }) {
    if (counted < 0) throw ArgumentError('Count cannot be negative');
    return db.transaction(() async {
      final delta = counted - await stockLeft(variantId);
      if (delta.abs() < 0.0005) return; // already right: the server would write nothing either
      await db.into(db.localMovements).insert(
          LocalMovementsCompanion.insert(opId: opId, variantId: variantId, qty: delta, counts: const Value(true)));
      await enqueue(opId, 'adjust_stock', variantId, {
        'variant_id': variantId,
        'counted': counted,
        'reason': reason,
        'location_id': ?locationId,
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
                 p.track_stock, p.tax_rate, v.cost, v.reorder_point,
                 exists (select 1 from outbox o where o.entity_id = p.id or o.entity_id = v.id) as pending,
                 coalesce((select sum(l.qty) from stock_levels l where l.variant_id = v.id), 0)
               + coalesce((select sum(m.qty) from local_movements m where m.variant_id = v.id), 0) as qty,
                 (coalesce((select max(l.counted) from stock_levels l where l.variant_id = v.id), 0)
                  or coalesce((select max(m.counts) from local_movements m where m.variant_id = v.id), 0)) as counted
          from products p
          join variants v on v.product_id = p.id and v.is_default = 1 and v.deleted_at is null
          left join prices pr on pr.variant_id = v.id and pr.currency = ?1 and pr.deleted_at is null
          where p.deleted_at is null and p.track_stock = 1$where
          ''',
          variables: vars,
          readsFrom: {db.products, db.variants, db.prices, db.stockLevels, db.localMovements, db.outbox},
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
            ),
            qty: r.read<bool>('counted') ? r.read<double>('qty') : null,
            reorderPoint: r.read<double>('reorder_point'),
            pending: r.read<bool>('pending'),
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
      select coalesce((select sum(qty) from stock_levels where variant_id = ?1), 0)
           + coalesce((select sum(qty) from local_movements where variant_id = ?1), 0) as q
      ''',
      variables: [Variable.withString(variantId)],
    ).getSingle();
    return r.read<double>('q');
  }

  @override
  Future<List<ProductView>> quickItems({int limit = 12}) async {
    final since = _iso(DateTime.now().subtract(const Duration(days: 30)));
    final rows = await db.customSelect(
      '''
      select p.id, v.id as variant_id, p.name, p.unit, v.sku, v.barcode, pr.price, p.photo_path, p.active,
             p.track_stock, p.tax_rate, v.cost, v.reorder_point,
             exists (select 1 from outbox o where o.entity_id = p.id) as pending
      from products p
      join variants v on v.product_id = p.id and v.is_default = 1 and v.deleted_at is null
      left join prices pr on pr.variant_id = v.id and pr.currency = ?1 and pr.deleted_at is null
      left join (
        select i.variant_id, sum(i.qty) as sold
        from sale_items i join sales s on s.id = i.sale_id
        where s.status = 'completed' and s.sold_at >= ?2
        group by i.variant_id
      ) t on t.variant_id = v.id
      where p.deleted_at is null and p.active = 1 and pr.price is not null
      order by coalesce(t.sold, 0) desc, coalesce(p.updated_at, '9999') desc, p.search_name
      limit ?3
      ''',
      variables: [Variable.withString(baseCurrency), Variable.withString(since), Variable.withInt(limit)],
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
        )
    ];
  }

  // ---------------------------------------------------------------------------
  // Sync
  // ---------------------------------------------------------------------------

  @override
  Future<void> posOpApplied(String opId, String? appliedAt) async {
    final at = appliedAt ?? _iso(DateTime.now());
    await (db.update(db.localMovements)..where((m) => m.opId.equals(opId)))
        .write(LocalMovementsCompanion(confirmedAfter: Value(at)));
    await (db.update(db.localLedger)..where((m) => m.opId.equals(opId)))
        .write(LocalLedgerCompanion(confirmedAfter: Value(at)));
  }

  static const _posTables = ['stock_levels', 'customers', 'customer_ledger'];

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
        // a stock effect also needs the local level row to be at least as new as the op, otherwise a newer
        // change (not returned yet because of the hold-back) would leave the level short for a while
        final levelAt = <String, DateTime>{};
        for (final l in await db.select(db.stockLevels).get()) {
          final t = DateTime.parse(l.updatedAt);
          final old = levelAt[l.variantId];
          if (old == null || t.isAfter(old)) levelAt[l.variantId] = t;
        }
        for (final m in await (db.select(db.localMovements)..where((x) => x.confirmedAfter.isNotNull())).get()) {
          final at = DateTime.parse(m.confirmedAfter!);
          final lvl = levelAt[m.variantId];
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
