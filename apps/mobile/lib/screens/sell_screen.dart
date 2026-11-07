import 'package:flutter/material.dart';

import '../core/money.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/local_store.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import '../sync/sync_badge.dart';
import '../core/camera_scanner.dart';
import 'cart.dart';
import 'pay_screen.dart';
import 'product_form_screen.dart';
import 'product_thumb.dart';
import 'products_screen.dart' show looksLikeBarcode;

/// The Sell screen: search or scan to add, quick-tap tiles for the usual items, the cart, and the Pay button.
class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  Cart? _cart;
  Future<List<ProductView>>? _quick;
  Set<String> _pinned = const {};
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _cart?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cart == null) {
      final store = CatalogScope.of(context).store;
      _cart = Cart(store)..restore();
      _quick = store.quickItems();
      store.pinnedVariants().then((p) {
        if (mounted) setState(() => _pinned = p);
      });
    }
  }

  /// Long-press on a tile: pin it to the top of the quick items, or unpin it.
  Future<void> _togglePin(ProductView p) async {
    final t = AppLocalizations.of(context);
    final store = CatalogScope.of(context).store;
    final messenger = ScaffoldMessenger.of(context);
    final pin = !_pinned.contains(p.variantId);
    await store.setPinned(p.variantId, pin);
    final pinned = await store.pinnedVariants();
    final next = store.quickItems();
    if (!mounted) return;
    setState(() {
      _pinned = pinned;
      _quick = next;
    });
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pin ? t.sellPinned(p.name) : t.sellUnpinned(p.name))));
  }

  String _money(int amount) =>
      Money(amount, CatalogScope.of(context).store.baseCurrency).format(Localizations.localeOf(context).languageCode);

  void _add(ProductView p) {
    final t = AppLocalizations.of(context);
    if (p.price == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.sellNoPrice)));
      return;
    }
    _cart!.add(p);
  }

  void _clearSearch() => setState(() {
        _search.clear();
        _query = '';
      });

  /// Enter in the search box: scanners type the code and press Enter, so a known barcode goes straight into the cart.
  Future<void> _onSubmit(String value) async {
    final code = value.trim();
    if (code.isEmpty) return;
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final hit = await scope.store.findByBarcode(code);
    if (!mounted) return;
    if (hit != null) {
      _add(hit);
      _clearSearch();
      _searchFocus.requestFocus();
      return;
    }
    if (!looksLikeBarcode(code)) return; // a name: the list already shows the matches
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(t.sellUnknownBarcode(code)),
      action: SnackBarAction(
        label: t.addProduct,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => scope.wrap(ProductFormScreen(barcode: code)),
        )),
      ),
    ));
    _searchFocus.requestFocus();
  }

  /// Camera scanning: every code goes straight into the cart; the camera stays open for the next one.
  Future<void> _scanWithCamera() async {
    final t = AppLocalizations.of(context);
    final store = CatalogScope.of(context).store;
    await cameraScanner.scanMany(context, (code) async {
      final hit = await store.findByBarcode(code);
      if (hit == null) return ScanFeedback(t.sellUnknownBarcode(code), ok: false);
      if (hit.price == null) return ScanFeedback(t.sellNoPrice, ok: false);
      _cart!.add(hit);
      return ScanFeedback(t.scanAdded(hit.name));
    });
  }

  Future<void> _editQty(int i) async {
    final t = AppLocalizations.of(context);
    final line = _cart!.lines[i];
    final c = TextEditingController(text: _fmtQty(line.qty));
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(line.product.name),
        content: TextField(
          key: const Key('qty-field'),
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: t.sellQuantity),
          onSubmitted: (v) => Navigator.pop(ctx, double.tryParse(v.replaceAll(',', '.'))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
          FilledButton(
            key: const Key('qty-ok'),
            onPressed: () => Navigator.pop(ctx, double.tryParse(c.text.replaceAll(',', '.'))),
            child: Text(t.ok),
          ),
        ],
      ),
    );
    if (value != null && value >= 0 && i < _cart!.lines.length) _cart!.setQty(i, value);
  }

  Future<void> _confirmClear() async {
    final t = AppLocalizations.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.sellClearTitle),
        content: Text(t.sellClearBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(key: const Key('clear-yes'), onPressed: () => Navigator.pop(ctx, true), child: Text(t.clear)),
        ],
      ),
    );
    if (yes == true) _cart!.clear();
  }

  static String _fmtQty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final cart = _cart!;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.sell),
        actions: [
          ListenableBuilder(
            listenable: cart,
            builder: (_, _) => cart.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    key: const Key('clear-cart'),
                    tooltip: t.clear,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: _confirmClear,
                  ),
          ),
          const SyncBadge(),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.s, Gap.xl, Gap.s),
              child: TextField(
                key: const Key('sell-search'),
                controller: _search,
                focusNode: _searchFocus,
                // wide screens (a tablet or PC with a USB scanner) start ready to scan; on a phone the keyboard would
                // cover the items, so the tindera taps the field (or the camera button) when she wants it
                autofocus: MediaQuery.of(context).size.shortestSide >= 600,
                textInputAction: TextInputAction.search,
                onSubmitted: _onSubmit,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: t.sellSearchHint,
                  suffixIcon: _query.isEmpty
                      ? (cameraScanner.available
                          ? IconButton(
                              key: const Key('camera-scan'),
                              tooltip: t.scanWithCamera,
                              icon: const Icon(Icons.qr_code_scanner),
                              onPressed: _scanWithCamera,
                            )
                          : const Icon(Icons.qr_code_scanner))
                      : IconButton(icon: const Icon(Icons.clear), tooltip: t.clear, onPressed: _clearSearch),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<Map<String, double>>(
                stream: scope.store.watchStock(),
                builder: (context, stockSnap) {
                  final stock = stockSnap.data ?? const <String, double>{};
                  return _query.trim().isEmpty ? _tiles(stock) : _results(stock);
                },
              ),
            ),
            ListenableBuilder(
              listenable: cart,
              builder: (_, _) => _CartPanel(
                cart: cart,
                money: _money,
                onEditQty: _editQty,
                onPay: cart.isEmpty ? null : () => _pay(cart),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pay(Cart cart) async {
    final scope = CatalogScope.of(context);
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => scope.wrap(PayScreen(cart: cart))));
    if (!mounted) return;
    // the sale just made changes which items sell most
    final next = scope.store.quickItems();
    setState(() {
      _quick = next;
    });
  }

  Widget _tiles(Map<String, double> stock) {
    final t = AppLocalizations.of(context);
    return FutureBuilder<List<ProductView>>(
      future: _quick,
      builder: (context, snap) {
        final items = snap.data;
        if (items == null) return const Center(child: CircularProgressIndicator());
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(t.noProductsYet, textAlign: TextAlign.center),
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xs, Gap.xl, Gap.l),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180, mainAxisExtent: 136, crossAxisSpacing: Gap.m, mainAxisSpacing: Gap.m),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final p = items[i];
            return _Tile(
              product: p,
              left: p.trackStock ? stock[p.variantId] : null,
              money: _money,
              pinned: _pinned.contains(p.variantId),
              onTap: () => _add(p),
              onLongPress: () => _togglePin(p),
            );
          },
        );
      },
    );
  }

  Widget _results(Map<String, double> stock) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    return StreamBuilder<List<ProductView>>(
      stream: scope.store.watchProducts(query: _query),
      builder: (context, snap) {
        final items = snap.data;
        if (items == null) return const Center(child: CircularProgressIndicator());
        if (items.isEmpty) return Center(child: Text(t.noMatches));
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final p = items[i];
            final left = p.trackStock ? stock[p.variantId] : null;
            return ListTile(
              key: Key('result-${p.id}'),
              leading: ProductThumb(productId: p.id, path: p.photoPath),
              title: Text(p.name, style: const TextStyle(fontSize: 18)),
              subtitle: left == null ? null : _StockText(left: left, reorderPoint: p.reorderPoint),
              trailing: Text(p.price == null ? '—' : _money(p.price!),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              onTap: () {
                _add(p);
                _clearSearch();
                _searchFocus.requestFocus();
              },
            );
          },
        );
      },
    );
  }
}

class _StockText extends StatelessWidget {
  const _StockText({required this.left, this.reorderPoint = 0});
  final double left;
  final double reorderPoint;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final out = left <= 0;
    final low = !out && reorderPoint > 0 && left <= reorderPoint;
    final n = left == left.roundToDouble() ? left.toInt().toString() : left.toStringAsFixed(1);
    return Text(
      out ? t.sellOutOfStock : (low ? t.sellStockLow(n) : t.sellStockLeft(n)),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: (out || low) ? Theme.of(context).colorScheme.error : null, fontSize: 13),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.product,
    required this.left,
    required this.money,
    required this.onTap,
    required this.onLongPress,
    this.pinned = false,
  });
  final ProductView product;
  final bool pinned;
  final VoidCallback onLongPress;
  final double? left;
  final String Function(int) money;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      key: Key('tile-${product.id}'),
      onTap: onTap,
      onLongPress: onLongPress,
      padding: const EdgeInsets.all(Gap.m + 2),
      radius: Gap.radiusL,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              product.photoPath != null
                  ? ProductThumb(productId: product.id, path: product.photoPath, size: 36)
                  : CoinBadge(
                      icon: Icons.inventory_2_rounded,
                      color: scheme.primary,
                      size: 36,
                    ),
              if (left != null)
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _StockText(left: left!, reorderPoint: product.reorderPoint),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Row(children: [
            if (pinned) ...[
              Icon(Icons.push_pin_rounded, key: Key('pin-${product.id}'), size: 14, color: scheme.primary),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          const SizedBox(height: 2),
          Text(
            product.price == null ? '—' : money(product.price!),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartPanel extends StatelessWidget {
  const _CartPanel({required this.cart, required this.money, required this.onEditQty, required this.onPay});
  final Cart cart;
  final String Function(int) money;
  final void Function(int) onEditQty;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 10,
      shadowColor: scheme.primary.withValues(alpha: 0.35),
      color: scheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Gap.radiusXL))),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (cart.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.l, Gap.l, Gap.l, Gap.s),
              child: Text(t.sellCartEmpty, style: TextStyle(color: scheme.outline)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(top: Gap.s),
                itemCount: cart.lines.length,
                itemBuilder: (context, i) {
                  final l = cart.lines[i];
                  return Padding(
                    key: Key('cart-line-$i'),
                    padding: const EdgeInsets.fromLTRB(Gap.l, 2, Gap.s, 2),
                    child: Row(children: [
                      Expanded(
                        child: Text(l.product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
                      ),
                      IconButton(
                        key: Key('minus-$i'),
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => cart.setQty(i, l.qty - 1),
                      ),
                      InkWell(
                        key: Key('qty-$i'),
                        onTap: () => onEditQty(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          child: Text(
                            l.qty == l.qty.roundToDouble() ? '${l.qty.toInt()}' : '${l.qty}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      IconButton(
                        key: Key('plus-$i'),
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => cart.setQty(i, l.qty + 1),
                      ),
                      SizedBox(width: 88, child: Padding(padding: const EdgeInsets.only(right: Gap.s), child: Text(money(l.lineTotal), textAlign: TextAlign.end, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))),
                    ]),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.s, Gap.xl, Gap.xl),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.sellItems(cart.itemCount), style: TextStyle(color: scheme.outline, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(money(cart.subtotal),
                      key: const Key('cart-total'),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
                ]),
              ),
              FilledButton.icon(
                key: const Key('pay-button'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(150, 58),
                  backgroundColor: scheme.obsidian,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                ),
                onPressed: onPay,
                icon: Icon(Icons.payments_rounded, color: scheme.glow, size: 22),
                label: Text(t.sellPay),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
