import 'package:flutter/material.dart';

import '../backend.dart';
import '../core/camera_scanner.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/bin_models.dart';
import '../l10n/app_localizations.dart';

class PutawayScreen extends StatefulWidget {
  const PutawayScreen({
    super.key,
    required this.backend,
    required this.warehouseId,
    required this.warehouseName,
  });

  final Backend backend;
  final String warehouseId;
  final String warehouseName;

  @override
  State<PutawayScreen> createState() => _PutawayScreenState();
}

class _PutawayScreenState extends State<PutawayScreen> {
  bool _loading = true;
  String? _error;
  List<ReceivingStockItem> _items = [];
  List<WarehouseBin> _bins = [];
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await widget.backend.fetchReceivingStock(widget.warehouseId);
      final bins = await widget.backend.fetchWarehouseBins(widget.warehouseId);
      if (mounted) {
        setState(() {
          _items = items;
          _bins = bins;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<ReceivingStockItem> get _filteredItems {
    if (_filter.trim().isEmpty) return _items;
    final q = _filter.trim().toLowerCase();
    return _items.where((i) {
      return i.productName.toLowerCase().contains(q) ||
          i.sku.toLowerCase().contains(q) ||
          i.binCode.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openPutawayDialog(ReceivingStockItem item) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PutawayItemSheet(
        backend: widget.backend,
        warehouseId: widget.warehouseId,
        item: item,
        bins: _bins,
      ),
    );

    if (result == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).putawaySuccess),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.putawayTitle,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            Text(
              widget.warehouseName,
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('putaway-refresh-btn'),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _loadData,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search / Filter Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.m, Gap.s, Gap.m, Gap.xs),
              child: TextField(
                key: const Key('putaway-search-field'),
                decoration: InputDecoration(
                  hintText: t.searchProducts,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _filter.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => setState(() => _filter = ''),
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(t.putawayError),
                              const SizedBox(height: Gap.s),
                              FilledButton.tonal(
                                onPressed: _loadData,
                                child: Text(t.tryAgain),
                              ),
                            ],
                          ),
                        )
                      : _filteredItems.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(Gap.xl),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 56,
                                      color: scheme.outline,
                                    ),
                                    const SizedBox(height: Gap.m),
                                    Text(
                                      _filter.isNotEmpty
                                          ? t.whUnknownProduct
                                          : t.putawayEmptyTitle,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: Gap.xs),
                                    Text(
                                      _filter.isNotEmpty
                                          ? t.whScanUnknown
                                          : t.putawayEmptyBody,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: scheme.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                Gap.m,
                                Gap.s,
                                Gap.m,
                                Gap.xxl,
                              ),
                              itemCount: _filteredItems.length,
                              itemBuilder: (ctx, index) {
                                final item = _filteredItems[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: Gap.s),
                                  child: AppCard(
                                    key: Key('putaway-item-${item.variantId}'),
                                    padding: const EdgeInsets.all(Gap.m),
                                    child: Row(
                                      children: [
                                        CoinBadge(
                                          icon: Icons.move_to_inbox_rounded,
                                          color: scheme.primary,
                                          size: 40,
                                        ),
                                        const SizedBox(width: Gap.m),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.productName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'SKU: ${item.sku} • Bin: ${item.binCode}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: scheme.outline,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: scheme.primaryContainer,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '${t.putawayAvailable}: ${item.qtyOnHand}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: scheme
                                                        .onPrimaryContainer,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        FilledButton(
                                          key: Key(
                                              'putaway-btn-${item.variantId}'),
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                            shape: const StadiumBorder(),
                                            minimumSize: const Size(0, 36),
                                          ),
                                          onPressed: () =>
                                              _openPutawayDialog(item),
                                          child: Text(
                                            t.putawayAction,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PutawayItemSheet extends StatefulWidget {
  const _PutawayItemSheet({
    required this.backend,
    required this.warehouseId,
    required this.item,
    required this.bins,
  });

  final Backend backend;
  final String warehouseId;
  final ReceivingStockItem item;
  final List<WarehouseBin> bins;

  @override
  State<_PutawayItemSheet> createState() => _PutawayItemSheetState();
}

class _PutawayItemSheetState extends State<_PutawayItemSheet> {
  WarehouseBin? _selectedBin;
  late double _qty;
  late TextEditingController _qtyController;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _qty = widget.item.qtyOnHand;
    _qtyController = TextEditingController(text: _qty.toString());
    // Auto-select first non-receiving bin if available
    final candidates = widget.bins
        .where((b) => b.id != widget.item.binId && b.active)
        .toList();
    if (candidates.isNotEmpty) {
      _selectedBin = candidates.first;
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _onScanBin() async {
    final code = await cameraScanner.scanOne(context);
    if (code == null || !mounted) return;
    final match = widget.bins.where((b) =>
        b.code.toUpperCase() == code.trim().toUpperCase() &&
        b.id != widget.item.binId);
    if (match.isNotEmpty) {
      setState(() => _selectedBin = match.first);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bin "$code" not found in warehouse'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (_selectedBin == null) {
      setState(() => _error = 'Please select a destination bin');
      return;
    }
    if (_qty <= 0 || _qty > widget.item.qtyOnHand) {
      setState(() => _error = 'Invalid quantity to put away');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.backend.executePutaway(
        warehouseId: widget.warehouseId,
        fromBinId: widget.item.binId,
        toBinId: _selectedBin!.id,
        variantId: widget.item.variantId,
        qty: _qty,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final eligibleBins = widget.bins
        .where((b) => b.id != widget.item.binId && b.active)
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: Gap.l,
        right: Gap.l,
        top: Gap.l,
        bottom: MediaQuery.of(context).viewInsets.bottom + Gap.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CoinBadge(
                icon: Icons.move_to_inbox_rounded,
                color: scheme.primary,
                size: 36,
              ),
              const SizedBox(width: Gap.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.putawayDialogTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      widget.item.productName,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: Gap.m),

          // Destination Bin Row & Picker
          Row(
            children: [
              Text(
                t.putawayDestinationBin,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                key: const Key('putaway-scan-bin-btn'),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                label: Text(t.putawayScanBin),
                onPressed: _onScanBin,
              ),
            ],
          ),
          const SizedBox(height: 4),

          DropdownButtonFormField<WarehouseBin>(
            isExpanded: true,
            key: const Key('putaway-bin-dropdown'),
            initialValue: _selectedBin,
            decoration: InputDecoration(
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: eligibleBins.map((bin) {
              return DropdownMenuItem<WarehouseBin>(
                value: bin,
                child: Text(
                  bin.locationLabel,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (bin) => setState(() => _selectedBin = bin),
          ),

          const SizedBox(height: Gap.m),

          // Quantity Stepper
          Row(
            children: [
              Text(
                t.putawayQuantity,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                'Max: ${widget.item.qtyOnHand}',
                style: TextStyle(fontSize: 12, color: scheme.outline),
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Row(
            children: [
              IconButton.filledTonal(
                key: const Key('putaway-qty-minus'),
                icon: const Icon(Icons.remove_rounded),
                onPressed: _qty > 1
                    ? () {
                        setState(() {
                          _qty -= 1;
                          _qtyController.text = _qty.toString();
                        });
                      }
                    : null,
              ),
              const SizedBox(width: Gap.s),
              Expanded(
                child: TextField(
                  key: const Key('putaway-qty-field'),
                  controller: _qtyController,
                  textAlign: TextAlign.center,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(isDense: true),
                  onChanged: (v) {
                    final d = double.tryParse(v);
                    if (d != null && d > 0) {
                      setState(() => _qty = d);
                    }
                  },
                ),
              ),
              const SizedBox(width: Gap.s),
              IconButton.filledTonal(
                key: const Key('putaway-qty-plus'),
                icon: const Icon(Icons.add_rounded),
                onPressed: _qty < widget.item.qtyOnHand
                    ? () {
                        setState(() {
                          _qty += 1;
                          _qtyController.text = _qty.toString();
                        });
                      }
                    : null,
              ),
              const SizedBox(width: Gap.s),
              OutlinedButton(
                key: const Key('putaway-qty-max'),
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: () {
                  setState(() {
                    _qty = widget.item.qtyOnHand;
                    _qtyController.text = _qty.toString();
                  });
                },
                child: const Text('MAX', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: Gap.s),
            Text(
              _error!,
              style: TextStyle(
                color: scheme.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: Gap.l),

          // Confirm Action
          FilledButton.icon(
            key: const Key('putaway-confirm-btn'),
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(t.putawayConfirm),
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}
