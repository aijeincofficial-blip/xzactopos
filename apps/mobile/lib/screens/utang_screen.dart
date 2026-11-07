import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../core/money.dart';
import '../core/search.dart';
import '../data/sales_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import '../sync/sync_badge.dart';
import 'customer_picker.dart';

/// Who owes what. Biggest balance first; tap a customer for the history and to record a payment.
class UtangScreen extends StatefulWidget {
  const UtangScreen({super.key});

  @override
  State<UtangScreen> createState() => _UtangScreenState();
}

class _UtangScreenState extends State<UtangScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    String money(int a) => Money(a, scope.store.baseCurrency).format(locale);
    return Scaffold(
      appBar: AppBar(title: Text(t.utangTitle), actions: const [SyncBadge()]),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-customer'),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(t.customerNew),
        onPressed: () async {
          final made = await showNewCustomerDialog(context, scope.store);
          if (made != null) scope.engine.poke();
        },
      ),
      body: StreamBuilder<List<CustomerView>>(
        stream: scope.store.watchCustomers(),
        builder: (context, snap) {
          final all = snap.data;
          if (all == null) return const Center(child: CircularProgressIndicator());
          final owed = all.where((c) => c.balance > 0).fold<int>(0, (a, c) => a + c.balance);
          final list = _q.isEmpty ? all : all.where((c) => searchKey(c.name).contains(_q)).toList();
          return Column(children: [
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.secondaryContainer,
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.utangTotalOwed),
                Text(money(owed),
                    key: const Key('utang-total'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              ]),
            ),
            if (all.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: TextField(
                  key: const Key('utang-search'),
                  onChanged: (v) => setState(() => _q = searchKey(v)),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: t.customerSearch,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(all.isEmpty ? t.utangEmpty : t.noMatches, textAlign: TextAlign.center),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final c = list[i];
                        return ListTile(
                          key: Key('customer-row-${c.id}'),
                          minVerticalPadding: 14,
                          title: Text(c.name, style: const TextStyle(fontSize: 18)),
                          subtitle: c.phone == null ? null : Text(c.phone!),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (c.pending)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Icon(Icons.cloud_upload_outlined, size: 18, semanticLabel: t.notSentYet),
                              ),
                            Text(
                              c.balance == 0 ? t.utangSettled : money(c.balance),
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: c.balance > 0 ? Theme.of(context).colorScheme.error : null),
                            ),
                          ]),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => scope.wrap(CustomerScreen(customerId: c.id)),
                          )),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

class CustomerScreen extends StatelessWidget {
  const CustomerScreen({super.key, required this.customerId});
  final String customerId;

  Future<void> _recordPayment(BuildContext context, CustomerView c) async {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final ccy = scope.store.baseCurrency;
    final locale = Localizations.localeOf(context).languageCode;
    final amount = TextEditingController(text: c.balance > 0 ? Money(c.balance, ccy).toDecimalString() : '');
    final note = TextEditingController();
    String? error;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(t.utangPayTitle(c.name)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              key: const Key('utang-amount'),
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 24),
              decoration: InputDecoration(labelText: t.utangAmountPaid, errorText: error),
            ),
            TextField(
              key: const Key('utang-note'),
              controller: note,
              decoration: InputDecoration(labelText: t.utangNote),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
            FilledButton(
              key: const Key('utang-save'),
              onPressed: () {
                int? v;
                try {
                  v = Money.parse(amount.text, ccy).amount;
                } catch (_) {}
                if (v == null || v <= 0) {
                  setState(() => error = t.errBadAmount);
                } else if (v > c.balance) {
                  setState(() => error = t.utangTooMuch(Money(c.balance, ccy).format(locale)));
                } else {
                  Navigator.pop(ctx, true);
                }
              },
              child: Text(t.save),
            ),
          ],
        ),
      ),
    );
    if (result != true) return;
    await scope.store.recordUtangPayment(
      customerId: c.id,
      amount: Money.parse(amount.text, ccy).amount,
      note: note.text.trim().isEmpty ? null : note.text.trim(),
      opId: const Uuid().v7(),
    );
    scope.engine.poke();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    String money(int a) => Money(a, scope.store.baseCurrency).format(locale);
    return StreamBuilder<List<CustomerView>>(
      stream: scope.store.watchCustomers(),
      builder: (context, snap) {
        final c = (snap.data ?? const <CustomerView>[]).where((x) => x.id == customerId).firstOrNull;
        return Scaffold(
          appBar: AppBar(title: Text(c?.name ?? ''), actions: const [SyncBadge()]),
          bottomNavigationBar: c == null || c.balance <= 0
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton.icon(
                      key: const Key('record-payment'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), textStyle: const TextStyle(fontSize: 20)),
                      icon: const Icon(Icons.payments_outlined),
                      label: Text(t.utangPaid),
                      onPressed: () => _recordPayment(context, c),
                    ),
                  ),
                ),
          body: c == null
              ? const SizedBox.shrink()
              : Column(children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.balance > 0 ? t.utangOwes : t.utangSettled),
                      if (c.balance != 0)
                        Text(money(c.balance),
                            key: const Key('customer-balance'),
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
                      if (c.phone != null) Text(c.phone!),
                    ]),
                  ),
                  Expanded(
                    child: StreamBuilder<List<LedgerEntryView>>(
                      stream: scope.store.watchLedger(customerId),
                      builder: (context, hs) {
                        final h = hs.data ?? const <LedgerEntryView>[];
                        return ListView.separated(
                          itemCount: h.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final e = h[i];
                            final label = switch (e.kind) {
                              'charge' => t.ledgerCharge,
                              'payment' => t.ledgerPayment,
                              _ => e.note == 'void' ? t.ledgerVoid : t.ledgerAdjust,
                            };
                            final sub = [
                              DateFormat.yMMMd(locale).add_jm().format(e.at),
                              if (e.localNo != null) e.localNo!,
                              if (e.note != null && e.note != 'void') e.note!,
                            ].join(' · ');
                            return ListTile(
                              key: Key('ledger-$i'),
                              title: Text(label),
                              subtitle: Text(sub),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                if (e.pending)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Icon(Icons.cloud_upload_outlined, size: 18, semanticLabel: t.notSentYet),
                                  ),
                                Text(
                                  e.amount > 0 ? '+${money(e.amount)}' : '−${money(-e.amount)}',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: e.amount > 0 ? Theme.of(context).colorScheme.error : Colors.green.shade700),
                                ),
                              ]),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ]),
        );
      },
    );
  }
}
