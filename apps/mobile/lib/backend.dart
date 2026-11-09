import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/count_models.dart';
import 'data/shift_models.dart';
import 'sync/sync_engine.dart';

/// True when the failure is an ANSWER from the server (it was reached and said no), false when it was not reached at all (no
/// signal, timeout, DNS). Only the second kind may fall back to what is saved on the phone.
bool serverAnswered(Object e) => e is PostgrestException || e is AuthException;

/// What the app needs from the server. Screens depend on this, so tests can fake it.
abstract class Backend implements SyncApi {
  bool get signedIn;

  /// The signed-in user's id, or null when signed out.
  String? get userId;
  Stream<bool> get signedInChanges;
  Future<void> signIn(String email, String password);

  /// Returns true when a session exists right away (email confirmation off).
  Future<bool> signUp(String email, String password);
  Future<void> signOut();

  /// Emails a reset link. Never says whether the address has an account.
  Future<void> sendPasswordReset(String email);

  /// Sets a new password for the signed-in user (also used right after opening a reset link).
  Future<void> updatePassword(String newPassword);

  /// Fires when the user opened a reset link and must choose a new password.
  Stream<void> get passwordRecovery;

  /// The user's access payload, or null when they have no business yet.
  Future<Map<String, dynamic>?> myAccess();

  /// Sales report from the server's rollups (report_summary), for whole days [from] to [to] inclusive.
  Future<Map<String, dynamic>> reportSummary(DateTime from, DateTime to);

  /// Creates the solo store, then refreshes the session so the token carries tenant_id.
  Future<void> provisionSoloStore({
    required String tenantId,
    required String locationId,
    required String storeName,
    required String locale,
  });

  // ---- supervisor PIN (P8-02b / P8-02c) ----
  //
  // ONLINE ONLY: the PIN is checked by the server and is never stored on the device, queued, logged or sent to
  // analytics. Keep it in the PIN field only for the length of the call and clear the field afterwards.

  /// Sets the signed-in user's own PIN (4 to 8 digits). Changing an existing PIN needs [currentPin].
  /// Result hints: `pin_wrong`, `pin_locked`, `pin_invalid`, `pin_required`. Throws on network trouble.
  Future<PinResult> setMyPin(String newPin, {String? currentPin});

  /// Asks the server for a single-use supervisor approval of [action] (`record_expense` | `void_expense` |
  /// `close_day` | `record_service_txn` (float top-up / withdraw) | `void_service_txn`) on [refId] (the expense /
  /// day close / service entry id, made BEFORE asking). [approverId] null = the signed-in
  /// supervisor confirms with her own PIN; else a manager's or the owner's user id, who types their PIN.
  /// Needs signal now; the returned approval id then rides in the queued op, which may wait up to 12 h offline.
  /// Result hints: `pin_wrong`, `pin_locked`, `pin_not_set`, and the refusals `not_allowed`, `approver_invalid`,
  /// `invalid_value`, `location_required`, `location_denied`. Throws on network trouble ("needs signal").
  Future<ApprovalResult> approveSupervisorAction({
    required String action,
    required String refId,
    required String pin,
    String? locationId,
    String? approverId,
  });

  /// Pulls store approver PIN hashes for offline verification (F-06).
  Future<List<Map<String, dynamic>>> pullOfflinePins({String? locationId});
}

class PinResult {
  const PinResult.ok()
      : ok = true,
        hint = null;
  const PinResult.refused(String this.hint) : ok = false;
  final bool ok;
  final String? hint;
}

class ApprovalResult {
  const ApprovalResult.ok({required String this.approvalId, required String this.approvedBy, required DateTime this.expiresAt})
      : ok = true,
        offlineApproval = null,
        hint = null;
  const ApprovalResult.offline({required Map<String, dynamic> this.offlineApproval, required String this.approvedBy})
      : ok = true,
        approvalId = null,
        expiresAt = null,
        hint = null;
  const ApprovalResult.refused(String this.hint)
      : ok = false,
        approvalId = null,
        approvedBy = null,
        expiresAt = null,
        offlineApproval = null;

  final bool ok;
  final String? approvalId;
  final String? approvedBy;
  final DateTime? expiresAt;
  final Map<String, dynamic>? offlineApproval;
  bool get isOffline => offlineApproval != null;

  /// Why there is no approval (see [Backend.approveSupervisorAction]); null when [ok].
  final String? hint;

  /// Reads the approve_supervisor_action answer: `{ok: true, approval_id, approved_by, expires_at}` or `{ok: false, hint}`.
  factory ApprovalResult.fromJson(Map<String, dynamic> j) => j['ok'] == true
      ? ApprovalResult.ok(
          approvalId: j['approval_id'] as String,
          approvedBy: j['approved_by'] as String,
          expiresAt: DateTime.parse(j['expires_at'] as String),
        )
      : ApprovalResult.refused((j['hint'] as String?) ?? 'rejected');
}

/// Refusals of set_my_pin / approve_supervisor_action that are answers for the user, not network trouble.
const pinRefusalHints = {
  'pin_invalid', 'pin_required', 'not_allowed', 'approver_invalid', 'invalid_value', 'location_required',
  'location_denied', 'module_disabled',
};

class SupabaseBackend implements Backend, DeviceApi, WarehouseApi, CountApi, ShiftApi {
  SupabaseClient get _c => Supabase.instance.client;

  @override
  bool get signedIn => _c.auth.currentSession != null;

  @override
  String? get userId => _c.auth.currentUser?.id;

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
  Future<void> sendPasswordReset(String email) =>
      _c.auth.resetPasswordForEmail(email, redirectTo: kIsWeb ? Uri.base.origin : null);

  @override
  Future<void> updatePassword(String newPassword) async {
    await _c.auth.updateUser(UserAttributes(password: newPassword));
  }

  @override
  Stream<void> get passwordRecovery =>
      _c.auth.onAuthStateChange.where((e) => e.event == AuthChangeEvent.passwordRecovery);

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

  /// An expired or revoked session is not a network problem: the engine tells the user to sign in again.
  Future<T> _auth<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PostgrestException catch (e) {
      if (isAuthExpired(e.code, e.message)) throw const AuthExpired();
      rethrow;
    } on AuthException catch (e) {
      if (e.statusCode == '401' || e.message.toLowerCase().contains('refresh')) throw const AuthExpired();
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> reportSummary(DateTime from, DateTime to) async {
    String d(DateTime x) => '${x.year.toString().padLeft(4, '0')}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    final res = await _auth(() => _c.rpc('report_summary', params: {'p_from': d(from), 'p_to': d(to)}));
    return (res as Map).cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> pullCatalog(Map<String, dynamic> cursors, {int limit = 500}) async {
    final res = await _auth(() => _c.rpc('sync_pull_catalog', params: {'p_cursors': cursors, 'p_limit': limit}));
    return (res as Map).cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> pullPos(Map<String, dynamic> cursors, {int limit = 500}) async {
    final res = await _auth(() => _c.rpc('sync_pull_pos', params: {'p_cursors': cursors, 'p_limit': limit}));
    return (res as Map).cast<String, dynamic>();
  }

  // ---- cashier shifts (F-05m) ----

  @override
  Future<Map<String, dynamic>> pullShifts(Map<String, dynamic>? cursor, {int limit = 100}) async {
    final res = await _auth(() => _c.rpc('sync_pull_shifts', params: {'p_cursor': cursor, 'p_limit': limit}));
    return (res as Map).cast<String, dynamic>();
  }

  @override
  Future<int?> shiftExpectedNow(String shiftId) async {
    try {
      final res = await _auth(() => _c.rpc('shift_expected_now', params: {'p_shift_id': shiftId}));
      return ((res as Map)['server_expected_cash'] as num?)?.toInt();
    } on PostgrestException {
      return null; // the server cannot say (not synced yet, not allowed): the phone's own figure is used
    } on AuthExpired {
      rethrow;
    } on Exception {
      return null; // no signal
    }
  }

  // ---- stock counts (online only, F-13h H6) ----

  /// Runs a count call: the server's refusal becomes a [CountException] with its hint, and anything that is not an answer
  /// from the server (no signal, timeout) becomes [CountOffline]. An expired sign-in stays [AuthExpired].
  Future<T> _count<T>(Future<T> Function() call) async {
    try {
      return await _auth(call);
    } on AuthExpired {
      rethrow;
    } on PostgrestException catch (e) {
      throw CountException(e.hint ?? e.code ?? 'error');
    } on Exception {
      throw const CountOffline();
    }
  }

  @override
  Future<CountSession?> openCount(String warehouseId) => _count(() async {
        final row = await _c
            .from('stock_counts')
            .select('id, count_no, warehouse_id, bin_id, notes, bin:bins!stock_counts_bin_fk(code), '
                'stock_count_items(variant_id, bin_id, qty_system, qty_counted, bin:bins!stock_count_items_bin_fk(code))')
            .eq('warehouse_id', warehouseId)
            .eq('status', 'open')
            .maybeSingle();
        return row == null ? null : CountSession.fromJson(row);
      });

  @override
  Future<void> startCount({required String id, required String warehouseId, String? binId, String? notes}) => _count(() async {
        await _c.rpc('start_count', params: {'p_id': id, 'p_warehouse_id': warehouseId, 'p_bin_id': binId, 'p_notes': notes});
      });

  @override
  Future<void> recordCount(String countId, List<CountEntry> items) => _count(() async {
        await _c.rpc('record_count', params: {'p_count_id': countId, 'p_items': [for (final i in items) i.toJson()]});
      });

  @override
  Future<CountResult> closeCount(String countId, {bool zeroUncounted = false}) => _count(() async {
        final res = await _c.rpc('close_count', params: {'p_count_id': countId, 'p_zero_uncounted': zeroUncounted});
        return CountResult.fromJson((res as Map).cast<String, dynamic>());
      });

  @override
  Future<void> cancelCount(String countId, {String? reason}) => _count(() async {
        await _c.rpc('cancel_count', params: {'p_count_id': countId, 'p_reason': reason});
      });

  @override
  Future<Map<String, dynamic>> pullWarehouse(Map<String, dynamic> cursors, {int limit = 500}) async {
    try {
      final res = await _auth(() => _c.rpc('sync_pull_warehouse', params: {'p_cursors': cursors, 'p_limit': limit}));
      return (res as Map).cast<String, dynamic>();
    } on PostgrestException catch (e) {
      // the tenant switched the warehouse module off: nothing to pull, and not a reason to keep the phone in backoff
      if (e.hint == 'module_disabled') return <String, dynamic>{};
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> pullSales(Map<String, dynamic>? cursor, {int limit = 100}) async {
    final res = await _auth(() => _c.rpc('sync_pull_sales', params: {'p_cursor': cursor, 'p_limit': limit}));
    return (res as Map).cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> pullExpenses(Map<String, dynamic>? cursor, {int limit = 100}) async {
    final res = await _auth(() => _c.rpc('sync_pull_expenses', params: {'p_cursor': cursor, 'p_limit': limit}));
    return (res as Map).cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> pullDayCloses(Map<String, dynamic>? cursor, {int limit = 100}) async {
    final res = await _auth(() => _c.rpc('sync_pull_day_closes', params: {'p_cursor': cursor, 'p_limit': limit}));
    return (res as Map).cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> pullService(Map<String, dynamic>? cursor, {int limit = 100}) async {
    final res = await _auth(() => _c.rpc('sync_pull_service', params: {'p_cursor': cursor, 'p_limit': limit}));
    return (res as Map).cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> pullConversions(Map<String, dynamic>? cursor, {int limit = 100}) async {
    final res = await _auth(() => _c.rpc('sync_pull_conversions', params: {'p_cursor': cursor, 'p_limit': limit}));
    return (res as Map).cast<String, dynamic>();
  }

  @override
  Future<PinResult> setMyPin(String newPin, {String? currentPin}) async {
    try {
      final res = await _auth(() => _c.rpc('set_my_pin', params: {'p_new_pin': newPin, 'p_current_pin': currentPin}));
      final j = (res as Map).cast<String, dynamic>();
      return j['ok'] == true ? const PinResult.ok() : PinResult.refused((j['hint'] as String?) ?? 'rejected');
    } on PostgrestException catch (e) {
      if (pinRefusalHints.contains(e.hint)) return PinResult.refused(e.hint!);
      rethrow;
    }
  }

  @override
  Future<ApprovalResult> approveSupervisorAction({
    required String action,
    required String refId,
    required String pin,
    String? locationId,
    String? approverId,
  }) async {
    try {
      final res = await _auth(() => _c.rpc('approve_supervisor_action', params: {
            'p_action': action,
            'p_ref_id': refId,
            'p_pin': pin,
            'p_location_id': locationId,
            'p_approver_id': approverId,
          }));
      return ApprovalResult.fromJson((res as Map).cast<String, dynamic>());
    } on PostgrestException catch (e) {
      if (pinRefusalHints.contains(e.hint)) return ApprovalResult.refused(e.hint!);
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> pullOfflinePins({String? locationId}) async {
    final res = await _auth(() => _c.rpc('pull_offline_pins', params: {'p_location_id': locationId}));
    return (res as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  @override
  Future<Map<String, dynamic>> registerDevice(String id, {String? name, String? platform}) async {
    try {
      final res = await _auth(() => _c.rpc('register_device', params: {'p_id': id, 'p_name': name, 'p_platform': platform}));
      return (res as Map).cast<String, dynamic>();
    } on PostgrestException catch (e) {
      // id_conflict / invalid_value (22023), device_limit (P0001): asking again will not help this session
      if (isPermanent(e.code, e.hint)) throw OpRejected(e.hint ?? e.code ?? 'rejected');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> syncPush(List<Map<String, dynamic>> ops) async {
    final res = await _auth(() => _c.rpc('sync_push', params: {'p_ops': ops}));
    return (res as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  @override
  Future<void> upsertProduct(String opId, Map<String, dynamic> payload) =>
      _op(() => _c.rpc('upsert_product', params: {'p_op_id': opId, 'p_product': payload}));

  @override
  Future<void> archiveProduct(String opId, String productId) =>
      _op(() => _c.rpc('archive_product', params: {'p_op_id': opId, 'p_product_id': productId}));

  static const _photoBucket = 'product-photos';

  @override
  Future<void> uploadPhoto(String path, Uint8List jpeg) async {
    try {
      await _c.storage.from(_photoBucket).uploadBinary(
            path,
            jpeg,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
    } on StorageException catch (e) {
      // 400/403 policy refusals and 413 too large will not change on retry
      final status = int.tryParse(e.statusCode ?? '');
      if (status != null && (status == 400 || status == 403 || status == 413)) {
        throw OpRejected(status == 413 ? 'photo_too_large' : 'not_allowed');
      }
      rethrow;
    }
  }

  @override
  Future<Uint8List> downloadPhoto(String path) => _c.storage.from(_photoBucket).download(path);

  /// Maps refusals that retrying cannot fix to [OpRejected]; everything else (network, 5xx, expired token)
  /// stays a normal exception so the engine retries it later with the same op id.
  Future<void> _op(Future<dynamic> Function() call) async {
    try {
      await _auth(call);
    } on PostgrestException catch (e) {
      if (isPermanent(e.code, e.hint)) throw OpRejected(e.hint ?? e.code ?? 'rejected');
      rethrow;
    }
  }
}

/// PostgREST answers 401 with PGRST301 or "JWT expired" when the token is no longer accepted.
bool isAuthExpired(String? code, String message) =>
    code == 'PGRST301' || code == 'PGRST303' || message.toLowerCase().contains('jwt expired');

const _permanentCodes = {'22023', '23505', '23514', '22P02', 'P0001'};
const _permanentDenials = {'not_allowed', 'cost_and_sku_only', 'module_disabled'};

/// True when the server's refusal is final for this op.
bool isPermanent(String? code, String? hint) =>
    _permanentCodes.contains(code) || (code == '42501' && _permanentDenials.contains(hint));
