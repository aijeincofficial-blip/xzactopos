import 'package:flutter/material.dart';

import '../backend.dart';
import '../data/local_store.dart';
import '../data/sales_models.dart';
import '../l10n/app_localizations.dart';
import 'photo_loader.dart';
import 'sync_engine.dart';

/// Opens the device store. [safeMode] asks for the most compatible storage (see AppDatabase.open).
typedef OpenStore = LocalStore Function({bool safeMode});

/// The stores (locations of type `store`) in a `get_my_access` payload, in its order (by code).
List<StoreRef> storesOf(Map<String, dynamic> access) => [
      for (final l in ((access['locations'] as List?) ?? const []).whereType<Map>())
        if (l['type'] == 'store' && l['id'] is String)
          StoreRef(id: l['id'] as String, name: (l['name'] as String?) ?? (l['code'] as String?) ?? ''),
    ];

/// What a phone pulls for a signed-in role (F-13h). A warehouse clerk works in a warehouse, not a store: warehouse data and
/// none of the store pulls. Everyone else (owner, admin, cashier, a solo owner whose role is null) pulls the store data and
/// never asks for warehouse data.
({bool store, bool warehouse}) syncScopeForRole(String? role) =>
    role == 'warehouse' ? (store: false, warehouse: true) : (store: true, warehouse: false);

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
  late PhotoLoader _photos;
  late Future<void> _ready;

  @override
  void initState() {
    super.initState();
    _ready = _open();
  }

  bool _opened = false;
  bool _discardUnsent = false;

  /// Opens a fresh connection each time, so "Try again" never reuses a connection that failed to start.
  /// If the normal open fails (e.g. a browser that blocks the shared worker from loading SQLite),
  /// it tries the most compatible storage once before giving up.
  Future<void> _open({bool retry = false}) async {
    if (retry) await _closeQuietly();
    try {
      await _start(safeMode: false);
    } on UnsentChangesException {
      rethrow; // not a storage problem: safe mode would hit the same thing
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
    // a warehouse clerk works in a warehouse, not a store: warehouse data, and none of the store pulls
    final scope = syncScopeForRole(widget.access['role'] as String?);
    _engine = SyncEngine(_store, widget.backend, pullsStore: scope.store, pullsWarehouse: scope.warehouse);
    _photos = PhotoLoader(_store, widget.backend);
    _opened = true;
    final tenant = (widget.access['tenant'] as Map?) ?? const {};
    await _store.ensureTenant(tenant['id'] as String? ?? '',
        baseCurrency: tenant['base_currency'] as String? ?? 'PHP',
        // F-01: the stores this user may work at; the device keeps one active (a solo business has exactly one)
        stores: storesOf(widget.access),
        discardUnsent: _discardUnsent);
    await _store.setMeta('store_name', tenant['name'] as String?);
    _engine.start();
  }

  bool get _canManageStock {
    final role = widget.access['role'];
    return role == null || role == 'superadmin' || role == 'admin' || role == 'warehouse';
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
        if (snap.error is UnsentChangesException) {
          final n = (snap.error! as UnsentChangesException).count;
          final t = AppLocalizations.of(context);
          return Scaffold(
            appBar: AppBar(title: Text(t.unsentTitle)),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(t.unsentBody(n), key: const Key('unsent-body'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('unsent-signout'),
                  onPressed: widget.backend.signOut,
                  child: Text(t.signOut),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('unsent-discard'),
                  onPressed: () {
                    _discardUnsent = true;
                    final next = _open(retry: true);
                    setState(() {
                      _ready = next;
                    });
                  },
                  child: Text(t.unsentDiscard),
                ),
              ]),
            ),
          );
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
        return CatalogScope(
            store: _store,
            engine: _engine,
            photos: _photos,
            canManageStock: _canManageStock,
            role: widget.access['role'] as String?,
            child: widget.child);
      },
    );
  }
}

class CatalogScope extends InheritedWidget {
  const CatalogScope({
    super.key,
    required this.store,
    required this.engine,
    required this.photos,
    this.canManageStock = true,
    this.role,
    required super.child,
  });

  final LocalStore store;
  final SyncEngine engine;
  final PhotoLoader photos;

  /// Superadmin, admins, and warehouse may stock in and count; cashiers only look.
  final bool canManageStock;

  /// Role of the signed-in user ('superadmin', 'admin', 'warehouse', 'cashier', or null for solo owner).
  final String? role;

  bool get isCashier => role == 'cashier';
  bool get isWarehouse => role == 'warehouse';
  bool get isAdminOrSuperadmin => role == null || role == 'superadmin' || role == 'admin';
  bool get canAccessExpenses => isAdminOrSuperadmin;
  bool get canCloseDay => isAdminOrSuperadmin;

  /// Same scope around [child]; for screens pushed on the navigator (they sit outside this widget).
  CatalogScope wrap(Widget child) => CatalogScope(
        store: store,
        engine: engine,
        photos: photos,
        canManageStock: canManageStock,
        role: role,
        child: child,
      );

  static CatalogScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CatalogScope>();
    assert(scope != null, 'CatalogScope missing above this widget');
    return scope!;
  }

  static CatalogScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CatalogScope>();
  }

  @override
  bool updateShouldNotify(CatalogScope old) =>
      store != old.store || engine != old.engine || role != old.role || canManageStock != old.canManageStock;
}
