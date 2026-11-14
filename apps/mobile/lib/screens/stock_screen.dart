import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../backend.dart';
import '../core/money.dart';
import '../data/sales_models.dart';
import '../data/transfer_models.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import '../sync/sync_badge.dart';
import 'product_thumb.dart';
import 'restock_screen.dart';
import 'transfer_create_screen.dart';

/// Counted stock on the shelf whose expiry date is within a week (or already past).
bool isExpiringRow(StockRow r, DateTime today) {
  if (r.expiresOn == null || (r.qty ?? 0) <= 0) return false;
  final left = r.daysLeft(today);
  return left != null && left <= 7;
}

String fmtQty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');

/// How much of each product the tindera has. Tap a product to record stock coming in or to correct the number.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

enum _StoreStockFilter { all, low, out, negative, expiring }

class _StockScreenState extends State<StockScreen> {
  String _query = '';
  _StoreStockFilter _filter = _StoreStockFilter.all;

  Widget? _stockSubtitle(AppLocalizations t, ColorScheme scheme, StockRow r, DateTime today) {
    final left = r.expiresOn == null ? null : r.daysLeft(today);
    final soon = isExpiringRow(r, today);
    final isNeg = r.counted && r.qty! < 0;
    final isOut = r.counted && r.qty! == 0;
    if (!r.low && !isNeg && !isOut && left == null) return null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (isNeg || isOut)
        Padding(
          padding: EdgeInsets.only(bottom: r.low || left != null ? 2 : 0),
          child: Container(
            key: Key(isNeg ? 'negative-stock-badge-${r.product.id}' : 'out-stock-badge-${r.product.id}'),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isNeg ? t.whStockBadgeNegative : t.whStockBadgeOut,
              style: TextStyle(
                color: scheme.onErrorContainer,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      if (r.low) ...[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: Key('low-stock-badge-${r.product.id}'),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                t.stockLowStockBadge,
                style: TextStyle(
                  color: scheme.onErrorContainer,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                t.stockRunningLow,
                style: TextStyle(color: scheme.error, fontSize: 12, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (r.reorderPoint > 0)
          Text(
            t.stockReorderAlert(fmtQty(r.qty ?? 0), fmtQty(r.reorderPoint)),
            key: Key('reorder-alert-${r.product.id}'),
            style: TextStyle(color: scheme.error, fontSize: 11, fontWeight: FontWeight.w500),
          ),
      ],
      if (left != null)
        Text(
          left < 0 ? t.stockExpiredAgo(-left) : t.stockExpiresIn(left),
          key: Key('expiry-${r.product.id}'),
          style: TextStyle(color: soon ? scheme.error : scheme.outline, fontSize: 12, fontWeight: soon ? FontWeight.w700 : null),
        ),
    ]);
  }

  Future<void> _open(StockRow row) async {
    final scope = CatalogScope.of(context);
    if (!scope.canManageStock) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => _ActionSheet(row: row, scope: scope),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.stockTitle), actions: [
        if (scope.canManageStock)
          IconButton(
            key: const Key('open-restock'),
            tooltip: t.restockTitle,
            icon: const Icon(Icons.shopping_basket_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => scope.wrap(const RestockScreen()))),
          ),
        const SyncBadge(),
      ]),
      body: StreamBuilder<List<StockRow>>(
        stream: scope.store.watchStockList(query: _query),
        builder: (context, snap) {
          final all = snap.data;
          if (all == null) return const Center(child: CircularProgressIndicator());
          final today = DateTime.now();
          final lowCount = all.where((r) => r.low).length;
          final expiringCount = all.where((r) => isExpiringRow(r, today)).length;
          final rows = switch (_filter) {
            _StoreStockFilter.all => all,
            _StoreStockFilter.low => all.where((r) => r.low).toList(),
            _StoreStockFilter.out => all.where((r) => r.counted && r.qty! == 0).toList(),
            _StoreStockFilter.negative => all.where((r) => r.counted && r.qty! < 0).toList(),
            _StoreStockFilter.expiring => all.where((r) => isExpiringRow(r, today)).toList(),
          };
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.l, Gap.s, Gap.l, Gap.s),
              child: TextField(
                key: const Key('stock-search'),
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  hintText: t.searchProducts,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.s),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: Gap.xs, runSpacing: Gap.xs, children: [
                  AppPillChip(
                    key: const Key('filter-all'),
                    label: t.stockAll,
                    height: 32,
                    selected: _filter == _StoreStockFilter.all,
                    onTap: () => setState(() => _filter = _StoreStockFilter.all),
                  ),
                  AppPillChip(
                    key: const Key('filter-low'),
                    label: t.stockLowCount(lowCount),
                    height: 32,
                    selected: _filter == _StoreStockFilter.low,
                    onTap: () => setState(() => _filter = _StoreStockFilter.low),
                  ),
                  AppPillChip(
                    key: const Key('filter-out'),
                    label: t.whStockFilterOut,
                    height: 32,
                    selected: _filter == _StoreStockFilter.out,
                    onTap: () => setState(() => _filter = _StoreStockFilter.out),
                  ),
                  AppPillChip(
                    key: const Key('filter-negative'),
                    label: t.whStockFilterNegative,
                    height: 32,
                    selected: _filter == _StoreStockFilter.negative,
                    onTap: () => setState(() => _filter = _StoreStockFilter.negative),
                  ),
                  if (expiringCount > 0 || _filter == _StoreStockFilter.expiring)
                    AppPillChip(
                      key: const Key('filter-expiring'),
                      label: t.stockExpiringFilter(expiringCount),
                      height: 32,
                      selected: _filter == _StoreStockFilter.expiring,
                      onTap: () => setState(() => _filter = _StoreStockFilter.expiring),
                    ),
                ]),
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          switch (_filter) {
                            _StoreStockFilter.low => t.stockNoneLow,
                            _StoreStockFilter.expiring => t.stockNoneExpiring,
                            _StoreStockFilter.out || _StoreStockFilter.negative => t.whStockNoFiltered,
                            _StoreStockFilter.all => all.isEmpty ? t.noProductsHere : t.noMatches,
                          },
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(Gap.l, Gap.s, Gap.l, Gap.xl + MediaQuery.paddingOf(context).bottom),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: Gap.s),
                      itemBuilder: (context, i) {
                        final r = rows[i];
                        final scheme = Theme.of(context).colorScheme;
                        return AppCard(
                          key: Key('stock-${r.product.id}'),
                          padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: 8),
                          radius: Gap.radiusL,
                          onTap: () => _open(r),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: ProductThumb(productId: r.product.id, name: r.product.displayName, path: r.product.photoPath, size: 38),
                            title: Text(r.product.displayName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            subtitle: _stockSubtitle(t, scheme, r, today),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              if (r.pending)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(Icons.cloud_upload_outlined, size: 18, semanticLabel: t.notSentYet),
                                ),
                              Text(
                                r.counted ? fmtQty(r.qty!) : t.stockNotCounted,
                                style: r.counted
                                    ? NightMarketText.mono(
                                        context,
                                        size: 17,
                                        weight: FontWeight.w600,
                                        color: r.low || r.qty! <= 0 ? scheme.error : scheme.onSurface,
                                      )
                                    : TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: scheme.outline,
                                      ),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

class _ActionSheet extends StatelessWidget {
  const _ActionSheet({required this.row, required this.scope});
  final StockRow row;
  final CatalogScope scope;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(row.product.displayName, style: Theme.of(context).textTheme.titleLarge),
          Text(row.counted ? t.stockNow(fmtQty(row.qty!)) : t.stockNotCounted),
          const SizedBox(height: 16),
          if (row.low) ...[
            FilledButton.tonalIcon(
              key: const Key('action-request-transfer'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: Text(t.stockRequestTransfer),
              onPressed: () async {
                final locId = (await scope.store.activeStoreNow()) ?? 'default-store';
                final backend = (scope.engine.api is Backend) ? scope.engine.api as Backend : null;
                if (!context.mounted) return;
                Navigator.pop(context);
                if (backend != null) {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => scope.wrap(
                      TransferCreateScreen(
                        backend: backend,
                        originLocationId: locId,
                        originName: t.stockTitle,
                        initialLine: TransferDraftLine(
                          variantId: row.product.variantId,
                          sku: row.product.sku,
                          productName: row.product.displayName,
                          unit: row.product.unit,
                          qty: row.reorderPoint > (row.qty ?? 0)
                              ? (row.reorderPoint - (row.qty ?? 0))
                              : 1.0,
                          availableQty: row.qty,
                        ),
                      ),
                    ),
                  ));
                }
              },
            ),
            const SizedBox(height: 8),
          ],
          FilledButton.icon(
            key: const Key('action-stock-in'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), textStyle: const TextStyle(fontSize: 20)),
            icon: const Icon(Icons.add_box_outlined),
            label: Text(t.stockIn),
            onPressed: () async {
              Navigator.pop(context);
              await showStockInDialog(context, scope, row);
            },
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextButton.icon(
                key: const Key('action-set-expiry'),
                icon: const Icon(Icons.event_outlined),
                label: Text(t.stockExpirySet),
                onPressed: () async {
                  Navigator.pop(context);
                  await showSetExpiry(context, scope, row);
                },
              ),
            ),
            if (row.expiresOn != null)
              TextButton(
                key: const Key('action-clear-expiry'),
                onPressed: () async {
                  Navigator.pop(context);
                  await scope.store.setExpiry(variantId: row.product.variantId, expiresOn: null, opId: const Uuid().v7());
                  scope.engine.poke();
                },
                child: Text(t.stockExpiryClear),
              ),
          ]),
          if (row.product.sellsByPiece) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('action-open-pack'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56), textStyle: const TextStyle(fontSize: 20)),
              icon: const Icon(Icons.unarchive_outlined),
              label: Text(t.tingiOpenPack),
              onPressed: () async {
                Navigator.pop(context);
                await showOpenPackDialog(context, scope, row);
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('action-pack-history'),
              onPressed: () async {
                Navigator.pop(context);
                await showPackHistory(context, scope);
              },
              child: Text(t.tingiHistory),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('action-count'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56), textStyle: const TextStyle(fontSize: 20)),
            icon: const Icon(Icons.fact_check_outlined),
            label: Text(t.stockCount),
            onPressed: () async {
              Navigator.pop(context);
              await showCountDialog(context, scope, row);
            },
          ),
        ]),
      ),
    );
  }
}

Future<void> showStockInDialog(BuildContext context, CatalogScope scope, StockRow row) async {
  final t = AppLocalizations.of(context);
  final ccy = scope.store.baseCurrency;
  final qty = TextEditingController();
  final cost = TextEditingController();
  DateTime? expiry;
  String? qtyError;
  String? costError;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(t.stockInTitle(row.product.displayName)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            key: const Key('stockin-qty'),
            controller: qty,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 24),
            decoration: InputDecoration(labelText: t.stockInQty, errorText: qtyError),
          ),
          TextField(
            key: const Key('stockin-cost'),
            controller: cost,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: t.stockInCost, errorText: costError),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('stockin-expiry'),
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(expiry == null ? t.stockInExpiry : DateFormat.yMMMd(Localizations.localeOf(ctx).languageCode).format(expiry!)),
              onPressed: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: expiry ?? now.add(const Duration(days: 90)),
                  firstDate: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30)),
                  lastDate: now.add(const Duration(days: 3000)),
                );
                if (d != null) setState(() => expiry = DateTime(d.year, d.month, d.day));
              },
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(
            key: const Key('stockin-save'),
            onPressed: () {
              final q = double.tryParse(qty.text.trim().replaceAll(',', '.'));
              var costBad = false;
              if (cost.text.trim().isNotEmpty) {
                try {
                  Money.parse(cost.text, ccy);
                } catch (_) {
                  costBad = true;
                }
              }
              setState(() {
                qtyError = (q == null || q <= 0) ? t.errBadAmount : null;
                costError = costBad ? t.errBadAmount : null;
              });
              if (qtyError == null && !costBad) Navigator.pop(ctx, true);
            },
            child: Text(t.save),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return;
  await scope.store.receiveStock(
    variantId: row.product.variantId,
    qty: double.parse(qty.text.trim().replaceAll(',', '.')),
    cost: cost.text.trim().isEmpty ? null : Money.parse(cost.text, ccy).amount,
    expiresOn: expiry,
    opId: const Uuid().v7(),
  );
  scope.engine.poke();
}

Future<void> showCountDialog(BuildContext context, CatalogScope scope, StockRow row) async {
  final t = AppLocalizations.of(context);
  final counted = TextEditingController(text: row.counted ? fmtQty(row.qty!) : '');
  var reason = 'counted';
  String? error;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(t.stockCountTitle(row.product.displayName)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            key: const Key('count-qty'),
            controller: counted,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 24),
            decoration: InputDecoration(labelText: t.stockCountQty, errorText: error),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final (key, label) in [('counted', t.reasonCounted), ('damage', t.reasonDamage), ('other', t.reasonOther)])
              ChoiceChip(
                key: Key('reason-$key'),
                label: Text(label),
                selected: reason == key,
                onSelected: (_) => setState(() => reason = key),
              ),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(
            key: const Key('count-save'),
            onPressed: () {
              final q = double.tryParse(counted.text.trim().replaceAll(',', '.'));
              if (q == null || q < 0) {
                setState(() => error = t.errBadAmount);
              } else {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(t.save),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return;
  await scope.store.adjustStock(
    variantId: row.product.variantId,
    counted: double.parse(counted.text.trim().replaceAll(',', '.')),
    reason: reason,
    opId: const Uuid().v7(),
  );
  scope.engine.poke();
}

/// "Open a pack": N packs leave stock, N x pieces-per-pack pieces enter it (one op).
Future<void> showOpenPackDialog(BuildContext context, CatalogScope scope, StockRow row) async {
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context); // the action sheet is gone by the time we finish
  final packs = TextEditingController(text: '1');
  final p = row.product;
  String? error;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final n = int.tryParse(packs.text.trim());
        final valid = n != null && n >= 1 && n <= tingiMaxPacks;
        return AlertDialog(
          title: Text(t.tingiOpenTitle(p.name)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              key: const Key('openpack-qty'),
              controller: packs,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 24),
              onChanged: (_) => setState(() => error = null),
              decoration: InputDecoration(labelText: t.tingiPacks, errorText: error),
            ),
            const SizedBox(height: 8),
            if (valid)
              Text(t.tingiPreview(n * p.piecesPerPack!, p.pieceName ?? ''), key: const Key('openpack-preview')),
            if (valid && row.counted && row.qty! < n)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(t.tingiLowWarn, key: const Key('openpack-warn'), style: TextStyle(color: Theme.of(ctx).colorScheme.error, fontSize: 12)),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
            FilledButton(
              key: const Key('openpack-ok'),
              onPressed: () {
                final m = int.tryParse(packs.text.trim());
                if (m == null || m < 1 || m > tingiMaxPacks) {
                  setState(() => error = t.errBadAmount);
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: Text(t.tingiOpenPack),
            ),
          ],
        );
      },
    ),
  );
  if (ok != true) return;
  final r = await scope.store.openPack(
    id: const Uuid().v7(),
    packVariantId: p.variantId,
    packs: int.parse(packs.text.trim()),
    opId: const Uuid().v7(),
  );
  scope.engine.poke();
  messenger.showSnackBar(SnackBar(content: Text(t.tingiOpened(r.pieces))));
}

/// The packs opened in the last 30 days; tap one to undo it.
Future<void> showPackHistory(BuildContext context, CatalogScope scope) {
  final now = DateTime.now();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _PackHistory(scope: scope, from: now.subtract(const Duration(days: 30)), to: now.add(const Duration(days: 1))),
  );
}

class _PackHistory extends StatelessWidget {
  const _PackHistory({required this.scope, required this.from, required this.to});
  final CatalogScope scope;
  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: StreamBuilder<List<ConversionView>>(
          stream: scope.store.watchConversions(from: from, to: to),
          builder: (context, snap) {
            final list = snap.data ?? const <ConversionView>[];
            return ListView(shrinkWrap: true, padding: const EdgeInsets.all(Gap.l), children: [
              Text(t.tingiHistory, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: Gap.s),
              if (list.isEmpty) Padding(padding: const EdgeInsets.all(Gap.l), child: Text(t.tingiHistoryNone)),
              for (final c in list)
                ListTile(
                  key: Key('pack-${c.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    t.tingiHistoryRow(c.packs, c.pieces, c.pieceName ?? ''),
                    style: TextStyle(decoration: c.voidedAt != null ? TextDecoration.lineThrough : null),
                  ),
                  subtitle: Text(
                    [
                      c.packName ?? '',
                      if (c.voidedAt != null) t.tingiCancelled,
                      if (c.rejectedHint == 'link_changed') t.tingiLinkChanged,
                    ].where((e) => e.isNotEmpty).join(' · '),
                    style: TextStyle(color: c.rejectedHint != null ? scheme.error : null, fontSize: 12),
                  ),
                  trailing: c.pending ? Icon(Icons.cloud_upload_outlined, size: 18, color: scheme.primary, semanticLabel: t.notSentYet) : null,
                  onTap: c.voidedAt != null ? null : () => _confirmVoid(context, c),
                ),
            ]);
          },
        ),
      ),
    );
  }

  Future<void> _confirmVoid(BuildContext context, ConversionView c) async {
    final t = AppLocalizations.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.tingiVoidTitle),
        content: Text(t.tingiVoidBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(key: const Key('pack-void-yes'), onPressed: () => Navigator.pop(ctx, true), child: Text(t.tingiVoidYes)),
        ],
      ),
    );
    if (yes != true) return;
    await scope.store.voidOpenPack(conversionId: c.id, opId: const Uuid().v7());
    scope.engine.poke();
  }
}

/// Pick the expiry date of what is on the shelf (the earliest one).
Future<void> showSetExpiry(BuildContext context, CatalogScope scope, StockRow row) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final picked = await showDatePicker(
    context: context,
    initialDate: row.expiresOn ?? today.add(const Duration(days: 90)),
    firstDate: today.subtract(const Duration(days: 365)),
    lastDate: today.add(const Duration(days: 3000)),
  );
  if (picked == null) return;
  await scope.store.setExpiry(
    variantId: row.product.variantId,
    expiresOn: DateTime(picked.year, picked.month, picked.day),
    opId: const Uuid().v7(),
  );
  scope.engine.poke();
}
