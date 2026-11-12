import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../backend.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/sales_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import '../sync/sync_badge.dart';
import 'supervisor_pin.dart';

String walletLabel(AppLocalizations t, String wallet) => switch (wallet) {
      'gcash' => t.walletGcash,
      'maya' => t.walletMaya,
      'load' => t.walletLoad,
      _ => t.walletOther,
    };

String serviceKindLabel(AppLocalizations t, String kind) => switch (kind) {
      'cash_in' => t.serviceCashIn,
      'cash_out' => t.serviceCashOut,
      'load' => t.serviceLoad,
      'float_topup' => t.serviceFloatTopup,
      'float_withdraw' => t.serviceFloatWithdraw,
      _ => t.serviceFloatAdjust,
    };

/// Load and e-wallet (GCash / Maya) cash-in and cash-out: enter each one, see today's fees and the wallet float.
class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key, required this.backend});
  final Backend backend;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    String money(int a) => Money(a, scope.store.baseCurrency).format(locale);
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);

    Widget action(String key, String kind, IconData icon) => Expanded(
          child: OutlinedButton(
            key: Key(key),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 78),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              backgroundColor: scheme.surface,
              side: BorderSide(color: scheme.outlineVariant),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gap.radiusM)),
            ),
            onPressed: () => showServiceDialog(context, scope, kind),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 22, color: scheme.primary),
              const SizedBox(height: 5),
              Text(
                serviceKindLabel(t, kind),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.15, color: scheme.onSurface),
              ),
            ]),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(t.servicesTitle), actions: const [SyncBadge()]),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Gap.xxl),
        children: [
          StreamBuilder<ServiceTotals>(
            stream: scope.store.watchTodayServices(),
            builder: (context, snap) {
              final d = snap.data ?? const ServiceTotals();
              return SummaryCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.servicesFeesToday.toUpperCase(),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scheme.outline, letterSpacing: 0.8)),
                  const SizedBox(height: Gap.s),
                  Text(money(d.fees),
                      key: const Key('services-fees'),
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
                ]),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.xs),
            child: Row(children: [
              action('service-cash-in', 'cash_in', Icons.south_west_rounded),
              const SizedBox(width: Gap.s),
              action('service-cash-out', 'cash_out', Icons.north_east_rounded),
              const SizedBox(width: Gap.s),
              action('service-load', 'load', Icons.phone_android_rounded),
              if (scope.canManageStock) ...[
                const SizedBox(width: Gap.s),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('service-float'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 78),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                      backgroundColor: scheme.surface,
                      side: BorderSide(color: scheme.outlineVariant),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gap.radiusM)),
                    ),
                    onPressed: () => _pickFloatMove(context, scope),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.account_balance_wallet_outlined, size: 22, color: scheme.primary),
                      const SizedBox(height: 5),
                      Text(
                        t.serviceMoveFloat,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.15, color: scheme.onSurface),
                      ),
                    ]),
                  ),
                ),
              ],
            ]),
          ),
          StreamBuilder<List<WalletFloatView>>(
            stream: scope.store.watchWalletFloat(),
            builder: (context, snap) {
              final floats = snap.data ?? const <WalletFloatView>[];
              if (floats.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(Gap.l, Gap.m, Gap.l, Gap.xs),
                child: AppCard(
                  padding: const EdgeInsets.all(Gap.l),
                  radius: Gap.radiusL,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.servicesFloat, style: TextStyle(fontSize: 12, color: scheme.outline, fontWeight: FontWeight.w700)),
                    const SizedBox(height: Gap.s),
                    for (final f in floats)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          Expanded(child: Text(walletLabel(t, f.wallet), style: const TextStyle(fontSize: 15))),
                          if (f.negative)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(t.servicesNeedsTopup, style: TextStyle(color: scheme.error, fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                          Text(money(f.balance),
                              key: Key('float-${f.wallet}'),
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: f.negative ? scheme.error : scheme.onSurface)),
                        ]),
                      ),
                  ]),
                ),
              );
            },
          ),
          StreamBuilder<List<ServiceTxnView>>(
            stream: scope.store.watchServiceTxns(from: from, to: from.add(const Duration(days: 1))),
            builder: (context, snap) {
              final list = snap.data ?? const <ServiceTxnView>[];
              if (list.isEmpty) return EmptyState(icon: Icons.swap_horiz_rounded, text: t.servicesNone);
              return Column(children: [
                for (final e in list)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.xs),
                    child: AppCard(
                      key: Key('service-${e.id}'),
                      padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.m),
                      radius: Gap.radiusL,
                      onTap: e.voided || !scope.canManageStock
                          ? null
                          : needsApproval(e.rejectedHint)
                              ? () => retryWithApproval(context, backend, e.id)
                              : () => _confirmVoid(context, scope, e),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${serviceKindLabel(t, e.kind)} · ${walletLabel(t, e.wallet)}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            Text(
                              [
                                DateFormat.jm(locale).format(e.txnAt),
                                if (e.fee > 0) t.serviceEarned(money(e.fee)),
                                if (e.ref != null && e.ref!.isNotEmpty) e.ref!,
                                if (e.note != null && e.note!.isNotEmpty) e.note!,
                                if (e.voided) t.expenseCancelled,
                              ].join(' · '),
                              style: TextStyle(color: scheme.outline, fontSize: 13),
                            ),
                            if (needsApproval(e.rejectedHint))
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(t.serviceNeedsPin,
                                    key: Key('needs-pin-${e.id}'),
                                    style: TextStyle(color: scheme.error, fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                          ]),
                        ),
                        Text(
                          money(e.kind == 'load' ? (e.price ?? e.amount) : e.amount),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: e.voided ? scheme.outline : scheme.onSurface,
                            decoration: e.voided ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (e.pending) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.cloud_upload_outlined, size: 18, color: scheme.primary, semanticLabel: t.notSentYet),
                        ],
                      ]),
                    ),
                  ),
              ]);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickFloatMove(BuildContext context, CatalogScope scope) async {
    final t = AppLocalizations.of(context);
    final kind = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final k in ['float_topup', 'float_withdraw', 'float_adjust'])
            ListTile(key: Key('float-kind-$k'), title: Text(serviceKindLabel(t, k)), onTap: () => Navigator.pop(ctx, k)),
        ]),
      ),
    );
    if (kind != null && context.mounted) await showServiceDialog(context, scope, kind);
  }

  Future<void> _confirmVoid(BuildContext context, CatalogScope scope, ServiceTxnView e) async {
    final t = AppLocalizations.of(context);
    final reason = TextEditingController();
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.serviceVoidTitle),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.serviceVoidBody),
          const SizedBox(height: 12),
          TextField(key: const Key('service-void-reason'), controller: reason, decoration: InputDecoration(labelText: t.expenseVoidReason)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(key: const Key('service-void-yes'), onPressed: () => Navigator.pop(ctx, true), child: Text(t.serviceVoidYes)),
        ],
      ),
    );
    if (yes != true) return;
    await scope.store.voidServiceTxn(
      txnId: e.id,
      reason: reason.text.trim().isEmpty ? null : reason.text.trim(),
      opId: const Uuid().v7(),
    );
    scope.engine.poke();
  }
}

/// Entry form for one service kind (cash in/out, load, or a float move).
Future<void> showServiceDialog(BuildContext context, CatalogScope scope, String kind) async {
  final t = AppLocalizations.of(context);
  final ccy = scope.store.baseCurrency;
  final isLoad = kind == 'load';
  final isCash = kind == 'cash_in' || kind == 'cash_out';
  final isAdjust = kind == 'float_adjust';
  final wallets = isCash ? ['gcash', 'maya', 'other'] : serviceWallets;
  var wallet = isLoad ? 'load' : 'gcash';
  final amount = TextEditingController();
  final fee = TextEditingController();
  final price = TextEditingController();
  final ref = TextEditingController();
  final note = TextEditingController();
  String? amountError, feeError, priceError, noteError;

  int? parse(String text, {bool allowNegative = false}) {
    try {
      final v = Money.parse(text, ccy).amount;
      return (v < 0 && !allowNegative) ? null : v;
    } catch (_) {
      return null;
    }
  }

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(serviceKindLabel(t, kind)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (kind == 'cash_in' || kind == 'cash_out')
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(kind == 'cash_in' ? t.serviceCashInHint : t.serviceCashOutHint, style: const TextStyle(fontSize: 12)),
              ),
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final w in wallets)
                AppPillChip(
                  key: Key('wallet-$w'),
                  label: walletLabel(t, w),
                  selected: wallet == w,
                  onTap: () => setState(() => wallet = w),
                ),
            ]),
            const SizedBox(height: 12),
            TextField(
              key: const Key('service-amount'),
              controller: amount,
              autofocus: true,
              keyboardType: TextInputType.numberWithOptions(decimal: true, signed: isAdjust),
              style: const TextStyle(fontSize: 24),
              decoration: InputDecoration(
                labelText: isLoad ? t.serviceLoadAmount : t.serviceAmount,
                helperText: isAdjust ? t.serviceAdjustHint : null,
                errorText: amountError,
              ),
            ),
            if (isCash) ...[
              const SizedBox(height: 8),
              TextField(
                key: const Key('service-fee'),
                controller: fee,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: t.serviceFee, errorText: feeError),
              ),
            ],
            if (isLoad) ...[
              const SizedBox(height: 8),
              TextField(
                key: const Key('service-price'),
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: t.servicePrice, errorText: priceError),
              ),
            ],
            if (isCash || isLoad) ...[
              const SizedBox(height: 8),
              TextField(key: const Key('service-ref'), controller: ref, decoration: InputDecoration(labelText: t.serviceRef)),
            ],
            if (!isCash && !isLoad) ...[
              const SizedBox(height: 8),
              TextField(key: const Key('service-note'), controller: note, decoration: InputDecoration(labelText: t.serviceNote, errorText: noteError)),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(
            key: const Key('service-save'),
            onPressed: () {
              final a = parse(amount.text, allowNegative: isAdjust);
              final f = fee.text.trim().isEmpty ? 0 : parse(fee.text);
              final p = isLoad ? parse(price.text) : null;
              setState(() {
                amountError = (a == null || a == 0 || (!isAdjust && a < 0)) ? t.errBadAmount : null;
                feeError = (isCash && f == null) ? t.errBadAmount : null;
                priceError = isLoad
                    ? (p == null ? t.errBadAmount : (a != null && p < a ? t.servicePriceTooLow : null))
                    : null;
                noteError = (isAdjust && note.text.trim().isEmpty) ? t.serviceNoteRequired : null;
              });
              if (amountError == null && feeError == null && priceError == null && noteError == null) Navigator.pop(ctx, true);
            },
            child: Text(t.save),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return;
  await scope.store.recordServiceTxn(
    id: const Uuid().v7(),
    kind: kind,
    wallet: wallet,
    amount: Money.parse(amount.text, ccy).amount,
    fee: isCash && fee.text.trim().isNotEmpty ? Money.parse(fee.text, ccy).amount : 0,
    price: isLoad ? Money.parse(price.text, ccy).amount : null,
    ref: ref.text.trim().isEmpty ? null : ref.text.trim(),
    note: note.text.trim().isEmpty ? null : note.text.trim(),
    opId: const Uuid().v7(),
  );
  scope.engine.poke();
}
