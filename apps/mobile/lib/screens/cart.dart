import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/local_store.dart';
import '../data/sales_models.dart';

class CartLine {
  CartLine(this.product, this.qty);
  final ProductView product;
  double qty;

  int get unitPrice => product.price ?? 0;
  SaleLine toSaleLine() => SaleLine(
        variantId: product.variantId,
        name: product.name,
        qty: qty,
        unitPrice: unitPrice,
        unitCost: product.cost,
        taxRate: product.taxRate,
        tracked: product.trackStock,
      );
  int get lineTotal => toSaleLine().lineTotal;
}

/// The sale being rung up. Kept on the device after every change, so a phone call or a restart does not lose it.
class Cart extends ChangeNotifier {
  Cart(this.store);

  /// The cart on screen (set by the Sell screen), so other screens (the store picker) can see and clear it.
  static Cart? current;

  final SalesStore store;
  static const _metaKey = 'cart';
  final lines = <CartLine>[];

  bool get isEmpty => lines.isEmpty;
  int get subtotal => lines.fold(0, (a, l) => a + l.lineTotal);
  int get itemCount => lines.length;

  /// Same product again adds to its line (no duplicate rows).
  void add(ProductView p, {double qty = 1}) {
    final i = lines.indexWhere((l) => l.product.variantId == p.variantId);
    if (i >= 0) {
      lines[i].qty += qty;
    } else {
      lines.add(CartLine(p, qty));
    }
    _changed();
  }

  /// A typed amount from the keypad: amounts for the same open-amount product add up on one line (price, quantity 1).
  void addOpenAmount(ProductView base, int cents) {
    final i = lines.indexWhere((l) => l.product.variantId == base.variantId);
    if (i >= 0) {
      lines[i] = CartLine(lines[i].product.withPrice((lines[i].product.price ?? 0) + cents), 1);
    } else {
      lines.add(CartLine(base.withPrice(cents), 1));
    }
    _changed();
  }

  void setQty(int index, double qty) {
    if (qty <= 0) {
      lines.removeAt(index);
    } else {
      lines[index].qty = qty;
    }
    _changed();
  }

  void remove(int index) {
    lines.removeAt(index);
    _changed();
  }

  void clear() {
    lines.clear();
    _changed();
  }

  void _changed() {
    notifyListeners();
    store.setMeta(_metaKey, lines.isEmpty ? null : jsonEncode([for (final l in lines) _encode(l)]));
  }

  Future<void> restore() async {
    final raw = await store.meta(_metaKey);
    if (raw == null) return;
    try {
      lines
        ..clear()
        ..addAll([for (final m in (jsonDecode(raw) as List).cast<Map<String, dynamic>>()) _decode(m)]);
      notifyListeners();
    } catch (_) {
      // an unreadable saved cart is not worth an error; start empty
      await store.setMeta(_metaKey, null);
    }
  }

  Map<String, dynamic> _encode(CartLine l) => {
        'id': l.product.id,
        'variantId': l.product.variantId,
        'name': l.product.name,
        'unit': l.product.unit,
        'sku': l.product.sku,
        'barcode': l.product.barcode,
        'price': l.product.price,
        'currency': l.product.currency,
        'photoPath': l.product.photoPath,
        'trackStock': l.product.trackStock,
        'taxRate': l.product.taxRate,
        'cost': l.product.cost,
        'qty': l.qty,
      };

  CartLine _decode(Map<String, dynamic> m) => CartLine(
        ProductView(
          id: m['id'] as String,
          variantId: m['variantId'] as String,
          name: m['name'] as String,
          unit: m['unit'] as String,
          sku: m['sku'] as String,
          barcode: m['barcode'] as String?,
          price: m['price'] as int?,
          currency: m['currency'] as String,
          photoPath: m['photoPath'] as String?,
          active: true,
          pending: false,
          trackStock: m['trackStock'] as bool,
          taxRate: (m['taxRate'] as num).toDouble(),
          cost: m['cost'] as int,
        ),
        (m['qty'] as num).toDouble(),
      );
}
