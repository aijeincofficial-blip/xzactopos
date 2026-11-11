import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../backend.dart';
import '../core/theme.dart';
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

/// The signed-in app: a floating glass bottom bar (Today, Stock, POS in the middle, Utang, More).
/// POS (the Sell screen) opens first and back from another tab returns to it.
/// Reports moved into More (owner only) to keep the bar at five items.
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
        ? Badge(label: Text('$count', key: labelKey), offset: const Offset(6, -4), child: icon)
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

/// Secondary store operations in a soft glass 2-column grid harmonized with Cobalt Royal + Cool Slate.
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
        glyph: const _Glyph(Icons.inventory_2_rounded, [Color(0xFF2563EB), Color(0xFF38BDF8)]),
        onTap: () => open(const ProductsScreen()),
      ),
      _GlassTile(
        key: const Key('tile-restock'),
        label: t.restockTitle,
        glyph: const _Glyph(Icons.playlist_add_check_rounded, [Color(0xFF059669), Color(0xFF10B981)], boxed: true),
        onTap: () => open(const RestockScreen()),
      ),
      if (scope.canManageStock)
        _GlassTile(
          key: const Key('tile-reports'),
          label: t.reportsTitle,
          glyph: const _Glyph(Icons.bar_chart_rounded, [Color(0xFF1D4ED8), Color(0xFF60A5FA)]),
          onTap: () => open(ReportsScreen(backend: backend)),
        ),
      if (scope.canManageStock)
        _GlassTile(
          key: const Key('more-expenses'),
          label: t.expensesTitle,
          glyph: const _Glyph(Icons.receipt_long_rounded, [Color(0xFFD97706), Color(0xFFF59E0B)]),
          onTap: () => open(ExpensesScreen(backend: backend)),
        ),
      _GlassTile(
        key: const Key('more-shift'),
        label: t.shiftTitle,
        glyph: const _Glyph(Icons.schedule_rounded, [Color(0xFF4F46E5), Color(0xFF818CF8)]),
        onTap: () => open(ShiftScreen(backend: backend, storeName: storeName)),
      ),
      if (scope.isAdminOrSuperadmin)
        _GlassTile(
          key: const Key('more-staff'),
          label: t.staffTitle,
          glyph: const _Glyph(Icons.groups_rounded, [Color(0xFF0D9488), Color(0xFF2DD4BF)]),
          onTap: () => open(StaffScreen(backend: backend)),
        ),
      _GlassTile(
        key: const Key('more-services'),
        label: t.servicesTitle,
        glyph: const _Glyph(Icons.phone_iphone_rounded, [Color(0xFF0D9488), Color(0xFF34D399)], coin: true),
        onTap: () => open(ServicesScreen(backend: backend)),
      ),
      if (scope.canManageStock)
        _GlassTile(
          key: const Key('more-close-day'),
          label: t.dayCloseTitle,
          glyph: const _Glyph(Icons.power_settings_new_rounded, [Color(0xFFEA580C), Color(0xFFF97316)], round: true),
          onTap: () => open(DayCloseScreen(backend: backend)),
        ),
      if (scope.canManageStock)
        _GlassTile(
          key: const Key('tile-transfers'),
          label: t.transfersTitle,
          glyph: const _Glyph(Icons.local_shipping_rounded, [Color(0xFF2563EB), Color(0xFF6366F1)]),
          onTap: () async {
            final locId = await scope.store.activeStoreNow();
            if (locId != null && context.mounted) {
              open(TransfersScreen(backend: backend, locationId: locId));
            }
          },
        ),
      if (scope.canManageStock)
        _GlassTile(
          key: const Key('tile-data'),
          label: t.dataTitle,
          glyph: const _Glyph(Icons.cloud_sync_rounded, [Color(0xFF0284C7), Color(0xFF38BDF8)]),
          onTap: () => open(const DataScreen()),
        ),
      _GlassTile(
        key: const Key('tile-settings'),
        label: t.settingsTitle,
        glyph: const _Glyph(Icons.settings_rounded, [Color(0xFF334155), Color(0xFF64748B)]),
        onTap: () => open(SettingsScreen(backend: backend, storeName: storeName)),
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? [const Color(0xFF111C33), Theme.of(context).scaffoldBackgroundColor]
              : [const Color(0xFFF8FAFC), Theme.of(context).scaffoldBackgroundColor],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(Gap.l, Gap.m, Gap.l, 128 + MediaQuery.paddingOf(context).bottom),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      storeName.isEmpty ? t.more : storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  const StoreChip(),
                  const SyncBadge(),
                  IconButton(
                    key: const Key('more-settings-gear'),
                    tooltip: t.settingsTitle,
                    icon: Icon(Icons.settings_outlined, size: 24, color: scheme.onSurface),
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
      ),
    );
  }
}

/// Soft sculptural glass tile: gradient glyph centered above crisp label.
class _GlassTile extends StatelessWidget {
  const _GlassTile({
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
    final dark = scheme.brightness == Brightness.dark;
    final r = BorderRadius.circular(20);

    final List<Color> bg = switch ((dark, featured)) {
      (false, false) => const [Colors.white, Color(0xFFF8FAFC)],
      (false, true) => const [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
      (true, false) => [const Color(0xFF162032).withValues(alpha: 0.92), const Color(0xFF111827).withValues(alpha: 0.92)],
      (true, true) => [const Color(0xFF1E3A8A).withValues(alpha: 0.72), const Color(0xFF172554).withValues(alpha: 0.72)],
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: bg),
        border: Border.all(
          color: featured
              ? scheme.primary.withValues(alpha: dark ? 0.35 : 0.25)
              : (dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: dark ? Colors.black.withValues(alpha: 0.25) : const Color(0x0B0F172A),
            blurRadius: 14,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
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

/// Jewel-like gradient glyph with soft ambient elevation.
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
          borderRadius: round ? null : BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(color: colors.last.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: _size * 0.56),
      );
    } else {
      body = SizedBox(
        width: _size + 6,
        height: _size + 6,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.translate(
              offset: const Offset(0, 3),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Icon(icon, size: _size, color: colors.last.withValues(alpha: 0.35)),
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
