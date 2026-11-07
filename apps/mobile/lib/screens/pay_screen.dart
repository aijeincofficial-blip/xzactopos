import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../core/money.dart';
import '../data/sales_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import 'cart.dart';
import 'customer_picker.dart';
import 'receipt_screen.dart';

/// Payment: cash with change, an e-wallet, or utang for whatever is not paid now.
/// Default is "exact cash", so the usual sale is one tap on Finish.
class PayScreen extends StatefulWidget {
  const PayScreen({super.key, required this.cart});
  final Cart cart;

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  // made once per screen, so a double tap or a retry can only ever record this one sale
  final _saleId = const Uuid().v7();
  final _opId = const Uuid().v7();
  final _received = TextEditingController();
  final _discount = TextEditingController();
  String _method = 'cash'; // cash | ewallet
  PickedCustomer? _customer;
  bool _saving = false;

  @override
  void dispose() {
    _received.dispose();
    _discount.dispose();
    super.dispose();
  }

  String get _ccy => CatalogScope.of(context).store.baseCurrency;
  String _money(int a) => Money(a, _ccy).format(Localizations.localeOf(context).languageCode);

  /// null = empty, -1 = not a valid amount
  int? _parse(String s) {
    if (s.trim().isEmpty) return null;
    try {
      final v = Money.parse(s, _ccy).amount;
      return v < 0 ? -1 : v;
    } catch (_) {
      return -1;
    }
  }

  int get _subtotal => widget.cart.subtotal;
  int get _discountAmt {
    final d = _parse(_discount.text);
    return (d == null || d < 0) ? 0 : (d > _subtotal ? _subtotal : d);
  }

  int get _total => _subtotal - _discountAmt;
  int? get _receivedRaw => _parse(_received.text);
  int get _receivedAmt => (_receivedRaw == null || _receivedRaw! < 0) ? _total : _receivedRaw!;
  int get _applied => _receivedAmt < _total ? _receivedAmt : _total;
  int get _utang => _total - _applied;
  int get _change => _method == 'cash' && _receivedAmt > _total ? _receivedAmt - _total : 0;
  bool get _valid =>
      _total > 0 && _receivedRaw != -1 && _parse(_discount.text) != -1 && (_utang == 0 || _customer != null);

  Future<void> _chooseCustomer() async {
    final store = CatalogScope.of(context).store;
    final c = await pickCustomer(context, store);
    if (c != null && mounted) setState(() => _customer = c);
  }

  Future<void> _finish() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final scope = CatalogScope.of(context);
    try {
      final draft = SaleDraft(
        id: _saleId,
        soldAt: DateTime.now(),
        lines: [for (final l in widget.cart.lines) l.toSaleLine()],
        discount: _discountAmt,
        customerId: _utang > 0 ? _customer!.id : null,
        payments: [
          if (_applied > 0)
            PaymentDraft(_method, _applied, tendered: _method == 'cash' ? _receivedAmt : null),
          if (_utang > 0) PaymentDraft('utang', _utang),
        ],
      );
      await scope.store.commitSale(draft, opId: _opId);
      widget.cart.clear();
      scope.engine.poke();
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => scope.wrap(ReceiptScreen(saleId: _saleId, justSold: true)),
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).errGeneric)));
    }
  }

  /// A few useful cash amounts: the smallest bills that cover the total.
  List<int> get _quick {
    const bills = [2000, 5000, 10000, 20000, 50000, 100000];
    final out = [for (final b in bills) if (b >= _total && b != _total) b];
    return out.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.payTitle)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            key: const Key('pay-done'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60), textStyle: const TextStyle(fontSize: 22)),
            onPressed: _valid && !_saving ? _finish : null,
            child: Text(t.payDone),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t.payTotal, style: TextStyle(color: scheme.outline)),
          Text(_money(_total),
              key: const Key('pay-total'), style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'cash', label: Text(t.payCash), icon: const Icon(Icons.payments_outlined)),
              ButtonSegment(value: 'ewallet', label: Text(t.payEwallet), icon: const Icon(Icons.phone_android)),
            ],
            selected: {_method},
            onSelectionChanged: (s) => setState(() => _method = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('received-field'),
            controller: _received,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 24),
            decoration: InputDecoration(
              labelText: _method == 'cash' ? t.payReceivedCash : t.payReceivedEwallet,
              hintText: Money(_total, _ccy).toDecimalString(),
              prefixText: '${NumberFormat.simpleCurrency(locale: Localizations.localeOf(context).languageCode, name: _ccy).currencySymbol} ',
              border: const OutlineInputBorder(),
              errorText: _receivedRaw == -1 ? t.errBadAmount : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionChip(
              key: const Key('quick-exact'),
              label: Text(t.payExact),
              onPressed: () => setState(_received.clear),
            ),
            if (_method == 'cash')
              for (final b in _quick)
                ActionChip(
                  key: Key('quick-$b'),
                  label: Text(_money(b)),
                  onPressed: () => setState(() => _received.text = Money(b, _ccy).toDecimalString()),
                ),
            ActionChip(
              key: const Key('all-utang'),
              avatar: const Icon(Icons.menu_book_outlined, size: 18),
              label: Text(t.payAllUtang),
              onPressed: () => setState(() => _received.text = '0'),
            ),
          ]),
          const SizedBox(height: 16),
          if (_change > 0)
            Card(
              color: scheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(child: Text(t.payChange, style: const TextStyle(fontSize: 20))),
                  Text(_money(_change),
                      key: const Key('pay-change'), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          if (_utang > 0)
            Card(
              color: scheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.payOnUtang(_money(_utang)), key: const Key('pay-utang'), style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('choose-customer'),
                    onPressed: _chooseCustomer,
                    icon: const Icon(Icons.person_outline),
                    label: Text(_customer?.name ?? t.payChooseCustomer),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 8),
          ExpansionTile(
            title: Text(t.payDiscount),
            initiallyExpanded: false,
            children: [
              TextField(
                key: const Key('discount-field'),
                controller: _discount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: t.payDiscountHint,
                  border: const OutlineInputBorder(),
                  errorText: _parse(_discount.text) == -1 ? t.errBadAmount : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ],
      ),
    );
  }
}
