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
  final _cardRef = TextEditingController();
  String _method = 'cash'; // cash | ewallet | card
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
    _cardRef.dispose();
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

  int get _totalDiscount =>
      widget.cart.lines.fold<int>(0, (a, l) => a + l.discount) + _discountAmt;

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
      subtitle: t.supervisorPinDiscountSubtitle(_money(_totalDiscount)),
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
    if (scope.isCashier && _totalDiscount > 0 && _approvalResult == null) {
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
              reference: _method == 'card' && _cardRef.text.trim().isNotEmpty
                  ? _cardRef.text.trim()
                  : null,
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
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(top: BorderSide(color: scheme.outlineVariant, width: 1.0)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, Gap.xs, 0, Gap.s),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // the number pad types the amount received (cash or e-wallet); no phone keyboard needed
                AmountPad(controller: _received, currency: _ccy, onChanged: () => setState(() {})),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.l),
                  child: FilledButton.icon(
                    key: const Key('pay-done'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: scheme.obsidian,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: scheme.chipFill,
                      disabledForegroundColor: scheme.outline,
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                    onPressed: _valid && !_saving ? _finish : null,
                    label: Text(t.payDone),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.l, Gap.xs, Gap.l, Gap.l),
        children: [
          // Total Due Hero Card
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: 10),
            radius: Gap.radiusL,
            child: Row(
              children: [
                CoinBadge(
                  icon: _method == 'cash'
                      ? Icons.payments_outlined
                      : (_method == 'card' ? Icons.credit_card_rounded : Icons.phone_android_rounded),
                  color: scheme.primary,
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
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.outline,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        _money(_total),
                        key: const Key('pay-total'),
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.8),
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  label: _method == 'cash'
                      ? t.payCash
                      : (_method == 'card' ? t.payCard : t.payEwallet),
                  color: scheme.primaryContainer,
                  textColor: scheme.onPrimaryContainer,
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.s),

          // Payment Method Recessed Pill Selector (single-line, Cobalt active card, zero text clipping)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: scheme.chipFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant, width: 1.0),
            ),
            child: Row(
              children: [
                _MethodTab(
                  icon: Icons.payments_outlined,
                  label: t.payCash,
                  selected: _method == 'cash',
                  onTap: () => setState(() => _method = 'cash'),
                ),
                const SizedBox(width: 4),
                _MethodTab(
                  icon: Icons.phone_android_rounded,
                  label: t.payEwallet,
                  selected: _method == 'ewallet',
                  onTap: () => setState(() => _method = 'ewallet'),
                ),
                const SizedBox(width: 4),
                _MethodTab(
                  icon: Icons.credit_card_rounded,
                  label: t.payCard,
                  selected: _method == 'card',
                  onTap: () => setState(() => _method = 'card'),
                ),
              ],
            ),
          ),
          if (_method == 'ewallet') ...[
            const SizedBox(height: Gap.s),
            Row(
              children: [
                Text(
                  t.payWalletTitle,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.outline),
                ),
                const SizedBox(width: Gap.s),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final w in paymentWallets)
                        _WalletPill(
                          key: Key('pay-wallet-$w'),
                          label: walletLabel(t, w),
                          selected: _wallet == w,
                          onTap: () => setState(() => _wallet = w),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (_method == 'card') ...[
            const SizedBox(height: Gap.s),
            TextField(
              key: const Key('pay-card-ref'),
              controller: _cardRef,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.pin_outlined),
                labelText: t.payCardRef,
                hintText: t.payCardRefHint,
              ),
            ),
          ],
          const SizedBox(height: Gap.s),

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
              floatingLabelBehavior: FloatingLabelBehavior.always,
              labelText: _method == 'cash'
                  ? t.payReceivedCash
                  : (_method == 'card' ? t.payCardReceived : t.payReceivedEwallet),
              hintText: Money(_total, _ccy).toDecimalString(),
              prefixText:
                  '${NumberFormat.simpleCurrency(locale: Localizations.localeOf(context).languageCode, name: _ccy).currencySymbol} ',
              prefixStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: scheme.onSurface),
              errorText: _receivedRaw == -1 ? t.errBadAmount : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Gap.s),

          // Quick Bill & Tender Pill Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PayPill(
                key: const Key('quick-exact'),
                icon: Icons.check_circle_rounded,
                label: t.payExact,
                selected: _received.text.trim().isEmpty,
                onTap: () => setState(_received.clear),
              ),
              if (_method == 'cash')
                for (final b in _quick)
                  _PayPill(
                    key: Key('quick-$b'),
                    label: _money(b),
                    selected: _receivedRaw == b,
                    onTap: () => setState(() => _received.text = Money(b, _ccy).toDecimalString()),
                  ),
              _PayPill(
                key: const Key('all-utang'),
                icon: Icons.menu_book_rounded,
                label: t.payAllUtang,
                selected: _received.text.trim() == '0',
                accentColor: scheme.payUtang,
                onTap: () => setState(() => _received.text = '0'),
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

/// Single-line tactile segment inside the payment method switcher.
class _MethodTab extends StatelessWidget {
  const _MethodTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.primary : scheme.outline;
    final r = BorderRadius.circular(12);

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 42,
        decoration: BoxDecoration(
          color: selected ? scheme.surface : Colors.transparent,
          borderRadius: r,
          border: selected ? Border.all(color: scheme.primary.withValues(alpha: 0.45), width: 1.3) : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: scheme.isDark ? 0.25 : 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: r,
          child: InkWell(
            borderRadius: r,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: fg),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        color: selected ? (scheme.isDark ? scheme.onSurface : scheme.primary) : scheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sleek pill selector for GCash / Maya / Other wallet sub-choice.
class _WalletPill extends StatelessWidget {
  const _WalletPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = BorderRadius.circular(20);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: selected ? scheme.obsidian : scheme.surface,
        borderRadius: r,
        border: Border.all(
          color: selected ? scheme.obsidian : scheme.outlineVariant,
          width: 1.0,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: scheme.obsidian.withValues(alpha: 0.24),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: r,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? Colors.white : scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tactile state-aware pill button for Exact, Quick Cash Bills, and All on Utang.
class _PayPill extends StatelessWidget {
  const _PayPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.accentColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = accentColor ?? scheme.primary;
    final r = BorderRadius.circular(20);

    final bg = selected
        ? active.withValues(alpha: scheme.isDark ? 0.24 : 0.12)
        : scheme.surface;
    final border = selected
        ? active.withValues(alpha: scheme.isDark ? 0.70 : 0.55)
        : scheme.outlineVariant;
    final fg = selected
        ? (scheme.isDark ? Colors.white : Color.lerp(active, Colors.black, 0.18)!)
        : scheme.onSurface;
    final iconColor = selected ? active : (accentColor ?? scheme.primary);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: r,
        border: Border.all(color: border, width: selected ? 1.4 : 1.0),
        boxShadow: [
          BoxShadow(
            color: selected
                ? active.withValues(alpha: 0.14)
                : (scheme.isDark ? Colors.black.withValues(alpha: 0.20) : const Color(0x080F172A)),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: r,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: icon != null ? 12 : 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: iconColor),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
