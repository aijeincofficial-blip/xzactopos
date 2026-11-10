import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../backend.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../data/transfer_models.dart';
import '../l10n/app_localizations.dart';
import 'transfer_create_screen.dart';
import 'transfer_receive_screen.dart';

class TransfersScreen extends StatefulWidget {
  const TransfersScreen({
    super.key,
    required this.backend,
    required this.locationId,
  });

  final Backend backend;
  final String locationId;

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<TransferHeader>> _incomingFuture;
  late Future<List<TransferHeader>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _reload();
  }

  void _reload() {
    setState(() {
      _incomingFuture = widget.backend.fetchIncomingTransfers(widget.locationId);
      _historyFuture = widget.backend.fetchTransferHistory(widget.locationId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.transfersTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: t.transfersIncoming),
            Tab(text: t.transfersHistory),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Incoming Tab
          RefreshIndicator(
            onRefresh: () async => _reload(),
            child: FutureBuilder<List<TransferHeader>>(
              future: _incomingFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final transfers = snapshot.data ?? [];
                if (transfers.isEmpty) {
                  return ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 80, left: Gap.xl, right: Gap.xl),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 48, color: scheme.outline),
                              const SizedBox(height: Gap.m),
                              Text(
                                t.transfersEmptyIncoming,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: scheme.outline, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(Gap.l),
                  itemCount: transfers.length,
                  separatorBuilder: (context, index) => const SizedBox(height: Gap.m),
                  itemBuilder: (context, i) {
                    final trf = transfers[i];
                    return _TransferCard(
                      transfer: trf,
                      onTap: () async {
                        final ok = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TransferReceiveScreen(
                              header: trf,
                              backend: widget.backend,
                            ),
                          ),
                        );
                        if (ok == true) _reload();
                      },
                    );
                  },
                );
              },
            ),
          ),

          // History Tab
          RefreshIndicator(
            onRefresh: () async => _reload(),
            child: FutureBuilder<List<TransferHeader>>(
              future: _historyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final transfers = snapshot.data ?? [];
                if (transfers.isEmpty) {
                  return ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 80, left: Gap.xl, right: Gap.xl),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.history_rounded, size: 48, color: scheme.outline),
                              const SizedBox(height: Gap.m),
                              Text(
                                t.transfersEmptyHistory,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: scheme.outline, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(Gap.l),
                  itemCount: transfers.length,
                  separatorBuilder: (context, index) => const SizedBox(height: Gap.m),
                  itemBuilder: (context, i) => _TransferCard(transfer: transfers[i]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('transfers-new-btn'),
        icon: const Icon(Icons.add_rounded),
        label: Text(t.transferNewAction),
        onPressed: () async {
          final res = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => TransferCreateScreen(
                backend: widget.backend,
                originLocationId: widget.locationId,
                originName: t.transfersTitle,
              ),
            ),
          );
          if (res == true) {
            _reload();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(t.transferCreatedSuccess),
                  backgroundColor: const Color(0xFF16A34A),
                ),
              );
            }
          }
        },
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.transfer, this.onTap});

  final TransferHeader transfer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final date = transfer.shippedAt ?? transfer.receivedAt;
    final when = date != null ? DateFormat.yMMMd(locale).add_jm().format(date) : '';

    return AppCard(
      padding: const EdgeInsets.all(Gap.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                transfer.transferNo,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
              _StatusBadge(status: transfer.status, hasDiscrepancy: transfer.hasDiscrepancy),
            ],
          ),
          const SizedBox(height: Gap.s),
          Text(
            '${t.transferFrom}: ${transfer.fromLocationName} -> ${transfer.toLocationName}',
            style: TextStyle(fontSize: 13, color: scheme.outline, fontWeight: FontWeight.w600),
          ),
          if (when.isNotEmpty)
            Text(when, style: TextStyle(fontSize: 11, color: scheme.outline)),
          const SizedBox(height: Gap.m),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${transfer.items.length} ${transfer.items.length == 1 ? "item" : "items"}',
                style: TextStyle(fontSize: 12, color: scheme.outline, fontWeight: FontWeight.w700),
              ),
              if (onTap != null && transfer.isShipped)
                FilledButton.tonal(
                  key: Key('receive-transfer-${transfer.id}'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                  onPressed: onTap,
                  child: Text(t.transferReceive, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.hasDiscrepancy});

  final String status;
  final bool hasDiscrepancy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'shipped':
        bg = scheme.primaryContainer;
        fg = scheme.onPrimaryContainer;
        label = 'In Transit';
      case 'received':
        if (hasDiscrepancy) {
          bg = scheme.errorContainer;
          fg = scheme.onErrorContainer;
          label = 'Discrepancy';
        } else {
          bg = scheme.secondaryContainer;
          fg = scheme.onSecondaryContainer;
          label = 'Received';
        }
      case 'cancelled':
        bg = scheme.surfaceContainerHighest;
        fg = scheme.outline;
        label = 'Cancelled';
      default:
        bg = scheme.surfaceContainerHighest;
        fg = scheme.onSurface;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}
