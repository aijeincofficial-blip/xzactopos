/// Cashier shifts on the phone (F-05m). A shift is one cashier at one store, from open to close: the cash they started with,
/// the cash they counted at the end, and the difference. The phone works out the expected cash from what it holds (the X
/// reading) and sends it with the close; the server stores that next to its own figure.
///
/// Everything here works offline: opening and closing are queued like sales. Money is integer minor units (centavos).
library;

class ShiftView {
  const ShiftView({
    required this.id,
    this.locationId,
    this.cashierId,
    required this.currency,
    required this.openingCash,
    required this.openedAt,
    this.closedAt,
    this.expectedCash,
    this.serverExpectedCash,
    this.countedCash,
    this.difference,
    this.note,
    this.closedBy,
    this.pending = false,
    this.rejectedHint,
  });

  final String id;
  final String? locationId;
  final String? cashierId;
  final String currency;
  final int openingCash;
  final DateTime openedAt;
  final DateTime? closedAt;

  /// What the phone worked out when the shift was closed.
  final int? expectedCash;

  /// What the server worked out from its own data (null until it has applied the close and the phone has pulled it).
  final int? serverExpectedCash;
  final int? countedCash;

  /// Counted minus expected: below zero is short, above is over.
  final int? difference;
  final String? note;
  final String? closedBy;

  /// A change to this shift is still on its way to the server.
  final bool pending;

  /// The server refused a change to this shift (the hint), until the clerk discards it.
  final String? rejectedHint;

  bool get isOpen => closedAt == null;

  /// The server's expected cash differs from the phone's: worth a look by a supervisor.
  bool get serverDisagrees => serverExpectedCash != null && expectedCash != null && serverExpectedCash != expectedCash;
}

/// The interim reading of an open shift (an "X"): everything that explains the cash expected in the drawer right now. Reading
/// it changes nothing. [expected] = opening cash + cash sales + utang cash taken - cash paid out + load / e-wallet cash effect.
class XReading {
  const XReading({
    required this.from,
    required this.to,
    required this.openingCash,
    required this.cashSales,
    required this.utangCash,
    required this.expensesCash,
    required this.serviceCash,
    required this.salesCount,
    required this.grossSales,
    required this.ewalletSales,
    required this.utangSales,
  });

  final DateTime from;
  final DateTime to;
  final int openingCash;
  final int cashSales;

  /// Cash taken from customers paying their utang.
  final int utangCash;

  /// Cash expenses paid out of the drawer.
  final int expensesCash;

  /// Cash effect of load and e-wallet entries (cash in adds, cash out takes, fees add).
  final int serviceCash;
  final int salesCount;
  final int grossSales;
  final int ewalletSales;
  final int utangSales;

  int get expected => openingCash + cashSales + utangCash - expensesCash + serviceCash;
}

/// Why a shift change could not be recorded on the device (checked before anything is queued).
class ShiftException implements Exception {
  const ShiftException(this.code);

  /// shift_already_open | shift_not_found | shift_closed | id_used
  final String code;
  @override
  String toString() => 'ShiftException($code)';
}

/// The shift side of the device store. Implemented by the Drift store; screens and the sync engine depend on this.
abstract class ShiftStore {
  /// The cashier's open shift, if any.
  Stream<ShiftView?> watchOpenShift(String cashierId);
  Future<ShiftView?> openShift(String cashierId);

  /// Recent shifts at the active store, newest first (the cashier's own, and for admins everyone's that was pulled).
  Stream<List<ShiftView>> watchShifts({int limit = 30});
  Future<ShiftView?> shift(String id);

  /// The X reading of a shift: from its start to now (or to its close).
  Stream<XReading?> watchXReading(String shiftId);
  Future<XReading?> xReading(String shiftId);

  /// Starts a shift at the active store. Throws [ShiftException] `shift_already_open` when the cashier has one open.
  Future<void> startShift({required String id, required String cashierId, int openingCash = 0, required String opId, DateTime? at});

  /// Closes the shift with the counted cash; [expectedCash] is the figure the clerk was shown (the server's when the phone
  /// asked it, else the X reading's). Throws [ShiftException] when the shift is unknown or already closed.
  Future<void> closeShift({
    required String id,
    required int countedCash,
    required int expectedCash,
    String? note,
    required String opId,
    DateTime? at,
  });

  // ---- sync ----
  Future<Map<String, dynamic>?> shiftCursor();

  /// Applies one sync_pull_shifts response. A shift with a change of this device still unsent is left as it is.
  Future<void> applyPullShifts(Map<String, dynamic> response);

  /// An open_shift / close_shift op was applied by the server ([result] carries its own expected cash for a close).
  Future<void> shiftOpApplied(String opId, String? appliedAt, {Map<String, dynamic>? result});
}

/// Shift calls that are not part of the sync API (kept apart like the warehouse ones): only the Supabase backend has them.
abstract class ShiftApi {
  /// sync_pull_shifts.
  Future<Map<String, dynamic>> pullShifts(Map<String, dynamic>? cursor, {int limit = 100});

  /// The server's expected cash for a shift right now (shift_expected_now), or null when it cannot say.
  Future<int?> shiftExpectedNow(String shiftId);
}
