import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../backend.dart';
import '../core/camera_scanner.dart';
import '../core/theme.dart';
import '../data/count_models.dart';
import '../data/local_store.dart';
import '../data/warehouse_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import '../sync/sync_engine.dart' show AuthExpired;
import 'warehouse_receive.dart' show parseQty;

/// Why the server refused a count call, in words for the clerk.
String countErrorText(AppLocalizations t, String hint) => switch (hint) {
      'count_in_progress' => t.whCountErrInProgress,
      'bin_required' => t.whCountErrBinRequired,
      'bin_not_found' || 'bin_not_allowed' || 'bin_out_of_scope' => t.whCountErrBin,
      'bins_not_enabled' => t.whCountErrBinsOff,
      'qty_invalid' => t.whErrQtyInvalid,
      'nothing_counted' => t.whCountErrNothing,
      'not_allowed' || 'location_denied' => t.whCountErrNotAllowed,
      'invalid_state' => t.whCountErrClosed,
      'implausible_snapshot' => t.whCountErrSnapshot,
      _ => t.errGeneric,
    };

String _n(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// The Count tab: start a count of the warehouse (or one bin), count products by search or scan, finish or cancel.
class CountTab extends StatelessWidget {
  const CountTab({super.key, required this.backend});
  final Backend backend;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final store = CatalogScope.of(context).store;
    final api = backend is CountApi ? backend as CountApi : null;
    return StreamBuilder<WarehouseView?>(
      stream: store.watchActiveWarehouse(),
      builder: (context, snap) {
        final wh = snap.data;
        if (wh == null) return Center(child: Padding(padding: const EdgeInsets.all(Gap.xl), child: Text(t.whNoWarehouse, textAlign: TextAlign.center)));
        if (api == null) return Center(child: Text(t.whCountSoon, key: const Key('count-soon'), textAlign: TextAlign.center));
        return _CountBody(key: ValueKey(wh.id), warehouse: wh, api: api);
      },
    );
  }
}

class _CountBody extends StatefulWidget {
  const _CountBody({super.key, required this.warehouse, required this.api});
  final WarehouseView warehouse;
  final CountApi api;

  @override
  State<_CountBody> createState() => _CountBodyState();
}

enum _Load { loading, offline, ready }

class _CountBodyState extends State<_CountBody> {
  _Load _load = _Load.loading;
  CountSession? _session;
  Map<String, String> _names = {};
  List<BinView> _bins = [];
  String? _error;
  bool _busy = false;
  String _startId = const Uuid().v7();

  // starting
  String? _scopeBin;
  final _notes = TextEditingController();

  // counting
  final _search = TextEditingController();
  String _query = '';
  ProductView? _picked;
  final _qty = TextEditingController();
  final _qtyFocus = FocusNode();
  String? _lineBin;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _notes.dispose();
    _search.dispose();
    _qty.dispose();
    _qtyFocus.dispose();
    super.dispose();
  }

  /// Runs a server call: shows the server's reason for a refusal, "no connection" for no signal. Returns false when it failed.
  Future<bool> _run(Future<void> Function() call) async {
    final t = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await call();
      return true;
    } on CountException catch (e) {
      if (mounted) setState(() => _error = countErrorText(t, e.hint));
    } on CountOffline {
      if (mounted) setState(() => _error = t.whCountOffline);
    } on AuthExpired {
      if (mounted) setState(() => _error = t.whCountOffline);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return false;
  }

  Future<void> _refresh() async {
    final store = CatalogScope.of(context).store;
    setState(() {
      _load = _Load.loading;
      _error = null;
    });
    try {
      final session = await widget.api.openCount(widget.warehouse.id);
      final products = await store.watchProducts().first;
      final bins = widget.warehouse.binsEnabled ? await store.watchBins(widget.warehouse.id).first : const <BinView>[];
      if (!mounted) return;
      setState(() {
        _session = session;
        _names = {for (final p in products) p.variantId: p.name};
        _bins = bins;
        _load = _Load.ready;
      });
    } on CountOffline {
      await _tryLoadLocalCount(store);
    } on AuthExpired {
      await _tryLoadLocalCount(store);
    } on CountException {
      await _tryLoadLocalCount(store);
    }
  }

  Future<void> _tryLoadLocalCount(dynamic store) async {
    try {
      final localSession = await store.localOpenCount(widget.warehouse.id);
      if (localSession != null) {
        final products = await store.watchProducts().first;
        final bins = widget.warehouse.binsEnabled ? await store.watchBins(widget.warehouse.id).first : const <BinView>[];
        if (!mounted) return;
        setState(() {
          _session = localSession;
          _names = {for (final p in products) p.variantId: p.name};
          _bins = bins;
          _load = _Load.ready;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _load = _Load.offline);
  }

  Future<void> _startOffline() async {
    final store = CatalogScope.of(context).store;
    final products = await store.watchProducts().first;
    final bins = widget.warehouse.binsEnabled ? await store.watchBins(widget.warehouse.id).first : const <BinView>[];
    final session = await store.startOfflineCount(
      id: _startId,
      warehouseId: widget.warehouse.id,
      binId: _scopeBin,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    if (!mounted) return;
    _startId = const Uuid().v7();
    _notes.clear();
    setState(() {
      _session = session;
      _names = {for (final p in products) p.variantId: p.name};
      _bins = bins;
      _load = _Load.ready;
    });
  }

  Future<void> _start() async {
    final ok = await _run(() => widget.api.startCount(
          id: _startId,
          warehouseId: widget.warehouse.id,
          binId: _scopeBin,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        ));
    if (!ok) return;
    _startId = const Uuid().v7();
    _notes.clear();
    await _refresh();
  }

  Future<void> _scan() async {
    final code = await cameraScanner.scanOne(context);
    if (code == null || !mounted) return;
    final p = await CatalogScope.of(context).store.findByBarcode(code);
    if (!mounted) return;
    if (p == null) {
      setState(() => _error = AppLocalizations.of(context).whScanUnknown);
    } else {
      _pick(p);
    }
  }

  void _pick(ProductView p, {String? bin}) {
    final existing = _session?.lines.where((l) => l.variantId == p.variantId && l.binId == bin).firstOrNull;
    setState(() {
      _picked = p;
      _lineBin = bin;
      _query = '';
      _search.clear();
      _error = null;
      _qty.text = existing == null ? '' : _n(existing.qtyCounted);
    });
    // the box appears with this rebuild; hand it the keyboard (autofocus is ignored while the search box has focus)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _qtyFocus.requestFocus();
    });
  }

  Future<void> _saveLine() async {
    final t = AppLocalizations.of(context);
    final session = _session!;
    final p = _picked!;
    final qty = parseQty(_qty.text);
    if (qty == null || qty < 0) {
      setState(() => _error = t.whErrQtyInvalid);
      return;
    }
    final bin = session.binId ?? _lineBin;
    if (widget.warehouse.binsEnabled && bin == null) {
      setState(() => _error = t.whCountErrBinRequired);
      return;
    }
    final store = CatalogScope.of(context).store;
    final localSys = await store.warehouseStockFor(widget.warehouse.id, p.variantId, binId: bin);
    final entry = CountEntry(variantId: p.variantId, qty: qty, binId: bin, qtySystem: localSys);

    if (session.isLocal) {
      await store.recordOfflineCount(session.id, [entry]);
      final updated = await store.localOpenCount(widget.warehouse.id);
      if (!mounted) return;
      setState(() {
        _session = updated;
        _picked = null;
        _qty.clear();
        _query = '';
        _search.clear();
      });
      return;
    }

    final ok = await _run(() => widget.api.recordCount(
          session.id,
          [entry],
        ));
    if (!ok) return;
    setState(() {
      _picked = null;
      _qty.clear();
      _query = '';
      _search.clear();
    });
    await _refresh();
  }

  Future<void> _finish() async {
    final t = AppLocalizations.of(context);
    final session = _session!;
    var zero = false;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(t.whCountFinishAsk),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.whCountFinishBody),
            if (session.wholeWarehouse || session.binId != null)
              CheckboxListTile(
                key: const Key('count-zero'),
                contentPadding: EdgeInsets.zero,
                value: zero,
                title: Text(t.whCountZeroUncounted),
                onChanged: (v) => setD(() => zero = v ?? false),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
            FilledButton(key: const Key('count-confirm'), onPressed: () => Navigator.pop(ctx, true), child: Text(t.whCountFinish)),
          ],
        ),
      ),
    );
    if (go != true || !mounted) return;

    if (session.isLocal) {
      final store = CatalogScope.of(context).store;
      await store.closeOfflineCount(session.id, zeroUncounted: zero);
      if (!mounted) return;
      setState(() => _session = null);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(key: const Key('count-result'), content: Text(t.whCountOfflineDone)));
      return;
    }

    CountResult? result;
    final ok = await _run(() async => result = await widget.api.closeCount(session.id, zeroUncounted: zero));
    if (!ok || !mounted) return;
    await _refresh();
    if (!mounted) return;
    final r = result!;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(key: const Key('count-result'), content: Text(t.whCountDone(r.corrections, _n(r.netVariance)))));
  }

  Future<void> _cancel() async {
    final t = AppLocalizations.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.whCountCancelAsk),
        content: Text(t.whCountCancelBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.whCountKeep)),
          FilledButton(key: const Key('count-cancel-confirm'), onPressed: () => Navigator.pop(ctx, true), child: Text(t.whCountCancel)),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final session = _session!;
    if (session.isLocal) {
      final store = CatalogScope.of(context).store;
      await store.cancelOfflineCount(session.id);
      if (!mounted) return;
      setState(() => _session = null);
      await _refresh();
      return;
    }
    final ok = await _run(() => widget.api.cancelCount(session.id));
    if (ok) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    switch (_load) {
      case _Load.loading:
        return const Center(child: CircularProgressIndicator());
      case _Load.offline:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(t.whCountOffline, key: const Key('count-offline'), textAlign: TextAlign.center),
              const SizedBox(height: Gap.m),
              FilledButton(key: const Key('count-retry'), onPressed: _refresh, child: Text(t.whCountRetry)),
              const SizedBox(height: Gap.m),
              OutlinedButton(
                key: const Key('count-start-offline'),
                onPressed: _busy ? null : _startOffline,
                child: Text(t.whCountStartOffline),
              ),
            ]),
          ),
        );
      case _Load.ready:
        return ListView(padding: const EdgeInsets.all(Gap.l), children: [
          if (_session == null) ..._startCard(context, t) else ..._countCard(context, t, _session!),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: Gap.m),
              child: Text(_error!, key: const Key('count-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ]);
    }
  }

  List<Widget> _startCard(BuildContext context, AppLocalizations t) => [
        Text(t.whCountNone, key: const Key('count-none'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: Gap.m),
        if (widget.warehouse.binsEnabled)
          DropdownButtonFormField<String?>(
            key: const Key('count-scope'),
            initialValue: _scopeBin,
            decoration: InputDecoration(labelText: t.whCountScope),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text(t.whCountWhole)),
              for (final b in _bins) DropdownMenuItem<String?>(value: b.id, child: Text(b.code)),
            ],
            onChanged: (v) => setState(() => _scopeBin = v),
          ),
        const SizedBox(height: Gap.m),
        TextField(key: const Key('count-notes'), controller: _notes, decoration: InputDecoration(labelText: t.whNotes)),
        const SizedBox(height: Gap.l),
        FilledButton(key: const Key('count-start'), onPressed: _busy ? null : _start, child: Text(t.whCountStart)),
      ];

  List<Widget> _countCard(BuildContext context, AppLocalizations t, CountSession s) {
    final store = CatalogScope.of(context).store;
    final needsBin = widget.warehouse.binsEnabled && s.binId == null;
    return [
      Text('${s.countNo} · ${s.wholeWarehouse ? t.whCountWhole : (s.binCode ?? '')}', key: const Key('count-header'), style: Theme.of(context).textTheme.titleMedium),
      if (s.isLocal) ...[
        const SizedBox(height: Gap.xs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Gap.s + 2, vertical: Gap.xs),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(Gap.radiusS),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: Gap.xs),
              Flexible(
                child: Text(
                  t.whCountOfflineBanner,
                  key: const Key('count-offline-banner'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: Gap.m),
      TextField(
        key: const Key('count-search'),
        controller: _search,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded),
          hintText: t.searchProducts,
          suffixIcon: cameraScanner.available
              ? IconButton(key: const Key('count-scan'), tooltip: t.scanWithCamera, icon: const Icon(Icons.qr_code_scanner_rounded), onPressed: _scan)
              : null,
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
      if (_query.trim().isNotEmpty)
        StreamBuilder<List<ProductView>>(
          stream: store.watchProducts(query: _query.trim()),
          builder: (context, snap) => Column(children: [
            for (final p in (snap.data ?? const <ProductView>[]).take(6))
              ListTile(key: Key('count-pick-${p.variantId}'), dense: true, title: Text(p.name), onTap: () => _pick(p)),
          ]),
        ),
      if (_picked != null)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.m),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_picked!.name, style: Theme.of(context).textTheme.titleSmall),
              if (needsBin)
                DropdownButtonFormField<String?>(
                  key: const Key('count-bin'),
                  initialValue: _lineBin,
                  decoration: InputDecoration(labelText: t.whCountBin),
                  items: [for (final b in _bins) DropdownMenuItem<String?>(value: b.id, child: Text(b.code))],
                  onChanged: (v) => setState(() => _lineBin = v),
                ),
              TextField(
                key: const Key('count-qty'),
                controller: _qty,
                focusNode: _qtyFocus,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: t.whCountQty),
              ),
              const SizedBox(height: Gap.m),
              FilledButton(key: const Key('count-save'), onPressed: _busy ? null : _saveLine, child: Text(t.whCountSaveLine)),
            ]),
          ),
        ),
      const SizedBox(height: Gap.m),
      if (s.lines.isEmpty) Text(t.whCountNoLines, key: const Key('count-no-lines')),
      for (final l in s.lines)
        ListTile(
          key: Key('count-line-${l.variantId}${l.binId == null ? '' : '-${l.binId}'}'),
          contentPadding: EdgeInsets.zero,
          title: Text(_names[l.variantId] ?? t.whUnknownProduct),
          subtitle: Text([if (l.binCode != null) l.binCode!, t.whCountSystemWas(_n(l.qtySystem))].join(' · ')),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_n(l.qtyCounted), style: Theme.of(context).textTheme.titleMedium),
            if (l.variance != 0) Text(l.variance > 0 ? '+${_n(l.variance)}' : _n(l.variance), style: TextStyle(color: Theme.of(context).colorScheme.tertiary)),
          ]),
          onTap: () {
            final p = _productOf(l.variantId);
            if (p != null) _pick(p, bin: l.binId);
          },
        ),
      const SizedBox(height: Gap.l),
      FilledButton(key: const Key('count-finish'), onPressed: _busy ? null : _finish, child: Text(t.whCountFinish)),
      const SizedBox(height: Gap.s),
      TextButton(key: const Key('count-cancel'), onPressed: _busy ? null : _cancel, child: Text(t.whCountCancel)),
    ];
  }

  ProductView? _productOf(String variantId) {
    // a line is edited by picking the product again; the name list is enough to rebuild a minimal pick
    final name = _names[variantId];
    if (name == null) return null;
    return ProductView(id: variantId, variantId: variantId, name: name, unit: '', sku: '', currency: '', active: true, pending: false);
  }
}
