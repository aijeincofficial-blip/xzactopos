import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../backend.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/local_store.dart';
import '../data/sales_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import '../sync/sync_badge.dart';

/// Sales for the last 7 or 30 days with multi-metric reporting, payment method distribution,
/// peak hours analysis, and inventory health for Solo store owners.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.backend});
  final Backend backend;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _Loaded {
  _Loaded(this.data, this.fetchedAt, {required this.offline});
  final Map<String, dynamic> data;
  final DateTime fetchedAt;
  final bool offline;
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _days = 7;
  Future<_Loaded?>? _load;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load ??= _fetch();
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<_Loaded?> _fetch() async {
    final store = CatalogScope.of(context).store;
    final key = 'report_$_days';
    final to = _today;
    final from = to.subtract(Duration(days: _days - 1));
    try {
      final data = await widget.backend.reportSummary(from, to);
      final now = DateTime.now();
      await store.setMeta(key, jsonEncode({'at': now.toUtc().toIso8601String(), 'data': data}));
      return _Loaded(data, now, offline: false);
    } catch (_) {
      final raw = await store.meta(key);
      if (raw == null) return null;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return _Loaded((m['data'] as Map).cast<String, dynamic>(), DateTime.parse(m['at'] as String).toLocal(), offline: true);
    }
  }

  void _reload({int? days}) {
    if (days != null) _days = days;
    final next = _fetch();
    setState(() {
      _load = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    String money(num a) => Money(a.toInt(), scope.store.baseCurrency).format(locale);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.reportsTitle),
        actions: [
          IconButton(
            key: const Key('report-refresh'),
            tooltip: t.reportsRefresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _reload,
          ),
          const SyncBadge(),
        ],
      ),
      body: FutureBuilder<_Loaded?>(
        future: _load,
        builder: (context, snap) {
          return ListView(
            padding: const EdgeInsets.only(bottom: Gap.xxl),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.m, Gap.xl, Gap.s),
                child: SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 7, label: Text(t.reportsDays(7))),
                    ButtonSegment(value: 30, label: Text(t.reportsDays(30))),
                  ],
                  selected: {_days},
                  onSelectionChanged: (s) => _reload(days: s.first),
                ),
              ),
              StreamBuilder<OutboxCounts>(
                stream: scope.store.watchOutboxCounts(),
                builder: (context, c) {
                  final n = c.data?.pending ?? 0;
                  return n == 0
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.xs),
                          child: Text(t.reportsNotSent(n), key: const Key('report-not-sent')),
                        );
                },
              ),
              if (snap.connectionState != ConnectionState.done)
                const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
              else if (snap.data == null)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text(t.reportsNeedSignal, textAlign: TextAlign.center)),
                )
              else
                ..._body(context, snap.data!, t, locale, money, scope),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    _Loaded l,
    AppLocalizations t,
    String locale,
    String Function(num) money,
    CatalogScope scope,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final totals = (l.data['totals'] as Map).cast<String, dynamic>();
    final net = (totals['net'] as num).toInt();
    final cogs = (totals['cogs'] as num).toInt();
    final txns = (totals['txns'] as num).toInt();
    final cashAmount = (totals['cash'] as num).toInt();
    final ewalletAmount = (totals['ewallet'] as num).toInt();
    final utangAmount = (totals['utang'] as num).toInt();

    final byDay = {for (final d in (l.data['days'] as List).cast<Map<String, dynamic>>()) d['day'] as String: (d['net'] as num).toInt()};
    final to = _today;
    final days = [for (var i = _days - 1; i >= 0; i--) to.subtract(Duration(days: i))];
    String key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
    final maxNet = byDay.values.fold<int>(1, (a, b) => b > a ? b : a);
    final top = (l.data['top_items'] as List).cast<Map<String, dynamic>>();
    final utang = (l.data['utang'] as Map).cast<String, dynamic>();
    final debtors = (utang['customers'] as List).cast<Map<String, dynamic>>();

    // Additional performance metrics
    final aov = txns > 0 ? (net / txns).round() : 0;
    final profit = net - cogs;
    // Expenses from the server rollup. Stock purchases are left out of the profit: the goods are already
    // in cost of goods when they sell, so taking them off again would count them twice.
    final exp = l.data['expenses'];
    var expTotal = 0, stockBought = 0;
    if (exp is Map) {
      expTotal = ((exp['total'] as num?) ?? 0).toInt();
      for (final c in ((exp['by_category'] as List?) ?? const []).cast<Map<String, dynamic>>()) {
        if (c['category'] == 'stock_purchase') stockBought += ((c['amount'] as num?) ?? 0).toInt();
      }
    }
    final opExpenses = expTotal - stockBought;
    final profitMargin = (net > 0 && cogs > 0) ? ((profit / net) * 100).toStringAsFixed(0) : null;
    final totalPayments = cashAmount + ewalletAmount + utangAmount;
    final cashPct = totalPayments > 0 ? (cashAmount / totalPayments * 100).round() : 0;
    final ewalletPct = totalPayments > 0 ? (ewalletAmount / totalPayments * 100).round() : 0;
    final utangPct = totalPayments > 0 ? (utangAmount / totalPayments * 100).round() : 0;

    return [
      if (l.offline)
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.s, Gap.xl, Gap.s),
          child: Container(
            key: const Key('report-offline'),
            padding: const EdgeInsets.all(Gap.m),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(Gap.radiusM),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_off_rounded, size: 20, color: scheme.onTertiaryContainer),
                const SizedBox(width: Gap.m),
                Expanded(
                  child: Text(
                    t.reportsAsOf(DateFormat.yMMMd(locale).add_jm().format(l.fetchedAt)),
                    style: TextStyle(color: scheme.onTertiaryContainer, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),

      // Hero Ceramic Card: Sales & Financial Overview
      Padding(
        padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.m, Gap.xl, Gap.m),
        child: AppCard(
          padding: const EdgeInsets.all(Gap.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CoinBadge(icon: Icons.trending_up_rounded, color: scheme.secondary, size: 42),
                  const SizedBox(width: Gap.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.reportsSales,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          t.reportsRevenueSub,
                          style: TextStyle(fontSize: 11, color: scheme.outline),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(
                    label: t.todayCount(txns),
                    color: scheme.chipFill,
                    textColor: scheme.onSurface,
                  ),
                ],
              ),
              const SizedBox(height: Gap.m),
              Text(
                money(net),
                key: const Key('report-net'),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              // Hidden or compact transaction text for tests
              Text(
                t.todayCount(txns),
                key: const Key('report-txns'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Gap.xs),
              if (cogs > 0)
                Wrap(
                  spacing: Gap.s,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.success.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(Gap.radiusS),
                      ),
                      child: Text(
                        t.reportsProfit(money(profit)),
                        key: const Key('report-profit'),
                        style: TextStyle(
                          color: scheme.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (profitMargin != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(Gap.radiusS),
                        ),
                        child: Text(
                          '$profitMargin margin',
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              if (expTotal > 0 && cogs > 0) ...[
                const SizedBox(height: Gap.m),
                Text(t.reportsExpenses(money(opExpenses)),
                    key: const Key('report-expenses'), style: TextStyle(color: scheme.outline, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(t.reportsNetProfit(money(profit - opExpenses)),
                    key: const Key('report-net-profit'),
                    style: TextStyle(color: (profit - opExpenses) < 0 ? scheme.error : scheme.success, fontSize: 15, fontWeight: FontWeight.w800)),
                if (stockBought > 0) ...[
                  const SizedBox(height: 2),
                  Text(t.reportsStockBought(money(stockBought)),
                      key: const Key('report-stock-bought'), style: TextStyle(color: scheme.outline, fontSize: 12)),
                  Text(t.reportsExpensesNote, style: TextStyle(color: scheme.outline, fontSize: 11)),
                ],
              ],
              const SizedBox(height: Gap.l),
              Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.4)),
              const SizedBox(height: Gap.l),

              // 3-Column Payment Breakdown
              Row(
                crossAxisAlignment: CrossAxisAlignment.end, // amounts line up even when a label wraps
                children: [
                  _Stat(t.todayCash, money(cashAmount), 'report-cash', Icons.payments_outlined, scheme.payCash),
                  _Stat(t.payEwallet, money(ewalletAmount), 'report-ewallet', Icons.account_balance_wallet_outlined, scheme.payEwallet),
                  _Stat(t.todayUtang, money(utangAmount), 'report-utang', Icons.assignment_late_outlined, scheme.payUtang),
                ],
              ),
              const SizedBox(height: Gap.m),

              // Visual Percentage Bar of Payments
              if (totalPayments > 0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    children: [
                      if (cashPct > 0)
                        Expanded(
                          flex: cashPct,
                          child: Container(height: 6, color: scheme.payCash),
                        ),
                      if (ewalletPct > 0)
                        Expanded(
                          flex: ewalletPct,
                          child: Container(height: 6, color: scheme.payEwallet),
                        ),
                      if (utangPct > 0)
                        Expanded(
                          flex: utangPct,
                          child: Container(height: 6, color: scheme.payUtang),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$cashPct% Cash', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: scheme.payCash)),
                    Text('$ewalletPct% E-Wallet', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: scheme.payEwallet)),
                    Text('$utangPct% Utang', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: scheme.payUtang)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),

      // Store Performance KPI Badges
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
        child: Row(
          children: [
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.all(Gap.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.reportsAvgOrder,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.outline),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      money(aov),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: Gap.m),
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.all(Gap.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.reportsTotalOrders,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.outline),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$txns',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Daily Breakdown
      _Heading(t.reportsPerDay),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.m),
          child: Column(
            children: [
              for (final d in days)
                Padding(
                  key: Key('day-${key(d)}'),
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 62,
                        child: Text(
                          DateFormat.MMMd(locale).format(d),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (_, c) => Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              height: 12,
                              width: ((byDay[key(d)] ?? 0) / maxNet * c.maxWidth).clamp(0, c.maxWidth).toDouble(),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [scheme.primary, scheme.secondary],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Gap.m),
                      SizedBox(
                        width: 84,
                        child: Text(
                          money(byDay[key(d)] ?? 0),
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),

      // Top Items / Best Sellers
      _Heading(t.reportsTopItems),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
        child: AppCard(
          padding: top.isEmpty ? const EdgeInsets.all(Gap.l) : const EdgeInsets.symmetric(vertical: Gap.s),
          child: top.isEmpty
              ? Text(t.reportsNothingYet, style: TextStyle(color: scheme.onSurfaceVariant))
              : Column(
                  children: [
                    for (var i = 0; i < top.length && i < 5; i++)
                      ListTile(
                        key: Key('top-$i'),
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: i == 0
                              ? scheme.payUtang
                              : (scheme.outlineVariant),
                          foregroundColor: i == 0 ? Colors.white : scheme.onSurface,
                          child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        ),
                        title: Text(
                          top[i]['name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        subtitle: Text(
                          t.reportsQty(_qty((top[i]['qty'] as num).toDouble())),
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                        ),
                        trailing: Text(
                          money(top[i]['revenue'] as num),
                          style: TextStyle(fontWeight: FontWeight.w800, color: scheme.primary, fontSize: 14),
                        ),
                      ),
                  ],
                ),
        ),
      ),

      // Utang & Receivables
      _Heading(t.utangTitle),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
        child: AppCard(
          padding: const EdgeInsets.all(Gap.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.reportsUtangOwed(money(utang['owed'] as num)),
                key: const Key('report-owed'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              if (debtors.isNotEmpty) ...[
                const SizedBox(height: Gap.s),
                Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.4)),
                const SizedBox(height: Gap.s),
                for (var i = 0; i < debtors.length && i < 5; i++)
                  ListTile(
                    key: Key('debtor-$i'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(debtors[i]['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Text(
                      money(debtors[i]['balance'] as num),
                      style: TextStyle(color: scheme.error, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),

      // Stock Health & Low Inventory Alerts
      Padding(
        padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xl, Gap.xl, Gap.s),
        child: StreamBuilder<List<StockRow>>(
          stream: scope.store.watchStockList(),
          builder: (context, snap) {
            final rows = snap.data ?? const <StockRow>[];
            final lowList = rows.where((r) => r.low).toList();
            return AppCard(
              padding: const EdgeInsets.all(Gap.l),
              child: Row(
                children: [
                  CoinBadge(
                    icon: lowList.isEmpty ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                    color: lowList.isEmpty ? scheme.payCash : scheme.payUtang,
                    size: 38,
                  ),
                  const SizedBox(width: Gap.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.reportsInventoryHealth,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        Text(
                          lowList.isEmpty
                                ? t.reportsAllHealthy
                                : t.reportsNeedReorder(lowList.length),
                          style: TextStyle(fontSize: 12, color: scheme.outline),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ];
  }

  static String _qty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toString();
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xl, Gap.xl, Gap.s),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.keyName, this.icon, this.iconColor);
  final String label;
  final String value;
  final String keyName;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            key: Key(keyName),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
