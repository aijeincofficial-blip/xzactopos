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

/// Solo home: today's takings first, one big Sell button, then the other jobs as cards.
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

    void open(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => scope.wrap(screen)));

    final cards = <Widget>[
      _Tile(key: const Key('tile-utang'), icon: Icons.menu_book_rounded, color: scheme.primary, label: t.utangTitle, onTap: () => open(const UtangScreen())),
      StreamBuilder<List<StockRow>>(
        stream: scope.store.watchStockList(),
        builder: (context, snap) => _Tile(
          key: const Key('tile-stock'),
          icon: Icons.inventory_rounded,
          color: scheme.tertiary,
          onColor: scheme.onTertiary,
          label: t.stockTitle,
          badge: (snap.data ?? const <StockRow>[]).where((r) => r.low).length,
          onTap: () => open(const StockScreen()),
        ),
      ),
      _Tile(key: const Key('tile-products'), icon: Icons.category_rounded, color: scheme.secondary, onColor: scheme.onSecondary, label: t.products, onTap: () => open(const ProductsScreen())),
      // reports are for the owner and admins (the same people who change stock)
      if (scope.canManageStock)
        _Tile(key: const Key('tile-reports'), icon: Icons.bar_chart_rounded, color: scheme.error, onColor: scheme.onError, label: t.reportsTitle, onTap: () => open(ReportsScreen(backend: backend))),
    ];

    return Scaffold(
      appBar: AppBar(
        // the store name is in the body (big); keeping the bar for the icons stops it being cut off
        actions: [
          const SyncBadge(),
          const ThemeButton(),
          const LanguageButton(),
          IconButton(
            key: const Key('change-password'),
            tooltip: t.changePassword,
            icon: const Icon(Icons.lock_reset),
            onPressed: () => showChangePasswordDialog(context, backend),
          ),
          IconButton(tooltip: t.signOut, icon: const Icon(Icons.logout), onPressed: backend.signOut),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, Gap.xl),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.l, Gap.s, Gap.l, Gap.s),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.welcome(storeName), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                StreamBuilder<List<ProductView>>(
                  stream: scope.store.watchProducts(),
                  builder: (context, snap) => Text(
                    t.productsOnDevice(snap.data?.length ?? 0),
                    key: const Key('product-count'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ]),
            ),
            StreamBuilder<TodayTotals>(
              stream: scope.store.watchToday(),
              builder: (context, snap) {
                final d = snap.data ?? const TodayTotals();
                return SummaryCard(
                  key: const Key('tile-today'),
                  accent: true,
                  onTap: () => open(const TodayScreen()),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(t.todaySales, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onPrimary.withValues(alpha: 0.85)))),
                      Icon(Icons.chevron_right_rounded, color: scheme.onPrimary.withValues(alpha: 0.85)),
                    ]),
                    const SizedBox(height: Gap.xs),
                    Text(
                      Money(d.total, scope.store.baseCurrency).format(locale),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: scheme.onPrimary),
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(t.todayCount(d.count), style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onPrimary.withValues(alpha: 0.85))),
                  ]),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.l, Gap.s, Gap.l, Gap.m),
              child: _SellButton(key: const Key('tile-sell'), label: t.sell, onTap: () => open(const SellScreen())),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.l),
              child: GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: Gap.m, crossAxisSpacing: Gap.m, mainAxisExtent: 140),
                children: cards,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The main job: a wide pill button in the accent colour.
class _SellButton extends StatelessWidget {
  const _SellButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondary,
      shape: const StadiumBorder(),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 68,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.point_of_sale_rounded, size: 30, color: scheme.onSecondary),
            const SizedBox(width: Gap.m),
            Text(label, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSecondary)),
          ]),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.icon, required this.color, this.onColor, required this.label, this.onTap, this.badge = 0});
  final IconData icon;
  final Color color;
  final Color? onColor;
  final String label;
  final VoidCallback? onTap;

  /// A count shown on the tile (e.g. products running low); 0 = none.
  final int badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconBadge(icon: icon, color: color, onColor: onColor),
          if (badge > 0)
            Container(
              key: const Key('tile-badge'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: scheme.error, borderRadius: BorderRadius.circular(Gap.radiusM)),
              child: Text('$badge', style: TextStyle(color: scheme.onError, fontWeight: FontWeight.w700)),
            ),
        ]),
        const Spacer(),
        Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
