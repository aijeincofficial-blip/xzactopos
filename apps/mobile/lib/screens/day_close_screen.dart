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

/// End of day: count the drawer, see what is short or over. Saved as a record (a recount adds another).
class DayCloseScreen extends StatefulWidget {
  const DayCloseScreen({super.key, required this.backend});
  final Backend backend;

  @override
  State<DayCloseScreen> createState() => _DayCloseScreenState();
}

class _DayCloseScreenState extends State<DayCloseScreen> {
  final _counted = TextEditingController();
  final _note = TextEditingController();
  bool _recount = false;
  String? _error;

  @override
  void dispose() {
    _counted.dispose();
    _note.dispose();
    super.dispose();
  }

  int? _parse(String ccy) {
    try {
      final c = Money.parse(_counted.text, ccy).amount;
      return c < 0 ? null : c;
    } catch (_) {
      return null;
    }
  }

  Future<void> _save(CatalogScope scope, DateTime day) async {
    final t = AppLocalizations.of(context);
    final counted = _parse(scope.store.baseCurrency);
    if (counted == null) {
      setState(() => _error = t.errBadAmount);
      return;
    }
    setState(() {
      _error = null;
      _recount = false;
    });
    await scope.store.closeDay(
      id: const Uuid().v7(),
      day: day,
      countedCash: counted,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      opId: const Uuid().v7(),
    );
    scope.engine.poke();
    _counted.clear();
    _note.clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final ccy = scope.store.baseCurrency;
    String money(int a) => Money(a, ccy).format(locale);
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);

    String diffText(int d) => d == 0 ? t.dayCloseExact : (d < 0 ? t.dayCloseShort(money(-d)) : t.dayCloseOver(money(d)));
    Color diffColor(int d) => d == 0 ? scheme.success : (d < 0 ? scheme.error : scheme.payUtang);

    return Scaffold(
      appBar: AppBar(title: Text(t.dayCloseTitle), actions: const [SyncBadge()]),
      body: StreamBuilder<DayCloseView?>(
        stream: scope.store.watchLatestDayClose(day),
        builder: (context, closeSnap) {
          final last = closeSnap.data;
          return StreamBuilder<int>(
            stream: scope.store.watchExpectedCash(day),
            builder: (context, expSnap) {
              final expected = expSnap.data ?? 0;
              final counted = _parse(ccy);
              final diff = counted == null ? null : counted - expected;
              final showForm = last == null || _recount;
              return ListView(padding: const EdgeInsets.only(bottom: Gap.xxl), children: [
                SummaryCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.dayCloseExpected.toUpperCase(),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scheme.outline, letterSpacing: 0.8)),
                    const SizedBox(height: Gap.s),
                    Text(money(expected),
                        key: const Key('close-expected'),
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
                    const SizedBox(height: Gap.xs),
                    Text(t.dayCloseHelp, style: TextStyle(color: scheme.outline, fontSize: 12)),
                  ]),
                ),
                if (showForm)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.s),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      TextField(
                        key: const Key('close-counted'),
                        controller: _counted,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() => _error = null),
                        style: const TextStyle(fontSize: 24),
                        decoration: InputDecoration(labelText: t.dayCloseCounted, errorText: _error),
                      ),
                      if (diff != null)
                        Padding(
                          padding: const EdgeInsets.only(top: Gap.m),
                          child: Text(diffText(diff),
                              key: const Key('close-diff'),
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: diffColor(diff))),
                        ),
                      const SizedBox(height: Gap.m),
                      TextField(key: const Key('close-note'), controller: _note, decoration: InputDecoration(labelText: t.dayCloseNote)),
                      const SizedBox(height: Gap.l),
                      FilledButton(key: const Key('close-save'), onPressed: () => _save(scope, day), child: Text(t.dayCloseSave)),
                    ]),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.s),
                    child: AppCard(
                      key: const Key('close-saved'),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.dayCloseSaved, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: Gap.xs),
                        Text(diffText(last.difference),
                            key: const Key('close-saved-diff'),
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: diffColor(last.difference))),
                        const SizedBox(height: Gap.xs),
                        Text(t.dayCloseLast(money(last.countedCash), DateFormat.jm(locale).format(last.closedAt.toLocal())),
                            style: TextStyle(color: scheme.outline, fontSize: 13)),
                        if (last.note != null && last.note!.isNotEmpty)
                          Text(last.note!, style: TextStyle(color: scheme.outline, fontSize: 13)),
                        if (needsApproval(last.rejectedHint))
                          Padding(
                            padding: const EdgeInsets.only(top: Gap.s),
                            child: FilledButton.tonal(
                              key: const Key('close-needs-pin'),
                              onPressed: () => retryWithApproval(context, widget.backend, last.id),
                              child: Text(t.dayCloseNeedsPin),
                            ),
                          )
                        else if (last.pending)
                          Padding(
                            padding: const EdgeInsets.only(top: Gap.s),
                            child: Icon(Icons.cloud_upload_outlined, size: 18, color: scheme.primary, semanticLabel: t.notSentYet),
                          ),
                        const SizedBox(height: Gap.m),
                        OutlinedButton(
                          key: const Key('close-again'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                          onPressed: () => setState(() => _recount = true),
                          child: Text(t.dayCloseAgain),
                        ),
                      ]),
                    ),
                  ),
              ]);
            },
          );
        },
      ),
    );
  }
}
