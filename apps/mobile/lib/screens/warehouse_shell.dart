import 'package:flutter/material.dart';

import '../app.dart' show LanguageButton;
import '../backend.dart';
import '../core/theme.dart';
import '../data/local_store.dart';
import '../data/warehouse_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import '../sync/sync_badge.dart';
import 'settings_screen.dart';

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
      const _CountTab(),
      const StockTab(),
      _MoreTab(backend: widget.backend, storeName: widget.storeName),
    ];
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(key: const Key('tab-receive'), icon: const Icon(Icons.move_to_inbox_outlined), selectedIcon: const Icon(Icons.move_to_inbox_rounded), label: t.whTabReceive),
          NavigationDestination(key: const Key('tab-count'), icon: const Icon(Icons.fact_check_outlined), selectedIcon: const Icon(Icons.fact_check_rounded), label: t.whTabCount),
          NavigationDestination(key: const Key('tab-stock'), icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2_rounded), label: t.whTabStock),
          NavigationDestination(key: const Key('tab-more'), icon: const Icon(Icons.menu_rounded), selectedIcon: const Icon(Icons.menu_rounded), label: t.whTabMore),
        ],
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
    return StreamBuilder<List<WarehouseView>>(
      stream: store.watchWarehouses(),
      builder: (context, snap) {
        final many = (snap.data?.length ?? 0) > 1;
        final label = active == null ? t.whTabReceive : '${active!.code} · ${active!.name}';
        return InkWell(
          key: const Key('warehouse-chip'),
          borderRadius: BorderRadius.circular(Gap.m),
          onTap: many ? () => showWarehousePicker(context, store, snap.data!, active) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.s),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.warehouse_rounded, size: 20),
              const SizedBox(width: Gap.s),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium)),
              if (many) const Icon(Icons.arrow_drop_down_rounded),
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
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.l, Gap.xl, Gap.s),
          child: Text(t.whSwitchTitle, style: Theme.of(ctx).textTheme.titleLarge),
        ),
        for (final w in all)
          ListTile(
            key: Key('warehouse-${w.id}'),
            leading: const Icon(Icons.warehouse_rounded),
            title: Text(w.name),
            subtitle: Text(w.code),
            trailing: w.id == active?.id ? Icon(Icons.check_circle_rounded, color: Theme.of(ctx).colorScheme.primary) : null,
            onTap: () => Navigator.pop(ctx, w),
          ),
        const SizedBox(height: Gap.s),
      ]),
    ),
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
                return ListView(padding: const EdgeInsets.all(Gap.l), children: [
                  Text(t.whOpenOrders, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: Gap.s),
                  if (orders.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: Gap.l), child: Text(t.whNoOrders, key: const Key('no-orders'))),
                  for (final o in orders) _OrderCard(order: o),
                  const SizedBox(height: Gap.xl),
                  Text(t.whReceipts, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: Gap.s),
                  if (receipts.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: Gap.l), child: Text(t.whNoReceipts, key: const Key('no-receipts'))),
                  for (final r in receipts) _ReceiptTile(receipt: r),
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
    final status = order.status == 'partly_received' ? t.whStatusPartly : t.whStatusOrdered;
    return Card(
      child: ListTile(
        key: Key('order-${order.id}'),
        title: Text('${order.poNo} · ${order.supplierName ?? ''}', overflow: TextOverflow.ellipsis),
        subtitle: Text([status, if (order.completeHere) t.whOrderComplete else t.whOrderLeft(_whole(order.remainingTotal))].join(' · ')),
        trailing: order.hasPending
            ? Tooltip(message: t.whWaitingSync, child: const Icon(Icons.cloud_upload_outlined, key: Key('order-pending')))
            : const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(_scoped(context, OrderDetailScreen(orderId: order.id))),
      ),
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
    return StreamBuilder<PurchaseOrderView?>(
      stream: _orderStream(store, orderId),
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
                    return ListView(padding: const EdgeInsets.all(Gap.l), children: [
                      Text(order.supplierName ?? '', style: Theme.of(context).textTheme.titleMedium),
                      if (order.hasPending) Padding(padding: const EdgeInsets.only(top: Gap.s), child: Text(t.whWaitingSync, key: const Key('detail-pending'))),
                      const SizedBox(height: Gap.l),
                      Text(t.whOrderLines, style: Theme.of(context).textTheme.titleSmall),
                      for (final l in order.items)
                        ListTile(
                          key: Key('line-${l.id}'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(names[l.variantId] ?? t.whUnknownProduct),
                          subtitle: Text(t.whLineProgress(_qty(l.received), _qty(l.ordered))),
                        ),
                    ]);
                  },
                ),
        );
      },
    );
  }
}

/// One order, re-read whenever warehouse data changes.
Stream<PurchaseOrderView?> _orderStream(LocalStore store, String id) async* {
  yield await store.purchaseOrder(id);
  await for (final _ in store.watchWarehouses()) {
    yield await store.purchaseOrder(id);
  }
}

class _ReceiptTile extends StatelessWidget {
  const _ReceiptTile({required this.receipt});
  final WhReceiptView receipt;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final title = receipt.kind == 'po' ? (receipt.poNo ?? '') : t.whReceiptWalkin;
    return ListTile(
      key: Key('receipt-${receipt.opId}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(receipt.confirmed ? Icons.check_circle_outline_rounded : Icons.cloud_upload_outlined),
      title: Text(title, overflow: TextOverflow.ellipsis),
      subtitle: Text(receipt.grnNo ?? t.whWaitingSync),
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
                  padding: const EdgeInsets.all(Gap.l),
                  child: TextField(
                    key: const Key('stock-search'),
                    decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: t.whSearchStock),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Expanded(
                  child: rows.isEmpty
                      ? _Empty(text: t.whNoStock, textKey: const Key('no-stock'))
                      : ListView(children: [
                          for (final r in rows)
                            ListTile(
                              key: Key('stock-${r.variantId}'),
                              title: Text(names[r.variantId] ?? t.whUnknownProduct),
                              subtitle: r.pending > 0 ? Text(t.whStockPending(_qty(r.pending))) : null,
                              trailing: Text(_qty(r.qty), style: Theme.of(context).textTheme.titleMedium),
                            ),
                        ]),
                ),
              ]);
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------------
// Count (v1: placeholder; counting is online-only and arrives in H6) and More
// ---------------------------------------------------------------------------------------------------------------------

class _CountTab extends StatelessWidget {
  const _CountTab();
  @override
  Widget build(BuildContext context) => _Empty(text: AppLocalizations.of(context).whCountSoon, textKey: const Key('count-soon'));
}

class _MoreTab extends StatelessWidget {
  const _MoreTab({required this.backend, required this.storeName});
  final Backend backend;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final store = CatalogScope.of(context).store;
    return ListView(children: [
      StreamBuilder<List<WarehouseView>>(
        stream: store.watchWarehouses(),
        builder: (context, snap) {
          final all = snap.data ?? const <WarehouseView>[];
          if (all.length < 2) return const SizedBox.shrink();
          return ListTile(
            key: const Key('more-switch'),
            leading: const Icon(Icons.swap_horiz_rounded),
            title: Text(t.whSwitchAction),
            onTap: () async => showWarehousePicker(context, store, all, await store.activeWarehouse()),
          );
        },
      ),
      ListTile(
        key: const Key('more-settings'),
        leading: const Icon(Icons.settings_rounded),
        title: Text(t.settingsTitle),
        onTap: () => Navigator.of(context).push(_scoped(context, SettingsScreen(backend: backend, storeName: storeName))),
      ),
    ]);
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
