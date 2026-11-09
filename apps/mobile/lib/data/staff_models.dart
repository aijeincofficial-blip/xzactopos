// Staff on the phone (priority 3): who works in the business, adding a cashier, switching a person on or off.
// Online only: accounts live on the server, nothing is kept in the local database.

class StaffMember {
  const StaffMember({required this.userId, required this.username, required this.fullName, required this.role, required this.active, this.stores = const []});
  final String userId;
  final String username;
  final String fullName;
  final String role;
  final bool active;
  final List<String> stores;

  String get shownName => fullName.trim().isEmpty ? username : fullName.trim();
}

class StaffStore {
  const StaffStore(this.id, this.name);
  final String id;
  final String name;
}

/// The server said no. [hint] is its short reason (duplicate, create_denied, manage_denied, self_deactivate, ...).
class StaffException implements Exception {
  const StaffException(this.hint);
  final String hint;
  @override
  String toString() => 'StaffException($hint)';
}

/// No answer from the server (no signal).
class StaffOffline implements Exception {
  const StaffOffline();
}

/// Staff calls. Kept apart from the sync API like `CountApi`.
abstract class StaffApi {
  Future<List<StaffMember>> listStaff();
  Future<List<StaffStore>> listStores();

  /// Adds a cashier who signs in as `username.storecode`. Returns the new user's id.
  Future<String> createCashier({required String username, required String fullName, required String password, required String locationId});

  Future<void> setActive(String userId, bool active);

  /// Clears the supervisor PIN (owner only on the server).
  Future<void> clearPin(String userId);
}

/// The name a cashier types on the sign-in screen.
String staffLogin(String username, String slug) => '$username.$slug';

/// What the sign-in field sends: a full email stays, `username.storecode` becomes the account's own address.
String loginEmail(String typed) {
  final v = typed.trim().toLowerCase();
  return v.contains('@') ? v : '$v@pos.invalid';
}

final usernamePattern = RegExp(r'^[a-z0-9][a-z0-9._-]{1,38}[a-z0-9]$');
