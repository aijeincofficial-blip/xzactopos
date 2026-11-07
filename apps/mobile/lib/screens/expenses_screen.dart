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
      appBar: AppBar(title: Text(t.expensesTitle), actions: const [SyncBadge()]),
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(t.expensesSpentToday.toUpperCase(),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scheme.outline, letterSpacing: 0.8)),
                    Text(t.expensesCount(d.count), key: const Key('expenses-count'), style: TextStyle(color: scheme.outline, fontSize: 12)),
                  ]),
                  const SizedBox(height: Gap.s),
                  Text(money(d.total),
                      key: const Key('expenses-total'),
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
                  const SizedBox(height: Gap.s),
                  Text('${t.expensePaidCash}: ${money(d.cash)}  ·  ${t.expensePaidEwallet}: ${money(d.ewallet)}',
                      style: TextStyle(color: scheme.outline, fontSize: 13)),
                ]),
              );
            },
          ),
          StreamBuilder<List<ExpenseView>>(
            stream: scope.store.watchExpenses(from: from, to: from.add(const Duration(days: 1))),
            builder: (context, snap) {
              final list = snap.data ?? const <ExpenseView>[];
              if (list.isEmpty) return EmptyState(icon: Icons.receipt_long_rounded, text: t.expensesNone);
              return Column(children: [
                for (final e in list)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.xs),
                    child: AppCard(
                      key: Key('expense-${e.id}'),
                      padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.m),
                      radius: Gap.radiusL,
                      onTap: e.voided
                          ? null
                          : needsApproval(e.rejectedHint)
                              ? () => retryWithApproval(context, backend, e.id)
                              : () => _confirmVoid(context, scope, e),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(expenseCategoryLabel(t, e.category),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            Text(
                              [
                                DateFormat.jm(locale).format(e.spentAt),
                                e.paidFrom == 'ewallet' ? t.expensePaidEwallet : t.expensePaidCash,
                                if (e.note != null && e.note!.isNotEmpty) e.note!,
                                if (e.voided) t.expenseCancelled,
                              ].join(' · '),
                              style: TextStyle(color: scheme.outline, fontSize: 13),
                            ),
                            if (needsApproval(e.rejectedHint))
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(t.expenseNeedsPin,
                                    key: Key('needs-pin-${e.id}'),
                                    style: TextStyle(color: scheme.error, fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                          ]),
                        ),
                        Text(
                          money(e.amount),
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

  Future<void> _confirmVoid(BuildContext context, CatalogScope scope, ExpenseView e) async {
    final t = AppLocalizations.of(context);
    final reason = TextEditingController();
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.expenseVoidTitle),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.expenseVoidBody),
          const SizedBox(height: 12),
          TextField(key: const Key('expense-void-reason'), controller: reason, decoration: InputDecoration(labelText: t.expenseVoidReason)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(key: const Key('expense-void-yes'), onPressed: () => Navigator.pop(ctx, true), child: Text(t.expenseVoidYes)),
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

Future<void> showAddExpenseDialog(BuildContext context, CatalogScope scope) async {
  final t = AppLocalizations.of(context);
  final ccy = scope.store.baseCurrency;
  final amount = TextEditingController();
  final note = TextEditingController();
  var category = 'stock_purchase';
  var paidFrom = 'cash';
  String? amountError;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(t.expenseAdd),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              key: const Key('expense-amount'),
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 24),
              decoration: InputDecoration(labelText: t.expenseAmount, errorText: amountError),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final c in expenseCategories)
                ChoiceChip(
                  key: Key('expense-cat-$c'),
                  label: Text(expenseCategoryLabel(t, c)),
                  selected: category == c,
                  onSelected: (_) => setState(() => category = c),
                ),
            ]),
            const SizedBox(height: 12),
            Text(t.expensePaidFrom, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            SegmentedButton<String>(
              key: const Key('expense-paid-from'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'cash', label: Text(t.expensePaidCash)),
                ButtonSegment(value: 'ewallet', label: Text(t.expensePaidEwallet)),
              ],
              selected: {paidFrom},
              onSelectionChanged: (s) => setState(() => paidFrom = s.first),
            ),
            const SizedBox(height: 12),
            TextField(key: const Key('expense-note'), controller: note, decoration: InputDecoration(labelText: t.expenseNote)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(
            key: const Key('expense-save'),
            onPressed: () {
              int? cents;
              try {
                cents = Money.parse(amount.text, ccy).amount;
              } catch (_) {
                cents = null;
              }
              setState(() => amountError = (cents == null || cents <= 0) ? t.errBadAmount : null);
              if (amountError == null) Navigator.pop(ctx, true);
            },
            child: Text(t.save),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return;
  await scope.store.recordExpense(
    id: const Uuid().v7(),
    amount: Money.parse(amount.text, ccy).amount,
    category: category,
    paidFrom: paidFrom,
    note: note.text.trim().isEmpty ? null : note.text.trim(),
    opId: const Uuid().v7(),
  );
  scope.engine.poke();
}
