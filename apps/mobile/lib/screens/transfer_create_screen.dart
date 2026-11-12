import 'package:flutter/material.dart';

import '../backend.dart';
import '../core/camera_scanner.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/transfer_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';

class TransferCreateScreen extends StatefulWidget {
  const TransferCreateScreen({
    super.key,
    required this.backend,
    required this.originLocationId,
    required this.originName,
    this.initialLine,
  });

  final Backend backend;
  final String originLocationId;
  final String originName;
  final TransferDraftLine? initialLine;

  @override
  State<TransferCreateScreen> createState() => _TransferCreateScreenState();
}

class _TransferCreateScreenState extends State<TransferCreateScreen> {
  bool _loadingDestinations = true;
  String? _destError;
  List<TransferLocationRef> _destinations = [];
  TransferLocationRef? _selectedDestination;

  final List<TransferDraftLine> _lines = [];
  final TextEditingController _notesController = TextEditingController();
  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    if (widget.initialLine != null) {
      _lines.add(widget.initialLine!);
    }
    _loadDestinations();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadDestinations() async {
    setState(() {
      _loadingDestinations = true;
      _destError = null;
    });

    try {
      final dests =
          await widget.backend.fetchTransferDestinations(widget.originLocationId);
      if (mounted) {
        setState(() {
          _destinations = dests;
          if (dests.isNotEmpty) {
            _selectedDestination = dests.first;
          }
          _loadingDestinations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _destError = e.toString();
          _loadingDestinations = false;
        });
      }
    }
  }

  Future<void> _openAddProductDialog() async {
    final scope = CatalogScope.of(context);
    final allProducts = await scope.store.watchProducts().first;

    if (!mounted) return;

    final selected = await showModalBottomSheet<TransferDraftLine>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddProductSheet(
        products: allProducts,
        existingIds: _lines.map((l) => l.variantId).toSet(),
      ),
    );

    if (selected != null) {
      setState(() {
        _lines.add(selected);
      });
    }
  }

  Future<void> _scanBarcodeToAdd() async {
    final code = await cameraScanner.scanOne(context);
    if (code == null || !mounted) return;

    final scope = CatalogScope.of(context);
    final match = await scope.store.findByBarcode(code.trim());
    if (!mounted) return;
    if (match != null) {
      if (_lines.any((l) => l.variantId == match.id)) {
        setState(() {
          final line = _lines.firstWhere((l) => l.variantId == match.id);
          line.qty += 1;
        });
      } else {
        setState(() {
          _lines.add(TransferDraftLine(
            variantId: match.id,
            sku: match.sku,
            productName: match.name,
            unit: match.unit,
            qty: 1,
          ));
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barcode "$code" not found in catalog'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _submitTransfer() async {
    final t = AppLocalizations.of(context);
    if (_selectedDestination == null) {
      setState(() => _submitError = t.transferSelectDestination);
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _submitError = t.transferNoItemsError);
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      await widget.backend.createAndShipTransfer(
        fromLocationId: widget.originLocationId,
        toLocationId: _selectedDestination!.id,
        items: _lines,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        shipNow: true,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final totalUnits = _lines.fold<double>(0.0, (acc, l) => acc + l.qty);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t.transferCreateTitle,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: _loadingDestinations
            ? const Center(child: CircularProgressIndicator())
            : _destError != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.transferDestinationsError),
                        const SizedBox(height: Gap.s),
                        FilledButton.tonal(
                          onPressed: _loadDestinations,
                          child: Text(t.tryAgain),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.m,
                      Gap.s,
                      Gap.m,
                      Gap.xxl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Origin & Destination Card
                        AppCard(
                          padding: const EdgeInsets.all(Gap.m),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CoinBadge(
                                    icon: Icons.store_rounded,
                                    color: scheme.primary,
                                    size: 32,
                                  ),
                                  const SizedBox(width: Gap.s),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t.transferOrigin,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: scheme.outline,
                                          ),
                                        ),
                                        Text(
                                          widget.originName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: Gap.m),
                              Divider(
                                height: 1,
                                color: scheme.outlineVariant
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: Gap.m),
                              Text(
                                t.transferDestination,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: Gap.xs),
                              DropdownButtonFormField<TransferLocationRef>(
                                isExpanded: true,
                                key: const Key('transfer-destination-picker'),
                                initialValue: _selectedDestination,
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: _destinations.map((d) {
                                  final typeLabel = d.isWarehouse
                                      ? 'Warehouse'
                                      : 'Store';
                                  return DropdownMenuItem(
                                    value: d,
                                    child: Text(
                                      '${d.name} ($typeLabel - ${d.code})',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (dest) {
                                  setState(() => _selectedDestination = dest);
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: Gap.m),

                        // Line Items Section Header
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                t.transferItemsSection.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: scheme.outline,
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton.filledTonal(
                              key: const Key('transfer-scan-item-btn'),
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.qr_code_scanner_rounded,
                                size: 18,
                              ),
                              tooltip: t.transferScanItem,
                              onPressed: _scanBarcodeToAdd,
                            ),
                            const SizedBox(width: Gap.xs),
                            FilledButton.tonalIcon(
                              key: const Key('transfer-add-item-btn'),
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: Text(
                                t.transferAddItem,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              onPressed: _openAddProductDialog,
                            ),
                          ],
                        ),
                        const SizedBox(height: Gap.xs),

                        if (_lines.isEmpty)
                          AppCard(
                            padding: const EdgeInsets.all(Gap.l),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.add_shopping_cart_rounded,
                                    size: 40,
                                    color: scheme.outline,
                                  ),
                                  const SizedBox(height: Gap.s),
                                  Text(
                                    t.transferEmptyItems,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: scheme.outline,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _lines.length,
                            itemBuilder: (ctx, index) {
                              final line = _lines[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: Gap.s),
                                child: AppCard(
                                  key: Key('transfer-line-${line.variantId}'),
                                  padding: const EdgeInsets.all(Gap.m),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              line.productName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              'SKU: ${line.sku}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: scheme.outline,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton.filledTonal(
                                            key: Key(
                                                'line-minus-${line.variantId}'),
                                            icon: const Icon(
                                              Icons.remove_rounded,
                                              size: 16,
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: line.qty > 1
                                                ? () => setState(
                                                    () => line.qty -= 1)
                                                : null,
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            child: Text(
                                              line.qty.toStringAsFixed(
                                                  line.qty == line.qty.roundToDouble()
                                                      ? 0
                                                      : 2),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          IconButton.filledTonal(
                                            key: Key(
                                                'line-plus-${line.variantId}'),
                                            icon: const Icon(
                                              Icons.add_rounded,
                                              size: 16,
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: () => setState(
                                                () => line.qty += 1),
                                          ),
                                          const SizedBox(width: Gap.xs),
                                          IconButton(
                                            key: Key(
                                                'line-remove-${line.variantId}'),
                                            icon: Icon(
                                              Icons.delete_outline_rounded,
                                              size: 20,
                                              color: scheme.error,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _lines.removeAt(index);
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: Gap.m),

                        // Notes Field
                        TextField(
                          key: const Key('transfer-notes-field'),
                          controller: _notesController,
                          decoration: InputDecoration(
                            labelText: t.transferNotesOptional,
                            hintText: t.transferNotesHint,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          maxLines: 2,
                        ),

                        if (_submitError != null) ...[
                          const SizedBox(height: Gap.s),
                          Text(
                            _submitError!,
                            style: TextStyle(
                              color: scheme.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],

                        const SizedBox(height: Gap.l),

                        // Dispatch & Ship Button
                        FilledButton.icon(
                          key: const Key('transfer-submit-ship'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.local_shipping_rounded),
                          label: Text(
                            '${t.transferShipAction} (${_lines.length} lines, $totalUnits units)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          onPressed: _submitting || _lines.isEmpty
                              ? null
                              : _submitTransfer,
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _AddProductSheet extends StatefulWidget {
  const _AddProductSheet({
    required this.products,
    required this.existingIds,
  });

  final List<dynamic> products;
  final Set<String> existingIds;

  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final available = widget.products.where((p) {
      final id = p.id as String;
      if (widget.existingIds.contains(id)) return false;
      if (_filter.trim().isEmpty) return true;
      final q = _filter.trim().toLowerCase();
      final name = (p.name as String).toLowerCase();
      final sku = (p.sku as String).toLowerCase();
      return name.contains(q) || sku.contains(q);
    }).toList();

    return Padding(
      padding: EdgeInsets.only(
        left: Gap.m,
        right: Gap.m,
        top: Gap.m,
        bottom: MediaQuery.of(context).viewInsets.bottom + Gap.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: Gap.s),
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Text(
                t.transferSelectProduct,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: Gap.s),
          TextField(
            key: const Key('add-product-search'),
            decoration: InputDecoration(
              hintText: t.searchProducts,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              isDense: true,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: Gap.s),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: available.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(Gap.l),
                    child: Text(
                      t.whUnknownProduct,
                      style: TextStyle(color: scheme.outline),
                    ),
                  )
                : ListView.builder(
                    itemCount: available.length,
                    itemBuilder: (ctx, index) {
                      final p = available[index];
                      return ListTile(
                        key: Key('product-choice-${p.id}'),
                        title: Text(
                          p.name as String,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text('SKU: ${p.sku}'),
                        trailing: const Icon(Icons.add_circle_outline_rounded),
                        onTap: () {
                          Navigator.pop(
                            context,
                            TransferDraftLine(
                              variantId: p.id as String,
                              sku: p.sku as String,
                              productName: p.name as String,
                              unit: (p.unit as String?) ?? 'pc',
                              qty: 1,
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
