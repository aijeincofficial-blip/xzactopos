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
  Future<void> adjustUtang({required String customerId, required int amount, String? note, required String opId}) {
    if (amount == 0) throw ArgumentError('Amount must not be zero');
    return db.transaction(() async {
      final at = _iso(DateTime.now());
      await db.into(db.localLedger).insert(LocalLedgerCompanion.insert(
            opId: opId,
            customerId: customerId,
            kind: 'adjust',
            amount: amount,
            note: Value(note),
            occurredAt: at,
          ));
      await enqueue(opId, 'adjust_utang', customerId, {
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
    String? note,
    DateTime? spentAt,
    String? approvalId,
    required String opId,
  }) {
    if (amount <= 0) throw ArgumentError('Amount must be above zero');
    if (!expenseCategories.contains(category)) throw ArgumentError('Unknown expense category: $category');
    if (!expensePaidFrom.contains(paidFrom)) throw ArgumentError('Paid from must be cash or ewallet');
    final n = _text200(note);
    return db.transaction(() async {
      if (await (db.select(db.expenses)..where((e) => e.id.equals(id))).getSingleOrNull() != null) {
        throw StateError('Expense id already used');
      }
      final at = _iso(spentAt ?? DateTime.now());
      await db.into(db.expenses).insert(ExpensesCompanion.insert(
            id: id,
            locationId: Value(locationId),
            amount: amount,
            currency: baseCurrency,
            category: category,
            paidFrom: Value(paidFrom),
            note: Value(n),
            spentAt: at,
          ));
      await enqueue(opId, 'record_expense', id, {
        'id': id,
        'amount': amount,
        'category': category,
        'paid_from': paidFrom,
        'note': ?n,
        'spent_at': at,
        'location_id': ?locationId,
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
      await enqueue(opId, 'void_expense', expenseId, {'expense_id': expenseId, 'reason': ?r, 'approval_id': ?approvalId});
    });
  }

  ExpenseView _expense(QueryRow r) => ExpenseView(
        id: r.read<String>('id'),
        amount: r.read<int>('amount'),
        category: r.read<String>('category'),
        paidFrom: r.read<String>('paid_from'),
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
        select x.id, x.amount, x.category, x.paid_from, x.note, x.spent_at, x.voided_at, x.void_reason, x.approved_by,
               $_pendingSql
        from expenses x
        where x.spent_at >= ?1 and x.spent_at < ?2
        order by x.spent_at desc, x.id desc
        ''',
        variables: [Variable.withString(_iso(from)), Variable.withString(_iso(to))],
        readsFrom: {db.expenses, db.outbox},
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
          where voided_at is null and spent_at >= ?1 and spent_at < ?2
          ''',
          variables: [Variable.withString(from), Variable.withString(to)],
          readsFrom: {db.expenses},
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
  // Utang payments are cash (the server has no payment method or store on them).
  static const _expectedCashSql = '''
    select
      coalesce((select sum(p.amount) from sale_payments p join sales s on s.id = p.sale_id
                where s.status = 'completed' and p.method = 'cash' and s.sold_at >= ?1 and s.sold_at < ?2), 0)
    - coalesce((select sum(l.amount) from server_ledger l
                where l.kind = 'payment' and julianday(l.occurred_at) >= julianday(?1)
                  and julianday(l.occurred_at) < julianday(?2)), 0)
    - coalesce((select sum(l.amount) from local_ledger l
                where l.kind = 'payment' and l.occurred_at >= ?1 and l.occurred_at < ?2), 0)
    - coalesce((select sum(e.amount) from expenses e
                where e.voided_at is null and e.paid_from = 'cash' and e.spent_at >= ?1 and e.spent_at < ?2), 0)
    + coalesce((select sum($_serviceCashSql) from service_txns t
                where t.voided_at is null and t.txn_at >= ?1 and t.txn_at < ?2), 0)
      as expected
  ''';

  /// [serviceCashEffect] in SQL, for a `service_txns t` row.
  static const _serviceCashSql = '''
    case t.kind when 'cash_in' then t.amount + t.fee when 'cash_out' then t.fee - t.amount
                when 'load' then coalesce(t.price, t.amount + t.fee)
                when 'float_topup' then -t.amount when 'float_withdraw' then t.amount else 0 end
  ''';

  Selectable<QueryRow> _expectedCashQuery(DateTime day) {
    final (from, to) = _dayBounds(day);
    return db.customSelect(_expectedCashSql,
        variables: [Variable.withString(from), Variable.withString(to)],
        readsFrom: {db.sales, db.salePayments, db.serverLedger, db.localLedger, db.expenses, db.serviceTxns});
  }

  @override
  Future<int> expectedCash(DateTime day) async => (await _expectedCashQuery(day).getSingle()).read<int>('expected');

  @override
  Stream<int> watchExpectedCash(DateTime day) => _expectedCashQuery(day).watchSingle().map((r) => r.read<int>('expected'));

  @override
  Future<void> closeDay({
    required String id,
    required DateTime day,
    required int countedCash,
    String? note,
    String? approvalId,
    required String opId,
  }) {
    if (countedCash < 0) throw ArgumentError('Counted cash cannot be negative');
    final n = _text200(note);
    return db.transaction(() async {
      if (await (db.select(db.dayCloses)..where((d) => d.id.equals(id))).getSingleOrNull() != null) {
        throw StateError('Day close id already used');
      }
      final expected = await expectedCash(day);
      final key = dayKey(day);
      final at = _iso(DateTime.now());
      await db.into(db.dayCloses).insert(DayClosesCompanion.insert(
            id: id,
            locationId: Value(locationId),
            day: key,
            currency: baseCurrency,
            expectedCash: expected,
            countedCash: countedCash,
            difference: countedCash - expected,
            note: Value(n),
            closedAt: at,
          ));
      await enqueue(opId, 'close_day', id, {
        'id': id,
        'day': key,
        'expected_cash': expected,
        'counted_cash': countedCash,
        'closed_at': at,
        'note': ?n,
        'location_id': ?locationId,
        'approval_id': ?approvalId,
      });
    });
  }

  @override
  Stream<DayCloseView?> watchLatestDayClose(DateTime day) => db
      .customSelect(
        '''
        select x.id, x.day, x.expected_cash, x.counted_cash, x.difference, x.server_expected_cash, x.note, x.closed_at,
               x.approved_by, $_pendingSql
        from day_closes x
        where x.day = ?1
        order by x.closed_at desc, x.id desc
        limit 1
        ''',
        variables: [Variable.withString(dayKey(day))],
        readsFrom: {db.dayCloses, db.outbox},
      )
      .watch()
      .map((rows) => rows.isEmpty
          ? null
          : DayCloseView(
              id: rows.first.read<String>('id'),
              day: rows.first.read<String>('day'),
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
      final at = _iso(txnAt ?? DateTime.now());
      await db.into(db.serviceTxns).insert(ServiceTxnsCompanion.insert(
            id: id,
            locationId: Value(locationId),
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
          opId: opId, txnId: id, wallet: wallet, amount: serviceFloatEffect(kind, amount)));
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
        'location_id': ?locationId,
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
          opId: opId, txnId: txnId, wallet: t.wallet, amount: -serviceFloatEffect(t.kind, t.amount)));
      await enqueue(opId, 'void_service_txn', txnId, {'txn_id': txnId, 'reason': ?r, 'approval_id': ?approvalId});
    });
  }

  static DateTime? _localOrNull(String? iso) => iso == null ? null : DateTime.parse(iso).toLocal();

  @override
  Stream<List<ServiceTxnView>> watchServiceTxns({required DateTime from, required DateTime to}) => db
      .customSelect(
        '''
        select x.id, x.kind, x.wallet, x.amount, x.fee, x.price, x.ref, x.note, x.txn_at, x.voided_at, x.void_reason,
               x.approved_by, $_pendingSql
        from service_txns x
        where x.txn_at >= ?1 and x.txn_at < ?2
        order by x.txn_at desc, x.id desc
        ''',
        variables: [Variable.withString(_iso(from)), Variable.withString(_iso(to))],
        readsFrom: {db.serviceTxns, db.outbox},
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
          where t.voided_at is null and t.txn_at >= ?1 and t.txn_at < ?2
          ''',
          variables: [Variable.withString(from), Variable.withString(to)],
          readsFrom: {db.serviceTxns},
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
          select w.wallet, w.balance as b, 0 as p from wallet_float w where ?1 is null or w.location_id = ?1
          union all
          select e.wallet, e.amount as b, 1 as p from local_float_effects e
        ) group by wallet
        ''',
        variables: [Variable<String>(locationId)],
        readsFrom: {db.walletFloats, db.localFloatEffects},
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
              locationId: Value(r['location_id'] as String?),
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
  Future<void> requeueWithApproval({required String opId, required String approvalId}) {
    return db.transaction(() async {
      final op = await (db.select(db.outbox)..where((o) => o.opId.equals(opId))).getSingleOrNull();
      if (op == null) throw StateError('Unknown op');
      if (!approvalKinds.contains(op.kind)) throw ArgumentError('${op.kind} does not take an approval');
      if (op.status != 'failed') throw StateError('Only a refused op can be sent again');
      final payload = (jsonDecode(op.payload) as Map).cast<String, dynamic>()..['approval_id'] = approvalId;
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
  Future<void> undoLocalOp(String kind, String entityId) async {
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
              locationId: Value(r['location_id'] as String?),
              amount: (r['amount'] as num).toInt(),
              currency: (r['currency'] as String).trim(),
              category: r['category'] as String,
              paidFrom: Value(r['paid_from'] as String? ?? 'cash'),
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
              locationId: Value(r['location_id'] as String?),
              day: r['day'] as String,
              currency: (r['currency'] as String).trim(),
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
  Future<void> posOpApplied(String opId, String? appliedAt) async {
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
        if (unsent.contains(id)) continue; // a local change (e.g. a cancel) is still on its way: keep ours
        await db.into(db.sales).insertOnConflictUpdate(SalesCompanion.insert(
              id: id,
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
