import 'package:flutter/material.dart';

import '../app.dart' show LanguageButton;
import '../backend.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/local_store.dart';
import '../data/warehouse_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import '../sync/sync_badge.dart';
import 'picklist_screen.dart';
import 'putaway_screen.dart';
import 'settings_screen.dart';
import 'transfers_screen.dart';
import 'warehouse_count.dart';
import 'warehouse_receive.dart';

/// The home of a warehouse clerk (F-13h): receive, count, stock, more. No selling, no store tabs.
class WarehouseShell extends StatefulWidget {
  const WarehouseShell({super.key, required this.backend, required this.storeName});
  final Backend backend;
  final String storeName;

  @override
  State<WarehouseShell> createState() => _WarehouseShellState();
}

class _WarehouseShellState extends State<WarehouseShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final store = CatalogScope.of(context).store;
    final pages = <Widget>[
      const ReceiveTab(),
      CountTab(backend: widget.backend),
      const StockTab(),
      _MoreTab(backend: widget.backend, storeName: widget.storeName),
    ];
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: Gap.l,
        title: StreamBuilder<WarehouseView?>(
          stream: store.watchActiveWarehouse(),
          builder: (context, snap) => WarehouseChip(active: snap.data),
        ),
        actions: const [SyncBadge(), LanguageButton()],
      ),
      body: SafeArea(top: false, child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7))),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            NavigationDestination(key: const Key('tab-receive'), icon: const Icon(Icons.move_to_inbox_outlined), selectedIcon: const Icon(Icons.move_to_inbox_rounded), label: t.whTabReceive),
            NavigationDestination(key: const Key('tab-count'), icon: const Icon(Icons.fact_check_outlined), selectedIcon: const Icon(Icons.fact_check_rounded), label: t.whTabCount),
            NavigationDestination(key: const Key('tab-stock'), icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2_rounded), label: t.whTabStock),
            NavigationDestination(key: const Key('tab-more'), icon: const Icon(Icons.menu_rounded), selectedIcon: const Icon(Icons.menu_rounded), label: t.whTabMore),
          ],
        ),
      ),
    );
  }
}

/// The warehouse this phone works in. Tapping opens the picker, but only when there is more than one warehouse.
class WarehouseChip extends StatelessWidget {
  const WarehouseChip({super.key, required this.active});
  final WarehouseView? active;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final store = CatalogScope.of(context).store;
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<WarehouseView>>(
      stream: store.watchWarehouses(),
      builder: (context, snap) {
        final many = (snap.data?.length ?? 0) > 1;
        final label = active == null ? t.whTabReceive : '${active!.code} · ${active!.name}';
        return InkWell(
          key: const Key('warehouse-chip'),
          borderRadius: BorderRadius.circular(999),
          onTap: many ? () => showWarehousePicker(context, store, snap.data!, active) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.warehouse_rounded, size: 17, color: scheme.primary),
              const SizedBox(width: Gap.s),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: scheme.onSurface),
                ),
              ),
              if (many) ...[
                const SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: scheme.primary),
              ],
            ]),
          ),
        );
      },
    );
  }
}

Future<void> showWarehousePicker(BuildContext context, LocalStore store, List<WarehouseView> all, WarehouseView? active) async {
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final picked = await showModalBottomSheet<WarehouseView>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Gap.radiusXL))),
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.l, Gap.m, Gap.l, Gap.l),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(99)),
              ),
            ),
            const SizedBox(height: Gap.m),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
              child: Text(t.whSwitchTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: Gap.m),
            for (final w in all)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.s),
                child: AppCard(
                  key: Key('warehouse-${w.id}'),
                  padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: Gap.s + 2),
                  borderColor: w.id == active?.id ? scheme.primary.withValues(alpha: 0.45) : null,
                  onTap: () => Navigator.pop(ctx, w),
                  child: Row(children: [
                    CoinBadge(
                      icon: Icons.warehouse_rounded,
                      color: w.id == active?.id ? scheme.primary : scheme.outline,
                      size: 36,
                    ),
                    const SizedBox(width: Gap.m),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(w.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        Text(w.code, style: TextStyle(fontSize: 12, color: scheme.outline)),
                      ]),
                    ),
                    if (w.id == active?.id) Icon(Icons.check_circle_rounded, color: scheme.primary),
                  ]),
                ),
              ),
          ]),
        ),
      );
    },
  );
  if (picked == null || picked.id == active?.id) return;
  await store.setActiveWarehouse(picked.id);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(t.whSwitched(picked.name))));
}

/// A pushed screen is outside the shell's CatalogScope, so carry it along.
Route<void> _scoped(BuildContext context, Widget child) {
  final scope = CatalogScope.of(context);
  return MaterialPageRoute<void>(
    builder: (_) => CatalogScope(
      store: scope.store,
      engine: scope.engine,
      photos: scope.photos,
      canManageStock: scope.canManageStock,
      role: scope.role,
      child: child,
    ),
  );
}

/// Whole quantities as ints so they print without a trailing .0.
num _whole(num v) => v == v.roundToDouble() ? v.toInt() : v;

String _qty(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

// ---------------------------------------------------------------------------------------------------------------------
// Receive: open orders and what this phone has received
// ---------------------------------------------------------------------------------------------------------------------

class ReceiveTab extends StatelessWidget {
  const ReceiveTab({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final store = CatalogScope.of(context).store;
    return StreamBuilder<WarehouseView?>(
      stream: store.watchActiveWarehouse(),
      builder: (context, wsnap) {
        final wh = wsnap.data;
        if (wh == null) return _Empty(text: t.whNoWarehouse, textKey: const Key('no-warehouse'));
        return StreamBuilder<List<PurchaseOrderView>>(
          stream: store.watchOpenPurchaseOrders(wh.id),
          builder: (context, osnap) {
            final orders = osnap.data ?? const <PurchaseOrderView>[];
            return StreamBuilder<List<WhReceiptView>>(
              stream: store.watchReceipts(wh.id),
              builder: (context, rsnap) {
                final receipts = rsnap.data ?? const <WhReceiptView>[];
                return ListView(padding: const EdgeInsets.fromLTRB(Gap.l, Gap.m, Gap.l, Gap.xxl), children: [
                  OutlinedButton.icon(
                    key: const Key('walkin-start'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(t.whWalkInStart, style: const TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () => Navigator.of(context).push(_scoped(context, WalkInScreen(warehouseId: wh.id))),
                  ),
                  const SizedBox(height: Gap.l),
                  Text(t.whOpenOrders, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: Gap.s),
                  if (orders.isEmpty)
                    AppCard(
                      padding: const EdgeInsets.all(Gap.l),
                      child: Text(t.whNoOrders, key: const Key('no-orders'), style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                    ),
                  for (final o in orders)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Gap.s),
                      child: _OrderCard(order: o),
                    ),
                  const SizedBox(height: Gap.l),
                  Text(t.whReceipts, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: Gap.s),
                  if (receipts.isEmpty)
                    AppCard(
                      padding: const EdgeInsets.all(Gap.l),
                      child: Text(t.whNoReceipts, key: const Key('no-receipts'), style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                    ),
                  for (final r in receipts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Gap.s),
                      child: _ReceiptTile(receipt: r),
                    ),
                ]);
              },
            );
          },
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final PurchaseOrderView order;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final status = order.status == 'partly_received' ? t.whStatusPartly : t.whStatusOrdered;
    return AppCard(
      key: Key('order-${order.id}'),
      padding: const EdgeInsets.all(Gap.m),
      onTap: () => Navigator.of(context).push(_scoped(context, OrderDetailScreen(orderId: order.id))),
      child: Row(children: [
        CoinBadge(
          icon: Icons.assignment_rounded,
          color: order.status == 'partly_received' ? scheme.tertiary : scheme.primary,
          size: 38,
        ),
        const SizedBox(width: Gap.m),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '${order.poNo} · ${order.supplierName ?? ''}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              [status, if (order.completeHere) t.whOrderComplete else t.whOrderLeft(_whole(order.remainingTotal))].join(' · '),
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
          ]),
        ),
        const SizedBox(width: Gap.s),
        order.hasPending
            ? Tooltip(
                message: t.whWaitingSync,
                child: Icon(Icons.cloud_upload_outlined, key: const Key('order-pending'), color: scheme.tertiary),
              )
            : Icon(Icons.chevron_right_rounded, color: scheme.outline),
      ]),
    );
  }
}

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final store = CatalogScope.of(context).store;
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<PurchaseOrderView?>(
      stream: store.watchPurchaseOrder(orderId),
      builder: (context, osnap) {
        final order = osnap.data;
        return Scaffold(
          appBar: AppBar(title: Text(order?.poNo ?? '')),
          body: order == null
              ? const SizedBox.shrink()
              : StreamBuilder<List<ProductView>>(
                  stream: store.watchProducts(),
                  builder: (context, psnap) {
                    final names = {for (final p in psnap.data ?? const <ProductView>[]) p.variantId: p.name};
                    return ListView(padding: const EdgeInsets.fromLTRB(Gap.l, Gap.m, Gap.l, Gap.xxl), children: [
                      AppCard(
                        padding: const EdgeInsets.all(Gap.m),
                        child: Row(children: [
                          CoinBadge(icon: Icons.local_shipping_rounded, color: scheme.primary, size: 38),
                          const SizedBox(width: Gap.m),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(order.supplierName ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                              if (order.hasPending)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(t.whWaitingSync, key: const Key('detail-pending'), style: TextStyle(fontSize: 12, color: scheme.tertiary, fontWeight: FontWeight.w600)),
                                ),
                            ]),
                          ),
                        ]),
                      ),
                      const SizedBox(height: Gap.m),
                      if (!order.completeHere)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Gap.l),
                          child: FilledButton.icon(
                            key: const Key('receive-start'),
                            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                            icon: const Icon(Icons.move_to_inbox_rounded),
                            label: Text(t.whReceiveStart, style: const TextStyle(fontWeight: FontWeight.w800)),
                            onPressed: () => Navigator.of(context).push(_scoped(context, ReceiveOrderScreen(orderId: order.id))),
                          ),
                        ),
                      Text(t.whOrderLines, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      const SizedBox(height: Gap.s),
                      for (final l in order.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Gap.s),
                          child: AppCard(
                            key: Key('line-${l.id}'),
                            padding: const EdgeInsets.all(Gap.m),
                            child: Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(names[l.variantId] ?? t.whUnknownProduct, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text(t.whLineProgress(_qty(l.received), _qty(l.ordered)), style: TextStyle(fontSize: 12, color: scheme.outline)),
                                ]),
                              ),
                              Icon(
                                l.received >= l.ordered ? Icons.check_circle_rounded : Icons.pending_outlined,
                                size: 20,
                                color: l.received >= l.ordered ? scheme.secondary : scheme.outline,
                              ),
                            ]),
                          ),
                        ),
                    ]);
                  },
                ),
        );
      },
    );
  }
}

class _ReceiptTile extends StatelessWidget {
  const _ReceiptTile({required this.receipt});
  final WhReceiptView receipt;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final title = receipt.kind == 'po' ? (receipt.poNo ?? '') : t.whReceiptWalkin;
    return AppCard(
      key: Key('receipt-${receipt.opId}'),
      padding: const EdgeInsets.all(Gap.m),
      child: Row(children: [
        CoinBadge(
          icon: receipt.confirmed ? Icons.check_circle_rounded : Icons.cloud_upload_rounded,
          color: receipt.confirmed ? scheme.secondary : scheme.tertiary,
          size: 36,
        ),
        const SizedBox(width: Gap.m),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 2),
            Text(receipt.grnNo ?? t.whWaitingSync, style: TextStyle(fontSize: 12, color: scheme.outline)),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------------
// Stock
// ---------------------------------------------------------------------------------------------------------------------

class StockTab extends StatefulWidget {
  const StockTab({super.key});
  @override
  State<StockTab> createState() => _StockTabState();
}

class _StockTabState extends State<StockTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final store = CatalogScope.of(context).store;
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<WarehouseView?>(
      stream: store.watchActiveWarehouse(),
      builder: (context, wsnap) {
        final wh = wsnap.data;
        if (wh == null) return _Empty(text: t.whNoWarehouse);
        return StreamBuilder<List<ProductView>>(
          stream: store.watchProducts(),
          builder: (context, psnap) => StreamBuilder<List<WhStockRow>>(
            stream: store.watchWarehouseStock(wh.id),
            builder: (context, ssnap) {
              final names = {for (final p in psnap.data ?? const <ProductView>[]) p.variantId: p.name};
              final q = _query.trim().toLowerCase();
              final rows = [
                for (final r in ssnap.data ?? const <WhStockRow>[])
                  if (q.isEmpty || (names[r.variantId] ?? '').toLowerCase().contains(q)) r,
              ]..sort((a, b) => (names[a.variantId] ?? '').compareTo(names[b.variantId] ?? ''));
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.l, Gap.m, Gap.l, Gap.s),
                  child: TextField(
                    key: const Key('stock-search'),
                    decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: t.whSearchStock),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Expanded(
                  child: rows.isEmpty
                      ? _Empty(text: t.whNoStock, textKey: const Key('no-stock'))
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(Gap.l, Gap.xs, Gap.l, Gap.xxl),
                          children: [
                            for (final r in rows)
                              Padding(
                                padding: const EdgeInsets.only(bottom: Gap.s),
                                child: AppCard(
                                  key: Key('stock-${r.variantId}'),
                                  padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: Gap.s + 2),
                                  onTap: wh.binsEnabled ? () => _showBins(context, store, wh, r.variantId, names[r.variantId] ?? t.whUnknownProduct) : null,
                                  child: Row(children: [
                                    CoinBadge(icon: Icons.inventory_2_rounded, color: scheme.primary, size: 36),
                                    const SizedBox(width: Gap.m),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(names[r.variantId] ?? t.whUnknownProduct, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                        if (r.pending > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(t.whStockPending(_qty(r.pending)), style: TextStyle(fontSize: 12, color: scheme.tertiary, fontWeight: FontWeight.w600)),
                                          ),
                                      ]),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: scheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        _qty(r.qty),
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: scheme.onPrimaryContainer),
                                      ),
                                    ),
                                  ]),
                                ),
                              ),
                          ],
                        ),
                ),
              ]);
            },
          ),
        );
      },
    );
  }
}

/// Where a product sits in a warehouse that uses bins.
Future<void> _showBins(BuildContext context, LocalStore store, WarehouseView wh, String variantId, String name) async {
  final t = AppLocalizations.of(context);
  final rows = [for (final r in await store.watchBinStock(wh.id).first) if (r.variantId == variantId) r];
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Gap.radiusXL))),
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.l, Gap.m, Gap.l, Gap.l),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(99)),
              ),
            ),
            const SizedBox(height: Gap.m),
            Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: Gap.m),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Gap.m),
                child: Text(t.whNoBinStock, key: const Key('no-bin-stock'), style: TextStyle(color: scheme.outline)),
              ),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.s),
                child: AppCard(
                  key: Key('bin-row-${r.binId}'),
                  padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: Gap.s + 2),
                  child: Row(children: [
                    CoinBadge(icon: Icons.view_module_rounded, color: scheme.primary, size: 34),
                    const SizedBox(width: Gap.m),
                    Expanded(child: Text(r.binCode, style: const TextStyle(fontWeight: FontWeight.w800))),
                    Text(_qty(r.qty), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ]),
                ),
              ),
          ]),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------------------------------------------------
// More
// ---------------------------------------------------------------------------------------------------------------------

class _MoreTab extends StatelessWidget {
  const _MoreTab({required this.backend, required this.storeName});
  final Backend backend;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final store = CatalogScope.of(context).store;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.l, Gap.m, Gap.l, Gap.xxl),
      children: [
        StreamBuilder<List<WarehouseView>>(
          stream: store.watchWarehouses(),
          builder: (context, snap) {
            final all = snap.data ?? const <WarehouseView>[];
            if (all.length < 2) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: Gap.s),
              child: _WhActionTile(
                key: const Key('more-switch'),
                icon: Icons.swap_horiz_rounded,
                color: scheme.primary,
                title: t.whSwitchAction,
                onTap: () async {
                  final active = await store.activeWarehouse();
                  if (context.mounted) await showWarehousePicker(context, store, all, active);
                },
              ),
            );
          },
        ),
        _WhActionTile(
          key: const Key('more-putaway'),
          icon: Icons.move_to_inbox_rounded,
          color: scheme.primary,
          title: t.putawayTitle,
          onTap: () async {
            final wh = await store.activeWarehouse();
            if (wh != null && context.mounted) {
              Navigator.of(context).push(_scoped(
                context,
                PutawayScreen(
                  backend: backend,
                  warehouseId: wh.id,
                  warehouseName: wh.name,
                ),
              ));
            }
          },
        ),
        const SizedBox(height: Gap.s),
        _WhActionTile(
          key: const Key('more-picklist'),
          icon: Icons.inventory_2_rounded,
          color: scheme.secondary,
          title: t.pickListTitle,
          onTap: () async {
            final wh = await store.activeWarehouse();
            if (wh != null && context.mounted) {
              Navigator.of(context).push(_scoped(
                context,
                PickListScreen(
                  backend: backend,
                  warehouseId: wh.id,
                  warehouseName: wh.name,
                ),
              ));
            }
          },
        ),
        const SizedBox(height: Gap.s),
        _WhActionTile(
          key: const Key('more-transfers'),
          icon: Icons.local_shipping_rounded,
          color: const Color(0xFF4F46E5),
          title: t.transfersTitle,
          onTap: () async {
            final wh = await store.activeWarehouse();
            if (wh != null && context.mounted) {
              Navigator.of(context).push(_scoped(context, TransfersScreen(backend: backend, locationId: wh.id)));
            }
          },
        ),
        const SizedBox(height: Gap.s),
        _WhActionTile(
          key: const Key('more-settings'),
          icon: Icons.settings_rounded,
          color: const Color(0xFF475569),
          title: t.settingsTitle,
          onTap: () => Navigator.of(context).push(_scoped(context, SettingsScreen(backend: backend, storeName: storeName))),
        ),
      ],
    );
  }
}

class _WhActionTile extends StatelessWidget {
  const _WhActionTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: Gap.s + 4),
      onTap: onTap,
      child: Row(children: [
        CoinBadge(icon: icon, color: color, size: 38),
        const SizedBox(width: Gap.m),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
        Icon(Icons.chevron_right_rounded, color: scheme.outline),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text, this.textKey});
  final String text;
  final Key? textKey;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(padding: const EdgeInsets.all(Gap.xl), child: Text(text, key: textKey, textAlign: TextAlign.center)),
      );
}
