import 'package:flutter/material.dart';

import '../app.dart' show LanguageButton;
import '../backend.dart';
import '../data/local_store.dart';
import '../data/sales_models.dart';
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

/// Solo home: big buttons, two to a row, nothing else to learn.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.backend, required this.storeName});
  final Backend backend;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);

    void open(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => scope.wrap(screen)));

    final tiles = <Widget>[
      _Tile(key: const Key('tile-sell'), icon: Icons.point_of_sale, label: t.sell, onTap: () => open(const SellScreen())),
      _Tile(key: const Key('tile-utang'), icon: Icons.menu_book_outlined, label: t.utangTitle, onTap: () => open(const UtangScreen())),
      _Tile(key: const Key('tile-today'), icon: Icons.today_outlined, label: t.todayTitle, onTap: () => open(const TodayScreen())),
      StreamBuilder<List<StockRow>>(
        stream: scope.store.watchStockList(),
        builder: (context, snap) => _Tile(
          key: const Key('tile-stock'),
          icon: Icons.inventory_outlined,
          label: t.stockTitle,
          badge: (snap.data ?? const <StockRow>[]).where((r) => r.low).length,
          onTap: () => open(const StockScreen()),
        ),
      ),
      _Tile(key: const Key('tile-products'), icon: Icons.inventory_2_outlined, label: t.products, onTap: () => open(const ProductsScreen())),
      // reports are for the owner and admins (the same people who change stock)
      if (scope.canManageStock)
        _Tile(key: const Key('tile-reports'), icon: Icons.bar_chart, label: t.reportsTitle, onTap: () => open(ReportsScreen(backend: backend))),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(storeName, overflow: TextOverflow.ellipsis),
        actions: [
          const SyncBadge(),
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            Text(t.welcome(storeName), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            StreamBuilder<List<ProductView>>(
              stream: scope.store.watchProducts(),
              builder: (context, snap) => Text(
                t.productsOnDevice(snap.data?.length ?? 0),
                key: const Key('product-count'),
              ),
            ),
            const SizedBox(height: 20),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 112),
              children: tiles,
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.icon, required this.label, this.onTap, this.badge = 0});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// A red count shown on the tile (e.g. products running low); 0 = none.
  final int badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Stack(children: [
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 40, color: scheme.onPrimaryContainer),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onPrimaryContainer)),
            ]),
          ),
          if (badge > 0)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                key: const Key('tile-badge'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: scheme.error, borderRadius: BorderRadius.circular(12)),
                child: Text('$badge', style: TextStyle(color: scheme.onError, fontWeight: FontWeight.w700)),
              ),
            ),
        ]),
      ),
    );
  }
}
