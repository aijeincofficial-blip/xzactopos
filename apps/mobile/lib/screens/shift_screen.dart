import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../backend.dart';
import '../core/export.dart';
import '../core/money.dart';
import '../core/shift_printer.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/shift_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import 'denomination_sheet.dart';
import '../sync/sync_badge.dart';

/// The text of a shift slip for sharing (an X reading while the shift is open, the Z report once closed).
String shiftSlipText(AppLocalizations t, String store, String ccy, String locale, ShiftView s, XReading? x) {
  String money(int a) => Money(a, ccy).format(locale);
  String when(DateTime d) => DateFormat.yMMMd(locale).add_jm().format(d);
  final b = StringBuffer()
    ..writeln(store)
    ..writeln(s.isOpen ? t.shiftTitle : t.shiftZTitle)
    ..writeln(t.shiftOpenedLine(when(s.openedAt)));
  if (s.closedAt != null) b.writeln(t.shiftClosedLine(when(s.closedAt!)));
  b.writeln('${t.shiftOpeningLabel}: ${money(s.openingCash)}');
  if (x != null) {
    b
      ..writeln('${t.shiftCashSales}: ${money(x.cashSales)}')
      ..writeln('${t.shiftUtangTaken}: ${money(x.utangCash)}')
      ..writeln('${t.shiftPaidOut}: ${money(x.expensesCash)}')
      ..writeln('${t.shiftLoadCash}: ${money(x.serviceCash)}')
      ..writeln(t.shiftSalesLine(x.salesCount, money(x.grossSales)))
      ..writeln(t.shiftOtherTenders(money(x.ewalletSales), money(x.utangSales)));
  }
  if (s.isOpen) {
    if (x != null) b.writeln('${t.dayCloseExpected}: ${money(x.expected)}');
  } else {
    b
      ..writeln('${t.dayCloseExpected}: ${money(s.expectedCash ?? 0)}')
      ..writeln('${t.dayCloseCounted}: ${money(s.countedCash ?? 0)}');
    final d = s.difference ?? 0;
    b.writeln(d == 0 ? t.dayCloseExact : (d < 0 ? t.dayCloseShort(money(-d)) : t.dayCloseOver(money(d))));
    if (s.note != null && s.note!.isNotEmpty) b.writeln(s.note);
    if (s.serverDisagrees) b.writeln(t.shiftServerDiffers(money(s.serverExpectedCash!)));
  }
  return b.toString().trimRight();
}

/// A cashier's shift: start it with the cash in the drawer, read it any time (X), close it with the cash counted (Z).
class ShiftScreen extends StatefulWidget {
  const ShiftScreen({super.key, required this.backend, required this.storeName});
  final Backend backend;
  final String storeName;

  @override
  State<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends State<ShiftScreen> {
  final _opening = TextEditingController();
  bool _openingLoaded = false;
  String? _error;
  bool _busy = false;

  String get _user => widget.backend.userId ?? '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_openingLoaded) {
      _openingLoaded = true;
      // start from what the last shift counted: that cash stayed in the drawer
      final store = CatalogScope.of(context).store;
      store.watchShifts(limit: 10).first.then((all) {
        final last = all.where((s) => !s.isOpen && s.cashierId == _user && s.countedCash != null).firstOrNull;
        if (last != null && mounted && _opening.text.isEmpty) {
          setState(() => _opening.text = Money(last.countedCash!, store.baseCurrency).toDecimalString());
        }
      });
    }
  }

  @override
  void dispose() {
    _opening.dispose();
    super.dispose();
  }

  int? _cents(String ccy) {
    final raw = _opening.text.trim();
    if (raw.isEmpty) return 0;
    try {
      final c = Money.parse(raw, ccy).amount;
      return c < 0 ? null : c;
    } catch (_) {
      return null;
    }
  }

  Future<void> _start() async {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final cents = _cents(scope.store.baseCurrency);
    if (cents == null) {
      setState(() => _error = t.shiftErrAmount);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await scope.store.startShift(id: const Uuid().v7(), cashierId: _user, openingCash: cents, opId: const Uuid().v7());
      scope.engine.poke();
    } on ShiftException catch (e) {
      if (mounted) setState(() => _error = e.code == 'shift_already_open' ? t.shiftErrAlreadyOpen : t.errGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openSlip(String id) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => CatalogScope.of(context).wrap(ShiftSlipScreen(shiftId: id, storeName: widget.storeName))),
      );

  Future<void> _close(ShiftView shift, XReading x) async {
    final scope = CatalogScope.of(context);
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _CloseSheet(scope: scope, backend: widget.backend, shift: shift, phoneExpected: x.expected),
      ),
    );
    if (id != null && mounted) _openSlip(id);
  }

  Future<void> _openCashDrop(ShiftView shift, XReading x) async {
    final scope = CatalogScope.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _CashDropSheet(
          scope: scope,
          storeName: widget.storeName,
          shift: shift,
          expectedCash: x.expected,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final ccy = scope.store.baseCurrency;
    String money(int a) => Money(a, ccy).format(locale);
    String when(DateTime d) => DateFormat.yMMMd(locale).add_jm().format(d);

    return Scaffold(
      appBar: AppBar(title: Text(t.shiftTitle), actions: const [SyncBadge()]),
      body: StreamBuilder<ShiftView?>(
        stream: scope.store.watchOpenShift(_user),
        builder: (context, snap) {
          final shift = snap.data;
          return ListView(padding: const EdgeInsets.only(bottom: Gap.xxl), children: [
            if (shift == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.s, Gap.xl, Gap.s),
                child: AppCard(
                  key: const Key('shift-none'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(t.shiftNoneOpen, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: Gap.xs),
                    Text(t.shiftNoneHelp, style: TextStyle(color: scheme.outline, fontSize: 13)),
                    const SizedBox(height: Gap.l),
                    TextField(
                      key: const Key('shift-opening'),
                      controller: _opening,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() => _error = null),
                      decoration: InputDecoration(labelText: t.shiftOpeningField, errorText: _error),
                    ),
                    const SizedBox(height: Gap.l),
                    FilledButton(key: const Key('shift-start'), onPressed: _busy ? null : _start, child: Text(t.shiftStart)),
                  ]),
                ),
              )
            else
              StreamBuilder<XReading?>(
                stream: scope.store.watchXReading(shift.id),
                builder: (context, xs) {
                  final x = xs.data;
                  if (x == null) return const SizedBox.shrink();
                  Widget line(String label, int amount, {Key? key}) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          Expanded(child: Text(label)),
                          Text(money(amount), key: key, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ]),
                      );
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SummaryCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.shiftOpenSince(DateFormat.jm(locale).format(shift.openedAt)).toUpperCase(),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scheme.outline, letterSpacing: 0.8)),
                        const SizedBox(height: Gap.s),
                        Text(t.dayCloseExpected, style: TextStyle(color: scheme.outline, fontSize: 13)),
                        Text(money(x.expected),
                            key: const Key('shift-expected'),
                            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
                        if (shift.pending)
                          Padding(
                            padding: const EdgeInsets.only(top: Gap.xs),
                            child: Icon(Icons.cloud_upload_outlined, size: 18, color: scheme.primary, semanticLabel: t.notSentYet),
                          ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.s),
                      child: AppCard(
                        child: Column(children: [
                          line(t.shiftOpeningLabel, x.openingCash, key: const Key('x-opening')),
                          line(t.shiftCashSales, x.cashSales, key: const Key('x-cash-sales')),
                          line(t.shiftUtangTaken, x.utangCash, key: const Key('x-utang')),
                          line(t.shiftPaidOut, x.expensesCash, key: const Key('x-paid-out')),
                          line(t.shiftLoadCash, x.serviceCash, key: const Key('x-service')),
                          const Divider(),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(t.shiftSalesLine(x.salesCount, money(x.grossSales)),
                                key: const Key('x-sales'), style: TextStyle(color: scheme.outline, fontSize: 13)),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(t.shiftOtherTenders(money(x.ewalletSales), money(x.utangSales)),
                                style: TextStyle(color: scheme.outline, fontSize: 13)),
                          ),
                          const SizedBox(height: Gap.s),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(t.shiftEstimateNote, style: TextStyle(color: scheme.outline, fontSize: 12)),
                          ),
                        ]),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        OutlinedButton.icon(
                          key: const Key('shift-cash-drop-btn'),
                          icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                          label: Text(t.shiftCashDrop),
                          onPressed: () => _openCashDrop(shift, x),
                        ),
                        const SizedBox(height: Gap.s),
                        FilledButton(key: const Key('shift-close'), onPressed: () => _close(shift, x), child: Text(t.shiftClose)),
                        const SizedBox(height: Gap.s),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton(
                              key: const Key('shift-share-x'),
                              onPressed: () => textSharer.shareText(shiftSlipText(t, widget.storeName, ccy, locale, shift, x)),
                              child: Text(t.shiftShareX),
                            ),
                          ),
                          if (shiftPrinter.available) ...[
                            const SizedBox(width: Gap.s),
                            IconButton.outlined(
                              key: const Key('shift-print-x'),
                              tooltip: t.shiftPrint,
                              icon: const Icon(Icons.print_outlined),
                              onPressed: () => shiftPrinter.printShift(
                                storeName: widget.storeName,
                                currency: ccy,
                                locale: locale,
                                shift: shift,
                                xReading: x,
                                t: t,
                              ),
                            ),
                            const SizedBox(width: Gap.xs),
                            IconButton.outlined(
                              key: const Key('shift-pdf-x'),
                              tooltip: t.shiftPrintPdf,
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              onPressed: () => shiftPrinter.shareShiftPdf(
                                storeName: widget.storeName,
                                currency: ccy,
                                locale: locale,
                                shift: shift,
                                xReading: x,
                                t: t,
                              ),
                            ),
                          ],
                        ]),
                      ]),
                    ),
                  ]);
                },
              ),
            StreamBuilder<List<ShiftView>>(
              stream: scope.store.watchShifts(),
              builder: (context, hs) {
                // a cashier sees their own shifts only (the phone may hold someone else's from a shared till); the owner and admins see all
                final all = scope.isAdminOrSuperadmin;
                final shifts = hs.data ?? const <ShiftView>[];
                final otherOpen = [for (final s in shifts) if (s.isOpen && s.cashierId != _user && all) s];
                final list = [for (final s in shifts) if (!s.isOpen && (all || s.cashierId == _user)) s];

                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (otherOpen.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.l, Gap.xl, Gap.s),
                      child: Text(t.shiftOtherOpen, key: const Key('shift-other-open-header'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                    for (final s in otherOpen)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.xs),
                        child: AppCard(
                          key: Key('shift-open-card-${s.id}'),
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(t.shiftCashierLabel(s.cashierId?.substring(0, 8) ?? '...'), style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(
                                  '${t.shiftOpenedLine(when(s.openedAt))} · ${money(s.openingCash)}',
                                  style: TextStyle(color: scheme.outline, fontSize: 13),
                                ),
                              ]),
                            ),
                            FilledButton.tonal(
                              key: Key('shift-supervisor-close-${s.id}'),
                              onPressed: () async {
                                final x = await scope.store.watchXReading(s.id).first;
                                if (x != null && mounted) {
                                  await _close(s, x);
                                }
                              },
                              child: Text(t.shiftClose),
                            ),
                          ]),
                        ),
                      ),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xl, Gap.xl, Gap.s),
                    child: Text(t.shiftHistory, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
                      child: Text(t.shiftNoHistory, key: const Key('shift-no-history'), style: TextStyle(color: scheme.outline)),
                    )
                  else
                    Column(children: [
                      for (final s in list)
                        ListTile(
                          key: Key('shift-row-${s.id}'),
                          title: Text(DateFormat.yMMMd(locale).add_jm().format(s.openedAt)),
                          subtitle: Text('${t.dayCloseCounted}: ${money(s.countedCash ?? 0)}'),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (s.pending) Icon(Icons.cloud_upload_outlined, size: 18, color: scheme.primary, semanticLabel: t.notSentYet),
                            const SizedBox(width: Gap.s),
                            Text(
                              (s.difference ?? 0) == 0 ? '0' : ((s.difference ?? 0) > 0 ? '+' : '') + money(s.difference ?? 0),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: (s.difference ?? 0) == 0 ? scheme.success : ((s.difference ?? 0) < 0 ? scheme.error : scheme.payUtang),
                              ),
                            ),
                          ]),
                          onTap: () => _openSlip(s.id),
                        ),
                    ]),
                ]);
              },
            ),
          ]);
        },
      ),
    );
  }
}

/// Count the drawer and close the shift. While online it shows the server's own expected cash; offline, the phone's.
class _CloseSheet extends StatefulWidget {
  const _CloseSheet({required this.scope, required this.backend, required this.shift, required this.phoneExpected});
  final CatalogScope scope;
  final Backend backend;
  final ShiftView shift;
  final int phoneExpected;

  @override
  State<_CloseSheet> createState() => _CloseSheetState();
}

class _CloseSheetState extends State<_CloseSheet> {
  final _counted = TextEditingController();
  final _note = TextEditingController();
  int? _server;
  bool _checking = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _askServer();
  }

  Future<void> _askServer() async {
    final api = widget.backend;
    // a shift the server has not heard of yet (still unsent) has nothing to ask about
    if (api is ShiftApi && !widget.shift.pending) {
      final v = await (api as ShiftApi).shiftExpectedNow(widget.shift.id);
      if (mounted) setState(() => _server = v);
    }
    if (mounted) setState(() => _checking = false);
  }

  @override
  void dispose() {
    _counted.dispose();
    _note.dispose();
    super.dispose();
  }

  int get _expected => _server ?? widget.phoneExpected;

  int? _parse(String ccy) {
    final raw = _counted.text.trim();
    if (raw.isEmpty) return null;
    try {
      final c = Money.parse(raw, ccy).amount;
      return c < 0 ? null : c;
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final store = widget.scope.store;
    final counted = _parse(store.baseCurrency);
    if (counted == null) {
      setState(() => _error = t.shiftErrAmount);
      return;
    }
    final nav = Navigator.of(context);
    await store.closeShift(
      id: widget.shift.id,
      countedCash: counted,
      expectedCash: _expected,
      note: _note.text,
      opId: const Uuid().v7(),
    );
    widget.scope.engine.poke();
    nav.pop(widget.shift.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final ccy = widget.scope.store.baseCurrency;
    String money(int a) => Money(a, ccy).format(locale);
    final counted = _parse(ccy);
    final diff = counted == null ? null : counted - _expected;
    String diffText(int d) => d == 0 ? t.dayCloseExact : (d < 0 ? t.dayCloseShort(money(-d)) : t.dayCloseOver(money(d)));
    Color diffColor(int d) => d == 0 ? scheme.success : (d < 0 ? scheme.error : scheme.payUtang);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(t.shiftCloseAsk, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Gap.m),
          Text(t.dayCloseExpected, style: TextStyle(color: scheme.outline, fontSize: 13)),
          Text(money(_expected), key: const Key('close-sheet-expected'), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
          Text(_checking ? t.shiftChecking : (_server != null ? t.shiftServerFigure : t.shiftPhoneFigure),
              key: const Key('close-sheet-source'), style: TextStyle(color: scheme.outline, fontSize: 12)),
          const SizedBox(height: Gap.l),
          TextField(
            key: const Key('close-sheet-counted'),
            controller: _counted,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() => _error = null),
            style: const TextStyle(fontSize: 24),
            decoration: InputDecoration(
              labelText: t.dayCloseCounted,
              errorText: _error,
              suffixIcon: IconButton(
                key: const Key('shift-denomination-btn'),
                tooltip: t.denominationCalculator,
                icon: const Icon(Icons.calculate_outlined),
                onPressed: () => showDenominationSheet(
                  context,
                  currency: ccy,
                  onApply: (total) {
                    setState(() {
                      _counted.text = total.toStringAsFixed(2);
                      _error = null;
                    });
                  },
                ),
              ),
            ),
          ),
          if (diff != null)
            Padding(
              padding: const EdgeInsets.only(top: Gap.m),
              child: Text(diffText(diff),
                  key: const Key('close-sheet-diff'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: diffColor(diff))),
            ),
          const SizedBox(height: Gap.m),
          TextField(key: const Key('close-sheet-note'), controller: _note, decoration: InputDecoration(labelText: t.dayCloseNote)),
          const SizedBox(height: Gap.l),
          FilledButton(key: const Key('close-sheet-confirm'), onPressed: _checking ? null : _save, child: Text(t.shiftConfirmClose)),
        ]),
      ),
    );
  }
}

/// The report of one shift: the Z report once it is closed (it can be shared and opened again from the history).
class ShiftSlipScreen extends StatelessWidget {
  const ShiftSlipScreen({super.key, required this.shiftId, required this.storeName});
  final String shiftId;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final ccy = scope.store.baseCurrency;
    String money(int a) => Money(a, ccy).format(locale);
    String when(DateTime d) => DateFormat.yMMMd(locale).add_jm().format(d);

    return Scaffold(
      appBar: AppBar(title: Text(t.shiftZTitle), actions: const [SyncBadge()]),
      body: StreamBuilder<ShiftView?>(
        stream: scope.store.watchShifts(limit: 200).map((l) => l.where((s) => s.id == shiftId).firstOrNull),
        builder: (context, snap) {
          final s = snap.data;
          if (s == null) return const SizedBox.shrink();
          final d = s.difference ?? 0;
          String diffText() => d == 0 ? t.dayCloseExact : (d < 0 ? t.dayCloseShort(money(-d)) : t.dayCloseOver(money(d)));
          Color diffColor() => d == 0 ? scheme.success : (d < 0 ? scheme.error : scheme.payUtang);
          Widget line(String label, String value, {Key? key}) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [Expanded(child: Text(label)), Text(value, key: key, style: const TextStyle(fontWeight: FontWeight.w700))]),
              );
          return ListView(padding: const EdgeInsets.all(Gap.xl), children: [
            AppCard(
              key: const Key('z-slip'),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(storeName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: Gap.xs),
                Text(t.shiftOpenedLine(when(s.openedAt)), style: TextStyle(color: scheme.outline, fontSize: 13)),
                if (s.closedAt != null) Text(t.shiftClosedLine(when(s.closedAt!)), style: TextStyle(color: scheme.outline, fontSize: 13)),
                const Divider(height: Gap.xl),
                line(t.shiftOpeningLabel, money(s.openingCash)),
                line(t.dayCloseExpected, money(s.expectedCash ?? 0), key: const Key('z-expected')),
                line(t.dayCloseCounted, money(s.countedCash ?? 0), key: const Key('z-counted')),
                const SizedBox(height: Gap.s),
                Text(diffText(), key: const Key('z-diff'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: diffColor())),
                if (s.note != null && s.note!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: Gap.s), child: Text(s.note!)),
                if (s.serverDisagrees)
                  Padding(
                    padding: const EdgeInsets.only(top: Gap.m),
                    child: Text(t.shiftServerDiffers(money(s.serverExpectedCash!)),
                        key: const Key('z-server-differs'), style: TextStyle(color: scheme.error, fontSize: 13)),
                  ),
                if (s.pending)
                  Padding(
                    padding: const EdgeInsets.only(top: Gap.s),
                    child: Icon(Icons.cloud_upload_outlined, size: 18, color: scheme.primary, semanticLabel: t.notSentYet),
                  ),
              ]),
            ),
            const SizedBox(height: Gap.l),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('z-share'),
                  onPressed: () => textSharer.shareText(shiftSlipText(t, storeName, ccy, locale, s, null)),
                  child: Text(t.shiftShareX),
                ),
              ),
              if (shiftPrinter.available) ...[
                const SizedBox(width: Gap.s),
                IconButton.outlined(
                  key: const Key('z-print'),
                  tooltip: t.shiftPrint,
                  icon: const Icon(Icons.print_outlined),
                  onPressed: () => shiftPrinter.printShift(
                    storeName: storeName,
                    currency: ccy,
                    locale: locale,
                    shift: s,
                    xReading: null,
                    t: t,
                  ),
                ),
                const SizedBox(width: Gap.xs),
                IconButton.outlined(
                  key: const Key('z-pdf'),
                  tooltip: t.shiftPrintPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  onPressed: () => shiftPrinter.shareShiftPdf(
                    storeName: storeName,
                    currency: ccy,
                    locale: locale,
                    shift: s,
                    xReading: null,
                    t: t,
                  ),
                ),
              ],
            ]),
          ]);
        },
      ),
    );
  }
}

class _CashDropSheet extends StatefulWidget {
  const _CashDropSheet({
    required this.scope,
    required this.storeName,
    required this.shift,
    required this.expectedCash,
  });

  final CatalogScope scope;
  final String storeName;
  final ShiftView shift;
  final int expectedCash;

  @override
  State<_CashDropSheet> createState() => _CashDropSheetState();
}

class _CashDropSheetState extends State<_CashDropSheet> {
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  int? _cents(String ccy) {
    final raw = _amount.text.trim();
    if (raw.isEmpty) return null;
    try {
      final c = Money.parse(raw, ccy).amount;
      return c <= 0 ? null : c;
    } catch (_) {
      return null;
    }
  }

  void _setPresetReason(String reason) {
    setState(() => _reason.text = reason);
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    final ccy = widget.scope.store.baseCurrency;
    final cents = _cents(ccy);
    if (cents == null) {
      setState(() => _error = t.shiftCashDropErrAmount);
      return;
    }
    if (cents > widget.expectedCash && widget.expectedCash > 0) {
      setState(() => _error = t.shiftCashDropErrExceeds);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final noteText = _reason.text.trim().isNotEmpty
          ? '${t.shiftCashDrop}: ${_reason.text.trim()}'
          : t.shiftCashDrop;
      await widget.scope.store.recordExpense(
        id: const Uuid().v7(),
        amount: cents,
        category: 'other',
        paidFrom: 'cash',
        note: noteText,
        opId: const Uuid().v7(),
      );
      widget.scope.engine.poke();

      if (!mounted) return;
      final locale = Localizations.localeOf(context).languageCode;
      final amountFormatted = Money(cents, ccy).format(locale);
      final dateStr = DateFormat.yMMMd(locale).add_jm().format(DateTime.now());

      final slipText = '''
================================
     ${t.shiftCashDropSlipTitle}
================================
Store: ${widget.storeName}
Date: $dateStr
Shift Cashier: ${widget.shift.cashierId}
Amount: $amountFormatted
Reason: $noteText

--------------------------------
${t.shiftCashDropSlipCashier}: _________________
${t.shiftCashDropSlipWitness}: _________________
================================
''';

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.shiftCashDropSuccess(amountFormatted)),
          action: SnackBarAction(
            label: t.shiftCashDropShare,
            onPressed: () => textSharer.shareText(slipText),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final ccy = widget.scope.store.baseCurrency;
    final locale = Localizations.localeOf(context).languageCode;
    final expectedFmt = Money(widget.expectedCash, ccy).format(locale);

    return Padding(
      padding: const EdgeInsets.all(Gap.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CoinBadge(
                icon: Icons.arrow_downward_rounded,
                color: Colors.amber.shade700,
                size: 36,
              ),
              const SizedBox(width: Gap.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.shiftCashDrop,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    Text(
                      t.shiftCashDropSubtitle,
                      style: TextStyle(fontSize: 12, color: scheme.outline),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: Gap.m),

          // Drawer Expected info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: Gap.s),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    t.dayCloseExpected,
                    style: TextStyle(fontSize: 12, color: scheme.outline, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: Gap.s),
                Text(
                  expectedFmt,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.m),

          // Amount input
          TextField(
            key: const Key('cash-drop-amount'),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: t.shiftCashDropAmount,
              hintText: t.shiftCashDropAmountHint,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: Gap.s),

          // Preset Chips
          Wrap(
            spacing: Gap.s,
            children: [
              ActionChip(
                key: const Key('cash-drop-chip-safe'),
                label: Text(t.shiftCashDropChipSafe),
                onPressed: () => _setPresetReason(t.shiftCashDropChipSafe),
              ),
              ActionChip(
                key: const Key('cash-drop-chip-bank'),
                label: Text(t.shiftCashDropChipBank),
                onPressed: () => _setPresetReason(t.shiftCashDropChipBank),
              ),
              ActionChip(
                key: const Key('cash-drop-chip-skim'),
                label: Text(t.shiftCashDropChipSkim),
                onPressed: () => _setPresetReason(t.shiftCashDropChipSkim),
              ),
            ],
          ),
          const SizedBox(height: Gap.s),

          // Reason note
          TextField(
            key: const Key('cash-drop-note'),
            controller: _reason,
            decoration: InputDecoration(
              labelText: t.shiftCashDropReason,
              hintText: t.shiftCashDropReasonHint,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: Gap.s),
            Text(
              _error!,
              key: const Key('cash-drop-error'),
              style: TextStyle(color: scheme.error, fontSize: 13),
            ),
          ],

          const SizedBox(height: Gap.l),
          FilledButton(
            key: const Key('cash-drop-confirm-btn'),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(t.shiftCashDropConfirm),
          ),
        ],
      ),
    );
  }
}
