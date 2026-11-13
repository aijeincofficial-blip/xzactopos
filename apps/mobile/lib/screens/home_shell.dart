import 'package:flutter/material.dart';

import '../backend.dart';
import '../core/design_tokens.g.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/sales_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import '../sync/sync_badge.dart';
import 'data_screen.dart';
import 'day_close_screen.dart';
import 'expenses_screen.dart';
import 'glass_tab_bar.dart';
import 'products_screen.dart';
import 'reports_screen.dart';
import 'restock_screen.dart';
import 'sell_screen.dart';
import 'services_screen.dart';
import 'settings_screen.dart';
import 'shift_screen.dart';
import 'staff_screen.dart';
import 'stock_screen.dart';
import 'store_picker.dart';
import 'today_screen.dart';
import 'transfers_screen.dart';
import 'utang_screen.dart';

class _TabSpec {
  const _TabSpec(this.key, this.label, this.icon, this.page);
  final String key;
  final String label;
  final Widget Function(Color color) icon;
  final Widget Function() page;
}

/// The signed-in app: a Night Market ink bottom bar (Today, Stock, POS in the middle, Utang, More).
/// POS (the Sell screen) opens first and back from another tab returns to it.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.backend, required this.storeName});
  final Backend backend;
  final String storeName;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

const _posIndex = 2;

class _HomeShellState extends State<HomeShell> {
  int _index = _posIndex;
  final Set<int> _built = {_posIndex};

  void _select(int i) => setState(() {
        _index = i;
        _built.add(i);
      });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final tabs = <_TabSpec>[
      _TabSpec('tab-today', t.tabToday, (c) => TodayGlyph(color: c), () => TodayScreen(backend: widget.backend)),
      _TabSpec('tile-stock', t.stockTitle, (c) => BoxGlyph(color: c), () => const StockScreen()),
      _TabSpec('tile-sell', t.tabPos, (c) => const SizedBox.shrink(),
          () => SellScreen(backend: widget.backend, storeName: widget.storeName)),
      _TabSpec('tile-utang', t.utangTitle, (c) => NotebookGlyph(color: c),
          () => UtangScreen(storeName: widget.storeName)),
      _TabSpec('tab-more', t.more, (c) => MoreGlyph(color: c),
          () => MoreScreen(backend: widget.backend, storeName: widget.storeName)),
    ];
    final index = _index.clamp(0, tabs.length - 1);

    Widget badged(Widget icon, int count, {Key? labelKey}) => count > 0
        ? Badge(
            backgroundColor: DesignTokens.swMeal,
            textColor: DesignTokens.swMealFg,
            label: Text('$count', key: labelKey),
            offset: const Offset(6, -4),
            child: icon,
          )
        : icon;

    Widget iconFor(_TabSpec s, Color color) {
      final base = s.icon(color);
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
      canPop: index == _posIndex,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(_posIndex);
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: index,
          children: [
            for (var i = 0; i < tabs.length; i++) _built.contains(i) ? tabs[i].page() : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: GlassTabBar(
          index: index,
          centerIndex: _posIndex,
          onSelect: _select,
          tabs: [
            for (final s in tabs) GlassTab(key: s.key, label: s.label, icon: (c) => iconFor(s, c)),
          ],
        ),
      ),
    );
  }
}

/// Secondary store operations in a tactile 2-column Night Market grid (`--paper`/`--ink2` + `1.5px` strokes).
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

    final tiles = <Widget>[
      _MoreTile(
        key: const Key('tile-products'),
        featured: true,
        label: t.products,
        glyph: const _MoreSwatchGlyph(
          icon: Icons.inventory_2_rounded,
          bg: DesignTokens.ink,
          fg: DesignTokens.lime,
        ),
        onTap: () => open(const ProductsScreen()),
      ),
      _MoreTile(
        key: const Key('tile-restock'),
        label: t.restockTitle,
        glyph: const _MoreSwatchGlyph(
          icon: Icons.playlist_add_check_rounded,
          bg: DesignTokens.okBg,
          fg: DesignTokens.okFg,
        ),
        onTap: () => open(const RestockScreen()),
      ),
      if (scope.canManageStock)
        _MoreTile(
          key: const Key('tile-reports'),
          label: t.reportsTitle,
          glyph: const _MoreSwatchGlyph(
            icon: Icons.bar_chart_rounded,
            bg: DesignTokens.swNoncoffee,
            fg: DesignTokens.swNoncoffeeFg,
          ),
          onTap: () => open(ReportsScreen(backend: backend)),
        ),
      if (scope.canManageStock)
        _MoreTile(
          key: const Key('more-expenses'),
          label: t.expensesTitle,
          glyph: const _MoreSwatchGlyph(
            icon: Icons.receipt_long_rounded,
            bg: DesignTokens.swPastry,
            fg: DesignTokens.swPastryFg,
          ),
          onTap: () => open(ExpensesScreen(backend: backend)),
        ),
      _MoreTile(
        key: const Key('more-shift'),
        label: t.shiftTitle,
        glyph: const _MoreSwatchGlyph(
          icon: Icons.schedule_rounded,
          bg: DesignTokens.swCoffee,
          fg: DesignTokens.swCoffeeFg,
        ),
        onTap: () => open(ShiftScreen(backend: backend, storeName: storeName)),
      ),
      if (scope.isAdminOrSuperadmin)
        _MoreTile(
          key: const Key('more-staff'),
          label: t.staffTitle,
          glyph: const _MoreSwatchGlyph(
            icon: Icons.groups_rounded,
            bg: DesignTokens.okBg,
            fg: DesignTokens.okFg,
          ),
          onTap: () => open(StaffScreen(backend: backend)),
        ),
      _MoreTile(
        key: const Key('more-services'),
        label: t.servicesTitle,
        glyph: const _MoreSwatchGlyph(
          icon: Icons.phone_iphone_rounded,
          bg: DesignTokens.lime,
          fg: DesignTokens.ink,
          coin: true,
        ),
        onTap: () => open(ServicesScreen(backend: backend)),
      ),
      if (scope.canManageStock)
        _MoreTile(
          key: const Key('more-close-day'),
          label: t.dayCloseTitle,
          glyph: const _MoreSwatchGlyph(
            icon: Icons.power_settings_new_rounded,
            bg: DesignTokens.swMeal,
            fg: DesignTokens.swMealFg,
          ),
          onTap: () => open(DayCloseScreen(backend: backend)),
        ),
      if (scope.canManageStock)
        _MoreTile(
          key: const Key('tile-transfers'),
          label: t.transfersTitle,
          glyph: const _MoreSwatchGlyph(
            icon: Icons.local_shipping_rounded,
            bg: DesignTokens.swCoffee,
            fg: DesignTokens.swCoffeeFg,
          ),
          onTap: () async {
            final locId = await scope.store.activeStoreNow();
            if (locId != null && context.mounted) {
              open(TransfersScreen(backend: backend, locationId: locId));
            }
          },
        ),
      if (scope.canManageStock)
        _MoreTile(
          key: const Key('tile-data'),
          label: t.dataTitle,
          glyph: const _MoreSwatchGlyph(
            icon: Icons.cloud_sync_rounded,
            bg: DesignTokens.swNoncoffee,
            fg: DesignTokens.swNoncoffeeFg,
          ),
          onTap: () => open(const DataScreen()),
        ),
      _MoreTile(
        key: const Key('tile-settings'),
        label: t.settingsTitle,
        glyph: _MoreSwatchGlyph(
          icon: Icons.settings_rounded,
          bg: scheme.chipFill,
          fg: scheme.onSurface,
        ),
        onTap: () => open(SettingsScreen(backend: backend, storeName: storeName)),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(Gap.l, Gap.m, Gap.l, 128 + MediaQuery.paddingOf(context).bottom),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeName.isEmpty ? t.more : storeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NightMarketText.display(context, size: 24),
                      ),
                    ],
                  ),
                ),
                const StoreChip(),
                const SyncBadge(),
                IconButton(
                  key: const Key('more-settings-gear'),
                  tooltip: t.settingsTitle,
                  icon: Icon(Icons.settings_outlined, size: 23, color: scheme.onSurface),
                  onPressed: () => open(SettingsScreen(backend: backend, storeName: storeName)),
                ),
              ],
            ),
            const SizedBox(height: Gap.m),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.48,
              children: tiles,
            ),
          ],
        ),
      ),
    );
  }
}

/// Crisp Night Market operation tile with `1.5px` stroke, zero blur or gradients.
class _MoreTile extends StatelessWidget {
  const _MoreTile({
    super.key,
    required this.label,
    required this.glyph,
    required this.onTap,
    this.featured = false,
  });

  final String label;
  final Widget glyph;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.isDark;
    final bg = featured
        ? (dark ? scheme.nmInkLine : scheme.nmOkBg.withValues(alpha: 0.48))
        : scheme.surface;
    final border = featured
        ? (dark ? scheme.nmLime.withValues(alpha: 0.6) : scheme.nmInk.withValues(alpha: 0.45))
        : scheme.outlineVariant;

    return AppCard(
      onTap: onTap,
      color: bg,
      borderColor: border,
      borderWidth: Gap.border,
      radius: Gap.radiusL,
      padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: Gap.m),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          glyph,
          const SizedBox(height: Gap.s),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: NightMarketFont.sans,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreSwatchGlyph extends StatelessWidget {
  const _MoreSwatchGlyph({
    required this.icon,
    required this.bg,
    required this.fg,
    this.coin = false,
  });

  final IconData icon;
  final Color bg;
  final Color fg;
  final bool coin;

  static const double _size = 44;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fg.withValues(alpha: 0.18), width: 1.2),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: fg, size: 24),
    );
    if (!coin) return badge;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        badge,
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: DesignTokens.ink,
              shape: BoxShape.circle,
              border: Border.all(color: DesignTokens.lime, width: 1.5),
            ),
            alignment: Alignment.center,
            child: const Text(
              '₱',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: DesignTokens.lime, height: 1),
            ),
          ),
        ),
      ],
    );
  }
}
