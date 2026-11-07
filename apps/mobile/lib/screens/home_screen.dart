import 'package:flutter/material.dart';

import '../backend.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/local_store.dart';
import '../data/sales_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import '../sync/sync_badge.dart';
import 'products_screen.dart';
import 'reports_screen.dart';
import 'sell_screen.dart';
import 'settings_screen.dart';
import 'stock_screen.dart';
import 'today_screen.dart';
import 'utang_screen.dart';

/// Solo home: sculpted white hero card, obsidian action pill, tactile service tiles,
/// and a dedicated store settings & management card.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.backend, required this.storeName});
  final Backend backend;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final dark = scheme.brightness == Brightness.dark;

    void open(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => scope.wrap(screen)));

    final cards = <Widget>[
      StreamBuilder<List<CustomerView>>(
        stream: scope.store.watchOverdueCustomers(),
        builder: (context, snap) {
          final overdue = (snap.data ?? const <CustomerView>[]).length;
          return _Tile(
            key: const Key('tile-utang'),
            icon: Icons.menu_book_rounded,
            color: scheme.primary,
            label: t.utangTitle,
            subLabel: overdue > 0 ? t.tileUtangOverdue(overdue) : t.tileUtangSub,
            badge: overdue,
            onTap: () => open(UtangScreen(storeName: storeName)),
          );
        },
      ),
      StreamBuilder<List<StockRow>>(
        stream: scope.store.watchStockList(),
        builder: (context, snap) {
          final rows = snap.data ?? const <StockRow>[];
          final today = DateTime.now();
          final lowCount = rows.where((r) => r.low).length;
          final expiring = rows.where((r) => isExpiringRow(r, today)).length;
          return _Tile(
            key: const Key('tile-stock'),
            icon: Icons.inventory_2_rounded,
            color: scheme.tertiary,
            label: t.stockTitle,
            subLabel: lowCount > 0
                ? t.tileStockLow(lowCount)
                : (expiring > 0 ? t.tileStockExpiring(expiring) : t.tileStockSub),
            badge: lowCount + expiring,
            onTap: () => open(const StockScreen()),
          );
        },
      ),
      _Tile(
        key: const Key('tile-products'),
        icon: Icons.category_rounded,
        color: scheme.secondary,
        label: t.products,
        subLabel: t.tileProductsSub,
        onTap: () => open(const ProductsScreen()),
      ),
      if (scope.canManageStock)
        _Tile(
          key: const Key('tile-reports'),
          icon: Icons.bar_chart_rounded,
          color: scheme.accent,
          label: t.reportsTitle,
          subLabel: t.tileReportsSub,
          onTap: () => open(ReportsScreen(backend: backend)),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: Gap.s,
        leadingWidth: 50,
        leading: Padding(
          padding: const EdgeInsets.only(left: Gap.m),
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      storeName.isNotEmpty ? storeName[0].toUpperCase() : 'X',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: scheme.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.scaffoldBackgroundColor, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: dark ? scheme.surface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront_rounded, size: 14, color: scheme.primary),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  storeName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          const SyncBadge(),
          IconButton(
            key: const Key('btn-settings'),
            tooltip: t.settingsTitle,
            icon: const Icon(Icons.settings_outlined, size: 20),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(4),
            visualDensity: VisualDensity.compact,
            onPressed: () => open(SettingsScreen(backend: backend, storeName: storeName)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, Gap.xs, 0, Gap.xxl),
          children: [
            // Greeting & Live Product Count
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xs, Gap.xl, Gap.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.welcome(storeName),
                          style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                              ),
                        ),
                        const SizedBox(height: 1),
                        StreamBuilder<List<ProductView>>(
                          stream: scope.store.watchProducts(),
                          builder: (context, snap) => Text(
                            t.productsOnDevice(snap.data?.length ?? 0),
                            key: const Key('product-count'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: scheme.outline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Sculptural White Hero Card: "Benta Ngayong Araw"
            StreamBuilder<TodayTotals>(
              stream: scope.store.watchToday(),
              builder: (context, snap) {
                final d = snap.data ?? const TodayTotals();
                final moneyStr = Money(d.total, scope.store.baseCurrency).format(locale);
                return SummaryCard(
                  key: const Key('tile-today'),
                  onTap: () => open(TodayScreen(backend: backend)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              t.todaySales.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: scheme.outline,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: Gap.s),
                          StatusPill(
                            label: t.todayCount(d.count),
                            color: scheme.obsidian,
                            textColor: scheme.onObsidian,
                          ),
                        ],
                      ),
                      const SizedBox(height: Gap.s),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CoinBadge(
                            icon: Icons.payments_rounded,
                            color: scheme.secondary,
                            size: 46,
                          ),
                          const SizedBox(width: Gap.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  moneyStr,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.0,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                Text(
                                  d.count == 0 ? t.startFirstSale : t.totalSalesToday,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: scheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: scheme.chipFill,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.arrow_forward_rounded, size: 16, color: scheme.outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            // Primary Obsidian Action Button: "Magbenta"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.xs),
              child: _ObsidianSellButton(
                key: const Key('tile-sell'),
                label: t.sell,
                onTap: () => open(const SellScreen()),
              ),
            ),

            // 2x2 Feature Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.xs),
              child: GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: Gap.m,
                  crossAxisSpacing: Gap.m,
                  mainAxisExtent: 118,
                ),
                children: cards,
              ),
            ),

            const SizedBox(height: Gap.m),

            // Store Settings Entry Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
              child: AppCard(
                key: const Key('tile-settings'),
                onTap: () => open(SettingsScreen(backend: backend, storeName: storeName)),
                padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.m),
                child: Row(
                  children: [
                    CoinBadge(icon: Icons.settings_rounded, color: scheme.primary, size: 38),
                    const SizedBox(width: Gap.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.storeSettings,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            t.storeSettingsHint,
                            style: TextStyle(fontSize: 12, color: scheme.outline),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: scheme.chipFill,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: scheme.outline),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The luxurious obsidian action button inspired by "Slide to Swap".
class _ObsidianSellButton extends StatelessWidget {
  const _ObsidianSellButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.obsidian;

    return Material(
      color: bg,
      shape: const StadiumBorder(),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [scheme.secondary, scheme.primary],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: scheme.onObsidian,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.white54),
                  Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.white70),
                  Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.white),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.subLabel,
    this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String subLabel;
  final VoidCallback? onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Gap.m),
      radius: Gap.radiusL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CoinBadge(icon: icon, color: color, size: 36),
              if (badge > 0)
                Container(
                  key: const Key('tile-badge'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badge',
                    style: TextStyle(
                      color: scheme.onError,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: scheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
