import 'dart:async';

import 'package:flutter/material.dart';

import '../backend.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/local_store.dart';
import '../data/shift_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import '../sync/sync_badge.dart';
import '../core/camera_scanner.dart';
import 'cart.dart';
import 'store_picker.dart';
import '../data/sales_models.dart';
import 'pay_screen.dart';
import 'shift_screen.dart';
import 'today_screen.dart';
import 'product_form_screen.dart';
import 'product_thumb.dart';
import 'products_screen.dart' show looksLikeBarcode;

/// The Sell screen: search or scan to add, quick-tap tiles for the usual items, the cart, and the Pay button.
class SellScreen extends StatefulWidget {
  const SellScreen({super.key, this.backend, this.storeName = ''});

  /// Needed for the Today strip (it opens the Today screen); without it the strip is left out.
  final Backend? backend;

  /// Named on the shift slips.
  final String storeName;

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
  StreamSubscription<List<ProductView>>? _catalogSub;
  StreamSubscription<String?>? _storeSub;

  @override
  void dispose() {
    _catalogSub?.cancel();
    _storeSub?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    if (identical(Cart.current, _cart)) Cart.current = null;
    _cart?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cart == null) {
      final store = CatalogScope.of(context).store;
      _cart = Cart(store)..restore();
      Cart.current = _cart;
      _quick = store.quickItems();
      store.pinnedVariants().then((p) {
        if (mounted) setState(() => _pinned = p);
      });
      // top sellers are per store: read them again when the store is switched
      var firstStore = true;
      _storeSub = store.watchActiveStore().listen((_) {
        if (firstStore) {
          firstStore = false;
          return;
        }
        if (mounted) {
          final next = store.quickItems();
          setState(() {
            _quick = next;
          });
        }
      });
      // Sell stays alive in its tab: products that arrive later (the first sync, an edit) must show up here
      var first = true;
      _catalogSub = store.watchProducts().listen((_) {
        if (first) {
          first = false;
          return;
        }
        if (mounted) {
          final next = store.quickItems();
          setState(() {
            _quick = next;
          });
        }
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.sellUnknownBarcode(code)),
        action: SnackBarAction(
          label: t.addProduct,
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => scope.wrap(ProductFormScreen(barcode: code)))),
        ),
      ),
    );
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
          const StoreChip(),
          const SyncBadge(),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.backend != null) _todayStrip(context, widget.backend!),
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

  /// Today's total in one line on top of Sell; tap for the full day.
  Widget _todayStrip(BuildContext context, Backend backend) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xs, Gap.xl, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: _todayCard(context, backend, t, scope, scheme)),
        const SizedBox(width: Gap.s),
        _shiftChip(context, backend, t, scope, scheme),
      ]),
    );
  }

  /// A small button beside the Today strip: is a shift open for this user, and a way into it.
  Widget _shiftChip(BuildContext context, Backend backend, AppLocalizations t, CatalogScope scope, ColorScheme scheme) {
    return StreamBuilder<ShiftView?>(
      stream: scope.store.watchOpenShift(backend.userId ?? ''),
      builder: (context, snap) {
        final open = snap.data != null;
        return AppCard(
          key: const Key('shift-chip'),
          padding: const EdgeInsets.all(Gap.s + 2),
          radius: Gap.radiusL,
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => scope.wrap(ShiftScreen(backend: backend, storeName: widget.storeName)))),
          child: Tooltip(
            message: open ? t.shiftChipOpen : t.shiftChipNone,
            child: Icon(open ? Icons.lock_open_rounded : Icons.lock_outline_rounded, size: 22, color: open ? scheme.success : scheme.outline),
          ),
        );
      },
    );
  }

  Widget _todayCard(BuildContext context, Backend backend, AppLocalizations t, CatalogScope scope, ColorScheme scheme) {
    return Builder(builder: (context) {
      return StreamBuilder<TodayTotals>(
        stream: scope.store.watchToday(),
        builder: (context, snap) {
          final d = snap.data ?? const TodayTotals();
          return AppCard(
            key: const Key('tile-today'),
            padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.s + 2),
            radius: Gap.radiusL,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => scope.wrap(TodayScreen(backend: backend)))),
            child: Row(
              children: [
                Icon(Icons.today_rounded, size: 20, color: scheme.primary),
                const SizedBox(width: Gap.s),
                Expanded(
                  child: Text(
                    t.todaySales,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: scheme.outline, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  _money(d.total),
                  key: const Key('today-strip-total'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: Gap.s),
                Flexible(
                  child: Text(
                    t.todayCount(d.count),
                    key: const Key('today-strip-count'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: scheme.outline),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: scheme.outline),
              ],
            ),
          );
        },
      );
    });
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.noProductsHere, textAlign: TextAlign.center),
                  const SizedBox(height: Gap.l),
                  FilledButton.icon(
                    key: const Key('sell-add-product'),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(t.addProduct),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => CatalogScope.of(context).wrap(const ProductFormScreen())),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xs, Gap.xl, Gap.l),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisExtent: 136,
            crossAxisSpacing: Gap.m,
            mainAxisSpacing: Gap.m,
          ),
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
        final items = snap.data?.where((p) => p.sku != openAmountSku).toList();
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
              trailing: Text(
                p.price == null ? '—' : _money(p.price!),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
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
      style: TextStyle(
        color: (out || low) ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.outline,
        fontSize: 12,
      ),
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
      padding: const EdgeInsets.fromLTRB(Gap.s, Gap.m, Gap.s, Gap.s),
      radius: 22,
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ProductThumb(productId: product.id, path: product.photoPath, size: 42),
                const Spacer(),
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  product.price == null ? '—' : money(product.price!),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: scheme.onSurface,
                  ),
                ),
                if (left != null)
                  DefaultTextStyle.merge(
                    style: const TextStyle(fontSize: 11),
                    child: _StockText(left: left!, reorderPoint: product.reorderPoint),
                  ),
              ],
            ),
          ),
          if (pinned)
            Positioned(
              top: 0,
              right: 2,
              child: Icon(Icons.push_pin_rounded, key: Key('pin-${product.id}'), size: 15, color: scheme.primary),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.m, Gap.xs, Gap.m, Gap.xs),
      child: AppCard(
        padding: EdgeInsets.zero,
        radius: 26,
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
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16),
                            ),
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
                          SizedBox(
                            width: 88,
                            child: Padding(
                              padding: const EdgeInsets.only(right: Gap.s),
                              child: Text(
                                money(l.lineTotal),
                                textAlign: TextAlign.end,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.l, Gap.s, Gap.m, Gap.m),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.sellItems(cart.itemCount),
                          style: TextStyle(color: scheme.outline, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          money(cart.subtotal),
                          key: const Key('cart-total'),
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.8),
                        ),
                      ],
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: onPay == null
                          ? null
                          : [
                              BoxShadow(
                                color: scheme.glow.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: FilledButton.icon(
                      key: const Key('pay-button'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(140, 56),
                        backgroundColor: scheme.obsidian,
                        foregroundColor: scheme.onObsidian,
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: scheme.glow.withValues(alpha: onPay == null ? 0 : 0.9),
                            width: 1.6,
                          ),
                        ),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                      ),
                      onPressed: onPay,
                      icon: Icon(Icons.payments_rounded, color: scheme.glow, size: 22),
                      label: Text(t.sellPay),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
