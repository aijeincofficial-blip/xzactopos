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
  final _searchCtrl = TextEditingController();
  SalesPeriodFilter _filter = SalesPeriodFilter.today;
  String _statusFilter = 'all'; // all | completed | voided
  String _query = '';
  DateTime? _customDate;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matchesSale(SaleSummary s) {
    if (!_matchesFilter(s.soldAt)) return false;
    if (_statusFilter == 'completed' && s.voided) return false;
    if (_statusFilter == 'voided' && !s.voided) return false;
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      final hitNo = s.displayNo.toLowerCase().contains(q) || s.localNo.toLowerCase().contains(q);
      final hitCust = s.customerName?.toLowerCase().contains(q) ?? false;
      if (!hitNo && !hitCust) return false;
    }
    return true;
  }

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
          final filtered = allSales.where(_matchesSale).toList();
          final periodTotal = filtered.where((s) => !s.voided).fold<int>(0, (sum, s) => sum + s.total);
          final hasSearchOrStatus = _query.trim().isNotEmpty || _statusFilter != 'all';

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
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.outline,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  StatusPill(
                                    label: t.todayCount(d.count),
                                    textKey: const Key('today-count'),
                                    color: scheme.primaryContainer,
                                    textColor: scheme.onPrimaryContainer,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                money(d.total),
                                key: const Key('today-total'),
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.9,
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
                                  borderRadius: BorderRadius.circular(Gap.radiusS),
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
                                    const SizedBox(width: 10),
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
                                    const SizedBox(width: 10),
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
                        horizontal: Gap.l,
                        vertical: Gap.xs,
                      ),
                      child: StreamBuilder<ServiceTotals>(
                        stream: scope.store.watchTodayServices(),
                        builder: (context, snap) => AppCard(
                          key: const Key('tile-services'),
                          padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.m),
                          radius: Gap.radiusL,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => scope.wrap(ServicesScreen(backend: widget.backend)),
                            ),
                          ),
                          child: Row(
                            children: [
                              CoinBadge(icon: Icons.smartphone_rounded, color: scheme.primary, size: 34),
                              const SizedBox(width: Gap.m),
                              Expanded(
                                child: Text(
                                  t.servicesTitle,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                money((snap.data ?? const ServiceTotals()).fees),
                                key: const Key('today-service-fees'),
                                style: NightMarketText.mono(context, size: 15.5, weight: FontWeight.w600),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right_rounded, size: 18, color: scheme.outline),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Expenses and Day Close tiles
                    if (scope.canManageStock)
                      if (scope.canAccessExpenses || scope.canCloseDay)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Gap.l,
                            vertical: Gap.xs,
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (scope.canAccessExpenses)
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
                                              t.expensesTitle.toUpperCase(),
                                              style: NightMarketText.eyebrow(context, size: 11),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              money(
                                                (snap.data ?? const ExpenseTotals()).total,
                                              ),
                                              key: const Key('today-expenses'),
                                              style: NightMarketText.mono(context, size: 17, weight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                if (scope.canAccessExpenses && scope.canCloseDay)
                                  const SizedBox(width: 10),
                                if (scope.canCloseDay)
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
                                      child: Row(
                                        children: [
                                          CoinBadge(icon: Icons.lock_clock_outlined, color: scheme.payExpense, size: 34),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              t.dayCloseTitle,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                color: scheme.onSurface,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
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
                      padding: const EdgeInsets.fromLTRB(Gap.l, Gap.l, Gap.m, Gap.xs),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                t.receiptTitle.toUpperCase(),
                                style: NightMarketText.eyebrow(context),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: scheme.chipFill,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: scheme.outlineVariant),
                                ),
                                child: Text(
                                  '${filtered.length} · ${money(periodTotal)}',
                                  style: NightMarketText.mono(context, size: 11, weight: FontWeight.w600),
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

                    // Receipt & Customer Search
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.xs),
                      child: TextField(
                        key: const Key('today-search'),
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: t.todaySearchHint,
                          prefixIcon: const Icon(Icons.search_rounded, size: 19),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  key: const Key('today-search-clear'),
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _query = '');
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),

                    // Period Selection Chips (Past Days Navigation)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.xs),
                      child: Row(
                        children: [
                          AppPillChip(
                            key: const Key('today-period-today'),
                            height: 34,
                            label: locale == 'fil' ? 'Ngayon' : 'Today',
                            selected: _filter == SalesPeriodFilter.today,
                            onTap: () => setState(() {
                              _filter = SalesPeriodFilter.today;
                              _customDate = null;
                            }),
                          ),
                          const SizedBox(width: 8),
                          AppPillChip(
                            key: const Key('today-period-yesterday'),
                            height: 34,
                            label: locale == 'fil' ? 'Kahapon' : 'Yesterday',
                            selected: _filter == SalesPeriodFilter.yesterday,
                            onTap: () => setState(() {
                              _filter = SalesPeriodFilter.yesterday;
                              _customDate = null;
                            }),
                          ),
                          const SizedBox(width: 8),
                          AppPillChip(
                            key: const Key('today-period-7d'),
                            height: 34,
                            label: locale == 'fil' ? 'Huling 7 Araw' : 'Past 7 Days',
                            selected: _filter == SalesPeriodFilter.past7Days,
                            onTap: () => setState(() {
                              _filter = SalesPeriodFilter.past7Days;
                              _customDate = null;
                            }),
                          ),
                          const SizedBox(width: 8),
                          AppPillChip(
                            key: const Key('today-period-all'),
                            height: 34,
                            label: locale == 'fil' ? 'Lahat ng Resibo' : 'All Receipts',
                            selected: _filter == SalesPeriodFilter.all,
                            onTap: () => setState(() {
                              _filter = SalesPeriodFilter.all;
                              _customDate = null;
                            }),
                          ),
                          if (_customDate != null) ...[
                            const SizedBox(width: 8),
                            AppPillChip(
                              key: const Key('today-period-custom'),
                              height: 34,
                              icon: Icons.close_rounded,
                              label: DateFormat.MMMd(locale).format(_customDate!),
                              selected: _filter == SalesPeriodFilter.custom,
                              onTap: () => setState(() {
                                _customDate = null;
                                _filter = SalesPeriodFilter.today;
                              }),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Status Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: 2),
                      child: Row(
                        children: [
                          AppPillChip(
                            key: const Key('today-status-all'),
                            height: 32,
                            label: t.todayFilterAll,
                            selected: _statusFilter == 'all',
                            onTap: () => setState(() => _statusFilter = 'all'),
                          ),
                          const SizedBox(width: 8),
                          AppPillChip(
                            key: const Key('today-status-completed'),
                            height: 32,
                            label: t.todayFilterCompleted,
                            selected: _statusFilter == 'completed',
                            onTap: () => setState(() => _statusFilter = 'completed'),
                          ),
                          const SizedBox(width: 8),
                          AppPillChip(
                            key: const Key('today-status-cancelled'),
                            height: 32,
                            label: t.todayFilterCancelled,
                            accentColor: scheme.error,
                            selected: _statusFilter == 'voided',
                            onTap: () => setState(() => _statusFilter = 'voided'),
                          ),
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
                      text: hasSearchOrStatus
                          ? t.todayNoMatches
                          : _filter == SalesPeriodFilter.today
                              ? t.todayNone
                              : (locale == 'fil' ? 'Walang nahanap na resibo' : 'No receipts found for this period'),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.l),
                  sliver: SliverList.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final s = filtered[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: AppCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Gap.l,
                            vertical: 6,
                          ),
                          radius: Gap.radiusL,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => scope.wrap(ReceiptScreen(saleId: s.id)),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            key: Key('sale-${s.id}'),
                            leading: CoinBadge(
                              icon: Icons.receipt_long_outlined,
                              color: s.voided ? scheme.outline : scheme.primary,
                              size: 36,
                            ),
                            title: Text(
                              money(s.total),
                              style: NightMarketText.mono(
                                context,
                                size: 15.5,
                                weight: FontWeight.w600,
                                color: s.voided ? scheme.outline : scheme.onSurface,
                              ).copyWith(
                                decoration: s.voided ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            subtitle: Text(
                              [
                                _formatSaleDate(s.soldAt, locale),
                                s.displayNo,
                                if (s.customerName != null) s.customerName!,
                                if (s.voided) t.receiptCancelled,
                              ].join(' · '),
                              style: TextStyle(
                                color: scheme.outline,
                                fontSize: 12.5,
                              ),
                            ),
                            trailing: s.pending
                                ? Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 18,
                                    color: scheme.primary,
                                    semanticLabel: t.notSentYet,
                                  )
                                : Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: scheme.outline,
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom),
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
          style: NightMarketText.mono(
            context,
            size: 14,
            weight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}
