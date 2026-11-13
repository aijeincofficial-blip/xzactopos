import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../core/export.dart';
import '../core/money.dart';
import '../core/utang_statement.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../core/search.dart';
import '../data/sales_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import '../sync/sync_badge.dart';
import 'customer_picker.dart';

/// Who owes what. Biggest balance first; tap a customer for the history and to record a payment.
class UtangScreen extends StatefulWidget {
  const UtangScreen({super.key, this.storeName = ''});
  final String storeName;

  @override
  State<UtangScreen> createState() => _UtangScreenState();
}

class _UtangScreenState extends State<UtangScreen> {
  String _q = '';
  bool _overdueOnly = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    String money(int a) => Money(a, scope.store.baseCurrency).format(locale);
    return Scaffold(
      appBar: AppBar(title: Text(t.utangTitle), actions: const [SyncBadge()]),
      // lifted above the glass tab bar (its height arrives as bottom padding; 0 when this screen is pushed on its own)
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: FloatingActionButton.extended(
          key: const Key('add-customer'),
          icon: const Icon(Icons.person_add_alt_1),
          label: Text(t.customerNew),
          onPressed: () async {
            final made = await showNewCustomerDialog(context, scope.store);
            if (made != null) scope.engine.poke();
          },
        ),
      ),
      body: StreamBuilder<List<CustomerView>>(
        stream: scope.store.watchCustomers(),
        builder: (context, snap) {
          final all = snap.data;
          if (all == null) return const Center(child: CircularProgressIndicator());
          final owed = all.where((c) => c.balance > 0).fold<int>(0, (a, c) => a + c.balance);
          final today = DateTime.now();
          final overdueCount = all.where((c) => c.overdue(today)).length;
          final byName = _q.isEmpty ? all : all.where((c) => searchKey(c.name).contains(_q)).toList();
          final list = _overdueOnly ? byName.where((c) => c.overdue(today)).toList() : byName;
          final scheme = Theme.of(context).colorScheme;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SummaryCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  t.utangTotalOwed.toUpperCase(),
                  style: NightMarketText.eyebrow(context),
                ),
                const SizedBox(height: 4),
                Text(
                  money(owed),
                  key: const Key('utang-total'),
                  style: NightMarketText.mono(context, size: 28, weight: FontWeight.w600, letterSpacing: -0.8),
                ),
              ]),
            ),
            if (all.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.l, Gap.xs, Gap.l, Gap.s),
                child: TextField(
                  key: const Key('utang-search'),
                  onChanged: (v) => setState(() => _q = searchKey(v)),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    hintText: t.customerSearch,
                  ),
                ),
              ),
            if (overdueCount > 0 || _overdueOnly)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.l),
                child: Row(children: [
                  ChoiceChip(
                    key: const Key('filter-utang-all'),
                    label: Text(t.stockAll),
                    selected: !_overdueOnly,
                    onSelected: (_) => setState(() => _overdueOnly = false),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    key: const Key('filter-utang-overdue'),
                    avatar: overdueCount > 0 ? const Icon(Icons.schedule_rounded, size: 16) : null,
                    label: Text(t.utangOverdueFilter(overdueCount)),
                    selected: _overdueOnly,
                    onSelected: (_) => setState(() => _overdueOnly = true),
                  ),
                ]),
              ),
            Expanded(
              child: list.isEmpty
                  ? EmptyState(
                      icon: all.isEmpty ? Icons.menu_book_outlined : Icons.search_off_rounded,
                      text: all.isEmpty ? t.utangEmpty : (_overdueOnly ? t.utangOverdueNone : t.noMatches),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(Gap.l, Gap.s, Gap.l, 88 + MediaQuery.paddingOf(context).bottom),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: Gap.s),
                      itemBuilder: (context, i) {
                        final c = list[i];
                        return AppCard(
                          key: Key('customer-row-${c.id}'),
                          padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: 8),
                          radius: Gap.radiusL,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => scope.wrap(CustomerScreen(customerId: c.id, storeName: widget.storeName)),
                          )),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: CoinBadge(icon: Icons.person_outline_rounded, color: scheme.primary, size: 36),
                            title: Text(c.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            subtitle: (c.phone == null && !c.overdue(today))
                                ? null
                                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    if (c.phone != null) Text(c.phone!, style: TextStyle(fontSize: 12.5, color: scheme.outline)),
                                    if (c.overdue(today))
                                      Text(
                                        t.utangOverdueDays(c.daysOverdue(today)),
                                        key: Key('overdue-${c.id}'),
                                        style: TextStyle(color: scheme.error, fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                  ]),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              if (c.pending)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(Icons.cloud_upload_outlined, size: 18, semanticLabel: t.notSentYet),
                                ),
                              Text(
                                c.balance == 0 ? t.utangSettled : money(c.balance),
                                style: c.balance > 0
                                    ? NightMarketText.mono(context, size: 15.5, weight: FontWeight.w600, color: scheme.error)
                                    : TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: scheme.outline,
                                      ),
                              ),
                            ]),
                          ),
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
  const CustomerScreen({super.key, required this.customerId, this.storeName = ''});
  final String customerId;
  final String storeName;

  Future<void> _setDue(BuildContext context, CustomerView c) async {
    final scope = CatalogScope.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: c.dueOn ?? today.add(const Duration(days: 7)),
      firstDate: today.subtract(const Duration(days: 60)),
      lastDate: today.add(const Duration(days: 700)),
    );
    if (picked == null) return;
    await scope.store.setUtangDue(customerId: c.id, dueOn: DateTime(picked.year, picked.month, picked.day), opId: const Uuid().v7());
    scope.engine.poke();
  }

  Future<void> _clearDue(BuildContext context, CustomerView c) async {
    final scope = CatalogScope.of(context);
    await scope.store.setUtangDue(customerId: c.id, dueOn: null, opId: const Uuid().v7());
    scope.engine.poke();
  }

  /// A plain-text statement (no phone number, no notes) through the system share sheet.
  Future<void> _sendStatement(BuildContext context, CustomerView c) async {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final ledger = await scope.store.watchLedger(c.id).first;
    final text = utangStatementText(
      storeName: storeName,
      customer: c,
      ledger: ledger,
      currency: scope.store.baseCurrency,
      locale: locale,
      labels: StatementLabels(
        title: t.stmtTitle,
        balance: t.stmtBalance,
        dueOn: t.stmtDueOn,
        recent: t.stmtRecent,
        charge: t.stmtCharge,
        payment: t.stmtPayment,
        adjust: t.stmtAdjust,
      ),
    );
    await textSharer.shareText(text);
  }

  Future<void> _recordPayment(BuildContext context, CustomerView c) async {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final ccy = scope.store.baseCurrency;
    final locale = Localizations.localeOf(context).languageCode;
    final amount = TextEditingController(text: c.balance > 0 ? Money(c.balance, ccy).toDecimalString() : '');
    final note = TextEditingController();
    String? error;
    var method = 'cash'; // how she paid: cash goes in the drawer, e-wallet does not
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(t.utangPayTitle(c.name)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SegmentedPillBar<String>(
              key: const Key('utang-method'),
              items: [
                SegmentedPillItem(value: 'cash', label: t.payCash, icon: Icons.payments_outlined),
                SegmentedPillItem(value: 'ewallet', label: t.payEwallet, icon: Icons.account_balance_wallet_outlined),
              ],
              selected: method,
              onChanged: (val) => setState(() => method = val),
            ),
            const SizedBox(height: 8),
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
      method: method,
      opId: const Uuid().v7(),
    );
    scope.engine.poke();
  }

  Future<void> _adjust(BuildContext context, CustomerView c) async {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ccy = scope.store.baseCurrency;
    final amount = TextEditingController();
    final note = TextEditingController();
    var less = true;
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(t.utangAdjustTitle(c.name)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 6, children: [
              AppPillChip(
                key: const Key('adjust-less'),
                label: t.utangWriteOff,
                selected: less,
                onTap: () => setState(() => less = true),
              ),
              AppPillChip(
                key: const Key('adjust-more'),
                label: t.utangAddMore,
                selected: !less,
                onTap: () => setState(() => less = false),
              ),
            ]),
            TextField(
              key: const Key('adjust-amount'),
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 24),
              decoration: InputDecoration(labelText: t.utangAdjustAmount, errorText: error),
            ),
            TextField(key: const Key('adjust-note'), controller: note, decoration: InputDecoration(labelText: t.utangNote)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
            FilledButton(
              key: const Key('adjust-save'),
              onPressed: () {
                int? v;
                try {
                  v = Money.parse(amount.text, ccy).amount;
                } catch (_) {}
                if (v == null || v <= 0) {
                  setState(() => error = t.errBadAmount);
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
    if (ok != true) return;
    final v = Money.parse(amount.text, ccy).amount;
    await scope.store.adjustUtang(
      customerId: c.id,
      amount: less ? -v : v,
      note: note.text.trim().isEmpty ? null : note.text.trim(),
      opId: const Uuid().v7(),
    );
    scope.engine.poke();
    messenger.showSnackBar(SnackBar(content: Text(t.utangAdjusted)));
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
                  SummaryCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        c.balance > 0 ? t.utangOwes : t.utangSettled,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.outline),
                      ),
                      const SizedBox(height: 4),
                      if (c.balance != 0)
                        Text(
                          money(c.balance),
                          key: const Key('customer-balance'),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                            color: c.balance > 0 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      if (c.phone != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(c.phone!, style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13)),
                        ),
                      if (c.balance > 0) ...[
                        const SizedBox(height: 6),
                        if (c.dueOn != null)
                          Text(
                            c.overdue(DateTime.now())
                                ? t.utangOverdueDays(c.daysOverdue(DateTime.now()))
                                : t.utangDueOn(DateFormat.yMMMd(locale).format(c.dueOn!)),
                            key: const Key('customer-due'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c.overdue(DateTime.now()) ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        Wrap(spacing: 8, children: [
                          TextButton(
                            key: const Key('set-due'),
                            onPressed: () => _setDue(context, c),
                            child: Text(c.dueOn == null ? t.utangDueSet : t.utangDueChange),
                          ),
                          if (c.dueOn != null)
                            TextButton(key: const Key('clear-due'), onPressed: () => _clearDue(context, c), child: Text(t.utangDueClear)),
                        ]),
                      ],
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              key: const Key('send-statement'),
                              icon: const Icon(Icons.ios_share_rounded, size: 17),
                              onPressed: () => _sendStatement(context, c),
                              label: Text(t.utangSendStatement),
                            ),
                            TextButton.icon(
                              key: const Key('export-ledger-csv'),
                              icon: const Icon(Icons.download_rounded, size: 17),
                              onPressed: () async {
                                final entries = await scope.store.watchLedger(c.id).first;
                                final safeName = c.name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
                                await csvSharer.share(
                                  fileName: 'utang-${safeName.isEmpty ? 'customer' : safeName}.csv',
                                  csv: utangLedgerCsv(entries, scope.store.baseCurrency),
                                );
                              },
                              label: Text(t.utangExportLedgerCsv),
                            ),
                            if (scope.canManageStock)
                              TextButton(
                                key: const Key('adjust-balance'),
                                onPressed: () => _adjust(context, c),
                                child: Text(t.utangAdjust),
                              ),
                          ],
                        ),
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
                              if (e.displayNo != null) e.displayNo!,
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
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: e.amount > 0 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.success),
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
