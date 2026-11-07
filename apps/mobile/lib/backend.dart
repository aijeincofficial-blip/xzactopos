import 'package:supabase_flutter/supabase_flutter.dart';

import 'sync/sync_engine.dart';

/// What the app needs from the server. Screens depend on this, so tests can fake it.
abstract class Backend implements SyncApi {
  bool get signedIn;
  Stream<bool> get signedInChanges;
  Future<void> signIn(String email, String password);

  /// Returns true when a session exists right away (email confirmation off).
  Future<bool> signUp(String email, String password);
  Future<void> signOut();

  /// The user's access payload, or null when they have no business yet.
  Future<Map<String, dynamic>?> myAccess();

  /// Creates the solo store, then refreshes the session so the token carries tenant_id.
  Future<void> provisionSoloStore({
    required String tenantId,
    required String locationId,
    required String storeName,
    required String locale,
  });
}

class SupabaseBackend implements Backend {
  SupabaseClient get _c => Supabase.instance.client;

  @override
  bool get signedIn => _c.auth.currentSession != null;

  @override
  Stream<bool> get signedInChanges =>
      _c.auth.onAuthStateChange.map((e) => e.session != null).distinct();

  @override
  Future<void> signIn(String email, String password) async {
    await _c.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<bool> signUp(String email, String password) async {
    final res = await _c.auth.signUp(email: email, password: password);
    return res.session != null;
  }

  @override
  Future<void> signOut() => _c.auth.signOut();

  @override
  Future<Map<String, dynamic>?> myAccess() async {
    try {
      final res = await _c.rpc('get_my_access');
      return (res as Map).cast<String, dynamic>();
    } on PostgrestException catch (e) {
      // 42501 / no_account: signed in, but no business (or token not refreshed yet)
      if (e.code == '42501') return null;
      rethrow;
    }
  }

  @override
  Future<void> provisionSoloStore({
    required String tenantId,
    required String locationId,
    required String storeName,
    required String locale,
  }) async {
    await _c.rpc('provision_solo_store', params: {
      'p_tenant_id': tenantId,
      'p_location_id': locationId,
      'p_store_name': storeName,
      'p_locale': locale,
    });
    await _c.auth.refreshSession();
  }

  @override
  Future<Map<String, dynamic>> pullCatalog(Map<String, dynamic> cursors, {int limit = 500}) async {
    final res = await _c.rpc('sync_pull_catalog', params: {'p_cursors': cursors, 'p_limit': limit});
    return (res as Map).cast<String, dynamic>();
  }

  @override
  Future<void> upsertProduct(String opId, Map<String, dynamic> payload) =>
      _op(() => _c.rpc('upsert_product', params: {'p_op_id': opId, 'p_product': payload}));

  @override
  Future<void> archiveProduct(String opId, String productId) =>
      _op(() => _c.rpc('archive_product', params: {'p_op_id': opId, 'p_product_id': productId}));

  /// Maps refusals that retrying cannot fix to [OpRejected]; everything else (network, 5xx, expired token)
  /// stays a normal exception so the engine retries it later with the same op id.
  Future<void> _op(Future<dynamic> Function() call) async {
    try {
      await call();
    } on PostgrestException catch (e) {
      if (isPermanent(e.code, e.hint)) throw OpRejected(e.hint ?? e.code ?? 'rejected');
      rethrow;
    }
  }
}

const _permanentCodes = {'22023', '23505', '23514', '22P02', 'P0001'};
const _permanentDenials = {'not_allowed', 'cost_and_sku_only', 'module_disabled'};

/// True when the server's refusal is final for this op.
bool isPermanent(String? code, String? hint) =>
    _permanentCodes.contains(code) || (code == '42501' && _permanentDenials.contains(hint));
