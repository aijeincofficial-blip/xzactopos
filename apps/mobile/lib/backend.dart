import 'package:supabase_flutter/supabase_flutter.dart';

/// What the app needs from the server. Screens depend on this, so tests can fake it.
abstract class Backend {
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
}
