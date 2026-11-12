import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../core/theme.dart';
import '../core/ui.dart';
import '../data/sales_models.dart';
import '../l10n/app_localizations.dart';
import 'cart.dart';

const _uuid = Uuid();

class HeldCart {
  const HeldCart({
    required this.id,
    required this.label,
    required this.createdAt,
    required this.lines,
  });

  final String id;
  final String label;
  final DateTime createdAt;
  final List<CartLine> lines;

  int get subtotal => lines.fold(0, (a, l) => a + l.lineTotal);
  int get itemCount => lines.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'lines': [for (final l in lines) l.toJson()],
      };

  static HeldCart? tryFromJson(Map<String, dynamic> m) {
    final id = m['id'];
    final rawLines = m['lines'];
    if (id is! String || id.isEmpty || rawLines is! List || rawLines.isEmpty) {
      return null;
    }
    try {
      final parsedLines = [
        for (final item in rawLines.cast<Map<String, dynamic>>()) CartLine.fromJson(item),
      ];
      final rawAt = m['createdAt'];
      final createdAt = (rawAt is String ? DateTime.tryParse(rawAt)?.toLocal() : null) ?? DateTime.now();
      return HeldCart(
        id: id,
        label: (m['label'] is String ? (m['label'] as String).trim() : ''),
        createdAt: createdAt,
        lines: parsedLines,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Device-local parked carts scoped per active store so cashiers can suspend a cart,
/// ring up the next customer in line, and resume with zero lost line overrides or discounts.
class HeldCarts extends ChangeNotifier {
  HeldCarts(this.store);

  static const maxHeldCarts = 20;
  final SalesStore store;
  final items = <HeldCart>[];

  bool get isEmpty => items.isEmpty;
  int get count => items.length;

  static String _keyFor(String? storeId) =>
      'held_carts:${(storeId == null || storeId.isEmpty) ? 'default' : storeId}';

  Future<String> _activeKey([String? explicitStoreId]) async {
    final resolved = explicitStoreId ?? await store.activeStoreNow() ?? store.activeLocationId;
    return _keyFor(resolved);
  }

  Future<void> restore({String? storeId}) async {
    final key = await _activeKey(storeId);
    final raw = await store.meta(key);
    items.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final entry in decoded) {
            if (entry is Map<String, dynamic>) {
              final hc = HeldCart.tryFromJson(entry);
              if (hc != null) items.add(hc);
            }
          }
        }
      } catch (_) {
        await store.setMeta(key, null);
      }
    }
    notifyListeners();
  }

  Future<void> _persist([String? storeId]) async {
    final key = await _activeKey(storeId);
    await store.setMeta(
      key,
      items.isEmpty ? null : jsonEncode([for (final h in items) h.toJson()]),
    );
  }

  Future<HeldCart?> parkCurrent(Cart cart, {String label = '', String? storeId}) async {
    if (cart.isEmpty) return null;
    final cleanLabel = label.trim();
    final held = HeldCart(
      id: _uuid.v7(),
      label: cleanLabel.length > 60 ? cleanLabel.substring(0, 60) : cleanLabel,
      createdAt: DateTime.now(),
      lines: cart.snapshot(),
    );
    items.insert(0, held);
    if (items.length > maxHeldCarts) {
      items.removeRange(maxHeldCarts, items.length);
    }
    cart.clear();
    notifyListeners();
    await _persist(storeId);
    return held;
  }

  Future<({HeldCart? resumed, bool swapped})> resume(
    String heldId,
    Cart cart, {
    String swapLabel = '',
    String? storeId,
  }) async {
    final idx = items.indexWhere((h) => h.id == heldId);
    if (idx < 0) return (resumed: null, swapped: false);
    final target = items.removeAt(idx);
    var swapped = false;
    if (!cart.isEmpty) {
      final cleanSwap = swapLabel.trim();
      items.insert(
        0,
        HeldCart(
          id: _uuid.v7(),
          label: cleanSwap.length > 60 ? cleanSwap.substring(0, 60) : cleanSwap,
          createdAt: DateTime.now(),
          lines: cart.snapshot(),
        ),
      );
      if (items.length > maxHeldCarts) {
        items.removeRange(maxHeldCarts, items.length);
      }
      swapped = true;
    }
    cart.replaceAll(target.lines);
    notifyListeners();
    await _persist(storeId);
    return (resumed: target, swapped: swapped);
  }

  Future<void> discard(String heldId, {String? storeId}) async {
    final before = items.length;
    items.removeWhere((h) => h.id == heldId);
    if (items.length == before) return;
    notifyListeners();
    await _persist(storeId);
  }
}

Future<String?> showHoldCartDialog(BuildContext context) async {
  final t = AppLocalizations.of(context);
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t.holdSaleTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.holdSaleHint,
            style: TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.outline),
          ),
          const SizedBox(height: Gap.m),
          TextField(
            key: const Key('hold-cart-note'),
            controller: ctrl,
            autofocus: true,
            maxLength: 60,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: t.holdSaleNoteLabel,
              hintText: t.holdSaleNoteHint,
              counterText: '',
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t.cancel),
        ),
        FilledButton.icon(
          key: const Key('confirm-hold-cart'),
          icon: const Icon(Icons.pause_circle_outline_rounded, size: 18),
          label: Text(t.holdSaleConfirm),
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
        ),
      ],
    ),
  );
}

Future<void> showHeldCartsSheet(
  BuildContext context, {
  required HeldCarts held,
  required Cart cart,
  required String Function(int) money,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      final t = AppLocalizations.of(ctx);
      final scheme = Theme.of(ctx).colorScheme;
      final locale = Localizations.localeOf(ctx).languageCode;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        minChildSize: 0.38,
        maxChildSize: 0.90,
        builder: (ctx, scrollCtrl) => ListenableBuilder(
          listenable: Listenable.merge([held, cart]),
          builder: (ctx, _) => Padding(
            key: const Key('held-carts-sheet'),
            padding: const EdgeInsets.fromLTRB(Gap.l, Gap.s, Gap.l, Gap.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: Gap.m),
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    CoinBadge(
                      icon: Icons.pause_circle_filled_rounded,
                      color: scheme.primary,
                      size: 38,
                    ),
                    const SizedBox(width: Gap.m),
                    Expanded(
                      child: Text(
                        t.heldSalesTitle,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    StatusPill(label: '${held.count}'),
                  ],
                ),
                if (!cart.isEmpty && !held.isEmpty) ...[
                  const SizedBox(height: Gap.m),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: Gap.s),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: scheme.isDark ? 0.35 : 0.65),
                      borderRadius: BorderRadius.circular(Gap.radiusM),
                      border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz_rounded, size: 18, color: scheme.primary),
                        const SizedBox(width: Gap.s),
                        Expanded(
                          child: Text(
                            t.heldSaleSwapBanner,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: scheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: Gap.m),
                Expanded(
                  child: held.isEmpty
                      ? EmptyState(
                          icon: Icons.pause_circle_outline_rounded,
                          text: t.heldSalesEmpty,
                        )
                      : ListView.separated(
                          controller: scrollCtrl,
                          itemCount: held.items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: Gap.s),
                          itemBuilder: (ctx, i) {
                            final h = held.items[i];
                            final timeText = DateFormat.jm(locale).format(h.createdAt);
                            final title = h.label.isNotEmpty ? h.label : t.heldSaleUntitled(timeText);
                            final summary = h.lines
                                .map((l) {
                                  final q = l.qty == l.qty.roundToDouble() ? '${l.qty.toInt()}' : '${l.qty}';
                                  return '${q}x ${l.product.name}';
                                })
                                .join(', ');
                            return AppCard(
                              key: Key('held-cart-${h.id}'),
                              padding: const EdgeInsets.all(Gap.m),
                              radius: Gap.radiusM,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      const SizedBox(width: Gap.s),
                                      Text(
                                        timeText,
                                        style: TextStyle(fontSize: 12, color: scheme.outline, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    summary,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12.5, color: scheme.outline),
                                  ),
                                  const SizedBox(height: Gap.s),
                                  Row(
                                    children: [
                                      Text(
                                        money(h.subtotal),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: scheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '· ${t.sellItems(h.itemCount)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 12.5, color: scheme.outline),
                                        ),
                                      ),
                                      IconButton(
                                        key: Key('discard-held-${h.id}'),
                                        tooltip: t.heldSaleDiscard,
                                        visualDensity: VisualDensity.compact,
                                        icon: Icon(Icons.delete_outline_rounded, size: 20, color: scheme.error),
                                        onPressed: () async {
                                          await held.discard(h.id);
                                          if (held.isEmpty && ctx.mounted) {
                                            Navigator.pop(ctx);
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      FilledButton.tonalIcon(
                                        key: Key('resume-held-${h.id}'),
                                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                        label: Text(t.heldSaleResume),
                                        onPressed: () async {
                                          final res = await held.resume(h.id, cart);
                                          if (ctx.mounted) Navigator.pop(ctx);
                                          if (res.resumed != null) {
                                            messenger
                                              ..hideCurrentSnackBar()
                                              ..showSnackBar(
                                                SnackBar(
                                                  content: Text(res.swapped ? t.heldSaleSwapped : t.heldSaleResumed),
                                                ),
                                              );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
