import 'package:flutter/material.dart';

import '../backend.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/local_store.dart';
import '../data/sales_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import '../sync/sync_badge.dart';
import 'day_close_screen.dart';
import 'expenses_screen.dart';
import 'products_screen.dart';
import 'reports_screen.dart';
import 'restock_screen.dart';
import 'sell_screen.dart';
import 'services_screen.dart';
import 'settings_screen.dart';
import 'stock_screen.dart';
import 'today_screen.dart';
import 'utang_screen.dart';

class _TabSpec {
  const _TabSpec(this.key, this.icon, this.selectedIcon, this.label, this.page);
  final String key;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget Function() page;
}

/// The signed-in app: a bottom bar for the daily tools (Sell, Stock, Utang, Reports) and More for the rest.
/// Sell opens first; Today is a strip on top of it. Tabs are built when first opened and then kept.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.backend, required this.storeName});
  final Backend backend;
  final String storeName;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final Set<int> _built = {0};

  void _select(int i) => setState(() {
        _index = i;
        _built.add(i);
      });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final tabs = <_TabSpec>[
      _TabSpec('tile-sell', Icons.point_of_sale_outlined, Icons.point_of_sale_rounded, t.sell,
          () => SellScreen(backend: widget.backend)),
      _TabSpec('tile-stock', Icons.inventory_2_outlined, Icons.inventory_2_rounded, t.stockTitle, () => const StockScreen()),
      _TabSpec('tile-utang', Icons.menu_book_outlined, Icons.menu_book_rounded, t.utangTitle,
          () => UtangScreen(storeName: widget.storeName)),
      if (scope.canManageStock)
        _TabSpec('tile-reports', Icons.bar_chart_outlined, Icons.bar_chart_rounded, t.reportsTitle,
            () => ReportsScreen(backend: widget.backend)),
      _TabSpec('tab-more', Icons.more_horiz_rounded, Icons.more_horiz_rounded, t.more,
          () => MoreScreen(backend: widget.backend, storeName: widget.storeName)),
    ];
    final index = _index.clamp(0, tabs.length - 1);

    Widget badged(Widget icon, int count, {Key? labelKey}) =>
        count > 0 ? Badge(label: Text('$count', key: labelKey), child: icon) : icon;

    // the badge shows on the selected tab too
    Widget icon(_TabSpec s, bool selected) {
      final base = Icon(selected ? s.selectedIcon : s.icon);
      return switch (s.key) {
        'tile-stock' => StreamBuilder<List<StockRow>>(
            stream: scope.store.watchStockList(),
            builder: (context, snap) {
              final rows = snap.data ?? const <StockRow>[];
              final today = DateTime.now();
              final n = rows.where((r) => r.low).length + rows.where((r) => isExpiringRow(r, today)).length;
              return badged(base, n, labelKey: const Key('tile-badge'));
            },
          ),
        'tile-utang' => StreamBuilder<List<CustomerView>>(
            stream: scope.store.watchCustomers(),
            builder: (context, snap) {
              final today = DateTime.now();
              final n = (snap.data ?? const <CustomerView>[]).where((c) => c.overdue(today)).length;
              return badged(base, n);
            },
          ),
        _ => base,
      };
    }

    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0); // back from another tab goes to Sell first
      },
      child: Scaffold(
        body: IndexedStack(
          index: index,
          children: [
            for (var i = 0; i < tabs.length; i++) _built.contains(i) ? tabs[i].page() : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: _select,
          destinations: [
            for (var i = 0; i < tabs.length; i++)
              NavigationDestination(
                key: Key(tabs[i].key),
                label: tabs[i].label,
                icon: icon(tabs[i], false),
                selectedIcon: icon(tabs[i], true),
              ),
          ],
        ),
      ),
    );
  }
}

/// Everything that is not a daily tool: products, restock, today's detail, expenses, load and e-wallet, day close, settings.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.backend, required this.storeName});
  final Backend backend;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    void open(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => scope.wrap(screen)));

    Widget row(String key, IconData icon, Color color, String title, {Widget? subtitle, required Widget Function() page}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Gap.s),
        child: AppCard(
          key: Key(key),
          padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.m),
          radius: Gap.radiusL,
          onTap: () => open(page()),
          child: Row(children: [
            CoinBadge(icon: icon, color: color, size: 38),
            const SizedBox(width: Gap.m),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ?subtitle,
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: scheme.outline),
          ]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.more), actions: const [SyncBadge()]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.s, Gap.xl, Gap.xxl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AppCard(
            padding: const EdgeInsets.all(Gap.l),
            child: Row(children: [
              CoinBadge(icon: Icons.storefront_rounded, color: scheme.primary, size: 44),
              const SizedBox(width: Gap.m),
              Expanded(
                child: Text(storeName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
          const SizedBox(height: Gap.l),
          row(
            'tile-products',
            Icons.category_rounded,
            scheme.secondary,
            t.products,
            subtitle: StreamBuilder<List<ProductView>>(
              stream: scope.store.watchProducts(),
              builder: (context, snap) => Text(
                t.productsOnDevice(snap.data?.length ?? 0),
                key: const Key('product-count'),
                style: TextStyle(fontSize: 12, color: scheme.outline),
              ),
            ),
            page: () => const ProductsScreen(),
          ),
          row('tile-restock', Icons.shopping_basket_rounded, scheme.tertiary, t.restockTitle, page: () => const RestockScreen()),
          row('more-today', Icons.today_rounded, scheme.primary, t.todayTitle, page: () => TodayScreen(backend: backend)),
          if (scope.canManageStock)
            row('more-expenses', Icons.receipt_long_rounded, scheme.error, t.expensesTitle, page: () => ExpensesScreen(backend: backend)),
          row('more-services', Icons.swap_horiz_rounded, scheme.secondary, t.servicesTitle, page: () => ServicesScreen(backend: backend)),
          if (scope.canManageStock)
            row('more-close-day', Icons.lock_clock_rounded, scheme.primary, t.dayCloseTitle, page: () => DayCloseScreen(backend: backend)),
          row('tile-settings', Icons.settings_rounded, scheme.outline, t.settingsTitle,
              page: () => SettingsScreen(backend: backend, storeName: storeName)),
        ]),
      ),
    );
  }
}
