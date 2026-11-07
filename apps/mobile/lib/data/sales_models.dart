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

// ---- Phase 8: load / e-wallet services (P8-06) ----

/// Service kinds the server accepts (op_record_service_txn). UI labels come from ARB keys, never these strings.
const serviceKinds = ['cash_in', 'cash_out', 'load', 'float_topup', 'float_withdraw', 'float_adjust'];

/// The kinds a customer pays a fee for (counted in [ServiceTotals.count]); the other three move the store's own float.
const customerServiceKinds = ['cash_in', 'cash_out', 'load'];

/// The store's wallets: GCash, Maya, the prepaid-load float, anything else. cash_in / cash_out never use `load`.
const serviceWallets = ['gcash', 'maya', 'load', 'other'];

/// What a service entry does to the drawer, in centavos (the fee is always collected in cash, on top of the principal):
/// cash_in +amount+fee, cash_out -amount+fee, load +price, float_topup -amount, float_withdraw +amount, float_adjust 0.
int serviceCashEffect(String kind, int amount, int fee, int? price) => switch (kind) {
      'cash_in' => amount + fee,
      'cash_out' => fee - amount,
      'load' => price ?? amount + fee,
      'float_topup' => -amount,
      'float_withdraw' => amount,
      _ => 0,
    };

/// What a service entry does to its wallet float, in centavos: cash_in / load / float_withdraw -amount,
/// cash_out / float_topup +amount, float_adjust +amount (signed).
int serviceFloatEffect(String kind, int amount) => switch (kind) {
      'cash_in' || 'load' || 'float_withdraw' => -amount,
      _ => amount,
    };

class ServiceTxnView {
  const ServiceTxnView({
    required this.id,
    required this.kind,
    required this.wallet,
    required this.amount,
    required this.fee,
    this.price,
    this.ref,
    this.note,
    required this.txnAt,
    this.voidedAt,
    this.voidReason,
    this.approvedBy,
    required this.pending,
    this.rejectedHint,
  });

  final String id;
  final String kind;
  final String wallet;

  /// Centavos: the principal (cash_in / cash_out), what the wallet paid (load), the float moved; signed for float_adjust.
  final int amount;

  /// The store's income for this entry (load: price - amount).
  final int fee;

  /// Cash the customer paid (load only).
  final int? price;

  /// Customer reference (phone, wallet reference no.).
  final String? ref;
  final String? note;
  final DateTime txnAt;
  final DateTime? voidedAt;
  final String? voidReason;
  final String? approvedBy;

  /// An op for this entry (record or void) has not reached the server yet.
  final bool pending;

  /// The server refused an op for this entry (e.g. `approval_expired`, `not_allowed`); it waits for the user.
  final String? rejectedHint;

  bool get voided => voidedAt != null;
  int get cashEffect => serviceCashEffect(kind, amount, fee, price);
  int get floatEffect => serviceFloatEffect(kind, amount);
}

/// Today's service entries that count (voided ones left out). Centavos.
class ServiceTotals {
  const ServiceTotals({this.count = 0, this.fees = 0, this.cashIn = 0, this.cashOut = 0, this.loadSales = 0, this.cash = 0});

  /// Customer services (cash_in + cash_out + load).
  final int count;

  /// Service income (fees and load margins).
  final int fees;

  /// Principal of the cash-ins and of the cash-outs; cash taken for loads (price).
  final int cashIn;
  final int cashOut;
  final int loadSales;

  /// What all service entries (float moves included) did to the drawer; part of [SalesStore.expectedCash].
  final int cash;
}

class WalletFloatView {
  const WalletFloatView({required this.wallet, required this.balance, required this.pending});
  final String wallet;

  /// Server balance + what this device did that the server's balance does not include yet. Centavos.
  final int balance;

  /// Includes effects of ops not yet covered by a pulled balance.
  final bool pending;

  /// Below zero: the wallet needs a top-up (allowed, never blocks an entry).
  bool get negative => balance < 0;
}

// ---- Phase 8: tingi / repack (P8-08) ----

/// Most packs opened at once, and most pieces per pack (the server refuses more).
const tingiMaxPacks = 10000;
const tingiMaxRatio = 10000;

/// half_up(n / d) for n >= 0, d > 0, exactly: floor((2n + d) / (2d)). BigInt so web builds (53-bit ints) stay exact.
int halfUpDiv(BigInt n, BigInt d) => ((BigInt.two * n + d) ~/ (BigInt.two * d)).toInt();

/// The server's `stock_blend_cost` with quantities in thousandths (stock quantities have 3 decimals there too):
/// the average cost after adding [addQtyMilli] units worth [addValueMilli] / 1000 centavos to [oldQtyMilli] units at
/// [oldCost]. Old level <= 0 or no old cost: the added units' own cost. Nothing added or no value: [oldCost].
int? _blendMilli(int oldQtyMilli, int? oldCost, int addQtyMilli, BigInt? addValueMilli) {
  if (addValueMilli == null || addQtyMilli <= 0) return oldCost;
  if (oldQtyMilli <= 0 || oldCost == null) return halfUpDiv(addValueMilli, BigInt.from(addQtyMilli));
  return halfUpDiv(BigInt.from(oldQtyMilli) * BigInt.from(oldCost) + addValueMilli, BigInt.from(oldQtyMilli + addQtyMilli));
}

/// New average cost after a stock in of [qty] at [unitCost] per unit (null: the average stays). Same rule as the server.
int? receiptAvgCost({required double oldQty, int? oldCost, required double qty, int? unitCost}) => _blendMilli(
    SaleLine.milli(oldQty), oldCost, SaleLine.milli(qty),
    unitCost == null ? null : BigInt.from(SaleLine.milli(qty)) * BigInt.from(unitCost));

/// New average cost of the piece after [pieces] come out of opened packs carrying [totalCost] centavos (null: the
/// average stays). The cost rule of P8-08, identical to the server's: half_up((Q x C + T) / (Q + N)) when the piece
/// level Q > 0 and its average C is known, else half_up(T / N).
int? conversionAvgCost({required double oldQty, int? oldCost, required int pieces, int? totalCost}) => _blendMilli(
    SaleLine.milli(oldQty), oldCost, pieces * 1000, totalCost == null ? null : BigInt.from(totalCost) * BigInt.from(1000));

/// What an opened pack did (also what the server will compute when the op reaches it).
class OpenedPack {
  const OpenedPack({
    required this.conversionId,
    required this.pieceVariantId,
    required this.packs,
    required this.pieces,
    this.packCost,
    this.totalCost,
    this.pieceCost,
  });

  final String conversionId;
  final String pieceVariantId;
  final int packs;
  final int pieces;

  /// Centavos: the pack's average cost (else its variant cost), packs x that, half_up(total / pieces). Null = unknown.
  final int? packCost;
  final int? totalCost;
  final int? pieceCost;
}

/// One opened pack, for a list (Stock history, Today).
class ConversionView {
  const ConversionView({
    required this.id,
    required this.packVariantId,
    required this.pieceVariantId,
    this.packName,
    this.pieceName,
    required this.packs,
    required this.ratio,
    required this.pieces,
    this.packCost,
    this.totalCost,
    this.pieceCost,
    this.note,
    required this.convertedAt,
    this.voidedAt,
    this.voidReason,
    required this.pending,
    this.rejectedHint,
  });

  final String id;
  final String packVariantId;
  final String pieceVariantId;

  /// Product names (null when the product is not on this device).
  final String? packName;
  final String? pieceName;
  final int packs;

  /// Pieces per pack at the time of opening.
  final int ratio;
  final int pieces;
  final int? packCost;
  final int? totalCost;
  final int? pieceCost;
  final String? note;
  final DateTime convertedAt;
  final DateTime? voidedAt;
  final String? voidReason;

  /// An op for this opening (open or void) has not reached the server yet.
  final bool pending;

  /// The server refused an op for this opening (e.g. `link_changed`, `not_allowed`); it waits for the user.
  final String? rejectedHint;

  bool get voided => voidedAt != null;
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
  /// - cash expenses that are not voided + the cash effect of service entries not voided (cash-in +amount+fee,
  /// cash-out -amount+fee, load +price, float top-up -amount, float withdraw +amount; see [serviceCashEffect]).
  /// Includes what this device has not sent yet. Centavos; may be below zero. (Opening float is not part of it.)
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

  // ---- load / e-wallet services (P8-06) ----
  //
  // cash_in / cash_out / load: anyone who sells, offline, no extra step. float_topup / float_withdraw and every void:
  // owner and store managers offline; a store SUPERVISOR needs a single-use approval per op (action
  // 'record_service_txn' with the new txn id, or 'void_service_txn' with the txn id), exactly like expenses.
  // float_adjust (and voiding one): owner or store manager only. A cashier's float / void op is refused (`not_allowed`).
  // The PIN never comes here: only the approval id travels.

  /// Records a service entry; shown at once and queued as one `record_service_txn` op. Money in centavos.
  /// [kind] one of [serviceKinds]; [wallet] one of [serviceWallets] (cash_in / cash_out not `load`).
  /// [amount] > 0 (signed, non-zero for float_adjust). [fee] >= 0 for cash_in / cash_out, 0 for float kinds.
  /// A load needs [price] (>= amount; the cash the customer pays); its fee is price - amount ([fee] may be left 0).
  /// float_adjust needs a [note]. [ref] is the customer's phone / reference (trimmed, max 200).
  Future<void> recordServiceTxn({
    required String id,
    required String kind,
    required String wallet,
    required int amount,
    int fee = 0,
    int? price,
    String? ref,
    String? note,
    DateTime? txnAt,
    String? approvalId,
    required String opId,
  });

  /// Voids a service entry (a reversing state, never a delete): its cash and float effects are taken back.
  /// Queued as one `void_service_txn` op.
  Future<void> voidServiceTxn({required String txnId, String? reason, String? approvalId, required String opId});

  /// Service entries in [from, to) (local times), newest first, voided ones included (marked).
  Stream<List<ServiceTxnView>> watchServiceTxns({required DateTime from, required DateTime to});

  /// Today's (device local day) service totals, voided ones left out.
  Stream<ServiceTotals> watchTodayServices();

  /// Float per wallet: the last pulled server balance + the effects of this device's ops it does not include yet
  /// (unsent, refused-but-not-discarded, or applied after that balance was read). Wallets in [serviceWallets] order;
  /// only wallets that have a balance or a local effect. Filtered to [locationId] when it is set.
  Stream<List<WalletFloatView>> watchWalletFloat();

  /// Puts a parked (failed) record_expense / void_expense / close_day / record_service_txn / void_service_txn op back
  /// in the queue with a new supervisor approval id, after the server refused it with one of [approvalHints]. Same op id: a refused op left nothing on
  /// the server, so it is applied once.
  Future<void> requeueWithApproval({required String opId, required String approvalId});

  // ---- tingi / repack (P8-08) ----
  //
  // The piece is its own product (with its own default variant); the pack variant carries the link. A variant is a pack
  // or a piece, never both. Who: owner and store managers (the server refuses others with `not_allowed`). Negative
  // stock is allowed (warn, never block), like a sale.

  /// Says "one [variantId] (the pack) breaks into [piecesPerPack] of [pieceVariantId]"; a null [pieceVariantId] clears
  /// the link. Applied here at once and queued as one `set_tingi_link` op (entity = the pack's product). Throws
  /// [ArgumentError] for a bad ratio or a self link, [StateError] for an unknown / archived product, a product that keeps
  /// no stock count, or a chain (the piece is a pack, or the pack is already someone's piece).
  Future<void> setTingiLink({required String variantId, String? pieceVariantId, int? piecesPerPack, required String opId});

  /// Same as [setTingiLink] with no piece.
  Future<void> clearTingiLink({required String variantId, required String opId});

  /// The piece product a pack variant breaks into (null when it has no link or the piece is not on this device).
  Future<ProductView?> tingiPiece(String packVariantId);

  /// Opens [packs] whole packs of [packVariantId]: packs out, packs x ratio pieces in, the pack cost carried into the
  /// pieces ([conversionAvgCost]). Both stock numbers change here at once (until the server's levels cover them) and
  /// one `open_pack` op is queued (entity = [id]). Opening more than is counted is allowed. Throws [ArgumentError] for a
  /// bad [packs], [StateError] when the product has no link, is archived or keeps no stock count.
  Future<OpenedPack> openPack({
    required String id,
    required String packVariantId,
    required int packs,
    String? note,
    DateTime? at,
    required String opId,
  });

  /// Takes an opening back (once): the packs return, the pieces go out (the piece count may go below zero), averages
  /// stay. Queued as one `void_open_pack` op.
  Future<void> voidOpenPack({required String conversionId, String? reason, required String opId});

  /// Openings in [from, to) (local times), newest first, voided ones included (marked).
  Stream<List<ConversionView>> watchConversions({required DateTime from, required DateTime to});

  /// The average cost this device uses for [variantId] (sale cost of goods, the pack cost when opening): the server's
  /// average, moved by this device's stock-ins and openings it has not caught up on (same integer rule). Null = none.
  Future<int?> averageCost(String variantId);

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

  /// Applies one sync_pull_service response: entries like [applyPullExpenses]; `floats` replace the stored balances,
  /// and local float effects the server applied at or before the response's `server_time` are dropped (that balance
  /// includes them).
  Future<void> applyPullService(Map<String, dynamic> response);

  /// Applies one sync_pull_conversions response, same rules as [applyPullExpenses] (a void still on its way is kept).
  /// The stock numbers are not touched: they come with sync_pull_pos.
  Future<void> applyPullConversions(Map<String, dynamic> response);
}
