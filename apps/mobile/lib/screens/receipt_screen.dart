import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../core/money.dart';
import '../core/receipt_printer.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/sales_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';

/// The receipt of a sale, from this device. Shown right after paying and again from the sales list.
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.saleId, this.justSold = false});
  final String saleId;

  /// Right after paying: the main button starts the next sale.
  final bool justSold;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  late Stream<SaleDetail?> _detail;
  late Future<String?> _storeName;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final store = CatalogScope.of(context).store;
    _detail = store.watchSale(widget.saleId);
    _storeName = store.meta('store_name');
  }

  Future<void> _cancelSale() async {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gap.radiusL)),
        title: Text(t.saleCancelTitle),
        content: Text(t.saleCancelBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.saleCancelNo)),
          FilledButton(
            key: const Key('cancel-sale-yes'),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.saleCancelYes),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await scope.store.voidSale(widget.saleId, opId: const Uuid().v7());
    scope.engine.poke();
  }

  ReceiptLabels _labels(AppLocalizations t) => ReceiptLabels(
        number: t.receiptNumber,
        subtotal: t.receiptSubtotal,
        discount: t.receiptDiscount,
        total: t.payTotal,
        cashReceived: t.receiptCashReceived,
        ewallet: t.payEwallet,
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
        await receiptPrinter.share(d, storeName: name, currency: scope.store.baseCurrency, locale: locale, labels: labels);
      } else {
        await receiptPrinter.print(d, storeName: name, currency: scope.store.baseCurrency, locale: locale, labels: labels);
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
    final scheme = theme.colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    String money(int a) => Money(a, scope.store.baseCurrency).format(locale);

    return Scaffold(
      appBar: AppBar(title: Text(t.receiptTitle)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xs, Gap.xl, Gap.m),
          child: FilledButton(
            key: const Key('receipt-next'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: dark ? scheme.primary : const Color(0xFF0F172A),
              foregroundColor: dark ? scheme.onPrimary : Colors.white,
              shape: const StadiumBorder(),
              elevation: 3,
              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(widget.justSold ? t.receiptNewSale : t.close),
                if (widget.justSold) ...[
                  const SizedBox(width: Gap.m),
                  Text(
                    '› › ›',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: (dark ? scheme.onPrimary : Colors.white).withOpacity(0.6),
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<SaleDetail?>(
        stream: _detail,
        builder: (context, snap) {
          final d = snap.data;
          if (!snap.hasData && snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (d == null) return Center(child: Text(t.errGeneric));
          final s = d.summary;
          final cash = d.payments.where((p) => p.method == 'cash').fold<int>(0, (a, p) => a + (p.tendered ?? 0));
          final ewallet = d.payments.where((p) => p.method == 'ewallet').fold<int>(0, (a, p) => a + p.amount);

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.s),
            children: [
              // Digital Slip Ceramic Card
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.m),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Coin badge header
                    Center(
                      child: CoinBadge(
                        icon: s.voided ? Icons.close_rounded : Icons.receipt_long_rounded,
                        color: s.voided ? scheme.error : scheme.primary,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: Gap.s),
                    FutureBuilder<String?>(
                      future: _storeName,
                      builder: (_, n) => Text(
                        n.data ?? '',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.receiptNumber(s.localNo),
                      key: const Key('receipt-no'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      DateFormat.yMMMd(locale).add_jm().format(s.soldAt),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant.withOpacity(0.8)),
                    ),
                    if (s.voided)
                      Padding(
                        padding: const EdgeInsets.only(top: Gap.s),
                        child: Text(
                          t.receiptCancelled,
                          key: const Key('receipt-cancelled'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.error, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1),
                        ),
                      ),
                    if (s.pending)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_upload_outlined, size: 14, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(t.notSentYet, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    const Divider(height: 18, thickness: 1),
                    // Purchased items
                    for (final i in d.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '${i.qty == i.qty.roundToDouble() ? i.qty.toInt() : i.qty} × ${i.name}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Text(
                              money(i.lineTotal),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    const Divider(height: 18, thickness: 1),
                    // Subtotal / Discounts
                    if (d.discount > 0) ...[
                      _row(t.receiptSubtotal, money(d.subtotal), scheme),
                      _row(t.receiptDiscount, '−${money(d.discount)}', scheme, isDiscount: true),
                      const SizedBox(height: 2),
                    ],
                    // Total Amount Row
                    _row(t.payTotal, money(s.total), scheme, key: const Key('receipt-total'), big: true),
                    const SizedBox(height: 4),
                    // Breakdown details
                    if (cash > 0) _row(t.receiptCashReceived, money(cash), scheme),
                    if (ewallet > 0) _row(t.payEwallet, money(ewallet), scheme),
                    if (d.change > 0) _row(t.payChange, money(d.change), scheme, key: const Key('receipt-change'), isAccent: true),
                    if (d.utang > 0) ...[
                      _row(t.receiptOnUtang, money(d.utang), scheme, key: const Key('receipt-utang'), isWarning: true),
                      if (s.customerName != null && d.customerId != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: StreamBuilder(
                            stream: scope.store.watchCustomers(),
                            builder: (_, snap) {
                              final c = (snap.data ?? const []).where((c) => c.id == d.customerId);
                              if (c.isEmpty) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(s.customerName!, style: theme.textTheme.bodySmall),
                                );
                              }
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  t.receiptBalance(s.customerName!, money(c.first.balance)),
                                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                    if (receiptPrinter.available) ...[
                      const SizedBox(height: Gap.m),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            key: const Key('receipt-print'),
                            style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                            onPressed: () => _output(d, share: false),
                            icon: const Icon(Icons.print_outlined, size: 18),
                            label: Text(t.receiptPrint),
                          ),
                          const SizedBox(width: Gap.m),
                          OutlinedButton.icon(
                            key: const Key('receipt-share'),
                            style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                            onPressed: () => _output(d, share: true),
                            icon: const Icon(Icons.share_outlined, size: 18),
                            label: Text(t.receiptShare),
                          ),
                        ],
                      ),
                    ],
                    if (!s.voided)
                      Padding(
                        padding: const EdgeInsets.only(top: Gap.xs),
                        child: Align(
                          alignment: Alignment.center,
                          child: TextButton.icon(
                            key: const Key('cancel-sale'),
                            onPressed: _cancelSale,
                            icon: Icon(Icons.cancel_outlined, size: 18, color: scheme.error),
                            label: Text(t.saleCancelButton, style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      t.receiptThanks,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(
    String label,
    String value,
    ColorScheme scheme, {
    Key? key,
    bool big = false,
    bool isDiscount = false,
    bool isAccent = false,
    bool isWarning = false,
  }) {
    Color? color;
    if (isDiscount) color = const Color(0xFF10B981);
    if (isAccent) color = scheme.primary;
    if (isWarning) color = scheme.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: big ? 17 : 14,
                color: big ? null : scheme.onSurfaceVariant,
                fontWeight: big ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            key: key,
            style: TextStyle(
              fontSize: big ? 20 : 15,
              fontWeight: big ? FontWeight.w900 : FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
