import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../core/money.dart';
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
  late Future<SaleDetail?> _detail;
  late Future<String?> _storeName;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final store = CatalogScope.of(context).store;
    _detail = store.getSale(widget.saleId);
    _storeName = store.meta('store_name');
  }

  Future<void> _cancelSale() async {
    final t = AppLocalizations.of(context);
    final scope = CatalogScope.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.saleCancelTitle),
        content: Text(t.saleCancelBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.saleCancelNo)),
          FilledButton(key: const Key('cancel-sale-yes'), onPressed: () => Navigator.pop(ctx, true), child: Text(t.saleCancelYes)),
        ],
      ),
    );
    if (yes != true) return;
    await scope.store.voidSale(widget.saleId, opId: const Uuid().v7());
    scope.engine.poke();
    if (!mounted) return;
    final next = scope.store.getSale(widget.saleId);
    setState(() {
      _detail = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final scope = CatalogScope.of(context);
    String money(int a) => Money(a, scope.store.baseCurrency).format(locale);
    return Scaffold(
      appBar: AppBar(title: Text(t.receiptTitle)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            key: const Key('receipt-next'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), textStyle: const TextStyle(fontSize: 20)),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(widget.justSold ? t.receiptNewSale : t.close),
          ),
        ),
      ),
      body: FutureBuilder<SaleDetail?>(
        future: _detail,
        builder: (context, snap) {
          final d = snap.data;
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (d == null) return Center(child: Text(t.errGeneric));
          final s = d.summary;
          final cash = d.payments.where((p) => p.method == 'cash').fold<int>(0, (a, p) => a + p.tendered!);
          final ewallet = d.payments.where((p) => p.method == 'ewallet').fold<int>(0, (a, p) => a + p.amount);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              FutureBuilder<String?>(
                future: _storeName,
                builder: (_, n) => Text(n.data ?? '',
                    textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              ),
              const SizedBox(height: 4),
              Text(t.receiptNumber(s.localNo), key: const Key('receipt-no'), textAlign: TextAlign.center),
              Text(DateFormat.yMMMd(locale).add_jm().format(s.soldAt), textAlign: TextAlign.center),
              if (s.voided)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(t.receiptCancelled,
                      key: const Key('receipt-cancelled'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 22, fontWeight: FontWeight.w800)),
                ),
              if (s.pending)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.cloud_upload_outlined, size: 16),
                    const SizedBox(width: 4),
                    Text(t.notSentYet),
                  ]),
                ),
              const Divider(height: 28),
              for (final i in d.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Text('${i.qty == i.qty.roundToDouble() ? i.qty.toInt() : i.qty} × ${i.name}',
                          style: const TextStyle(fontSize: 17)),
                    ),
                    Text(money(i.lineTotal), style: const TextStyle(fontSize: 17)),
                  ]),
                ),
              const Divider(height: 28),
              if (d.discount > 0) ...[
                _row(t.receiptSubtotal, money(d.subtotal)),
                _row(t.receiptDiscount, '−${money(d.discount)}'),
              ],
              _row(t.payTotal, money(s.total), big: true, key: const Key('receipt-total')),
              const SizedBox(height: 8),
              if (cash > 0) _row(t.receiptCashReceived, money(cash)),
              if (ewallet > 0) _row(t.payEwallet, money(ewallet)),
              if (d.change > 0) _row(t.payChange, money(d.change), key: const Key('receipt-change')),
              if (d.utang > 0) ...[
                _row(t.receiptOnUtang, money(d.utang), key: const Key('receipt-utang')),
                if (s.customerName != null && d.customerId != null)
                  StreamBuilder(
                    stream: scope.store.watchCustomers(),
                    builder: (_, snap) {
                      final c = (snap.data ?? const []).where((c) => c.id == d.customerId);
                      if (c.isEmpty) return Text(s.customerName!);
                      return Text(t.receiptBalance(s.customerName!, money(c.first.balance)));
                    },
                  ),
              ],
              const SizedBox(height: 24),
              if (!s.voided)
                Align(
                  child: TextButton.icon(
                    key: const Key('cancel-sale'),
                    onPressed: _cancelSale,
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(t.saleCancelButton),
                  ),
                ),
              Text(t.receiptThanks, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, String value, {bool big = false, Key? key}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: big ? 22 : 17, fontWeight: big ? FontWeight.w800 : null))),
          Text(value, key: key, style: TextStyle(fontSize: big ? 24 : 17, fontWeight: big ? FontWeight.w800 : null)),
        ]),
      );
}
