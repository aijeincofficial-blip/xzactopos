import 'package:flutter/material.dart';

import '../core/money.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';

class DenomItem {
  const DenomItem({
    required this.id,
    required this.value,
    required this.label,
    required this.isBill,
  });

  final String id;
  final double value;
  final String label;
  final bool isBill;
}

const phpDenominations = [
  DenomItem(id: 'bill_1000', value: 1000, label: '1,000', isBill: true),
  DenomItem(id: 'bill_500', value: 500, label: '500', isBill: true),
  DenomItem(id: 'bill_200', value: 200, label: '200', isBill: true),
  DenomItem(id: 'bill_100', value: 100, label: '100', isBill: true),
  DenomItem(id: 'bill_50', value: 50, label: '50', isBill: true),
  DenomItem(id: 'bill_20', value: 20, label: '20', isBill: true),
  DenomItem(id: 'coin_20', value: 20, label: '20', isBill: false),
  DenomItem(id: 'coin_10', value: 10, label: '10', isBill: false),
  DenomItem(id: 'coin_5', value: 5, label: '5', isBill: false),
  DenomItem(id: 'coin_1', value: 1, label: '1', isBill: false),
  DenomItem(id: 'coin_025', value: 0.25, label: '0.25', isBill: false),
];

Future<void> showDenominationSheet(
  BuildContext context, {
  required String currency,
  required void Function(double total) onApply,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Gap.radiusL)),
    ),
    builder: (ctx) => _DenominationSheetContent(
      currency: currency,
      onApply: onApply,
    ),
  );
}

class _DenominationSheetContent extends StatefulWidget {
  const _DenominationSheetContent({
    required this.currency,
    required this.onApply,
  });

  final String currency;
  final void Function(double total) onApply;

  @override
  State<_DenominationSheetContent> createState() => _DenominationSheetContentState();
}

class _DenominationSheetContentState extends State<_DenominationSheetContent> {
  final Map<String, int> _counts = {};

  double get _total {
    double sum = 0;
    for (final d in phpDenominations) {
      final c = _counts[d.id] ?? 0;
      if (c > 0) sum += d.value * c;
    }
    return (sum * 100).round() / 100;
  }

  void _increment(String id) {
    setState(() {
      _counts[id] = (_counts[id] ?? 0) + 1;
    });
  }

  void _decrement(String id) {
    setState(() {
      final current = _counts[id] ?? 0;
      if (current > 1) {
        _counts[id] = current - 1;
      } else {
        _counts.remove(id);
      }
    });
  }

  void _setCount(String id, String val) {
    final n = int.tryParse(val);
    setState(() {
      if (n == null || n <= 0) {
        _counts.remove(id);
      } else {
        _counts[id] = n;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final scheme = Theme.of(context).colorScheme;
    final totalMinor = (_total * 100).round();
    final totalFmt = Money(totalMinor, widget.currency).format(locale);

    final bills = phpDenominations.where((d) => d.isBill).toList();
    final coins = phpDenominations.where((d) => !d.isBill).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.l, Gap.m, Gap.l, Gap.s),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t.denominationCalculator,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    key: const Key('denom-clear-btn'),
                    onPressed: _counts.isEmpty ? null : () => setState(() => _counts.clear()),
                    child: Text(t.clearCount),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Denomination List
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.m),
                children: [
                  _buildSectionHeader(t.bills, Icons.money_rounded, scheme),
                  ...bills.map((d) => _buildRow(d, scheme)),
                  const SizedBox(height: Gap.m),
                  _buildSectionHeader(t.coins, Icons.monetization_on_rounded, scheme),
                  ...coins.map((d) => _buildRow(d, scheme)),
                ],
              ),
            ),

            // Bottom Bar
            Container(
              padding: EdgeInsets.fromLTRB(
                Gap.l,
                Gap.m,
                Gap.l,
                Gap.m + MediaQuery.paddingOf(context).bottom,
              ),
              decoration: BoxDecoration(
                color: scheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t.totalCalculated,
                          style: TextStyle(fontSize: 12, color: scheme.outline),
                        ),
                        Text(
                          totalFmt,
                          key: const Key('denom-total-text'),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    key: const Key('apply-denomination-btn'),
                    onPressed: _total <= 0
                        ? null
                        : () {
                            widget.onApply(_total);
                            Navigator.of(context).pop();
                          },
                    child: Text(t.applyCount),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.s, top: Gap.xs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: Gap.xs),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: scheme.primary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(DenomItem d, ColorScheme scheme) {
    final locale = Localizations.localeOf(context).languageCode;
    final count = _counts[d.id] ?? 0;
    final rowTotal = (count * d.value * 100).round();
    final rowTotalFmt = Money(rowTotal, widget.currency).format(locale);

    return Container(
      margin: const EdgeInsets.only(bottom: Gap.s),
      padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: Gap.xs + 2),
      decoration: BoxDecoration(
        color: count > 0 ? scheme.primary.withValues(alpha: 0.04) : Colors.transparent,
        border: Border.all(
          color: count > 0 ? scheme.primary.withValues(alpha: 0.3) : scheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(Gap.radiusM),
      ),
      child: Row(
        children: [
          // Denomination badge
          Container(
            width: 70,
            alignment: Alignment.centerLeft,
            child: Text(
              '₱${d.label}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: count > 0 ? scheme.primary : scheme.onSurface,
              ),
            ),
          ),

          // Stepper Controls
          IconButton(
            key: Key('denom-dec-${d.id}'),
            icon: const Icon(Icons.remove_circle_outline, size: 22),
            onPressed: count > 0 ? () => _decrement(d.id) : null,
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 44,
            child: TextFormField(
              key: Key('denom-input-${d.id}'),
              initialValue: count > 0 ? count.toString() : '',
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
                hintText: '0',
                border: InputBorder.none,
              ),
              onChanged: (v) => _setCount(d.id, v),
            ),
          ),
          IconButton(
            key: Key('denom-inc-${d.id}'),
            icon: const Icon(Icons.add_circle_outline, size: 22),
            onPressed: () => _increment(d.id),
            visualDensity: VisualDensity.compact,
          ),

          const Spacer(),

          // Row Subtotal
          Text(
            count > 0 ? rowTotalFmt : '—',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: count > 0 ? scheme.onSurface : scheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
