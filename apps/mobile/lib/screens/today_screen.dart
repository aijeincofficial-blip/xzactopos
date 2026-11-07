import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/money.dart';
import '../core/theme.dart';
import '../core/ui.dart';
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
    final scheme = Theme.of(context).colorScheme;
    String money(int a) => Money(a, scope.store.baseCurrency).format(locale);
    final now = DateTime.now();
    bool isToday(DateTime d) => d.year == now.year && d.month == now.month && d.day == now.day;

    return Scaffold(
      appBar: AppBar(title: Text(t.todayTitle), actions: const [SyncBadge()]),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Gap.xxl),
        children: [
          StreamBuilder<TodayTotals>(
            stream: scope.store.watchToday(),
            builder: (context, snap) {
              final d = snap.data ?? const TodayTotals();
              return SummaryCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          t.todaySales.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: scheme.outline,
                            letterSpacing: 0.8,
                          ),
                        ),
                        StatusPill(
                          label: t.todayCount(d.count),
                          textKey: const Key('today-count'),
                          color: scheme.obsidian,
                          textColor: Colors.white,
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.s),
                    Text(
                      money(d.total),
                      key: const Key('today-total'),
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: Gap.m),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: scheme.chipFill,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: scheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _Stat(label: t.todayCash, value: money(d.cash), keyName: 'today-cash'),
                          Container(width: 1, height: 24, color: scheme.outlineVariant),
                          _Stat(label: t.payEwallet, value: money(d.ewallet), keyName: 'today-ewallet'),
                          Container(width: 1, height: 24, color: scheme.outlineVariant),
                          _Stat(label: t.todayUtang, value: money(d.utang), keyName: 'today-utang'),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          StreamBuilder<List<SaleSummary>>(
            stream: scope.store.watchSales(),
            builder: (context, snap) {
              final today = (snap.data ?? const <SaleSummary>[]).where((s) => isToday(s.soldAt)).toList();
              if (today.isEmpty) {
                return EmptyState(
                  icon: Icons.receipt_long_rounded,
                  text: t.todayNone,
                );
              }
              return Column(
                children: [
                  for (final s in today)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.xs),
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.s),
                        radius: Gap.radiusL,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => scope.wrap(ReceiptScreen(saleId: s.id)),
                        )),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          key: Key('sale-${s.id}'),
                          leading: CoinBadge(
                            icon: Icons.receipt_rounded,
                            color: s.voided ? scheme.outline : scheme.primary,
                            size: 40,
                          ),
                          title: Text(
                            money(s.total),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: s.voided ? scheme.outline : scheme.onSurface,
                              decoration: s.voided ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          subtitle: Text(
                            [
                              DateFormat.jm(locale).format(s.soldAt),
                              s.localNo,
                              if (s.customerName != null) s.customerName!,
                              if (s.voided) t.receiptCancelled,
                            ].join(' · '),
                            style: TextStyle(color: scheme.outline, fontSize: 13),
                          ),
                          trailing: s.pending
                              ? Icon(Icons.cloud_upload_outlined, size: 18, color: scheme.primary, semanticLabel: t.notSentYet)
                              : const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                ],
              );
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: scheme.outline,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          key: Key(keyName),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}
