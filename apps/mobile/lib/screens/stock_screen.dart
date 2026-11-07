import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/money.dart';
import '../data/sales_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import '../sync/sync_badge.dart';
import 'product_thumb.dart';

String fmtQty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');

/// How much of each product the tindera has. Tap a product to record stock coming in or to correct the number.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  String _query = '';
  bool _lowOnly = false;

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
      appBar: AppBar(title: Text(t.stockTitle), actions: const [SyncBadge()]),
      body: StreamBuilder<List<StockRow>>(
        stream: scope.store.watchStockList(query: _query),
        builder: (context, snap) {
          final all = snap.data;
          if (all == null) return const Center(child: CircularProgressIndicator());
          final lowCount = all.where((r) => r.low).length;
          final rows = _lowOnly ? all.where((r) => r.low).toList() : all;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                key: const Key('stock-search'),
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: t.searchProducts,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                ChoiceChip(
                  key: const Key('filter-all'),
                  label: Text(t.stockAll),
                  selected: !_lowOnly,
                  onSelected: (_) => setState(() => _lowOnly = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  key: const Key('filter-low'),
                  avatar: lowCount > 0 ? const Icon(Icons.warning_amber_rounded, size: 18) : null,
                  label: Text(t.stockLowCount(lowCount)),
                  selected: _lowOnly,
                  onSelected: (_) => setState(() => _lowOnly = true),
                ),
              ]),
            ),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(_lowOnly ? t.stockNoneLow : (all.isEmpty ? t.noProductsYet : t.noMatches),
                            textAlign: TextAlign.center),
                      ),
                    )
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final r = rows[i];
                        final scheme = Theme.of(context).colorScheme;
                        return ListTile(
                          key: Key('stock-${r.product.id}'),
                          minVerticalPadding: 12,
                          leading: ProductThumb(productId: r.product.id, path: r.product.photoPath),
                          title: Text(r.product.name, style: const TextStyle(fontSize: 18)),
                          subtitle: r.low ? Text(t.stockRunningLow, style: TextStyle(color: scheme.error)) : null,
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (r.pending)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Icon(Icons.cloud_upload_outlined, size: 18, semanticLabel: t.notSentYet),
                              ),
                            Text(
                              r.counted ? fmtQty(r.qty!) : t.stockNotCounted,
                              style: TextStyle(
                                fontSize: r.counted ? 22 : 15,
                                fontWeight: r.counted ? FontWeight.w800 : null,
                                color: r.low || (r.counted && r.qty! <= 0)
                                    ? scheme.error
                                    : (r.counted ? null : scheme.outline),
                              ),
                            ),
                          ]),
                          onTap: () => _open(r),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(row.product.name, style: Theme.of(context).textTheme.titleLarge),
          Text(row.counted ? t.stockNow(fmtQty(row.qty!)) : t.stockNotCounted),
          const SizedBox(height: 16),
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
  String? qtyError;
  String? costError;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(t.stockInTitle(row.product.name)),
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
        title: Text(t.stockCountTitle(row.product.name)),
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
