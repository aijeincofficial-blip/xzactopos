import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../backend.dart';
import '../core/money.dart';
import '../core/printer_config.dart';
import '../core/receipt_printer.dart';
import '../core/supervisor_pin_dialog.dart';
import '../data/sales_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';

/// The receipt of a sale, styled after the authentic thermal paper ticket design
/// with scalloped tear edges, official XZACTO logo lockup, green payment status pill,
/// itemized product rows with stock counts, dashed divider, and dual action buttons.
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.saleId, this.justSold = false});
  final String saleId;

  /// Right after paying: the primary secondary button starts the next sale.
  final bool justSold;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  late Stream<SaleDetail?> _detail;
  late Stream<TodayTotals> _today;
  late Stream<List<StockRow>> _stock;
  late Future<String?> _storeName;
  bool _loaded = false;
  bool _autoPrinted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final store = CatalogScope.of(context).store;
    _detail = store.watchSale(widget.saleId);
    _today = store.watchToday();
    _stock = store.watchStockList();
    _storeName = store.meta('store_name');

    if (widget.justSold && activePrinterConfig.autoPrint && !_autoPrinted) {
      _autoPrinted = true;
      _detail.first.then((d) {
        if (mounted && d != null) _output(d, share: false);
      });
    }
  }

  Future<void> _cancelSale() async {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text(t.saleCancelTitle),
        content: Text(t.saleCancelBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.saleCancelNo),
          ),
          FilledButton(
            key: const Key('cancel-sale-yes'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.saleCancelYes),
          ),
        ],
      ),
    );
    if (yes != true) return;
    if (!mounted) return;

    if (scope.isCashier) {
      final backend = (scope.engine.api is Backend) ? scope.engine.api as Backend : null;
      if (backend != null) {
        final approval = await showSupervisorPinDialog(
          context,
          backend: backend,
          action: 'void_sale',
          refId: widget.saleId,
        );
        if (approval == null) return;
        if (!mounted) return;
      }
    }

    await scope.store.voidSale(widget.saleId, opId: const Uuid().v7());
    scope.engine.poke();
  }

  Future<void> _openReturnSheet(SaleDetail d) async {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final messenger = ScaffoldMessenger.of(context);
    final refunded = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (_) => _ReturnItemsSheet(detail: d),
    );
    if (refunded != null && mounted) {
      final formatted = Money(refunded, scope.store.baseCurrency).format(locale);
      messenger.showSnackBar(
        SnackBar(content: Text(t.saleReturnSuccess(formatted))),
      );
    }
  }

  ReceiptLabels _labels(AppLocalizations t) => ReceiptLabels(
    number: t.receiptNumber,
    subtotal: t.receiptSubtotal,
    discount: t.receiptDiscount,
    total: t.payTotal,
    cashReceived: t.receiptCashReceived,
    ewallet: t.payEwallet,
    card: t.payCard,
    change: t.payChange,
    onUtang: t.receiptOnUtang,
    cancelled: t.receiptCancelled,
    thanks: t.receiptThanks,
  );

  Future<void> _output(SaleDetail d, {required bool share}) async {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    try {
      final name = await _storeName ?? '';
      final labels = _labels(t);
      if (share) {
        await receiptPrinter.share(
          d,
          storeName: name,
          currency: scope.store.baseCurrency,
          locale: locale,
          labels: labels,
        );
      } else {
        await receiptPrinter.print(
          d,
          storeName: name,
          currency: scope.store.baseCurrency,
          locale: locale,
          labels: labels,
        );
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(t.receiptPrintFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final scope = CatalogScope.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    String money(int a) => Money(a, scope.store.baseCurrency).format(locale);

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0B132B) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                color: dark ? Colors.white : const Color(0xFF0F172A),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          'RECEIPT',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            color: dark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ),
      body: StreamBuilder<SaleDetail?>(
        stream: _detail,
        builder: (context, snapSale) {
          final d = snapSale.data;
          if (!snapSale.hasData &&
              snapSale.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (d == null) return Center(child: Text(t.errGeneric));

          final s = d.summary;
          final cash = d.payments
              .where((p) => p.method == 'cash')
              .fold<int>(0, (a, p) => a + (p.tendered ?? 0));
          final ewallet = d.payments
              .where((p) => p.method == 'ewallet')
              .fold<int>(0, (a, p) => a + p.amount);
          final card = d.payments
              .where((p) => p.method == 'card')
              .fold<int>(0, (a, p) => a + p.amount);

          return StreamBuilder<TodayTotals>(
            stream: _today,
            builder: (context, snapToday) {
              final todayTotal = snapToday.data?.total ?? s.total;

              return StreamBuilder<List<StockRow>>(
                stream: _stock,
                builder: (context, snapStock) {
                  final stockRows = snapStock.data ?? const <StockRow>[];
                  final stockMap = <String, StockRow>{
                    for (final r in stockRows)
                      r.product.name.trim().toLowerCase(): r,
                  };

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      // Authentic Thermal Paper Slip
                      CustomPaint(
                        painter: const _ReceiptTicketShadowPainter(
                          clipper: _ReceiptTicketClipper(),
                        ),
                        child: ClipPath(
                          clipper: const _ReceiptTicketClipper(),
                          child: Container(
                            color: Colors.white,
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Official XZACTO Logo Lockup
                                _buildReceiptLogo(),
                                const SizedBox(height: 6),

                                // Store Name
                                FutureBuilder<String?>(
                                  future: _storeName,
                                  builder: (_, n) => Text(
                                    n.data ?? 'Tindahan Ni Rosa',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Payment Status Pill Banner
                                _buildPaymentBanner(
                                  voided: s.voided,
                                  totalText: money(s.total),
                                  statusText: s.voided
                                      ? t.receiptCancelled
                                      : 'Payment Successful',
                                ),
                                const SizedBox(height: 16),

                                // Purchased Items List
                                for (final item in d.items) ...[
                                  _buildItemRow(
                                    item: item,
                                    stockRow:
                                        stockMap[item.name
                                            .trim()
                                            .toLowerCase()],
                                    moneyText: money(item.lineTotal),
                                    discountText: item.discount > 0 ? money(item.discount) : null,
                                  ),
                                ],
                                const SizedBox(height: 14),

                                // Dashed Divider
                                const _DashedDivider(),
                                const SizedBox(height: 14),

                                // Summary Breakdown
                                _buildSummaryRow(
                                  label: '${t.receiptSubtotal}:',
                                  value: money(d.subtotal),
                                ),
                                if (d.discount > 0)
                                  _buildSummaryRow(
                                    label: '${t.receiptDiscount}:',
                                    value: '−${money(d.discount)}',
                                    valueColor: const Color(0xFF10B981),
                                  ),
                                _buildSummaryRow(
                                  label: locale == 'fil'
                                      ? 'Benta ngayong araw:'
                                      : 'Sales Today:',
                                  value: money(todayTotal),
                                ),
                                _buildSummaryRow(
                                  label: '${t.payTotal}:',
                                  value: money(s.total),
                                  isTotal: true,
                                  key: const Key('receipt-total'),
                                ),
                                if (d.refundedTotal > 0)
                                  _buildSummaryRow(
                                    label: '${t.saleReturnTotal}:',
                                    value: '−${money(d.refundedTotal)}',
                                    valueColor: const Color(0xFFCD201D),
                                    key: const Key('receipt-refunded'),
                                  ),
                                if (cash > 0)
                                  _buildSummaryRow(
                                    label: locale == 'fil'
                                        ? 'Ibinayad (Cash):'
                                        : 'Paid via Cash:',
                                    value: money(cash),
                                  ),
                                if (ewallet > 0)
                                  _buildSummaryRow(
                                    label: locale == 'fil'
                                        ? 'Ibinayad (E-Wallet):'
                                        : 'Paid via E-Wallet:',
                                    value: money(ewallet),
                                  ),
                                if (card > 0)
                                  _buildSummaryRow(
                                    label: locale == 'fil'
                                        ? 'Ibinayad (Kard):'
                                        : 'Paid via Card:',
                                    value: money(card),
                                    key: const Key('receipt-card'),
                                  ),
                                if (d.change > 0)
                                  _buildSummaryRow(
                                    label: '${t.payChange}:',
                                    value: money(d.change),
                                    key: const Key('receipt-change'),
                                  ),
                                if (d.utang > 0) ...[
                                  _buildSummaryRow(
                                    label: '${t.receiptOnUtang}:',
                                    value: money(d.utang),
                                    valueColor: const Color(0xFFEF4444),
                                    key: const Key('receipt-utang'),
                                  ),
                                  if (s.customerName != null &&
                                      d.customerId != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: StreamBuilder(
                                        stream: scope.store.watchCustomers(),
                                        builder: (_, snap) {
                                          final c = (snap.data ?? const [])
                                              .where(
                                                (c) => c.id == d.customerId,
                                              );
                                          if (c.isEmpty) {
                                            return Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                s.customerName!,
                                                style:
                                                    theme.textTheme.bodySmall,
                                              ),
                                            );
                                          }
                                          return Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              t.receiptBalance(
                                                s.customerName!,
                                                money(c.first.balance),
                                              ),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFFEF4444),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                ],

                                const SizedBox(height: 14),
                                const _DashedDivider(),
                                const SizedBox(height: 12),

                                // Receipt Number and Timestamp
                                Text(
                                  t.receiptNumber(d.displayNo),
                                  key: const Key('receipt-no'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat.yMMMd(
                                    locale,
                                  ).add_jm().format(s.soldAt),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                if (s.voided)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      t.receiptCancelled,
                                      key: const Key('receipt-cancelled'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFFEF4444),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                if (s.pending)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.cloud_upload_outlined,
                                          size: 13,
                                          color: Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          t.notSentYet,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  t.receiptThanks,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Dual Action Buttons below Receipt Card
                      Row(
                        children: [
                          // Left Button: Print Receipt (only when this device can print or share a PDF)
                          if (receiptPrinter.available) ...[
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: FilledButton(
                                  key: const Key('receipt-print'),
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  onPressed: () => _output(d, share: false),
                                  child: Text(
                                    locale == 'fil'
                                        ? 'I-print ang Resibo'
                                        : 'Print Receipt',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],

                          // Right Button: New Transaction (if justSold) or Share (if viewing history)
                          if (widget.justSold || receiptPrinter.available)
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton(
                                  key: Key(
                                    widget.justSold
                                        ? 'receipt-next'
                                        : 'receipt-share',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: dark ? theme.colorScheme.surface : Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  onPressed: () {
                                    if (widget.justSold) {
                                      Navigator.of(context).pop();
                                    } else {
                                      _output(d, share: true);
                                    }
                                  },
                                  child: Text(
                                    widget.justSold
                                        ? (locale == 'fil'
                                              ? 'Bagong Benta'
                                              : 'New Transaction')
                                        : (locale == 'fil'
                                              ? 'I-share'
                                              : 'Share'),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),

                      // Partial item return button when sale has returnable items
                      if (d.hasReturnableItems)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              key: const Key('return-items-btn'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: dark ? theme.colorScheme.surface : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              onPressed: () => _openReturnSheet(d),
                              icon: const Icon(Icons.assignment_return_outlined, size: 18),
                              label: Text(t.saleReturnButton),
                            ),
                          ),
                        ),

                      // Cancel sale option if not voided and no partial returns exist
                      if (!s.voided && !d.hasPartialReturns)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Center(
                            child: TextButton.icon(
                              key: const Key('cancel-sale'),
                              onPressed: _cancelSale,
                              icon: Icon(
                                Icons.cancel_outlined,
                                size: 16,
                                color: theme.colorScheme.error,
                              ),
                              label: Text(
                                t.saleCancelButton,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // Official XZACTO Brand Logo Lockup for Receipt
  Widget _buildReceiptLogo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/brand/logo_mark.png',
          width: 36,
          height: 36,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'XZACTO',
              style: TextStyle(
                fontFamily: 'sans-serif',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: Color(0xFF0F172A),
                height: 1.0,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'POS APP',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
                color: Color(0xFF2EBCA4),
                height: 1.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Payment Status Banner
  Widget _buildPaymentBanner({
    required bool voided,
    required String totalText,
    required String statusText,
  }) {
    final bgColor = voided ? const Color(0xFFFEE2E2) : const Color(0xFFE8F7EE);
    final borderColor = voided
        ? const Color(0xFFFCA5A5)
        : const Color(0xFFBCE3C9);
    final iconColor = voided
        ? const Color(0xFFEF4444)
        : const Color(0xFF10B981);
    final icon = voided ? Icons.cancel_rounded : Icons.check_circle_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 8),
              Text(
                totalText,
                key: const Key('receipt-total-banner'),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: voided ? const Color(0xFFB91C1C) : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  // Itemized product row with thumbnail and stock count
  Widget _buildItemRow({
    required SaleItemView item,
    StockRow? stockRow,
    required String moneyText,
    String? discountText,
  }) {
    final qtyLeft = stockRow?.qty;
    final stockText = qtyLeft != null ? '(${qtyLeft.toInt()} left)' : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildItemThumb(item.name, stockRow?.product.photoPath),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (discountText != null)
                  Text(
                    '-$discountText off',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
                  ),
                if (item.returnedQty > 0)
                  Text(
                    '−${item.returnedQty == item.returnedQty.roundToDouble() ? item.returnedQty.toInt() : item.returnedQty} returned',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFCD201D),
                    ),
                  ),
                if (stockText != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    stockText,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            'x${item.qty == item.qty.roundToDouble() ? item.qty.toInt() : item.qty}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            '—',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            moneyText,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  // Product thumbnail matching the mockup's category tiles
  Widget _buildItemThumb(String name, String? photoPath) {
    if (photoPath != null && photoPath.isNotEmpty) {
      final file = File(photoPath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            width: 34,
            height: 34,
            cacheWidth: 80,
            cacheHeight: 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _fallbackItemThumb(name),
          ),
        );
      }
    }
    return _fallbackItemThumb(name);
  }

  Widget _fallbackItemThumb(String name) {
    final lower = name.toLowerCase();
    Color bg = const Color(0xFFEFF6FF);
    Color fg = const Color(0xFF2563EB);
    IconData icon = Icons.inventory_2_outlined;

    if (lower.contains('kape') || lower.contains('coffee')) {
      bg = const Color(0xFFEFF6FF);
      fg = const Color(0xFF2563EB);
      icon = Icons.local_cafe_outlined;
    } else if (lower.contains('sardinas') ||
        lower.contains('fish') ||
        lower.contains('can')) {
      bg = const Color(0xFFE6F8F3);
      fg = const Color(0xFF10B981);
      icon = Icons.lunch_dining_outlined;
    } else if (lower.contains('asukal') ||
        lower.contains('sugar') ||
        lower.contains('bigas')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
      icon = Icons.shopping_bag_outlined;
    }

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: fg),
    );
  }

  // Summary breakdown row
  Widget _buildSummaryRow({
    required String label,
    required String value,
    bool isTotal = false,
    Color? valueColor,
    Key? key,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isTotal ? 4 : 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isTotal ? 15.5 : 13.5,
                fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
                color: isTotal
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF475569),
              ),
            ),
          ),
          Text(
            value,
            key: key,
            style: TextStyle(
              fontSize: isTotal ? 18 : 13.5,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thermal Paper Ticket Custom Clipper & Shadow
// ---------------------------------------------------------------------------

class _ReceiptTicketClipper extends CustomClipper<Path> {
  const _ReceiptTicketClipper();

  static const double toothWidth = 8.0;
  static const double toothHeight = 3.5;
  static const double cornerRadius = 12.0;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = cornerRadius;
    final th = toothHeight;
    final tw = toothWidth;
    final path = Path();

    final topSpan = w - 2 * r;
    final topTeeth = (topSpan / tw).round().clamp(1, 100);
    final actualTw = topSpan / topTeeth;

    // Start at top-left, past corner
    path.moveTo(r, th);

    // Top serrated edge
    for (int i = 0; i < topTeeth; i++) {
      final startX = r + i * actualTw;
      final midX = startX + actualTw / 2;
      final endX = startX + actualTw;
      path.lineTo(midX, 0);
      path.lineTo(endX, th);
    }

    // Top-right corner
    path.quadraticBezierTo(w, th, w, th + r);

    // Right edge
    path.lineTo(w, h - th - r);

    // Bottom-right corner
    path.quadraticBezierTo(w, h - th, w - r, h - th);

    // Bottom serrated edge (right to left)
    for (int i = 0; i < topTeeth; i++) {
      final startX = w - r - i * actualTw;
      final midX = startX - actualTw / 2;
      final endX = startX - actualTw;
      path.lineTo(midX, h);
      path.lineTo(endX, h - th);
    }

    // Bottom-left corner
    path.quadraticBezierTo(0, h - th, 0, h - th - r);

    // Left edge
    path.lineTo(0, th + r);

    // Top-left corner
    path.quadraticBezierTo(0, th, r, th);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ReceiptTicketShadowPainter extends CustomPainter {
  const _ReceiptTicketShadowPainter({required this.clipper});
  final CustomClipper<Path> clipper;

  @override
  void paint(Canvas canvas, Size size) {
    final path = clipper.getClip(size);
    final shadowPaint = Paint()
      ..color = const Color(0x140F172A)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.save();
    canvas.translate(0, 6);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ReceiptTicketShadowPainter oldDelegate) =>
      false;
}

// ---------------------------------------------------------------------------
// Dashed Divider Widget
// ---------------------------------------------------------------------------

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  static const double dashHeight = 1.2;
  static const Color dashColor = Color(0xFFCBD5E1);
  static const double dashWidth = 5.0;
  static const double dashGap = 3.5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        final count = (boxWidth / (dashWidth + dashGap)).floor();
        if (count <= 0) return const SizedBox.shrink();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(count, (_) {
            return const SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: dashColor,
                  borderRadius: BorderRadius.all(Radius.circular(0.5)),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Partial Item Return Modal Bottom Sheet
// ---------------------------------------------------------------------------

class _ReturnItemsSheet extends StatefulWidget {
  const _ReturnItemsSheet({required this.detail});
  final SaleDetail detail;

  @override
  State<_ReturnItemsSheet> createState() => _ReturnItemsSheetState();
}

class _ReturnItemsSheetState extends State<_ReturnItemsSheet> {
  final Map<String, double> _returnQtyByVariant = {};
  final TextEditingController _reasonCtrl = TextEditingController();
  late String _refundMethod;
  bool _submitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final d = widget.detail;
    _refundMethod = (d.utang > 0 && d.customerId != null) ? 'utang' : 'cash';
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

  void _stepQty(SaleItemView item, double delta) {
    final maxRem = item.remainingQty;
    final current = _returnQtyByVariant[item.variantId] ?? 0;
    double next = current + delta;
    if (next < 0) next = 0;
    if (next > maxRem) next = maxRem;
    setState(() {
      if (next <= 0) {
        _returnQtyByVariant.remove(item.variantId);
      } else {
        _returnQtyByVariant[item.variantId] = next;
      }
      _errorText = null;
    });
  }

  Future<void> _submit() async {
    final scope = CatalogScope.of(context);
    final lines = <SaleReturnLine>[
      for (final e in _returnQtyByVariant.entries)
        if (e.value > 0) SaleReturnLine(variantId: e.key, qty: e.value),
    ];
    if (lines.isEmpty || _submitting) return;

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      SupervisorApprovalResult? approval;
      if (scope.isCashier) {
        final backend =
            (scope.engine.api is Backend) ? scope.engine.api as Backend : null;
        if (backend != null) {
          approval = await showSupervisorPinDialog(
            context,
            backend: backend,
            action: 'void_sale',
            refId: widget.detail.summary.id,
          );
          if (approval == null) {
            if (mounted) setState(() => _submitting = false);
            return;
          }
          if (!mounted) return;
        }
      }

      final refunded = await scope.store.returnSaleItems(
        widget.detail.summary.id,
        items: lines,
        refundMethod: _refundMethod,
        reason: _reasonCtrl.text,
        approvalId: approval?.approvalId,
        offlineApproval: approval?.offlineApproval,
        opId: const Uuid().v7(),
      );
      scope.engine.poke();
      if (mounted) Navigator.of(context).pop(refunded);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _errorText = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    String money(int a) => Money(a, scope.store.baseCurrency).format(locale);

    final d = widget.detail;
    final returnableItems = d.items
        .where((i) => i.variantId.isNotEmpty && i.remainingQty > 0)
        .toList();

    final refundPreview = computePartialReturnRefund(
      saleSubtotal: d.subtotal,
      saleDiscount: d.discount,
      saleTotal: d.summary.total,
      alreadyRefundedTotal: d.refundedTotal,
      items: d.items,
      returnByVariant: _returnQtyByVariant,
    );
    final hasSelection =
        _returnQtyByVariant.values.any((qty) => qty > 0) && !_submitting;

    final methods = <ButtonSegment<String>>[
      ButtonSegment(value: 'cash', label: Text(t.payCash)),
      ButtonSegment(value: 'ewallet', label: Text(t.payEwallet)),
      ButtonSegment(value: 'card', label: Text(t.payCard)),
      if (d.customerId != null)
        ButtonSegment(value: 'utang', label: Text(t.receiptOnUtang)),
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.saleReturnTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                t.saleReturnSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              for (final item in returnableItems) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withAlpha(90),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${money(item.unitPrice)} · ${t.saleReturnRemaining(_fmtQty(item.remainingQty))}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: Key('return-dec-${item.variantId}'),
                        onPressed: (_returnQtyByVariant[item.variantId] ?? 0) > 0
                            ? () => _stepQty(item, -1)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                      ),
                      SizedBox(
                        width: 36,
                        child: Text(
                          _fmtQty(_returnQtyByVariant[item.variantId] ?? 0),
                          key: Key('return-qty-${item.variantId}'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        key: Key('return-inc-${item.variantId}'),
                        onPressed: (_returnQtyByVariant[item.variantId] ?? 0) <
                                item.remainingQty
                            ? () => _stepQty(
                                  item,
                                  item.remainingQty -
                                              (_returnQtyByVariant[
                                                      item.variantId] ??
                                                  0) <
                                          1
                                      ? item.remainingQty -
                                          (_returnQtyByVariant[
                                                  item.variantId] ??
                                              0)
                                      : 1,
                                )
                            : null,
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              Text(
                t.saleReturnMethod,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: methods,
                selected: {_refundMethod},
                onSelectionChanged: (sel) {
                  setState(() => _refundMethod = sel.first);
                },
              ),

              const SizedBox(height: 16),
              TextField(
                key: const Key('return-reason-field'),
                controller: _reasonCtrl,
                decoration: InputDecoration(
                  labelText: t.saleReturnReason,
                  hintText: t.saleReturnReasonHint,
                ),
              ),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withAlpha(90),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      t.saleReturnTotal,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      money(refundPreview),
                      key: const Key('return-refund-preview'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),

              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.error,
                  ),
                ),
              ],

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(t.saleCancelNo),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('confirm-return-btn'),
                      onPressed: hasSelection ? _submit : null,
                      child: Text(t.saleReturnConfirm),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
