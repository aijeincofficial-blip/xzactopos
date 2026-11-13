import 'dart:async';

import 'package:flutter/material.dart';

import '../backend.dart';
import '../core/design_tokens.g.dart';
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
import 'held_carts.dart';
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
  HeldCarts? _held;
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
    _held?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cart == null) {
      final store = CatalogScope.of(context).store;
      _cart = Cart(store)..restore();
      _held = HeldCarts(store)..restore();
      Cart.current = _cart;
      _quick = store.quickItems();
      store.pinnedVariants().then((p) {
        if (mounted) setState(() => _pinned = p);
      });
      // top sellers and held carts are per store: read them again when the store is switched
      var firstStore = true;
      _storeSub = store.watchActiveStore().listen((storeId) {
        if (firstStore) {
          firstStore = false;
          return;
        }
        _held?.restore(storeId: storeId);
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
      return ScanFeedback(
        t.scanAdded(hit.name),
        subtext: '${t.sellItems(_cart!.itemCount)} · ${_money(_cart!.subtotal)}',
      );
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

  String get _ccy => CatalogScope.of(context).store.baseCurrency;

  Future<void> _editLine(int i) async {
    final t = AppLocalizations.of(context);
    final line = _cart!.lines[i];
    final qtyCtrl = TextEditingController(text: _fmtQty(line.qty));
    final discCtrl = TextEditingController(
      text: line.discount > 0 ? Money(line.discount, _ccy).toDecimalString() : '',
    );
    final priceCtrl = TextEditingController(
      text: Money(line.unitPrice, _ccy).toDecimalString(),
    );

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(line.product.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('line-qty-field'),
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: t.sellQuantity),
              ),
              const SizedBox(height: Gap.s),
              TextField(
                key: const Key('line-price-field'),
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: t.cartUnitPriceOverride,
                  prefixText: '${Money(0, _ccy).currencySymbol} ',
                ),
              ),
              const SizedBox(height: Gap.s),
              TextField(
                key: const Key('line-discount-field'),
                controller: discCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: t.cartLineDiscountHint,
                  prefixText: '${Money(0, _ccy).currencySymbol} ',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('line-remove-btn'),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () {
              Navigator.pop(ctx, false);
              _cart!.remove(i);
            },
            child: Text(t.clear),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(
            key: const Key('line-edit-save'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.ok),
          ),
        ],
      ),
    );

    if (updated == true && i < _cart!.lines.length) {
      final newQty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? line.qty;
      if (newQty <= 0) {
        _cart!.remove(i);
        return;
      }
      _cart!.setQty(i, newQty);

      final newPriceVal = priceCtrl.text.trim();
      if (newPriceVal.isNotEmpty) {
        try {
          final newPrice = Money.parse(newPriceVal, _ccy).amount;
          if (newPrice >= 0) {
            _cart!.setUnitPrice(i, newPrice);
          }
        } catch (_) {}
      }

      final discVal = discCtrl.text.trim();
      if (discVal.isEmpty) {
        _cart!.setDiscount(i, 0);
      } else {
        try {
          final disc = Money.parse(discVal, _ccy).amount;
          if (disc >= 0) {
            _cart!.setDiscount(i, disc);
          }
        } catch (_) {}
      }
    }
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

  Future<void> _holdCart() async {
    if (_cart!.isEmpty) return;
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final note = await showHoldCartDialog(context);
    if (note == null || !mounted || _cart!.isEmpty) return;
    final parked = await _held!.parkCurrent(_cart!, label: note);
    if (parked != null && mounted) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t.holdSaleSaved)));
    }
  }

  Future<void> _openHeldCarts() async {
    await showHeldCartsSheet(
      context,
      held: _held!,
      cart: _cart!,
      money: _money,
    );
  }

  static String _fmtQty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final cart = _cart!;
    final held = _held!;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.sell),
        actions: [
          ListenableBuilder(
            listenable: held,
            builder: (_, _) => held.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    key: const Key('held-carts-btn'),
                    visualDensity: VisualDensity.compact,
                    tooltip: t.heldSalesTitle,
                    onPressed: _openHeldCarts,
                    icon: Badge.count(
                      key: const Key('held-carts-count'),
                      count: held.count,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      textColor: Theme.of(context).colorScheme.onPrimary,
                      child: const Icon(Icons.pause_circle_outline_rounded),
                    ),
                  ),
          ),
          ListenableBuilder(
            listenable: cart,
            builder: (_, _) => cart.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    key: const Key('clear-cart'),
                    visualDensity: VisualDensity.compact,
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
              padding: const EdgeInsets.fromLTRB(Gap.l, Gap.s, Gap.l, Gap.xs),
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
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  hintText: t.sellSearchHint,
                  suffixIcon: _query.isEmpty
                      ? (cameraScanner.available
                            ? IconButton(
                                key: const Key('camera-scan'),
                                tooltip: t.scanWithCamera,
                                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                                onPressed: _scanWithCamera,
                              )
                            : const Icon(Icons.qr_code_scanner_rounded, size: 20))
                      : IconButton(icon: const Icon(Icons.close_rounded, size: 18), tooltip: t.clear, onPressed: _clearSearch),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<StockRow>>(
                stream: scope.store.watchStockList(),
                builder: (context, stockSnap) {
                  final rows = stockSnap.data ?? const <StockRow>[];
                  final today = dateOnly(DateTime.now());
                  final stock = <String, double>{
                    for (final r in rows)
                      if (r.qty != null) r.product.variantId: r.qty!,
                  };
                  final expiryByVariant = <String, _ExpiryFlag>{
                    for (final r in rows)
                      if (r.expired(today))
                        r.product.variantId: _ExpiryFlag.expired
                      else if (r.expiringSoon(today))
                        r.product.variantId: _ExpiryFlag.expiringSoon,
                  };
                  return Column(
                    children: [
                      Expanded(
                        child: _query.trim().isEmpty
                            ? _tiles(stock, expiryByVariant, cart)
                            : _results(stock, expiryByVariant),
                      ),
                      ListenableBuilder(
                        listenable: cart,
                        builder: (_, _) {
                          var expiredCartCount = 0;
                          for (final l in cart.lines) {
                            if (expiryByVariant[l.product.variantId] == _ExpiryFlag.expired) {
                              expiredCartCount += 1;
                            }
                          }
                          return _CartPanel(
                            cart: cart,
                            expiredCartCount: expiredCartCount,
                            money: _money,
                            onEditQty: _editQty,
                            onEditLine: _editLine,
                            onHold: cart.isEmpty ? null : _holdCart,
                            onPay: cart.isEmpty ? null : () => _pay(cart),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Today's total in one compact bar on top of Sell; tap for the full day.
  Widget _todayStrip(BuildContext context, Backend backend) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.l, Gap.s, Gap.l, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: _todayCard(context, backend, t, scope, scheme)),
        const SizedBox(width: Gap.s),
        _shiftChip(context, backend, t, scope, scheme),
      ]),
    );
  }

  /// Compact shift status button beside the Today strip.
  Widget _shiftChip(BuildContext context, Backend backend, AppLocalizations t, CatalogScope scope, ColorScheme scheme) {
    return StreamBuilder<ShiftView?>(
      stream: scope.store.watchOpenShift(backend.userId ?? ''),
      builder: (context, snap) {
        final open = snap.data != null;
        return AppCard(
          key: const Key('shift-chip'),
          padding: const EdgeInsets.all(10),
          radius: Gap.radiusM,
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => scope.wrap(ShiftScreen(backend: backend, storeName: widget.storeName)))),
          child: Tooltip(
            message: open ? t.shiftChipOpen : t.shiftChipNone,
            child: Icon(open ? Icons.lock_open_rounded : Icons.lock_outline_rounded, size: 20, color: open ? scheme.success : scheme.outline),
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
            padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: 10),
            radius: Gap.radiusM,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => scope.wrap(TodayScreen(backend: backend)))),
            child: Row(
              children: [
                Icon(Icons.today_rounded, size: 18, color: scheme.accent),
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
                  style: NightMarketText.mono(context, size: 15.5, weight: FontWeight.w600),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.isDark ? scheme.nmInkLine : scheme.nmOkBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      t.todayCount(d.count),
                      key: const Key('today-strip-count'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.isDark ? scheme.nmOkBg : scheme.nmOkFg,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 17, color: scheme.outline),
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

  Widget _tiles(Map<String, double> stock, Map<String, _ExpiryFlag> expiryByVariant, Cart cart) {
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
        return ListenableBuilder(
          listenable: cart,
          builder: (context, _) {
            final qtyByVariant = <String, double>{
              for (final l in cart.lines) l.product.variantId: l.qty,
            };
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(Gap.l, Gap.xs, Gap.l, Gap.s),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 192,
                mainAxisExtent: 128,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final p = items[i];
                return _Tile(
                  product: p,
                  left: p.trackStock ? stock[p.variantId] : null,
                  expiryFlag: expiryByVariant[p.variantId],
                  money: _money,
                  pinned: _pinned.contains(p.variantId),
                  cartQty: qtyByVariant[p.variantId] ?? 0,
                  onTap: () => _add(p),
                  onLongPress: () => _togglePin(p),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _results(Map<String, double> stock, Map<String, _ExpiryFlag> expiryByVariant) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    return StreamBuilder<List<ProductView>>(
      stream: scope.store.watchProducts(query: _query),
      builder: (context, snap) {
        final items = snap.data?.where((p) => p.sku != openAmountSku).toList();
        if (items == null) return const Center(child: CircularProgressIndicator());
        if (items.isEmpty) return Center(child: Text(t.noMatches));
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.xs),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final p = items[i];
            final left = p.trackStock ? stock[p.variantId] : null;
            final expiryFlag = expiryByVariant[p.variantId];
            return ListTile(
              key: Key('result-${p.id}'),
              contentPadding: const EdgeInsets.symmetric(horizontal: Gap.xs, vertical: 2),
              leading: ProductThumb(
                productId: p.id,
                path: p.photoPath,
                name: p.name,
                category: p.sku,
                size: 38,
              ),
              title: Text(p.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              subtitle: (left == null && expiryFlag == null)
                  ? null
                  : Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (left != null) _StockText(left: left, reorderPoint: p.reorderPoint),
                        if (expiryFlag != null) _ExpiryPill(flag: expiryFlag),
                      ],
                    ),
              trailing: Text(
                p.price == null ? '—' : _money(p.price!),
                style: NightMarketText.mono(context, size: 15, weight: FontWeight.w600),
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

enum _ExpiryFlag { expired, expiringSoon }

class _ExpiryPill extends StatelessWidget {
  const _ExpiryPill({required this.flag, this.badgeKey});
  final _ExpiryFlag flag;
  final Key? badgeKey;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isExpired = flag == _ExpiryFlag.expired;
    final bg = isExpired
        ? scheme.errorContainer
        : scheme.payUtang.withValues(alpha: scheme.isDark ? 0.25 : 0.14);
    final fg = isExpired ? scheme.error : scheme.payUtang;
    return Container(
      key: badgeKey,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isExpired ? t.sellExpiredBadge : t.sellExpiringSoonBadge,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          height: 1.1,
        ),
      ),
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
    final scheme = Theme.of(context).colorScheme;
    final out = left <= 0;
    final low = !out && reorderPoint > 0 && left <= reorderPoint;
    final n = left == left.roundToDouble() ? left.toInt().toString() : left.toStringAsFixed(1);
    return Text(
      out ? t.sellOutOfStock : (low ? t.sellStockLow(n) : t.sellStockLeft(n)),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: out ? scheme.error : (low ? scheme.payUtang : scheme.outline),
        fontWeight: (out || low) ? FontWeight.w600 : FontWeight.w400,
        fontSize: 11.5,
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
    this.expiryFlag,
    this.pinned = false,
    this.cartQty = 0,
  });
  final ProductView product;
  final _ExpiryFlag? expiryFlag;
  final bool pinned;
  final double cartQty;
  final VoidCallback onLongPress;
  final double? left;
  final String Function(int) money;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.isDark;
    final inCart = cartQty > 0;
    final qtyText = cartQty == cartQty.roundToDouble() ? '${cartQty.toInt()}' : '$cartQty';
    final activeBorder = dark ? scheme.nmLime : scheme.nmInk;
    final activeBg = dark ? scheme.nmInkLine : scheme.nmOkBg.withValues(alpha: 0.48);

    return AppCard(
      key: Key('tile-${product.id}'),
      onTap: onTap,
      onLongPress: onLongPress,
      padding: const EdgeInsets.fromLTRB(Gap.s, 10, Gap.s, 8),
      radius: 20,
      color: inCart ? activeBg : null,
      borderColor: inCart ? activeBorder : null,
      borderWidth: inCart ? 2.0 : Gap.border,
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ProductThumb(
                  productId: product.id,
                  path: product.photoPath,
                  name: product.name,
                  category: product.sku,
                  size: 40,
                ),
                const Spacer(),
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: scheme.onSurface),
                ),
                Text(
                  product.price == null ? '—' : money(product.price!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NightMarketText.mono(
                    context,
                    size: 16,
                    weight: FontWeight.w600,
                    color: inCart ? (dark ? scheme.nmLime : scheme.nmInk) : scheme.onSurface,
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
          if (inCart)
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.nmLime,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scheme.nmInk, width: 1.2),
                ),
                child: Text(
                  '×$qtyText',
                  style: NightMarketText.mono(
                    context,
                    size: 10.5,
                    weight: FontWeight.w600,
                    color: scheme.nmInk,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          if (expiryFlag != null)
            Positioned(
              top: 0,
              right: pinned ? 18 : 0,
              child: _ExpiryPill(
                flag: expiryFlag!,
                badgeKey: Key('expiry-badge-${product.id}'),
              ),
            ),
          if (pinned)
            Positioned(
              top: 0,
              right: 2,
              child: Icon(
                Icons.push_pin_rounded,
                key: Key('pin-${product.id}'),
                size: 15,
                color: dark ? scheme.nmLime : scheme.nmInk,
              ),
            ),
        ],
      ),
    );
  }
}

class _CartPanel extends StatelessWidget {
  const _CartPanel({
    required this.cart,
    required this.money,
    required this.onEditQty,
    required this.onEditLine,
    required this.onPay,
    this.expiredCartCount = 0,
    this.onHold,
  });
  final Cart cart;
  final int expiredCartCount;
  final String Function(int) money;
  final void Function(int) onEditQty;
  final void Function(int) onEditLine;
  final VoidCallback? onHold;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final hasItems = !cart.isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.l, Gap.xs, Gap.l, Gap.s),
      child: Container(
        decoration: BoxDecoration(
          color: hasItems ? scheme.surface : scheme.nmInk,
          borderRadius: BorderRadius.circular(Gap.radiusL),
          border: Border.all(
            color: hasItems ? scheme.outlineVariant : scheme.nmInkLine2,
            width: Gap.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasItems && expiredCartCount > 0)
              Container(
                key: const Key('cart-expired-warning'),
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(Gap.m, 8, Gap.m, 2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(Gap.radiusS),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 15, color: scheme.onErrorContainer),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        t.sellCartExpiredWarning(expiredCartCount),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (hasItems) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 176),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(top: 6, bottom: 2),
                  itemCount: cart.lines.length,
                  separatorBuilder: (_, _) => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: Gap.l),
                    child: DashedDivider(),
                  ),
                  itemBuilder: (context, i) {
                    final l = cart.lines[i];
                    return Padding(
                      key: Key('cart-line-$i'),
                      padding: const EdgeInsets.fromLTRB(Gap.l, 2, Gap.m, 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              key: Key('edit-line-$i'),
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => onEditLine(i),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l.product.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: scheme.onSurface),
                                    ),
                                    if (l.discount > 0)
                                      Text(
                                        t.cartLineDiscountShort(money(l.discount)),
                                        key: Key('line-discount-$i'),
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: scheme.success,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            key: Key('minus-$i'),
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.remove_circle_outline_rounded, size: 21, color: scheme.outline),
                            onPressed: () => cart.setQty(i, l.qty - 1),
                          ),
                          InkWell(
                            key: Key('qty-$i'),
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => onEditQty(i),
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 32),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: scheme.chipFill,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: scheme.outlineVariant, width: 1.0),
                              ),
                              child: Text(
                                l.qty == l.qty.roundToDouble() ? '${l.qty.toInt()}' : '${l.qty}',
                                style: NightMarketText.mono(
                                  context,
                                  size: 14,
                                  weight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            key: Key('plus-$i'),
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.add_circle_outline_rounded, size: 21, color: scheme.primary),
                            onPressed: () => cart.setQty(i, l.qty + 1),
                          ),
                          SizedBox(
                            width: 82,
                            child: Text(
                              money(l.lineTotal),
                              textAlign: TextAlign.end,
                              style: NightMarketText.mono(
                                context,
                                size: 14,
                                weight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Divider(height: 1.5, thickness: 1.5, color: scheme.outlineVariant),
            ],
            // Dark `--ink` Night Market sticky checkout summary bar
            Container(
              color: scheme.nmInk,
              padding: EdgeInsets.fromLTRB(Gap.l, hasItems ? 10 : 11, Gap.m, hasItems ? 10 : 11),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (cart.isEmpty)
                          Text(
                            t.sellCartEmpty,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: DesignTokens.mutedOnDark, fontSize: 12, fontWeight: FontWeight.w500),
                          )
                        else if (cart.totalDiscount > 0)
                          Text(
                            t.cartLineDiscountShort(money(cart.totalDiscount)),
                            key: const Key('cart-total-discount'),
                            style: TextStyle(color: scheme.nmLime, fontWeight: FontWeight.w700, fontSize: 12.5),
                          )
                        else
                          Text(
                            t.sellItems(cart.itemCount),
                            style: TextStyle(color: DesignTokens.mutedOnDark, fontWeight: FontWeight.w600, fontSize: 12.5),
                          ),
                        const SizedBox(height: 1),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  money(cart.subtotal),
                                  key: const Key('cart-total'),
                                  style: NightMarketText.mono(
                                    context,
                                    size: cart.isEmpty ? 20 : 24,
                                    weight: FontWeight.w600,
                                    color: hasItems ? scheme.nmLime : DesignTokens.mutedOnDark,
                                  ),
                                ),
                              ),
                            ),
                            if (cart.isEmpty) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  t.sellItems(cart.itemCount),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: DesignTokens.mutedOnDark, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (onHold != null) ...[
                    IconButton.filledTonal(
                      key: const Key('hold-cart-btn'),
                      tooltip: t.holdSaleAction,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 48),
                        backgroundColor: scheme.nmInk2,
                        foregroundColor: scheme.nmLime,
                        side: BorderSide(color: scheme.nmInkLine2, width: Gap.border),
                      ),
                      onPressed: onHold,
                      icon: const Icon(Icons.pause_rounded, size: 21),
                    ),
                    const SizedBox(width: 8),
                  ],
                  FilledButton.icon(
                    key: const Key('pay-button'),
                    style: FilledButton.styleFrom(
                      elevation: 0,
                      minimumSize: Size(cart.isEmpty ? 116 : 136, 48),
                      backgroundColor: scheme.obsidian,
                      foregroundColor: scheme.onObsidian,
                      disabledBackgroundColor: DesignTokens.disabledBg,
                      disabledForegroundColor: DesignTokens.mutedOnDark,
                      shape: const StadiumBorder(),
                      side: BorderSide.none,
                      textStyle: const TextStyle(
                        fontFamily: NightMarketFont.sans,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: onPay,
                    icon: Icon(
                      Icons.payments_rounded,
                      size: 20,
                      color: onPay == null ? DesignTokens.mutedOnDark : scheme.onObsidian,
                    ),
                    label: Text(t.sellPay),
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
