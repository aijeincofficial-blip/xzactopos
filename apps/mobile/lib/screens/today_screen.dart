import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/money.dart';
import '../data/sales_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import '../sync/sync_badge.dart';
import 'receipt_screen.dart';

/// Today's takings and the sales made today, newest first. Tap a sale to see its receipt (and cancel it).
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    String money(int a) => Money(a, scope.store.baseCurrency).format(locale);
    final now = DateTime.now();
    bool isToday(DateTime d) => d.year == now.year && d.month == now.month && d.day == now.day;
    return Scaffold(
      appBar: AppBar(title: Text(t.todayTitle), actions: const [SyncBadge()]),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          StreamBuilder<TodayTotals>(
            stream: scope.store.watchToday(),
            builder: (context, snap) {
              final d = snap.data ?? const TodayTotals();
              final scheme = Theme.of(context).colorScheme;
              return Container(
                color: scheme.primaryContainer,
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.todaySales),
                  Text(money(d.total),
                      key: const Key('today-total'),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
                  Text(t.todayCount(d.count), key: const Key('today-count')),
                  const SizedBox(height: 12),
                  Row(children: [
                    _Stat(label: t.todayCash, value: money(d.cash), keyName: 'today-cash'),
                    _Stat(label: t.payEwallet, value: money(d.ewallet), keyName: 'today-ewallet'),
                    _Stat(label: t.todayUtang, value: money(d.utang), keyName: 'today-utang'),
                  ]),
                ]),
              );
            },
          ),
          StreamBuilder<List<SaleSummary>>(
            stream: scope.store.watchSales(),
            builder: (context, snap) {
              final today = (snap.data ?? const <SaleSummary>[]).where((s) => isToday(s.soldAt)).toList();
              if (today.isEmpty) {
                return Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(t.todayNone)));
              }
              return Column(children: [
                for (final s in today)
                  ListTile(
                    key: Key('sale-${s.id}'),
                    title: Text(
                      money(s.total),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          decoration: s.voided ? TextDecoration.lineThrough : null),
                    ),
                    subtitle: Text([
                      DateFormat.jm(locale).format(s.soldAt),
                      s.localNo,
                      if (s.customerName != null) s.customerName!,
                      if (s.voided) t.receiptCancelled,
                    ].join(' · ')),
                    trailing: s.pending ? Icon(Icons.cloud_upload_outlined, size: 18, semanticLabel: t.notSentYet) : null,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => scope.wrap(ReceiptScreen(saleId: s.id)),
                    )),
                  ),
              ]);
            },
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.keyName});
  final String label;
  final String value;
  final String keyName;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, key: Key(keyName), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
      );
}
