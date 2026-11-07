import 'package:flutter/material.dart';

import '../app.dart' show LanguageButton;
import '../backend.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/local_store.dart';
import '../data/sales_models.dart';
import '../core/theme_picker.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import '../sync/sync_badge.dart';
import 'password_screens.dart';
import 'products_screen.dart';
import 'reports_screen.dart';
import 'sell_screen.dart';
import 'stock_screen.dart';
import 'today_screen.dart';
import 'utang_screen.dart';

/// Solo home: sculpted white hero card, obsidian action pill, and tactile service tiles.
/// Faithfully mirrors the luxury, high-trust atmosphere of modern fintech apps.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.backend, required this.storeName});
  final Backend backend;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final dark = scheme.brightness == Brightness.dark;

    void open(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => scope.wrap(screen)));

    final cards = <Widget>[
      _Tile(
        key: const Key('tile-utang'),
        icon: Icons.menu_book_rounded,
        color: const Color(0xFF2563EB),
        label: t.utangTitle,
        subLabel: 'Talaan ng pautang',
        onTap: () => open(const UtangScreen()),
      ),
      StreamBuilder<List<StockRow>>(
        stream: scope.store.watchStockList(),
        builder: (context, snap) {
          final lowCount = (snap.data ?? const <StockRow>[]).where((r) => r.low).length;
          return _Tile(
            key: const Key('tile-stock'),
            icon: Icons.inventory_2_rounded,
            color: const Color(0xFFF59E0B),
            label: t.stockTitle,
            subLabel: lowCount > 0 ? '$lowCount paubos' : 'Balanse ng gamit',
            badge: lowCount,
            onTap: () => open(const StockScreen()),
          );
        },
      ),
      _Tile(
        key: const Key('tile-products'),
        icon: Icons.category_rounded,
        color: const Color(0xFF0A8268),
        label: t.products,
        subLabel: 'Katalogo at presyo',
        onTap: () => open(const ProductsScreen()),
      ),
      if (scope.canManageStock)
        _Tile(
          key: const Key('tile-reports'),
          icon: Icons.bar_chart_rounded,
          color: const Color(0xFF8B5CF6),
          label: t.reportsTitle,
          subLabel: 'Benta at kita',
          onTap: () => open(ReportsScreen(backend: backend)),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          storeName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          const SyncBadge(),
          const ThemeButton(),
          const LanguageButton(),
          IconButton(
            key: const Key('change-password'),
            tooltip: t.changePassword,
            icon: const Icon(Icons.lock_reset_rounded),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(4),
            visualDensity: VisualDensity.compact,
            onPressed: () => showChangePasswordDialog(context, backend),
          ),
          IconButton(
            tooltip: t.signOut,
            icon: const Icon(Icons.logout_rounded),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(4),
            visualDensity: VisualDensity.compact,
            onPressed: backend.signOut,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, Gap.xl),
          children: [
            // Greeting + Inventory Count Subtitle
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xs, Gap.xl, Gap.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.welcome(storeName),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: 1),
                  StreamBuilder<List<ProductView>>(
                    stream: scope.store.watchProducts(),
                    builder: (context, snap) => Text(
                      t.productsOnDevice(snap.data?.length ?? 0),
                      key: const Key('product-count'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: scheme.outline,
                      ),
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
                  onTap: () => open(const TodayScreen()),
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
                            color: dark ? scheme.primaryContainer : const Color(0xFF0F172A),
                            textColor: Colors.white,
                          ),
                        ],
                      ),
                      const SizedBox(height: Gap.s),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const CoinBadge(
                            icon: Icons.payments_rounded,
                            color: Color(0xFF10B981),
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
                                  d.count == 0
                                      ? (locale == 'fil' ? 'Simulan ang unang benta' : 'Start your first sale')
                                      : (locale == 'fil' ? 'Kabuuang benta ngayong araw' : 'Total sales today'),
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
                              color: dark ? scheme.surface : const Color(0xFFF1F5F9),
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
    final dark = scheme.brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF1E293B) : const Color(0xFF0F172A);

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
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF34D399), Color(0xFF059669)],
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
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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
