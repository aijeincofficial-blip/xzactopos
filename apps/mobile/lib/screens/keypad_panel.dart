import 'package:flutter/material.dart';

import '../core/money.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';

/// A number pad for an amount that is not in the catalog (a loose item, a service). It only builds the amount;
/// the caller decides what an "add" means.
class KeypadPanel extends StatefulWidget {
  const KeypadPanel({super.key, required this.currency, required this.locale, required this.onAdd});

  final String currency;
  final String locale;

  /// Called with the typed amount in centavos (> 0), then the pad clears.
  final void Function(int amount) onAdd;

  @override
  State<KeypadPanel> createState() => _KeypadPanelState();
}

class _KeypadPanelState extends State<KeypadPanel> {
  String _text = '';

  /// Digits allowed after the point (PHP: 2).
  int get _decimals => exponentOf(widget.currency);

  void _press(String k) {
    setState(() {
      switch (k) {
        case 'del':
          if (_text.isNotEmpty) _text = _text.substring(0, _text.length - 1);
        case '.':
          if (_decimals > 0 && !_text.contains('.')) _text = _text.isEmpty ? '0.' : '$_text.';
        default:
          final next = _text == '0' ? k : _text + k; // no leading zeros
          final dot = next.indexOf('.');
          final fractionOk = dot < 0 || next.length - dot - 1 <= _decimals;
          final wholeLen = dot < 0 ? next.length : dot;
          if (fractionOk && wholeLen <= 7) _text = next;
      }
    });
  }

  int? get _amount {
    if (_text.isEmpty) return null;
    try {
      final v = Money.parse(_text.endsWith('.') ? _text.substring(0, _text.length - 1) : _text, widget.currency).amount;
      return v > 0 ? v : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final amount = _amount;
    final shown = _text.isEmpty ? Money(0, widget.currency).format(widget.locale) : _text;

    Widget key(String k, {Widget? child}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: OutlinedButton(
              key: Key('key-$k'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56), padding: EdgeInsets.zero),
              onPressed: () => _press(k),
              child: child ?? Text(k, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.s, Gap.xl, Gap.s),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            shown,
            key: const Key('keypad-display'),
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              color: _text.isEmpty ? scheme.outline : scheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: Gap.s),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final k in row) key(k)]),
        Row(children: [
          key('.'),
          key('0'),
          key('del', child: const Icon(Icons.backspace_outlined)),
        ]),
        const SizedBox(height: Gap.s),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('keypad-add'),
            onPressed: amount == null
                ? null
                : () {
                    widget.onAdd(amount);
                    setState(() => _text = '');
                  },
            child: Text(t.keypadAdd),
          ),
        ),
      ]),
    );
  }
}
