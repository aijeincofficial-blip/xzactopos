import 'package:flutter/material.dart';

import '../core/money.dart';
import '../data/local_store.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import '../sync/sync_badge.dart';
import 'product_form_screen.dart';

/// Product list for the tindera: search on top, big "+" to add, tap a row to edit.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Enter in the search box. USB and Bluetooth barcode scanners type the code and press Enter,
  /// so this is also the scan path: a known barcode opens the product, an unknown one offers to add it.
  Future<void> _onSubmit(String value) async {
    final code = value.trim();
    if (code.isEmpty) return;
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final hit = await scope.store.findByBarcode(code);
    if (!mounted) return;
    if (hit != null) {
      _clearSearch();
      await _open(product: hit);
      return;
    }
    if (!looksLikeBarcode(code)) return; // a name search: the list already shows the matches
    final add = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.unknownBarcodeTitle),
        content: Text(t.unknownBarcodeBody(code)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.cancel)),
          FilledButton(
            key: const Key('add-scanned'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(t.addProduct),
          ),
        ],
      ),
    );
    if (add == true && mounted) {
      _clearSearch();
      await _open(barcode: code);
    }
  }

  void _clearSearch() => setState(() {
        _search.clear();
        _query = '';
      });

  void _readyToScan() {
    _search.selection = TextSelection(baseOffset: 0, extentOffset: _search.text.length);
    _searchFocus.requestFocus();
  }

  Future<void> _open({ProductView? product, String? barcode}) async {
    final scope = CatalogScope.of(context);
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CatalogScope(
        store: scope.store,
        engine: scope.engine,
        child: ProductFormScreen(product: product, barcode: barcode),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(t.products), actions: const [SyncBadge()]),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-product'),
        onPressed: () => _open(),
        icon: const Icon(Icons.add),
        label: Text(t.addProduct),
      ),
      body: Column(
        children: [
          const _NeedsAttentionBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              key: const Key('product-search'),
              controller: _search,
              focusNode: _searchFocus,
              textInputAction: TextInputAction.search,
              onSubmitted: _onSubmit,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: t.searchProducts,
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _query.isEmpty
                    ? IconButton(
                        key: const Key('scan-button'),
                        icon: const Icon(Icons.qr_code_scanner),
                        tooltip: t.scanBarcode,
                        onPressed: _readyToScan,
                      )
                    : IconButton(icon: const Icon(Icons.clear), tooltip: t.clear, onPressed: _clearSearch),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ProductView>>(
              stream: scope.store.watchProducts(query: _query),
              builder: (context, snap) {
                final items = snap.data;
                if (items == null) return const Center(child: CircularProgressIndicator());
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(_query.isEmpty ? t.noProductsYet : t.noMatches,
                          textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = items[i];
                    return ListTile(
                      minVerticalPadding: 14,
                      title: Text(p.name, style: const TextStyle(fontSize: 18)),
                      subtitle: p.barcode == null ? null : Text(p.barcode!),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (p.pending)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(Icons.cloud_upload_outlined, size: 18, semanticLabel: t.notSentYet),
                          ),
                        Text(
                          p.price == null ? '—' : Money(p.price!, p.currency).format(locale),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ]),
                      onTap: () => _open(product: p),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows ops the server refused for good, with the reason and a way to drop them.
class _NeedsAttentionBanner extends StatelessWidget {
  const _NeedsAttentionBanner();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    return StreamBuilder<OutboxCounts>(
      stream: scope.store.watchOutboxCounts(),
      builder: (context, snap) {
        final failed = snap.data?.failed ?? 0;
        if (failed == 0) return const SizedBox.shrink();
        return MaterialBanner(
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          content: Text(t.syncNeedsAttention(failed)),
          actions: [
            TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _FailedOpsDialog(store: scope.store),
              ),
              child: Text(t.review),
            ),
          ],
        );
      },
    );
  }
}

class _FailedOpsDialog extends StatefulWidget {
  const _FailedOpsDialog({required this.store});
  final LocalStore store;

  @override
  State<_FailedOpsDialog> createState() => _FailedOpsDialogState();
}

class _FailedOpsDialogState extends State<_FailedOpsDialog> {
  late Future<List<OutboxOp>> _ops = widget.store.failedOps();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(t.needsAttentionTitle),
      content: SizedBox(
        width: 400,
        child: FutureBuilder<List<OutboxOp>>(
          future: _ops,
          builder: (context, snap) {
            final ops = snap.data ?? const [];
            if (ops.isEmpty) return Text(t.nothingToFix);
            return ListView(
              shrinkWrap: true,
              children: [
                for (final op in ops)
                  ListTile(
                    title: Text((op.payload['name'] as String?) ?? t.removedProduct),
                    subtitle: Text(opErrorText(t, op.lastError)),
                    trailing: TextButton(
                      onPressed: () async {
                        await widget.store.discardFailed(op.opId);
                        setState(() => _ops = widget.store.failedOps());
                      },
                      child: Text(t.discardChange),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t.close))],
    );
  }
}

/// Digits or a code-like token (no spaces), as printed under barcodes: EAN-8/13, UPC, Code 128 labels.
bool looksLikeBarcode(String s) => RegExp(r'^[0-9]{6,14}$').hasMatch(s) || RegExp(r'^[A-Z0-9][A-Z0-9._-]{5,63}$').hasMatch(s);

/// Server hint -> sentence the tindera understands.
String opErrorText(AppLocalizations t, String? hint) => switch (hint) {
      'duplicate_barcode' => t.errDuplicateBarcode,
      'duplicate_sku' => t.errDuplicateBarcode,
      'limit_products' => t.errLimitProducts,
      'not_allowed' || 'cost_and_sku_only' => t.errNotAllowed,
      'product_archived' => t.errProductArchived,
      _ => t.errGeneric,
    };
