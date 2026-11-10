import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../backend.dart';
import '../core/money.dart';
import '../core/supervisor_pin_dialog.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/sales_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import 'cart.dart';
import 'services_screen.dart' show walletLabel;
import 'customer_picker.dart';
import 'keypad_panel.dart';
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
  final _utangKey = GlobalKey();
  bool _utangShown = false;
  String _wallet = 'gcash'; // which wallet an e-wallet payment went to
  PickedCustomer? _customer;
  bool _saving = false;
  SupervisorApprovalResult? _approvalResult;

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
    var v = s.trim();
    if (v.endsWith('.')) v = v.substring(0, v.length - 1); // half-typed on the pad, e.g. "100."
    if (v.isEmpty) return null;
    try {
      final amount = Money.parse(v, _ccy).amount;
      return amount < 0 ? -1 : amount;
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

  Future<bool> _requestSupervisorApproval() async {
    final scope = CatalogScope.of(context);
    final backend = (scope.engine.api is Backend) ? scope.engine.api as Backend : null;
    if (backend == null) return true;
    final t = AppLocalizations.of(context);
    final res = await showSupervisorPinDialog(
      context,
      backend: backend,
      action: 'sale_discount',
      refId: _saleId,
      title: t.supervisorPinDiscountTitle,
      subtitle: t.supervisorPinDiscountSubtitle(_money(_discountAmt)),
    );
    if (!mounted) return false;
    if (res != null) {
      setState(() => _approvalResult = res);
      return true;
    }
    return false;
  }

  Future<void> _finish() async {
    if (!_valid || _saving) return;
    final scope = CatalogScope.of(context);
    if (scope.isCashier && _discountAmt > 0 && _approvalResult == null) {
      final approved = await _requestSupervisorApproval();
      if (!approved) return;
      if (!mounted) return;
    }
    setState(() => _saving = true);
    try {
      final draft = SaleDraft(
        id: _saleId,
        soldAt: DateTime.now(),
        lines: [for (final l in widget.cart.lines) l.toSaleLine()],
        discount: _discountAmt,
        customerId: _utang > 0 ? _customer!.id : null,
        approvalId: _approvalResult?.approvalId,
        offlineApproval: _approvalResult?.offlineApproval,
        payments: [
          if (_applied > 0)
            PaymentDraft(
              _method,
              _applied,
              tendered: _method == 'cash' ? _receivedAmt : null,
              wallet: _method == 'ewallet' ? _wallet : null,
            ),
          if (_utang > 0) PaymentDraft('utang', _utang),
        ],
      );
      await scope.store.commitSale(draft, opId: _opId);
      widget.cart.clear();
      scope.engine.poke();
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => scope.wrap(ReceiptScreen(saleId: _saleId, justSold: true))),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).errGeneric)));
    }
  }

  /// A few useful cash amounts: the smallest bills that cover the total.
  List<int> get _quick {
    const bills = [2000, 5000, 10000, 20000, 50000, 100000];
    final out = [
      for (final b in bills)
        if (b >= _total && b != _total) b,
    ];
    return out.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    // when part or all of the sale goes on utang, the who-owes button must not stay under the keypad
    if (_utang > 0 && !_utangShown) {
      _utangShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _utangKey.currentContext;
        if (c != null && mounted) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });
    } else if (_utang <= 0) {
      _utangShown = false;
    }
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.payTitle)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, Gap.xs, 0, Gap.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // the number pad types the amount received (cash or e-wallet); no phone keyboard needed
              AmountPad(controller: _received, currency: _ccy, onChanged: () => setState(() {})),
              const SizedBox(height: Gap.s),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
                child: FilledButton.icon(
                  key: const Key('pay-done'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(60),
                    backgroundColor: scheme.obsidian,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: scheme.outlineVariant,
                    disabledForegroundColor: scheme.outline,
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: (_valid && !_saving)
                            ? scheme.glow.withValues(alpha: 0.85)
                            : Colors.transparent,
                        width: 1.6,
                      ),
                    ),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
                  icon: Icon(Icons.check_circle_rounded, color: scheme.glow, size: 22),
                  onPressed: _valid && !_saving ? _finish : null,
                  label: Text(t.payDone),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.l, Gap.s, Gap.l, Gap.l),
        children: [
          // Total Due Hero Card (Sleek horizontal ceramic row)
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.m),
            radius: Gap.radiusL,
            child: Row(
              children: [
                CoinBadge(
                  icon: _method == 'cash' ? Icons.payments_rounded : Icons.phone_android_rounded,
                  color: scheme.payCash,
                  size: 40,
                ),
                const SizedBox(width: Gap.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.payTotal.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: scheme.outline,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        _money(_total),
                        key: const Key('pay-total'),
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -1.0),
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  label: _method == 'cash' ? t.payCash : t.payEwallet,
                  color: scheme.obsidian,
                  textColor: Colors.white,
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.m),

          // Payment Method Segmented Switcher
          SegmentedButton<String>(
            style: SegmentedButton.styleFrom(shape: const StadiumBorder(), visualDensity: VisualDensity.compact),
            segments: [
              ButtonSegment(value: 'cash', label: Text(t.payCash), icon: const Icon(Icons.payments_rounded, size: 18)),
              ButtonSegment(
                value: 'ewallet',
                label: Text(t.payEwallet),
                icon: const Icon(Icons.phone_android_rounded, size: 18),
              ),
            ],
            selected: {_method},
            onSelectionChanged: (s) => setState(() => _method = s.first),
          ),
          if (_method == 'ewallet') ...[
            const SizedBox(height: Gap.s),
            Text(t.payWalletTitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (final w in paymentWallets)
                  ChoiceChip(
                    key: Key('pay-wallet-$w'),
                    label: Text(walletLabel(t, w)),
                    selected: _wallet == w,
                    onSelected: (_) => setState(() => _wallet = w),
                  ),
              ],
            ),
          ],
          const SizedBox(height: Gap.m),

          // Amount received: typed with the pad below (no system keyboard)
          TextField(
            key: const Key('received-field'),
            controller: _received,
            keyboardType: TextInputType.none,
            showCursor: true,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            decoration: InputDecoration(
              isDense: true,
              labelText: _method == 'cash' ? t.payReceivedCash : t.payReceivedEwallet,
              hintText: Money(_total, _ccy).toDecimalString(),
              prefixText:
                  '${NumberFormat.simpleCurrency(locale: Localizations.localeOf(context).languageCode, name: _ccy).currencySymbol} ',
              prefixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              errorText: _receivedRaw == -1 ? t.errBadAmount : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Gap.s),

          // Quick Bill Pill Chips
          Wrap(
            spacing: Gap.s,
            runSpacing: Gap.s,
            children: [
              ActionChip(
                key: const Key('quick-exact'),
                avatar: const Icon(Icons.check_rounded, size: 16),
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
                avatar: const Icon(Icons.menu_book_rounded, size: 16),
                label: Text(t.payAllUtang),
                onPressed: () => setState(() => _received.text = '0'),
              ),
            ],
          ),
          const SizedBox(height: Gap.m),

          // Sukli / Change Card
          if (_change > 0)
            AppCard(
              color: scheme.secondaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.m),
              radius: Gap.radiusM,
              child: Row(
                children: [
                  CoinBadge(icon: Icons.currency_exchange_rounded, color: scheme.success, size: 38),
                  const SizedBox(width: Gap.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.payChange.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSecondaryContainer,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          _money(_change),
                          key: const Key('pay-change'),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: scheme.onSecondaryContainer,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Utang / Receivables Card
          if (_utang > 0)
            AppCard(
              key: _utangKey,
              color: scheme.primaryContainer,
              padding: const EdgeInsets.all(Gap.m),
              radius: Gap.radiusM,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.payOnUtang(_money(_utang)),
                    key: const Key('pay-utang'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: Gap.s),
                  OutlinedButton.icon(
                    key: const Key('choose-customer'),
                    onPressed: _chooseCustomer,
                    icon: const Icon(Icons.person_outline, size: 18),
                    label: Text(_customer?.name ?? t.payChooseCustomer),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Gap.s),

          // Discount Collapsible
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: Gap.xs),
            radius: Gap.radiusM,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              shape: const Border(),
              leading: const Icon(Icons.local_offer_outlined),
              title: Text(t.payDiscount, style: const TextStyle(fontWeight: FontWeight.w700)),
              initiallyExpanded: false,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const Key('discount-field'),
                        controller: _discount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: t.payDiscountHint,
                          errorText: _parse(_discount.text) == -1 ? t.errBadAmount : null,
                        ),
                        onChanged: (_) => setState(() {
                          _approvalResult = null;
                        }),
                      ),
                      if (scope.isCashier && _discountAmt > 0) ...[
                        const SizedBox(height: Gap.xs),
                        if (_approvalResult == null)
                          Container(
                            key: const Key('discount-supervisor-required'),
                            padding: const EdgeInsets.symmetric(horizontal: Gap.s, vertical: Gap.xs),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.shield_outlined, size: 16, color: Colors.amber.shade800),
                                const SizedBox(width: Gap.xs),
                                Expanded(
                                  child: Text(
                                    t.supervisorPinRequiredDiscount,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.amber.shade900,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  key: const Key('discount-approve-btn'),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: Gap.s),
                                    minimumSize: const Size(0, 32),
                                  ),
                                  onPressed: _requestSupervisorApproval,
                                  child: Text(t.supervisorPinApproveBtn),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            key: const Key('discount-approved-badge'),
                            padding: const EdgeInsets.symmetric(horizontal: Gap.s, vertical: Gap.xs),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.green.shade700),
                                const SizedBox(width: Gap.xs),
                                Expanded(
                                  child: Text(
                                    t.supervisorPinApprovedBy(_approvalResult!.approvedBy),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade900,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
