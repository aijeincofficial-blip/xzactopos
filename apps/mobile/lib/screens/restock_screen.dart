import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/money.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/sales_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import '../sync/sync_badge.dart';
import 'restock.dart';
import 'stock_screen.dart' show fmtQty, showStockInDialog;

/// The shopping list for tomorrow ("pasuyo"): everything running low, with a suggested amount to buy.
/// Untick what you will not buy, copy the list to send it, and tap an item when it arrives to record stock in.
class RestockScreen extends StatefulWidget {
  const RestockScreen({super.key});

  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> {
  final Set<String> _skipped = {};

  String _listText(AppLocalizations t, List<RestockLine> lines) => [
        t.restockShareHeader,
        for (final l in lines) '• ${l.row.product.name} × ${l.suggested}',
      ].join('\n');

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    String money(int c) => Money(c, scope.store.baseCurrency).format(locale);

    return Scaffold(
      appBar: AppBar(title: Text(t.restockTitle), actions: const [SyncBadge()]),
      body: StreamBuilder<List<StockRow>>(
        stream: scope.store.watchStockList(),
        builder: (context, snap) {
          final data = snap.data;
          if (data == null) return const Center(child: CircularProgressIndicator());
          final lines = buildRestock(data);
          if (lines.isEmpty) {
            return EmptyState(key: const Key('restock-empty'), icon: Icons.check_circle_outline_rounded, text: t.restockEmpty);
          }
          final chosen = [
            for (final l in lines)
              if (!_skipped.contains(l.row.product.variantId)) l,
          ];
          final total = chosen.fold<int>(0, (a, l) => a + l.estimate);
          return Column(children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.s, Gap.xl, Gap.l),
                itemCount: lines.length,
                separatorBuilder: (_, _) => const SizedBox(height: Gap.s),
                itemBuilder: (context, i) {
                  final l = lines[i];
                  final id = l.row.product.variantId;
                  final on = !_skipped.contains(id);
                  return AppCard(
                    key: Key('restock-$id'),
                    padding: const EdgeInsets.symmetric(horizontal: Gap.s, vertical: Gap.s),
                    radius: Gap.radiusL,
                    onTap: scope.canManageStock ? () => showStockInDialog(context, scope, l.row) : null,
                    child: Row(children: [
                      Checkbox(
                        key: Key('restock-check-$id'),
                        value: on,
                        onChanged: (v) => setState(() => v == true ? _skipped.remove(id) : _skipped.add(id)),
                      ),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(l.row.product.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          Text(t.restockNow(fmtQty(l.row.qty!)), style: TextStyle(fontSize: 12, color: scheme.error)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(t.restockBuy(l.suggested), style: NightMarketText.mono(context, size: 15, weight: FontWeight.w600)),
                        if (l.estimate > 0)
                          Text(
                            money(l.estimate),
                            style: NightMarketText.mono(context, size: 12, weight: FontWeight.w500, color: scheme.outline),
                          ),
                      ]),
                      const SizedBox(width: Gap.s),
                    ]),
                  );
                },
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(top: BorderSide(color: scheme.outlineVariant, width: Gap.border)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.m, Gap.xl, Gap.l),
                child: SafeArea(
                  top: false,
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.restockItems(chosen.length), style: TextStyle(fontSize: 13, color: scheme.outline)),
                        Text(total > 0 ? t.restockEstimate(money(total)) : '—',
                            key: const Key('restock-total'),
                            style: NightMarketText.mono(context, size: 20, weight: FontWeight.w600)),
                      ]),
                    ),
                    FilledButton.icon(
                      key: const Key('restock-copy'),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text(t.restockCopy),
                      onPressed: chosen.isEmpty
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await Clipboard.setData(ClipboardData(text: _listText(t, chosen)));
                              messenger.showSnackBar(SnackBar(content: Text(t.restockCopied)));
                            },
                    ),
                  ]),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
