import 'package:flutter/material.dart';

import '../backend.dart';
import '../data/local_store.dart';
import '../l10n/app_localizations.dart';
import 'sync_engine.dart';

/// Opens the device store. [safeMode] asks for the most compatible storage (see AppDatabase.open).
typedef OpenStore = LocalStore Function({bool safeMode});

/// Opens the device store for the signed-in business and keeps sync running while it is on screen.
class StoreSession extends StatefulWidget {
  const StoreSession({
    super.key,
    required this.backend,
    required this.access,
    required this.openStore,
    required this.child,
  });

  final Backend backend;
  final Map<String, dynamic> access;
  final OpenStore openStore;
  final Widget child;

  @override
  State<StoreSession> createState() => _StoreSessionState();
}

class _StoreSessionState extends State<StoreSession> {
  late LocalStore _store;
  late SyncEngine _engine;
  late Future<void> _ready;

  @override
  void initState() {
    super.initState();
    _ready = _open();
  }

  bool _opened = false;

  /// Opens a fresh connection each time, so "Try again" never reuses a connection that failed to start.
  /// If the normal open fails (e.g. a browser that blocks the shared worker from loading SQLite),
  /// it tries the most compatible storage once before giving up.
  Future<void> _open({bool retry = false}) async {
    if (retry) await _closeQuietly();
    try {
      await _start(safeMode: false);
    } catch (e) {
      debugPrint('StoreSession: normal open failed ($e); trying safe mode');
      await _closeQuietly();
      try {
        await _start(safeMode: true);
      } catch (e2, s) {
        debugPrint('StoreSession: could not open the device store: $e2\n$s');
        rethrow;
      }
    }
  }

  Future<void> _start({required bool safeMode}) async {
    _store = widget.openStore(safeMode: safeMode);
    _engine = SyncEngine(_store, widget.backend);
    _opened = true;
    final tenant = (widget.access['tenant'] as Map?) ?? const {};
    await _store.ensureTenant(tenant['id'] as String? ?? '',
        baseCurrency: tenant['base_currency'] as String? ?? 'PHP');
    _engine.start();
  }

  Future<void> _closeQuietly() async {
    if (!_opened) return;
    _opened = false;
    _engine.dispose();
    try {
      await _store.close();
    } catch (_) {}
  }

  @override
  void dispose() {
    _closeQuietly();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(AppLocalizations.of(context).errStoreOpen, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                FilledButton(
                  key: const Key('store-retry'),
                  onPressed: () {
                    final next = _open(retry: true);
                    setState(() {
                      _ready = next;
                    });
                  },
                  child: Text(AppLocalizations.of(context).tryAgain),
                ),
              ]),
            ),
          );
        }
        return CatalogScope(store: _store, engine: _engine, child: widget.child);
      },
    );
  }
}

class CatalogScope extends InheritedWidget {
  const CatalogScope({super.key, required this.store, required this.engine, required super.child});

  final LocalStore store;
  final SyncEngine engine;

  static CatalogScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CatalogScope>();
    assert(scope != null, 'CatalogScope missing above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(CatalogScope old) => store != old.store || engine != old.engine;
}
