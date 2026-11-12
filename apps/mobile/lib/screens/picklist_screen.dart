import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend.dart';
import '../core/camera_scanner.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/bin_models.dart';
import '../data/transfer_models.dart';
import '../l10n/app_localizations.dart';

class PickListScreen extends StatefulWidget {
  const PickListScreen({
    super.key,
    required this.backend,
    required this.warehouseId,
    required this.warehouseName,
    this.initialTransferId,
    this.initialTransferNo,
  });

  final Backend backend;
  final String warehouseId;
  final String warehouseName;
  final String? initialTransferId;
  final String? initialTransferNo;

  @override
  State<PickListScreen> createState() => _PickListScreenState();
}

class _PickListScreenState extends State<PickListScreen> {
  bool _loading = true;
  String? _error;
  List<TransferHeader> _draftTransfers = [];
  TransferHeader? _selectedTransfer;
  PickListSummary? _pickList;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (widget.initialTransferId != null) {
        await _loadPickList(widget.initialTransferId!);
      } else {
        final drafts = await widget.backend.fetchDraftTransfers(widget.warehouseId);
        setState(() {
          _draftTransfers = drafts;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadPickList(String transferId) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var pl = await widget.backend.fetchPickListForTransfer(transferId);
      if (pl == null) {
        await widget.backend.generatePickList(transferId);
        pl = await widget.backend.fetchPickListForTransfer(transferId);
      }
      if (mounted) {
        setState(() {
          _pickList = pl;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _openPickItemSheet(PickListItem item) {
    if (_pickList == null) return;
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PickItemSheet(
        backend: widget.backend,
        pickListId: _pickList!.id,
        item: item,
      ),
    ).then((picked) {
      if (picked == true && _selectedTransfer != null) {
        _loadPickList(_selectedTransfer!.id);
      } else if (picked == true && widget.initialTransferId != null) {
        _loadPickList(widget.initialTransferId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.pickListTitle),
            Text(
              widget.warehouseName,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 48, color: scheme.error),
                        const SizedBox(height: Gap.m),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: Gap.m),
                        FilledButton.tonal(
                          onPressed: _load,
                          child: Text(t.whCountRetry),
                        ),
                      ],
                    ),
                  ),
                )
              : _pickList != null
                  ? _buildPickListView(t, scheme)
                  : _buildDraftTransfersView(t, scheme),
    );
  }

  Widget _buildDraftTransfersView(AppLocalizations t, ColorScheme scheme) {
    if (_draftTransfers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.checklist_rounded, size: 56, color: scheme.outline),
              const SizedBox(height: Gap.m),
              Text(
                t.pickListNoDrafts,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(Gap.m),
      itemCount: _draftTransfers.length,
      itemBuilder: (context, idx) {
        final trf = _draftTransfers[idx];
        return Padding(
          padding: const EdgeInsets.only(bottom: Gap.m),
          child: AppCard(
            key: Key('transfer-draft-${trf.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      trf.transferNo,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const Spacer(),
                    StatusPill(
                      label: t.pickListPending,
                      color: scheme.primaryContainer,
                      textColor: scheme.onPrimaryContainer,
                    ),
                  ],
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  '${t.transferTo}: ${trf.toLocationName}',
                  style: TextStyle(fontSize: 13, color: scheme.outline),
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  t.pickListItemsCount(trf.items.length),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: Gap.m),
                FilledButton.icon(
                  key: Key('open-picklist-btn-${trf.transferNo}'),
                  icon: const Icon(Icons.inventory_2_rounded, size: 18),
                  label: Text(t.pickListAction),
                  onPressed: () {
                    setState(() => _selectedTransfer = trf);
                    _loadPickList(trf.id);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPickListView(AppLocalizations t, ColorScheme scheme) {
    final pl = _pickList!;
    final total = pl.items.length;
    final picked = pl.completedCount;
    final progress = total > 0 ? picked / total : 0.0;

    return ListView(
      padding: const EdgeInsets.all(Gap.m),
      children: [
        // Header card with progress
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    pl.pickListNo,
                    key: const Key('picklist-no'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  StatusPill(
                    label: pl.status == 'completed'
                        ? t.pickListCompleted
                        : pl.status == 'in_progress'
                            ? t.pickListInProgress
                            : t.pickListPending,
                    color: pl.status == 'completed' ? scheme.success.withValues(alpha: 0.14) : scheme.primaryContainer,
                    textColor: pl.status == 'completed' ? scheme.success : scheme.onPrimaryContainer,
                  ),
                ],
              ),
              const SizedBox(height: Gap.s),
              Text(
                t.pickListProgress(picked, total),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: Gap.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: scheme.chipFill,
                  color: pl.isAllPicked ? scheme.success : scheme.primary,
                ),
              ),
              const SizedBox(height: Gap.s),
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: scheme.outline),
                  const SizedBox(width: Gap.xs),
                  Expanded(
                    child: Text(
                      t.pickListStagingNotice,
                      style: TextStyle(fontSize: 11, color: scheme.outline),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: Gap.m),
        Row(
          children: [
            Icon(Icons.route_outlined, size: 16, color: scheme.primary),
            const SizedBox(width: Gap.xs),
            Text(
              t.pickListWalkingRoute,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: Gap.s),

        // Items list ordered by walking route
        for (final item in pl.items)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.s),
            child: AppCard(
              key: Key('picklist-item-${item.sku}'),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoinBadge(
                  icon: item.isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.inventory_2_outlined,
                  color: item.isCompleted ? scheme.success : scheme.primary,
                  size: 36,
                ),
                const SizedBox(width: Gap.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      Text(
                        'SKU: ${item.sku}',
                        style: TextStyle(fontSize: 12, color: scheme.outline),
                      ),
                      const SizedBox(height: Gap.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.chipFill,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${item.binCode} (${item.locationInfo.isNotEmpty ? item.locationInfo : "Floor"})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(height: Gap.xs),
                      Text(
                        'Picked: ${item.qtyPicked} / ${item.qtyRequested}',
                        key: Key('pick-qty-label-${item.sku}'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: item.isCompleted ? scheme.success : scheme.onSurface,
                        ),
                      ),
                      if (item.shortReason != null && item.shortReason!.isNotEmpty)
                        Text(
                          'Short reason: ${item.shortReason}',
                          style: TextStyle(fontSize: 11, color: scheme.error),
                        ),
                    ],
                  ),
                ),
                if (!item.isCompleted)
                  ElevatedButton(
                    key: Key('pick-btn-${item.sku}'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: Gap.m),
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                    ),
                    onPressed: () => _openPickItemSheet(item),
                    child: Text(t.pickListItemPick),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PickItemSheet extends StatefulWidget {
  const _PickItemSheet({
    required this.backend,
    required this.pickListId,
    required this.item,
  });

  final Backend backend;
  final String pickListId;
  final PickListItem item;

  @override
  State<_PickItemSheet> createState() => _PickItemSheetState();
}

class _PickItemSheetState extends State<_PickItemSheet> {
  late double _qtyToPick;
  final _shortReasonController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Default to remaining needed
    _qtyToPick = widget.item.qtyRequested - widget.item.qtyPicked;
    if (_qtyToPick < 0) _qtyToPick = 0;
  }

  @override
  void dispose() {
    _shortReasonController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final code = await cameraScanner.scanOne(context);
    if (code == null || !mounted) return;

    final trimmed = code.trim().toUpperCase();
    if (trimmed == widget.item.sku.toUpperCase() || trimmed == widget.item.binCode.toUpperCase()) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barcode matched!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scanned "$code" does not match SKU ${widget.item.sku} or Bin ${widget.item.binCode}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (_qtyToPick < 0) {
      setState(() => _error = 'Quantity cannot be negative');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.backend.confirmPickItem(
        pickListId: widget.pickListId,
        itemId: widget.item.id,
        qtyPicked: _qtyToPick,
        shortReason: _qtyToPick < widget.item.qtyRequested
            ? _shortReasonController.text.trim()
            : null,
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
                icon: Icons.inventory_2_rounded,
                color: scheme.primary,
                size: 36,
              ),
              const SizedBox(width: Gap.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.pickListItemPick,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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

          // Location Box
          Container(
            padding: const EdgeInsets.all(Gap.m),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined, size: 20, color: scheme.primary),
                const SizedBox(width: Gap.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bin: ${widget.item.binCode}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      if (widget.item.locationInfo.isNotEmpty)
                        Text(
                          widget.item.locationInfo,
                          style: TextStyle(fontSize: 12, color: scheme.outline),
                        ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('pick-scan-btn'),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                  label: Text(t.pickListScanItem),
                  onPressed: _scanBarcode,
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.m),

          // Quantity Stepper
          Text(
            t.pickListQtyToPick,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Gap.xs),
          Row(
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.remove),
                onPressed: _qtyToPick > 0
                    ? () => setState(() => _qtyToPick = (_qtyToPick - 1).clamp(0, widget.item.qtyRequested))
                    : null,
              ),
              Expanded(
                child: Text(
                  _qtyToPick.toString(),
                  key: const Key('pick-qty-value'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.add),
                onPressed: _qtyToPick < widget.item.qtyRequested
                    ? () => setState(() => _qtyToPick = (_qtyToPick + 1).clamp(0, widget.item.qtyRequested))
                    : null,
              ),
              const SizedBox(width: Gap.s),
              TextButton(
                key: const Key('pick-all-btn'),
                onPressed: () => setState(() => _qtyToPick = widget.item.qtyRequested),
                child: const Text('Pick All'),
              ),
            ],
          ),

          if (_qtyToPick < widget.item.qtyRequested) ...[
            const SizedBox(height: Gap.m),
            Text(
              t.pickListShortReason,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Gap.xs),
            TextField(
              key: const Key('pick-short-reason-field'),
              controller: _shortReasonController,
              decoration: InputDecoration(
                hintText: t.pickListShortReasonHint,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: Gap.s),
            Text(_error!, style: TextStyle(color: scheme.error, fontSize: 13)),
          ],

          const SizedBox(height: Gap.l),
          FilledButton(
            key: const Key('pick-confirm-btn'),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(t.pickListConfirmPick),
          ),
        ],
      ),
    );
  }
}
