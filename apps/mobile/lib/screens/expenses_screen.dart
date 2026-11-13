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
import 'services_screen.dart' show walletLabel;
import 'supervisor_pin.dart';

/// Money spent today (stock, electricity, fare...). Add one, or cancel one that was a mistake.
class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key, required this.backend});
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

    return Scaffold(
      appBar: AppBar(
        title: Text(t.expensesTitle),
        actions: const [SyncBadge()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('expense-add'),
        icon: const Icon(Icons.add_rounded),
        label: Text(t.expenseAdd),
        onPressed: () => showAddExpenseDialog(context, scope),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          StreamBuilder<ExpenseTotals>(
            stream: scope.store.watchTodayExpenses(),
            builder: (context, snap) {
              final d = snap.data ?? const ExpenseTotals();
              return SummaryCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          t.expensesSpentToday.toUpperCase(),
                          style: NightMarketText.eyebrow(context),
                        ),
                        Text(
                          t.expensesCount(d.count),
                          key: const Key('expenses-count'),
                          style: NightMarketText.mono(context, size: 12, weight: FontWeight.w500, color: scheme.outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.s),
                    Text(
                      money(d.total),
                      key: const Key('expenses-total'),
                      style: NightMarketText.mono(context, size: 32, weight: FontWeight.w600, letterSpacing: -1.0),
                    ),
                    const SizedBox(height: Gap.s),
                    Text(
                      '${t.expensePaidCash}: ${money(d.cash)}  ·  ${t.expensePaidEwallet}: ${money(d.ewallet)}',
                      style: NightMarketText.mono(context, size: 13, weight: FontWeight.w500, color: scheme.outline),
                    ),
                  ],
                ),
              );
            },
          ),
          StreamBuilder<List<ExpenseView>>(
            stream: scope.store.watchExpenses(
              from: from,
              to: from.add(const Duration(days: 1)),
            ),
            builder: (context, snap) {
              final list = snap.data ?? const <ExpenseView>[];
              if (list.isEmpty) {
                return EmptyState(icon: Icons.receipt_long_rounded, text: t.expensesNone);
              }
              return Column(
                children: [
                  for (final e in list)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Gap.l,
                        vertical: 4,
                      ),
                      child: AppCard(
                        key: Key('expense-${e.id}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: Gap.l,
                          vertical: 12,
                        ),
                        radius: Gap.radiusL,
                        onTap: e.voided
                            ? null
                            : needsApproval(e.rejectedHint)
                            ? () => retryWithApproval(context, backend, e.id)
                            : () => _confirmVoid(context, scope, e),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    expenseCategoryLabel(t, e.category),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    [
                                      DateFormat.jm(locale).format(e.spentAt),
                                      e.paidFrom == 'ewallet'
                                          ? t.expensePaidEwallet
                                          : t.expensePaidCash,
                                      if (e.note != null && e.note!.isNotEmpty)
                                        e.note!,
                                      if (e.voided) t.expenseCancelled,
                                    ].join(' · '),
                                    style: TextStyle(
                                      color: scheme.outline,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (needsApproval(e.rejectedHint))
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        t.expenseNeedsPin,
                                        key: Key('needs-pin-${e.id}'),
                                        style: TextStyle(
                                          color: scheme.error,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              money(e.amount),
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: e.voided
                                    ? scheme.outline
                                    : scheme.onSurface,
                                decoration: e.voided
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            if (e.pending) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 18,
                                color: scheme.primary,
                                semanticLabel: t.notSentYet,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmVoid(
    BuildContext context,
    CatalogScope scope,
    ExpenseView e,
  ) async {
    final t = AppLocalizations.of(context);
    final reason = TextEditingController();
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.expenseVoidTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.expenseVoidBody),
            const SizedBox(height: 12),
            TextField(
              key: const Key('expense-void-reason'),
              controller: reason,
              decoration: InputDecoration(labelText: t.expenseVoidReason),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            key: const Key('expense-void-yes'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.expenseVoidYes),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await scope.store.voidExpense(
      expenseId: e.id,
      reason: reason.text.trim().isEmpty ? null : reason.text.trim(),
      opId: const Uuid().v7(),
    );
    scope.engine.poke();
  }
}

Future<void> showAddExpenseDialog(
  BuildContext context,
  CatalogScope scope,
) async {
  final t = AppLocalizations.of(context);
  final ccy = scope.store.baseCurrency;
  final amount = TextEditingController();
  final note = TextEditingController();
  var category = 'stock_purchase';
  var paidFrom = 'cash';
  var wallet = 'gcash';
  String? amountError;
  // a bottom sheet: it keeps its room when the keyboard is open (a dialog got cramped there)
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.l, Gap.xl, Gap.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.expenseAdd, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                key: const Key('expense-amount'),
                controller: amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(fontSize: 24),
                decoration: InputDecoration(
                  labelText: t.expenseAmount,
                  errorText: amountError,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final c in expenseCategories)
                    AppPillChip(
                      key: Key('expense-cat-$c'),
                      label: expenseCategoryLabel(t, c),
                      selected: category == c,
                      onTap: () => setState(() => category = c),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(t.expensePaidFrom, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              SegmentedPillBar<String>(
                key: const Key('expense-paid-from'),
                items: [
                  SegmentedPillItem(value: 'cash', label: t.expensePaidCash, icon: Icons.payments_outlined),
                  SegmentedPillItem(value: 'ewallet', label: t.expensePaidEwallet, icon: Icons.account_balance_wallet_outlined),
                ],
                selected: paidFrom,
                onChanged: (val) => setState(() => paidFrom = val),
              ),
              if (paidFrom == 'ewallet') ...[
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, children: [
                for (final w in paymentWallets)
                  AppPillChip(
                    key: Key('expense-wallet-$w'),
                    label: walletLabel(t, w),
                    selected: wallet == w,
                    onTap: () => setState(() => wallet = w),
                  ),
              ]),
              ],
              const SizedBox(height: 12),
              TextField(
                key: const Key('expense-note'),
                controller: note,
                decoration: InputDecoration(labelText: t.expenseNote),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(t.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      key: const Key('expense-save'),
                      onPressed: () {
                        int? cents;
                        try {
                          cents = Money.parse(amount.text, ccy).amount;
                        } catch (_) {
                          cents = null;
                        }
                        setState(
                          () => amountError = (cents == null || cents <= 0)
                              ? t.errBadAmount
                              : null,
                        );
                        if (amountError == null) Navigator.pop(ctx, true);
                      },
                      child: Text(t.save),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (ok != true) return;
  await scope.store.recordExpense(
    id: const Uuid().v7(),
    amount: Money.parse(amount.text, ccy).amount,
    category: category,
    paidFrom: paidFrom,
    wallet: paidFrom == 'ewallet' ? wallet : null,
    note: note.text.trim().isEmpty ? null : note.text.trim(),
    opId: const Uuid().v7(),
  );
  scope.engine.poke();
}
