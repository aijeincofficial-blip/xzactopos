import 'local_store.dart' show ProductView;

/// One line in a sale being committed. Money is integer centavos; [qty] may be fractional (kilo items).
class SaleLine {
  const SaleLine({
    required this.variantId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    this.unitCost = 0,
    this.taxRate = 0,
    this.tracked = true,
  });

  final String variantId;
  final String name;
  final double qty;
  final int unitPrice;
  final int unitCost;

  /// Price already includes tax; 0.12 = 12%.
  final double taxRate;

  /// The product keeps a stock count (a sale takes qty from it).
  final bool tracked;

  /// qty x price, rounded half up, computed in thousandths so no floating noise can differ from the server.
  int get lineTotal => (milli(qty) * unitPrice + 500) ~/ 1000;

  /// Tax contained in the line price: total x rate / (1 + rate), in whole centavos.
  int get lineTax {
    final bp = (taxRate * 10000).round();
    if (bp <= 0) return 0;
    return (lineTotal * bp + (10000 + bp) ~/ 2) ~/ (10000 + bp);
  }

  static int milli(double qty) => (qty * 1000).round();
}

class PaymentDraft {
  const PaymentDraft(this.method, this.amount, {this.tendered, this.reference});

  /// cash | utang | ewallet
  final String method;

  /// The part of the sale this payment covers (change given back is not included).
  final int amount;

  /// Cash handed over (cash only); change = tendered - amount.
  final int? tendered;
  final String? reference;
}

class SaleDraft {
  const SaleDraft({
    required this.id,
    required this.soldAt,
    required this.lines,
    required this.payments,
    this.discount = 0,
    this.customerId,
  });

  final String id;
  final DateTime soldAt;
  final List<SaleLine> lines;
  final List<PaymentDraft> payments;
  final int discount;
  final String? customerId;

  int get subtotal => lines.fold(0, (a, l) => a + l.lineTotal);
  int get total => subtotal - discount;
  int get utang => payments.where((p) => p.method == 'utang').fold(0, (a, p) => a + p.amount);
}

class SaleReceipt {
  const SaleReceipt(this.id, this.localNo);
  final String id;
  final String localNo;
}

class SaleSummary {
  const SaleSummary({
    required this.id,
    required this.localNo,
    required this.status,
    required this.total,
    required this.soldAt,
    this.customerName,
    required this.pending,
  });

  final String id;
  final String localNo;
  final String status; // completed | voided
  final int total;
  final DateTime soldAt;
  final String? customerName;

  /// The server has not confirmed this sale yet.
  final bool pending;
  bool get voided => status == 'voided';
}

class SaleItemView {
  const SaleItemView(this.name, this.qty, this.unitPrice, this.lineTotal);
  final String name;
  final double qty;
  final int unitPrice;
  final int lineTotal;
}

class SalePaymentView {
  const SalePaymentView(this.method, this.amount, this.tendered, this.reference);
  final String method;
  final int amount;
  final int? tendered;
  final String? reference;
  int get change => tendered == null ? 0 : tendered! - amount;
}

class SaleDetail {
  const SaleDetail({
    required this.summary,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.items,
    required this.payments,
    this.customerId,
  });

  final SaleSummary summary;
  final int subtotal;
  final int discount;
  final int tax;
  final List<SaleItemView> items;
  final List<SalePaymentView> payments;
  final String? customerId;

  int get change => payments.fold(0, (a, p) => a + p.change);
  int get utang => payments.where((p) => p.method == 'utang').fold(0, (a, p) => a + p.amount);
}

class TodayTotals {
  const TodayTotals({this.count = 0, this.total = 0, this.cash = 0, this.ewallet = 0, this.utang = 0});
  final int count;
  final int total;
  final int cash;
  final int ewallet;
  final int utang;
}

class CustomerView {
  const CustomerView({required this.id, required this.name, this.phone, required this.balance, required this.pending});
  final String id;
  final String name;
  final String? phone;

  /// What the customer owes, in centavos (negative = she has paid ahead).
  final int balance;
  final bool pending;
}

class LedgerEntryView {
  const LedgerEntryView({
    required this.kind,
    required this.amount,
    this.localNo,
    this.note,
    required this.at,
    required this.pending,
  });

  final String kind; // charge | payment | adjust
  final int amount;
  final String? localNo;
  final String? note;
  final DateTime at;
  final bool pending;
}

/// One product on the Stock screen. [qty] is null when nobody has counted it yet.
class StockRow {
  const StockRow({required this.product, required this.qty, required this.reorderPoint, required this.pending});
  final ProductView product;
  final double? qty;
  final double reorderPoint;

  /// Has a stock change the server has not confirmed yet.
  final bool pending;

  bool get counted => qty != null;

  /// At or below the reorder point (only when a reorder point is set and the product is counted).
  bool get low => qty != null && reorderPoint > 0 && qty! <= reorderPoint;
}

// ---- Phase 8: expenses and the day close (P8-02c) ----

/// Expense categories the server accepts (op_record_expense). UI labels come from ARB keys, never these strings.
const expenseCategories = ['stock_purchase', 'utilities', 'transport', 'wages', 'rent', 'other'];

/// Where the money came from: the drawer (counts against expected cash) or the e-wallet.
const expensePaidFrom = ['cash', 'ewallet'];

/// Rejection hints that mean "a supervisor approval is missing or no longer good". The op is parked as failed
/// (never retried on its own); the UI asks for a new approval and calls [SalesStore.requeueWithApproval],
/// or discards the op.
const approvalHints = {'approval_required', 'approval_invalid', 'approval_expired', 'approval_used'};
bool needsApproval(String? hint) => hint != null && approvalHints.contains(hint);

/// YYYY-MM-DD of the local calendar day of [t] (the business day; device time zone = tenant time zone for solo).
String dayKey(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

class ExpenseView {
  const ExpenseView({
    required this.id,
    required this.amount,
    required this.category,
    required this.paidFrom,
    this.note,
    required this.spentAt,
    this.voidedAt,
    this.voidReason,
    this.approvedBy,
    required this.pending,
    this.rejectedHint,
  });

  final String id;

  /// Centavos, always > 0.
  final int amount;
  final String category;
  final String paidFrom; // cash | ewallet
  final String? note;
  final DateTime spentAt;
  final DateTime? voidedAt;
  final String? voidReason;
  final String? approvedBy;

  /// An op for this expense (record or void) has not reached the server yet.
  final bool pending;

  /// The server refused an op for this expense (e.g. `approval_expired`); it waits for the user. Null when fine.
  final String? rejectedHint;

  bool get voided => voidedAt != null;
}

/// Today's expenses that count (voided ones left out). Centavos.
class ExpenseTotals {
  const ExpenseTotals({this.count = 0, this.total = 0, this.cash = 0, this.ewallet = 0});
  final int count;
  final int total;
  final int cash;
  final int ewallet;
}

class DayCloseView {
  const DayCloseView({
    required this.id,
    required this.day,
    required this.expectedCash,
    required this.countedCash,
    required this.difference,
    this.serverExpectedCash,
    this.note,
    required this.closedAt,
    this.approvedBy,
    required this.pending,
    this.rejectedHint,
  });

  final String id;

  /// YYYY-MM-DD.
  final String day;

  /// What the phone expected in the drawer when the count was saved (see [SalesStore.expectedCash]).
  final int expectedCash;
  final int countedCash;

  /// counted - expected: below zero = short (kulang), above zero = over (sobra).
  final int difference;

  /// The server's own figure for that day (null until pulled). Differs from [expectedCash] when the phone did not have
  /// every sale or payment yet; informational, never an error.
  final int? serverExpectedCash;
  final String? note;
  final DateTime closedAt;
  final String? approvedBy;
  final bool pending;
  final String? rejectedHint;
}

/// Everything the Sell, Utang and Today screens need from the device.
abstract class SalesStore {
  /// The store (location) this device sells for; sent with every sale.
  String? get locationId;
  set locationId(String? id);

  /// Commits a sale in one transaction: sale, lines, payments, stock effects, utang entry and the outbox op.
  Future<SaleReceipt> commitSale(SaleDraft draft, {required String opId});

  /// Cancels a completed sale: stock goes back, an utang charge is reversed. Queued as one op.
  Future<void> voidSale(String saleId, {required String opId, String? reason});

  Future<void> saveCustomer({required String id, required String name, String? phone, required String opId});
  /// Owner write-off or correction of a customer's balance. [amount] is signed: positive = owes more, negative = owes less.
  Future<void> adjustUtang({required String customerId, required int amount, String? note, required String opId});
  Future<void> recordUtangPayment({required String customerId, required int amount, String? note, required String opId});

  Stream<List<CustomerView>> watchCustomers();
  Stream<List<LedgerEntryView>> watchLedger(String customerId);
  Stream<List<SaleSummary>> watchSales({int limit = 200});
  Future<SaleDetail?> getSale(String saleId);

  /// Same as [getSale], and again whenever the sale or its sending state changes (e.g. the server confirmed it).
  Stream<SaleDetail?> watchSale(String saleId);
  Stream<TodayTotals> watchToday();

  /// Stock coming in. [cost] is the cost per unit in centavos (optional).
  Future<void> receiveStock({required String variantId, required double qty, int? cost, required String opId});

  /// "I counted [counted]": writes the difference between this and the stock shown now. [reason]: counted | damage | other.
  Future<void> adjustStock({required String variantId, required double counted, String reason = 'counted', required String opId});

  /// Stock screen rows (tracked products only), search by name, low ones first.
  Stream<List<StockRow>> watchStockList({String query = ''});

  /// Stock left per counted variant (server level plus what this device did that the server has not caught up on).
  /// Variants nobody has counted are left out.
  Stream<Map<String, double>> watchStock();
  Future<double> stockLeft(String variantId);

  /// The products to show as quick-tap tiles: most sold in the last 30 days, topped up with the newest products.
  Future<List<ProductView>> quickItems({int limit = 12});

  /// Variants the tindera pinned as favorites; they come first in [quickItems]. Kept on this device only.
  Future<Set<String>> pinnedVariants();
  Future<void> setPinned(String variantId, bool pinned);

  Future<String?> meta(String key);
  Future<void> setMeta(String key, String? value);

  // ---- expenses and the day close (P8-02c) ----
  //
  // Who may write: the owner and store managers, offline, with no extra step. A store SUPERVISOR needs a single-use
  // approval per op: make the expense / day close id first, call Backend.approveSupervisorAction (needs signal at
  // that moment), then pass the returned approval_id here. The queued op can then wait in the outbox up to 12 hours
  // with no signal (the approval expires after that and the op is parked with `approval_expired`).
  // A PIN is NEVER passed to, stored by, or queued from these methods: only the approval id travels.

  /// Records money spent. [amount] in centavos (> 0); [category] one of [expenseCategories]; [paidFrom] one of
  /// [expensePaidFrom]. Shown at once; queued as one `record_expense` op.
  Future<void> recordExpense({
    required String id,
    required int amount,
    required String category,
    String paidFrom = 'cash',
    String? note,
    DateTime? spentAt,
    String? approvalId,
    required String opId,
  });

  /// Voids an expense (a reversing state, never a delete). Queued as one `void_expense` op.
  Future<void> voidExpense({required String expenseId, String? reason, String? approvalId, required String opId});

  /// Expenses spent in [from, to) (local times), newest first, voided ones included (marked).
  Stream<List<ExpenseView>> watchExpenses({required DateTime from, required DateTime to});

  /// Today's (device local day) expense totals, voided ones left out.
  Stream<ExpenseTotals> watchTodayExpenses();

  /// Cash that should be in the drawer for the local day of [day]: cash taken by completed sales + utang payments
  /// - cash expenses that are not voided. Includes what this device has not sent yet. Centavos; may be below zero.
  /// (Opening float is not part of it.)
  Future<int> expectedCash(DateTime day);
  Stream<int> watchExpectedCash(DateTime day);

  /// Saves a cash count for the local day of [day]: stores the [expectedCash] of that moment, [countedCash] and the
  /// difference, and queues one `close_day` op. Several closes per day are allowed (a re-count).
  Future<void> closeDay({
    required String id,
    required DateTime day,
    required int countedCash,
    String? note,
    String? approvalId,
    required String opId,
  });

  /// The newest close for the local day of [day] (null when the day was not closed).
  Stream<DayCloseView?> watchLatestDayClose(DateTime day);

  /// Puts a parked (failed) record_expense / void_expense / close_day op back in the queue with a new supervisor
  /// approval id, after the server refused it with one of [approvalHints]. Same op id: a refused op left nothing on
  /// the server, so it is applied once.
  Future<void> requeueWithApproval({required String opId, required String approvalId});

  // ---- sync side ----
  /// Marks the stock/utang effects of an op as applied by the server at [appliedAt].
  Future<void> posOpApplied(String opId, String? appliedAt);

  /// Applies one sync_pull_sales response: recent sales (also from other devices) with lines and payments.
  /// Sales with unsent local changes are left alone.
  Future<void> applyPullSales(Map<String, dynamic> response);

  /// Applies one sync_pull_pos response; drops local effects the server's copy now covers.
  Future<void> applyPullPos(Map<String, dynamic> response);

  /// Applies one sync_pull_expenses response: the server's copy replaces the local row (so a local record or void is
  /// no longer counted separately). Rows with an unsent op are left alone until that op has gone.
  Future<void> applyPullExpenses(Map<String, dynamic> response);

  /// Applies one sync_pull_day_closes response, same rules as [applyPullExpenses].
  Future<void> applyPullDayCloses(Map<String, dynamic> response);
}
