import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../backend.dart';
import '../core/theme.dart';
import '../data/sales_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
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
import 'stock_screen.dart';
import 'store_picker.dart';
import 'today_screen.dart';
import 'utang_screen.dart';

class _TabSpec {
  const _TabSpec(this.key, this.label, this.icon, this.page);
  final String key;
  final String label;
  final Widget Function(Color color) icon;
  final Widget Function() page;
}

/// The signed-in app: a floating glass bottom bar (Today, Stock, POS in the middle, Utang, More).
/// POS (the Sell screen) opens first and back from another tab returns to it.
/// Reports moved into More (owner only) to keep the bar at five items.
/// Tabs are built when first opened and then kept.
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
      _TabSpec('tile-sell', t.tabPos, (c) => const SizedBox.shrink(), () => SellScreen(backend: widget.backend)),
      _TabSpec('tile-utang', t.utangTitle, (c) => NotebookGlyph(color: c), () => UtangScreen(storeName: widget.storeName)),
      _TabSpec('tab-more', t.more, (c) => MoreGlyph(color: c),
          () => MoreScreen(backend: widget.backend, storeName: widget.storeName)),
    ];
    final index = _index.clamp(0, tabs.length - 1);

    Widget badged(Widget icon, int count, {Key? labelKey}) => count > 0
        ? Badge(label: Text('$count', key: labelKey), offset: const Offset(6, -4), child: icon)
        : icon;

    // counts show on the selected tab too
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
        if (!didPop) _select(_posIndex); // back from another tab goes to POS first
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

/// Everything that is not a daily tool, as a grid of soft glass tiles:
/// products, restock list, reports (owner), expenses, load and e-wallet, day close, import and export, settings.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.backend, required this.storeName});
  final Backend backend;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;

    void open(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => scope.wrap(screen)));

    final tiles = <Widget>[
      _GlassTile(
        key: const Key('tile-products'),
        featured: true,
        label: t.products,
        glyph: const _Glyph(Icons.inventory_2_rounded, [Color(0xFF1E6FF2), Color(0xFF38BDF8)]),
        onTap: () => open(const ProductsScreen()),
      ),
      _GlassTile(
        key: const Key('tile-restock'),
        label: t.restockTitle,
        glyph: const _Glyph(Icons.format_list_bulleted_rounded, [Color(0xFF0284C7), Color(0xFF10B981)], boxed: true),
        onTap: () => open(const RestockScreen()),
      ),
      if (scope.canManageStock)
        _GlassTile(
          key: const Key('tile-reports'),
          label: t.reportsTitle,
          glyph: const _Glyph(Icons.insert_chart_rounded, [Color(0xFF2563EB), Color(0xFF38BDF8)]),
          onTap: () => open(ReportsScreen(backend: backend)),
        ),
      if (scope.canManageStock)
        _GlassTile(
          key: const Key('more-expenses'),
          label: t.expensesTitle,
          glyph: const _Glyph(Icons.receipt_long_rounded, [Color(0xFFFF8A00), Color(0xFFF59E0B)]),
          onTap: () => open(ExpensesScreen(backend: backend)),
        ),
      _GlassTile(
        key: const Key('more-services'),
        label: t.servicesTitle,
        glyph: const _Glyph(Icons.phone_iphone_rounded, [Color(0xFF0D9488), Color(0xFF2FD9B2)], coin: true),
        onTap: () => open(ServicesScreen(backend: backend)),
      ),
      if (scope.canManageStock)
        _GlassTile(
          key: const Key('more-close-day'),
          label: t.dayCloseTitle,
          glyph: const _Glyph(Icons.power_settings_new_rounded, [Color(0xFFFF7A00), Color(0xFFEA580C)], round: true),
          onTap: () => open(DayCloseScreen(backend: backend)),
        ),
      if (scope.canManageStock)
        _GlassTile(
          key: const Key('tile-data'),
          label: t.dataTitle,
          glyph: const _Glyph(Icons.upload_rounded, [Color(0xFF0EA5E9), Color(0xFF2563EB)]),
          onTap: () => open(const DataScreen()),
        ),
      _GlassTile(
        key: const Key('tile-settings'),
        label: t.settingsTitle,
        glyph: const _Glyph(Icons.settings_rounded, [Color(0xFF1E3A8A), Color(0xFF1E6FF2)]),
        onTap: () => open(SettingsScreen(backend: backend, storeName: storeName)),
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // ends on the scaffold colour so there is no seam above the floating bar
          colors: dark
              ? [const Color(0xFF1A2140), Theme.of(context).scaffoldBackgroundColor]
              : [const Color(0xFFF8F9FD), Theme.of(context).scaffoldBackgroundColor],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.l, Gap.xl, 100),
            children: [
              // header: store name, settings gear (matches owner mockup)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: dark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('more-settings-gear'),
                    tooltip: t.settingsTitle,
                    icon: Icon(Icons.settings_rounded, size: 26, color: dark ? Colors.white : const Color(0xFF1E293B)),
                    onPressed: () => open(SettingsScreen(backend: backend, storeName: storeName)),
                  ),
                ],
              ),
              const Align(alignment: Alignment.centerLeft, child: StoreChip()),
              const SizedBox(height: Gap.l),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.42,
                children: tiles,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft glass tile: big gradient glyph centred above the label.
class _GlassTile extends StatelessWidget {
  const _GlassTile({super.key, required this.label, required this.glyph, required this.onTap, this.featured = false});
  final String label;
  final Widget glyph;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    final r = BorderRadius.circular(22);

    final List<Color> bg = switch ((dark, featured)) {
      (false, false) => const [Colors.white, Color(0xFFF7F8FD)],
      (false, true) => const [Color(0xFFF0F6FE), Color(0xFFE5F0FD)],
      (true, false) => [const Color(0xFF1E293B).withValues(alpha: 0.85), const Color(0xFF162032).withValues(alpha: 0.85)],
      (true, true) => [const Color(0xFF1E3A8A).withValues(alpha: 0.70), const Color(0xFF172554).withValues(alpha: 0.70)],
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: bg),
        border: Border.all(color: dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: dark ? Colors.black.withValues(alpha: 0.25) : const Color(0x0C0F172A),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: r,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.s, vertical: Gap.m),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: dark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A "3D" glyph: gradient-filled icon over a blurred coloured shadow.
/// [boxed] puts it on a gradient rounded square, [round] on a gradient circle, [coin] adds an amber coin.
class _Glyph extends StatelessWidget {
  const _Glyph(this.icon, this.colors, {this.boxed = false, this.round = false, this.coin = false});
  final IconData icon;
  final List<Color> colors;
  final bool boxed;
  final bool round;
  final bool coin;

  static const double _size = 42;

  @override
  Widget build(BuildContext context) {
    final gradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors);

    Widget body;
    if (boxed || round) {
      body = Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          gradient: gradient,
          shape: round ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: round ? null : BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.40), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: Icon(icon, color: Colors.white, size: _size * 0.58),
      );
    } else {
      body = SizedBox(
        width: _size + 6,
        height: _size + 6,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.translate(
              offset: const Offset(0, 4),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Icon(icon, size: _size, color: colors.last.withValues(alpha: 0.45)),
              ),
            ),
            ShaderMask(
              shaderCallback: (b) => gradient.createShader(b),
              blendMode: BlendMode.srcIn,
              child: Icon(icon, size: _size, color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (!coin) return body;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        body,
        Positioned(
          right: -2,
          top: 2,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)]),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: const Center(
              child: Text('₱', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }
}
