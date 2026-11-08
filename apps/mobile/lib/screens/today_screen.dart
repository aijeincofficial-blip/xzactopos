import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../backend.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/sales_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import '../sync/sync_badge.dart';
import 'day_close_screen.dart';
import 'expenses_screen.dart';
import 'receipt_screen.dart';
import 'store_picker.dart';
import 'services_screen.dart';

enum SalesPeriodFilter {
  today,
  yesterday,
  past7Days,
  all,
  custom,
}

/// Today's takings and sales history (today and past days), newest first.
/// Uses lazy sliver list rendering to prevent memory leaks on large transaction volumes.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.backend});
  final Backend backend;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  SalesPeriodFilter _filter = SalesPeriodFilter.today;
  DateTime? _customDate;

  bool _matchesFilter(DateTime soldAt) {
    final now = DateTime.now();
    final d = DateTime(soldAt.year, soldAt.month, soldAt.day);
    final today = DateTime(now.year, now.month, now.day);
    switch (_filter) {
      case SalesPeriodFilter.today:
        return d == today;
      case SalesPeriodFilter.yesterday:
        return d == today.subtract(const Duration(days: 1));
      case SalesPeriodFilter.past7Days:
        return d.isAfter(today.subtract(const Duration(days: 7)));
      case SalesPeriodFilter.all:
        return true;
      case SalesPeriodFilter.custom:
        if (_customDate == null) return true;
        final target = DateTime(_customDate!.year, _customDate!.month, _customDate!.day);
        return d == target;
    }
  }

  String _formatSaleDate(DateTime soldAt, String locale) {
    final now = DateTime.now();
    final d = DateTime(soldAt.year, soldAt.month, soldAt.day);
    final today = DateTime(now.year, now.month, now.day);
    final timeStr = DateFormat.jm(locale).format(soldAt);
    if (d == today) {
      return timeStr;
    } else if (d == today.subtract(const Duration(days: 1))) {
      return 'Yesterday · $timeStr';
    } else {
      return '${DateFormat.MMMd(locale).format(soldAt)} · $timeStr';
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _customDate ?? now,
      firstDate: DateTime(2024),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _customDate = picked;
        _filter = SalesPeriodFilter.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final scheme = Theme.of(context).colorScheme;
    String money(int a) => Money(a, scope.store.baseCurrency).format(locale);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.todayTitle),
        actions: const [StoreChip(), SyncBadge()],
      ),
      body: StreamBuilder<List<SaleSummary>>(
        stream: scope.store.watchSales(limit: 500),
        builder: (context, snapSales) {
          final allSales = snapSales.data ?? const <SaleSummary>[];
          final filtered = allSales.where((s) => _matchesFilter(s.soldAt)).toList();
          final periodTotal = filtered.where((s) => !s.voided).fold<int>(0, (sum, s) => sum + s.total);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Today's summary card
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.chipFill,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: scheme.outlineVariant),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _Stat(
                                        label: t.todayCash,
                                        value: money(d.cash),
                                        keyName: 'today-cash',
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 24,
                                      color: scheme.outlineVariant,
                                    ),
                                    Expanded(
                                      child: _Stat(
                                        label: t.payEwallet,
                                        value: money(d.ewallet),
                                        keyName: 'today-ewallet',
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 24,
                                      color: scheme.outlineVariant,
                                    ),
                                    Expanded(
                                      child: _Stat(
                                        label: t.todayUtang,
                                        value: money(d.utang),
                                        keyName: 'today-utang',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Services tile
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Gap.xl,
                        vertical: Gap.xs,
                      ),
                      child: StreamBuilder<ServiceTotals>(
                        stream: scope.store.watchTodayServices(),
                        builder: (context, snap) => AppCard(
                          key: const Key('tile-services'),
                          padding: const EdgeInsets.all(Gap.m),
                          radius: Gap.radiusL,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => scope.wrap(ServicesScreen(backend: widget.backend)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.phone_iphone_rounded, color: scheme.primary),
                              const SizedBox(width: Gap.m),
                              Expanded(
                                child: Text(
                                  t.servicesTitle,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                money((snap.data ?? const ServiceTotals()).fees),
                                key: const Key('today-service-fees'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Expenses and Day Close tiles
                    if (scope.canManageStock)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Gap.xl,
                          vertical: Gap.xs,
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: StreamBuilder<ExpenseTotals>(
                                  stream: scope.store.watchTodayExpenses(),
                                  builder: (context, snap) => AppCard(
                                    key: const Key('tile-expenses'),
                                    padding: const EdgeInsets.all(Gap.m),
                                    radius: Gap.radiusL,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => scope.wrap(ExpensesScreen(backend: widget.backend)),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t.expensesTitle,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: scheme.outline,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          money(
                                            (snap.data ?? const ExpenseTotals()).total,
                                          ),
                                          key: const Key('today-expenses'),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: Gap.m),
                              Expanded(
                                child: AppCard(
                                  key: const Key('tile-close-day'),
                                  padding: const EdgeInsets.all(Gap.m),
                                  radius: Gap.radiusL,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => scope.wrap(DayCloseScreen(backend: widget.backend)),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.dayCloseTitle,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: scheme.outline,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Icon(
                                        Icons.lock_clock_rounded,
                                        size: 22,
                                        color: scheme.payExpense,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Receipts & Past Days Filter Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.l, Gap.xl, Gap.xs),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                t.receiptTitle.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.outline,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: scheme.chipFill,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${filtered.length} · ${money(periodTotal)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.event_outlined, size: 20),
                            tooltip: 'Pick Date',
                            onPressed: () => _pickDate(context),
                          ),
                        ],
                      ),
                    ),

                    // Period Selection Chips (Past Days Navigation)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.xs),
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: Text(locale == 'fil' ? 'Ngayon' : 'Today'),
                            selected: _filter == SalesPeriodFilter.today,
                            onSelected: (_) => setState(() {
                              _filter = SalesPeriodFilter.today;
                              _customDate = null;
                            }),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(locale == 'fil' ? 'Kahapon' : 'Yesterday'),
                            selected: _filter == SalesPeriodFilter.yesterday,
                            onSelected: (_) => setState(() {
                              _filter = SalesPeriodFilter.yesterday;
                              _customDate = null;
                            }),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(locale == 'fil' ? 'Huling 7 Araw' : 'Past 7 Days'),
                            selected: _filter == SalesPeriodFilter.past7Days,
                            onSelected: (_) => setState(() {
                              _filter = SalesPeriodFilter.past7Days;
                              _customDate = null;
                            }),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(locale == 'fil' ? 'Lahat ng Resibo' : 'All Receipts'),
                            selected: _filter == SalesPeriodFilter.all,
                            onSelected: (_) => setState(() {
                              _filter = SalesPeriodFilter.all;
                              _customDate = null;
                            }),
                          ),
                          if (_customDate != null) ...[
                            const SizedBox(width: 8),
                            InputChip(
                              label: Text(DateFormat.MMMd(locale).format(_customDate!)),
                              selected: _filter == SalesPeriodFilter.custom,
                              onDeleted: () => setState(() {
                                _customDate = null;
                                _filter = SalesPeriodFilter.today;
                              }),
                              onPressed: () => setState(() {
                                _filter = SalesPeriodFilter.custom;
                              }),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: Gap.xs),
                  ],
                ),
              ),

              // Lazy list of receipt cards (recycled on the fly)
              if (filtered.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: Gap.l),
                    child: EmptyState(
                      icon: Icons.receipt_long_rounded,
                      text: _filter == SalesPeriodFilter.today
                          ? t.todayNone
                          : (locale == 'fil' ? 'Walang nahanap na resibo' : 'No receipts found for this period'),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
                  sliver: SliverList.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final s = filtered[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: Gap.xs),
                        child: AppCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Gap.l,
                            vertical: Gap.s,
                          ),
                          radius: Gap.radiusL,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => scope.wrap(ReceiptScreen(saleId: s.id)),
                            ),
                          ),
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
                                _formatSaleDate(s.soldAt, locale),
                                s.localNo,
                                if (s.customerName != null) s.customerName!,
                                if (s.voided) t.receiptCancelled,
                              ].join(' · '),
                              style: TextStyle(
                                color: scheme.outline,
                                fontSize: 13,
                              ),
                            ),
                            trailing: s.pending
                                ? Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 18,
                                    color: scheme.primary,
                                    semanticLabel: t.notSentYet,
                                  )
                                : const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: Color(0xFFCBD5E1),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.keyName,
  });
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
