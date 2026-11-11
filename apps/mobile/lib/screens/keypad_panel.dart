import 'package:flutter/material.dart';

import '../core/money.dart';
import '../core/theme.dart';

/// A compact number pad that types into [controller] (the amount received on the Pay screen).
/// Keys: 1-9, the decimal point (when the currency has decimals), 0, and backspace
/// (long-press backspace clears). Whole part is capped at 7 digits, decimals at the currency's exponent.
class AmountPad extends StatelessWidget {
  const AmountPad({super.key, required this.controller, required this.currency, this.onChanged});

  final TextEditingController controller;
  final String currency;

  /// Called after every key, so the screen can recompute change / utang.
  final VoidCallback? onChanged;

  int get _decimals => exponentOf(currency);

  void _press(String k) {
    var text = controller.text;
    switch (k) {
      case 'del':
        if (text.isNotEmpty) text = text.substring(0, text.length - 1);
      case 'clear':
        text = '';
      case '.':
        if (_decimals > 0 && !text.contains('.')) text = text.isEmpty ? '0.' : '$text.';
      default:
        final next = text == '0' ? k : text + k; // no leading zeros
        final dot = next.indexOf('.');
        final fractionOk = dot < 0 || next.length - dot - 1 <= _decimals;
        final wholeLen = dot < 0 ? next.length : dot;
        if (fractionOk && wholeLen <= 7) text = next;
    }
    controller.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(Gap.radiusS);

    Widget key(String k, {Widget? child}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(3.5),
            child: Material(
              color: scheme.surface,
              borderRadius: radius,
              elevation: 0,
              child: InkWell(
                key: Key('key-$k'),
                borderRadius: radius,
                onTap: () => _press(k),
                onLongPress: k == 'del' ? () => _press('clear') : null,
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(color: scheme.outlineVariant, width: 1.0),
                  ),
                  child: child ??
                      Text(k, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: scheme.onSurface)),
                ),
              ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.m),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final k in row) key(k)]),
        Row(children: [
          _decimals > 0 ? key('.') : key('00'),
          key('0'),
          key('del', child: Icon(Icons.backspace_outlined, size: 20, color: scheme.onSurface)),
        ]),
      ]),
    );
  }
}
