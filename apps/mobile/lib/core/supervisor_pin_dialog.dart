import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
import 'pin_auth.dart';

/// Shows a tactical supervisor approval dialog with a dedicated numeric keypad and haptic feedback.
Future<SupervisorApprovalResult?> showSupervisorPinDialog(
  BuildContext context, {
  required Backend backend,
  required String action,
  required String refId,
  String? locationId,
  String? title,
  String? subtitle,
}) async {
  final scope = CatalogScope.maybeOf(context);
  final loc = locationId ?? (scope != null ? await scope.store.activeStoreNow() : null);

  // Background refresh of offline PINs if online
  if (loc != null) {
    backend.pullOfflinePins(locationId: loc).then((pins) {
      if (pins.isNotEmpty) {
        final models = pins.map((p) => SupervisorPin.fromJson(p)).toList();
        SupervisorPinStorage.savePins(loc, models);
      }
    }).catchError((_) {});
  }

  if (!context.mounted) return null;

  return showModalBottomSheet<SupervisorApprovalResult>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _SupervisorPinSheet(
      backend: backend,
      action: action,
      refId: refId,
      locationId: loc,
      customTitle: title,
      customSubtitle: subtitle,
    ),
  );
}

class SupervisorApprovalResult {
  const SupervisorApprovalResult({
    this.approvalId,
    this.offlineApproval,
    required this.approvedBy,
  });

  final String? approvalId;
  final Map<String, dynamic>? offlineApproval;
  final String approvedBy;

  bool get isOffline => offlineApproval != null;
}

class _SupervisorPinSheet extends StatefulWidget {
  const _SupervisorPinSheet({
    required this.backend,
    required this.action,
    required this.refId,
    this.locationId,
    this.customTitle,
    this.customSubtitle,
  });

  final Backend backend;
  final String action;
  final String refId;
  final String? locationId;
  final String? customTitle;
  final String? customSubtitle;

  @override
  State<_SupervisorPinSheet> createState() => _SupervisorPinSheetState();
}

class _SupervisorPinSheetState extends State<_SupervisorPinSheet> {
  String _pin = '';
  bool _verifying = false;
  String? _errorMessage;

  void _onDigit(String d) {
    if (_verifying || _pin.length >= 6) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin += d;
      _errorMessage = null;
    });

    if (_pin.length >= 4) {
      // Auto-verify if reaches 4 digits
      _verify();
    }
  }

  void _onBackspace() {
    if (_verifying || _pin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _verify() async {
    final t = AppLocalizations.of(context);
    final enteredPin = _pin;
    setState(() => _verifying = true);

    // 1. Try online approval first if connected
    try {
      final r = await widget.backend.approveSupervisorAction(
        action: widget.action,
        refId: widget.refId,
        pin: enteredPin,
        locationId: widget.locationId,
      );

      if (r.ok && r.approvalId != null) {
        HapticFeedback.mediumImpact();
        if (mounted) {
          Navigator.pop(
            context,
            SupervisorApprovalResult(
              approvalId: r.approvalId,
              approvedBy: r.approvedBy ?? 'Supervisor',
            ),
          );
        }
        return;
      }

      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _verifying = false;
          _pin = '';
          _errorMessage = switch (r.hint) {
            'pin_wrong' => t.approvalWrongPin,
            'pin_locked' => t.approvalLocked,
            'pin_not_set' => t.approvalNoPin,
            _ => t.approvalRefused,
          };
        });
      }
      return;
    } catch (_) {
      // 2. Offline fallback: verify against cached store approver PIN hashes
      if (widget.locationId != null) {
        final match = await SupervisorPinStorage.verifyOfflinePin(
          locationId: widget.locationId!,
          pin: enteredPin,
        );

        if (match != null) {
          HapticFeedback.mediumImpact();
          final offlineApproval = {
            'approver_id': match.userId,
            'approved_at': DateTime.now().toUtc().toIso8601String(),
            'action': widget.action,
            'ref_id': widget.refId,
          };

          if (mounted) {
            Navigator.pop(
              context,
              SupervisorApprovalResult(
                offlineApproval: offlineApproval,
                approvedBy: match.displayName,
              ),
            );
          }
          return;
        }
      }

      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _verifying = false;
          _pin = '';
          _errorMessage = t.approvalWrongPin;
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
        children: [
          // Header
          Row(
            children: [
              CoinBadge(
                icon: Icons.shield_outlined,
                color: scheme.primary,
                size: 38,
              ),
              const SizedBox(width: Gap.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.customTitle ?? t.approvalTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      widget.customSubtitle ?? t.approvalBody,
                      style: TextStyle(fontSize: 12, color: scheme.outline),
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

          const SizedBox(height: Gap.l),

          // PIN Dots Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) {
              final filled = index < _pin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.4),
                  border: Border.all(
                    color: filled ? scheme.primary : scheme.outline.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
              );
            }),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: Gap.m),
            Text(
              _errorMessage!,
              key: const Key('supervisor-pin-error'),
              style: TextStyle(
                color: scheme.error,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],

          if (_verifying) ...[
            const SizedBox(height: Gap.m),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],

          const SizedBox(height: Gap.l),

          // Numeric Keypad
          _Keypad(
            onDigit: _onDigit,
            onBackspace: _onBackspace,
            disabled: _verifying,
          ),
        ],
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    required this.disabled,
  });

  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _KeypadButton(digit: '1', onPressed: disabled ? null : () => onDigit('1')),
            _KeypadButton(digit: '2', onPressed: disabled ? null : () => onDigit('2')),
            _KeypadButton(digit: '3', onPressed: disabled ? null : () => onDigit('3')),
          ],
        ),
        const SizedBox(height: Gap.s),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _KeypadButton(digit: '4', onPressed: disabled ? null : () => onDigit('4')),
            _KeypadButton(digit: '5', onPressed: disabled ? null : () => onDigit('5')),
            _KeypadButton(digit: '6', onPressed: disabled ? null : () => onDigit('6')),
          ],
        ),
        const SizedBox(height: Gap.s),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _KeypadButton(digit: '7', onPressed: disabled ? null : () => onDigit('7')),
            _KeypadButton(digit: '8', onPressed: disabled ? null : () => onDigit('8')),
            _KeypadButton(digit: '9', onPressed: disabled ? null : () => onDigit('9')),
          ],
        ),
        const SizedBox(height: Gap.s),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 72, height: 56),
            _KeypadButton(digit: '0', onPressed: disabled ? null : () => onDigit('0')),
            SizedBox(
              width: 72,
              height: 56,
              child: IconButton(
                key: const Key('keypad-backspace'),
                icon: const Icon(Icons.backspace_outlined),
                onPressed: disabled ? null : onBackspace,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({required this.digit, required this.onPressed});

  final String digit;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 56,
      child: FilledButton.tonal(
        key: Key('keypad-$digit'),
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: EdgeInsets.zero,
        ),
        onPressed: onPressed,
        child: Text(
          digit,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
