import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../backend.dart';
import '../core/camera_scanner.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/transfer_models.dart';
import '../l10n/app_localizations.dart';

class TransferReceiveScreen extends StatefulWidget {
  const TransferReceiveScreen({
    super.key,
    required this.header,
    required this.backend,
  });

  final TransferHeader header;
  final Backend backend;

  @override
  State<TransferReceiveScreen> createState() => _TransferReceiveScreenState();
}

class _TransferReceiveScreenState extends State<TransferReceiveScreen> {
  late Map<String, double> _counts;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Default counted quantities to the shipped quantities
    _counts = {
      for (final item in widget.header.items) item.id: item.qtyShipped,
    };
  }

  bool get _hasDiscrepancy {
    for (final item in widget.header.items) {
      final counted = _counts[item.id] ?? 0.0;
      if (counted != item.qtyShipped) {
        return true;
      }
    }
    return false;
  }

  Future<void> _scanBarcode() async {
    await cameraScanner.scanMany(context, (code) async {
      final hit = widget.header.items.where(
        (i) => (i.barcode != null && i.barcode == code) || (i.sku != null && i.sku == code),
      ).firstOrNull;

      if (hit == null) {
        return ScanFeedback(code, ok: false);
      }

      if (mounted) {
        setState(() {
          final curr = _counts[hit.id] ?? 0.0;
          _counts[hit.id] = curr + 1.0;
        });
      }
      return ScanFeedback('${hit.productName} (+1)');
    });
  }

  Future<void> _confirmReceipt() async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    try {
      final payload = widget.header.items.map((i) {
        final counted = _counts[i.id] ?? 0.0;
        return {
          'variant_id': i.variantId,
          'qty_received': counted,
        };
      }).toList();

      await widget.backend.receiveTransfer(
        transferId: widget.header.id,
        items: payload,
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _hasDiscrepancy ? t.transferReceivedDiscrepancy : t.transferReceivedSuccess,
          ),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(t.errGeneric)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final when = widget.header.shippedAt != null
        ? DateFormat.yMMMd(locale).add_jm().format(widget.header.shippedAt!)
        : '';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.header.transferNo),
        actions: [
          if (cameraScanner.available)
            IconButton(
              key: const Key('scan-transfer-barcode'),
              tooltip: t.transferScanItem,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              onPressed: _scanBarcode,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(Gap.l),
                children: [
                  // Manifest Header Card
                  AppCard(
                    padding: const EdgeInsets.all(Gap.l),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CoinBadge(icon: Icons.local_shipping_rounded, color: scheme.primary, size: 36),
                            const SizedBox(width: Gap.m),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.header.transferNo,
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                  ),
                                  Text(
                                    '${t.transferFrom}: ${widget.header.fromLocationName} -> ${widget.header.toLocationName}',
                                    style: TextStyle(fontSize: 12, color: scheme.outline),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (when.isNotEmpty) ...[
                          const SizedBox(height: Gap.s),
                          Text('${t.transferShipped}: $when', style: TextStyle(fontSize: 12, color: scheme.outline)),
                        ],
                        if (widget.header.notes != null && widget.header.notes!.isNotEmpty) ...[
                          const SizedBox(height: Gap.s),
                          Text(widget.header.notes!, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: Gap.l),
                  Text(
                    t.transferReceivePrompt,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.outline),
                  ),
                  const SizedBox(height: Gap.s),

                  // Line items
                  for (final item in widget.header.items) ...[
                    _TransferItemCard(
                      item: item,
                      countedQty: _counts[item.id] ?? 0.0,
                      onQtyChanged: (q) => setState(() => _counts[item.id] = q),
                    ),
                    const SizedBox(height: Gap.s),
                  ],
                ],
              ),
            ),

            // Discrepancy warning banner if counts differ
            if (_hasDiscrepancy)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.l),
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(Gap.radiusM),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: Gap.s),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 20, color: scheme.onErrorContainer),
                      const SizedBox(width: Gap.s),
                      Expanded(
                        child: Text(
                          t.transferDiscrepancyWarning,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom Confirm Button
            Padding(
              padding: const EdgeInsets.all(Gap.l),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  key: const Key('confirm-receive-button'),
                  icon: _saving
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary))
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(t.transferConfirmReceive, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  onPressed: _saving ? null : _confirmReceipt,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransferItemCard extends StatelessWidget {
  const _TransferItemCard({
    required this.item,
    required this.countedQty,
    required this.onQtyChanged,
  });

  final TransferItem item;
  final double countedQty;
  final ValueChanged<double> onQtyChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final diff = countedQty - item.qtyShipped;
    final isDiscrepant = diff != 0;

    return AppCard(
      padding: const EdgeInsets.all(Gap.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.transferItemShipped(item.qtyShipped),
                      style: TextStyle(fontSize: 12, color: scheme.outline),
                    ),
                    if (item.barcode != null && item.barcode!.isNotEmpty)
                      Text(
                        'Barcode: ${item.barcode}',
                        style: TextStyle(fontSize: 11, color: scheme.outline),
                      ),
                  ],
                ),
              ),

              // Discrepancy badge
              if (isDiscrepant)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: diff < 0 ? scheme.errorContainer : scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    diff < 0 ? 'Short ${-diff}' : 'Over +$diff',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: diff < 0 ? scheme.onErrorContainer : scheme.onPrimaryContainer,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gap.s),

          // Stepper controls
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${t.transferItemCounted}:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.outline),
              ),
              const SizedBox(width: Gap.m),
              IconButton.outlined(
                icon: const Icon(Icons.remove, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: countedQty > 0 ? () => onQtyChanged(countedQty - 1.0) : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.m),
                child: Text(
                  countedQty == countedQty.roundToDouble()
                      ? '${countedQty.toInt()}'
                      : countedQty.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton.outlined(
                icon: const Icon(Icons.add, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: () => onQtyChanged(countedQty + 1.0),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
