import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/camera_scanner.dart';
import '../core/theme.dart';
import '../data/local_store.dart';
import '../data/warehouse_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';

/// Parses a quantity typed by the clerk ("12", "12.5", "12,5"). Null when empty or not a number.
double? parseQty(String raw) => double.tryParse(raw.trim().replaceAll(',', '.'));

/// Parses an invoice cost typed in pesos into minor units (centavos). Null when empty or not a number.
int? parseCostMinor(String raw) {
  final v = parseQty(raw);
  return v == null ? null : (v * 100).round();
}

String refusalText(AppLocalizations t, String code) => switch (code) {
      'unknown_order' => t.whErrUnknownOrder,
      'order_closed' => t.whErrOrderClosed,
      'not_on_order' => t.whErrNotOnOrder,
      'duplicate_line' => t.whErrDuplicateLine,
      'qty_invalid' => t.whErrQtyInvalid,
      'cost_invalid' => t.whErrCostInvalid,
      'no_lines' => t.whErrNoLines,
      'unknown_warehouse' => t.whErrUnknownWarehouse,
      _ => t.errGeneric,
    };

String _qty(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// One line being typed: quantity and optional invoice cost.
class _LineInput {
  _LineInput({String qty = ''}) : qty = TextEditingController(text: qty);
  final TextEditingController qty;
  final TextEditingController cost = TextEditingController();
  void dispose() {
    qty.dispose();
    cost.dispose();
  }
}

// ---------------------------------------------------------------------------------------------------------------------
// Receive against an order
// ---------------------------------------------------------------------------------------------------------------------

class ReceiveOrderScreen extends StatefulWidget {
  const ReceiveOrderScreen({super.key, required this.orderId});
  final String orderId;

  @override
  State<ReceiveOrderScreen> createState() => _ReceiveOrderScreenState();
}

class _ReceiveOrderScreenState extends State<ReceiveOrderScreen> {
  PurchaseOrderView? _order;
  Map<String, String> _names = {};
  final _inputs = <String, _LineInput>{};
  final _ref = TextEditingController();
  final _notes = TextEditingController();
  String? _error;
  bool _saving = false;
  // one id per screen: a double tap or a retry is the same receipt
  final String _opId = const Uuid().v7();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final store = CatalogScope.of(context).store;
    final order = await store.purchaseOrder(widget.orderId);
    final products = await store.watchProducts().first;
    if (!mounted) return;
    setState(() {
      _order = order;
      _names = {for (final p in products) p.variantId: p.name};
      for (final l in order?.items ?? const <PoLineView>[]) {
        _inputs[l.id] = _LineInput(qty: l.remaining > 0 ? _qty(l.remaining) : '');
      }
    });
  }

  @override
  void dispose() {
    for (final i in _inputs.values) {
      i.dispose();
    }
    _ref.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final order = _order!;
    final lines = <ReceiptLine>[];
    for (final l in order.items) {
      final input = _inputs[l.id]!;
      final raw = input.qty.text.trim();
      if (raw.isEmpty) continue;
      final qty = parseQty(raw);
      if (qty == null || qty < 0) {
        setState(() => _error = t.whErrQtyInvalid);
        return;
      }
      if (qty == 0) continue;
      final costRaw = input.cost.text.trim();
      final cost = parseCostMinor(costRaw);
      if (costRaw.isNotEmpty && (cost == null || cost < 0)) {
        setState(() => _error = t.whErrCostInvalid);
        return;
      }
      lines.add(ReceiptLine(variantId: l.variantId, qty: qty, unitCost: cost));
    }
    if (lines.isEmpty) {
      setState(() => _error = t.whErrNoLines);
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final scope = CatalogScope.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await scope.store.receiveAgainstPo(
        poId: order.id,
        lines: lines,
        deliveryRef: _ref.text,
        notes: _notes.text,
        opId: _opId,
      );
      scope.engine.poke();
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t.whReceiptSaved)));
    } on WarehouseReceiptException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = refusalText(t, e.code);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final order = _order;
    return Scaffold(
      appBar: AppBar(title: Text(order == null ? t.whReceiveTitle : '${t.whReceiveTitle} · ${order.poNo}')),
      body: order == null
          ? const SizedBox.shrink()
          : ListView(padding: const EdgeInsets.all(Gap.l), children: [
              for (final l in order.items) _lineCard(context, t, l),
              const SizedBox(height: Gap.m),
              TextField(key: const Key('field-ref'), controller: _ref, decoration: InputDecoration(labelText: t.whDeliveryRef)),
              const SizedBox(height: Gap.m),
              TextField(key: const Key('field-notes'), controller: _notes, decoration: InputDecoration(labelText: t.whNotes)),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: Gap.m),
                  child: Text(_error!, key: const Key('receive-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              const SizedBox(height: Gap.l),
              FilledButton(key: const Key('receive-save'), onPressed: _saving ? null : _save, child: Text(t.whReceiveSave)),
            ]),
    );
  }

  Widget _lineCard(BuildContext context, AppLocalizations t, PoLineView l) {
    final input = _inputs[l.id]!;
    final typed = parseQty(input.qty.text) ?? 0;
    final over = typed > l.remaining;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.m),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_names[l.variantId] ?? t.whUnknownProduct, style: Theme.of(context).textTheme.titleSmall),
          Text(t.whLineProgress(_qty(l.received), _qty(l.ordered))),
          const SizedBox(height: Gap.s),
          Row(children: [
            Expanded(
              child: TextField(
                key: Key('qty-${l.id}'),
                controller: input.qty,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: t.whQtyReceived),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: Gap.m),
            Expanded(
              child: TextField(
                key: Key('cost-${l.id}'),
                controller: input.cost,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: t.whInvoiceCost),
              ),
            ),
          ]),
          if (over)
            Padding(
              padding: const EdgeInsets.only(top: Gap.s),
              child: Text(t.whOverDelivery, key: Key('over-${l.id}'), style: TextStyle(color: Theme.of(context).colorScheme.tertiary)),
            ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------------
// A delivery with no order
// ---------------------------------------------------------------------------------------------------------------------

class WalkInScreen extends StatefulWidget {
  const WalkInScreen({super.key, required this.warehouseId});
  final String warehouseId;

  @override
  State<WalkInScreen> createState() => _WalkInScreenState();
}

class _WalkInScreenState extends State<WalkInScreen> {
  final _lines = <(ProductView, _LineInput)>[];
  List<SupplierView> _suppliers = [];
  String? _supplierId;
  final _ref = TextEditingController();
  final _notes = TextEditingController();
  final _search = TextEditingController();
  String _query = '';
  String? _error;
  bool _saving = false;
  final String _opId = const Uuid().v7();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final s = await CatalogScope.of(context).store.watchSuppliers().first;
      if (mounted) setState(() => _suppliers = s);
    });
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.$2.dispose();
    }
    _ref.dispose();
    _notes.dispose();
    _search.dispose();
    super.dispose();
  }

  void _add(ProductView p) {
    if (_lines.any((l) => l.$1.variantId == p.variantId)) return;
    setState(() {
      _lines.add((p, _LineInput(qty: '1')));
      _query = '';
      _search.clear();
      _error = null;
    });
  }

  Future<void> _scan() async {
    final code = await cameraScanner.scanOne(context);
    if (code == null || !mounted) return;
    final p = await CatalogScope.of(context).store.findByBarcode(code);
    if (!mounted) return;
    if (p == null) {
      setState(() => _error = AppLocalizations.of(context).whScanUnknown);
    } else {
      _add(p);
    }
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final lines = <ReceiptLine>[];
    for (final (p, input) in _lines) {
      final qty = parseQty(input.qty.text);
      if (qty == null || qty <= 0) {
        setState(() => _error = t.whErrQtyInvalid);
        return;
      }
      final costRaw = input.cost.text.trim();
      final cost = parseCostMinor(costRaw);
      if (costRaw.isNotEmpty && (cost == null || cost < 0)) {
        setState(() => _error = t.whErrCostInvalid);
        return;
      }
      lines.add(ReceiptLine(variantId: p.variantId, qty: qty, unitCost: cost));
    }
    if (lines.isEmpty) {
      setState(() => _error = t.whErrNoLines);
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final scope = CatalogScope.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await scope.store.receiveWithoutPo(
        warehouseId: widget.warehouseId,
        supplierId: _supplierId,
        lines: lines,
        deliveryRef: _ref.text,
        notes: _notes.text,
        opId: _opId,
      );
      scope.engine.poke();
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t.whReceiptSaved)));
    } on WarehouseReceiptException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = refusalText(t, e.code);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final store = CatalogScope.of(context).store;
    return Scaffold(
      appBar: AppBar(title: Text(t.whWalkInTitle)),
      body: ListView(padding: const EdgeInsets.all(Gap.l), children: [
        Text(t.whWalkInHint),
        const SizedBox(height: Gap.m),
        DropdownButtonFormField<String?>(
          key: const Key('field-supplier'),
          initialValue: _supplierId,
          decoration: InputDecoration(labelText: t.whSupplier),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(t.whNoSupplier)),
            for (final s in _suppliers) DropdownMenuItem<String?>(value: s.id, child: Text(s.name)),
          ],
          onChanged: (v) => setState(() => _supplierId = v),
        ),
        const SizedBox(height: Gap.m),
        TextField(
          key: const Key('walkin-search'),
          controller: _search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: t.searchProducts,
            suffixIcon: cameraScanner.available
                ? IconButton(key: const Key('walkin-scan'), tooltip: t.scanWithCamera, icon: const Icon(Icons.qr_code_scanner_rounded), onPressed: _scan)
                : null,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        if (_query.trim().isNotEmpty)
          StreamBuilder<List<ProductView>>(
            stream: store.watchProducts(query: _query.trim()),
            builder: (context, snap) => Column(children: [
              for (final p in (snap.data ?? const <ProductView>[]).take(6))
                ListTile(key: Key('pick-${p.variantId}'), dense: true, title: Text(p.name), onTap: () => _add(p)),
            ]),
          ),
        const SizedBox(height: Gap.m),
        for (final (p, input) in _lines)
          Card(
            key: Key('walkin-line-${p.variantId}'),
            child: Padding(
              padding: const EdgeInsets.all(Gap.m),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(p.name, style: Theme.of(context).textTheme.titleSmall)),
                  IconButton(
                    key: Key('remove-${p.variantId}'),
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() {
                      _lines.removeWhere((l) => l.$1.variantId == p.variantId);
                      input.dispose();
                    }),
                  ),
                ]),
                Row(children: [
                  Expanded(
                    child: TextField(
                      key: Key('qty-${p.variantId}'),
                      controller: input.qty,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: t.whQtyReceived),
                    ),
                  ),
                  const SizedBox(width: Gap.m),
                  Expanded(
                    child: TextField(
                      key: Key('cost-${p.variantId}'),
                      controller: input.cost,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: t.whInvoiceCost),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        TextField(key: const Key('field-ref'), controller: _ref, decoration: InputDecoration(labelText: t.whDeliveryRef)),
        const SizedBox(height: Gap.m),
        TextField(key: const Key('field-notes'), controller: _notes, decoration: InputDecoration(labelText: t.whNotes)),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: Gap.m),
            child: Text(_error!, key: const Key('receive-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: Gap.l),
        FilledButton(key: const Key('receive-save'), onPressed: _saving ? null : _save, child: Text(t.whReceiveSave)),
      ]),
    );
  }
}
