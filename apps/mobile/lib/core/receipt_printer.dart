import '../data/sales_models.dart';

/// Where a finished receipt goes besides the screen. Thermal printers, sharing and PDF come in Phase 7;
/// until then the app uses [NoPrinter] and the receipt is shown on screen only.
abstract class ReceiptPrinter {
  bool get available;
  Future<void> print(SaleDetail sale, {required String storeName});
}

class NoPrinter implements ReceiptPrinter {
  const NoPrinter();
  @override
  bool get available => false;
  @override
  Future<void> print(SaleDetail sale, {required String storeName}) async {}
}
