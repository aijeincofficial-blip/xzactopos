import 'package:flutter/material.dart';

import '../backend.dart';
import '../data/sales_models.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';

String expenseCategoryLabel(AppLocalizations t, String category) => switch (category) {
      'stock_purchase' => t.expenseCategoryStockPurchase,
      'utilities' => t.expenseCategoryUtilities,
      'transport' => t.expenseCategoryTransport,
      'wages' => t.expenseCategoryWages,
      'rent' => t.expenseCategoryRent,
      _ => t.expenseCategoryOther,
    };

/// Asks for a supervisor PIN and exchanges it for a one-time approval (needs signal). The PIN is only typed here and
/// sent to the server; it is never stored. Returns the approval id, or null when cancelled.
Future<String?> askSupervisorApproval(
  BuildContext context,
  Backend backend, {
  required String action,
  required String refId,
}) {
  final t = AppLocalizations.of(context);
  final pin = TextEditingController();
  String? error;
  var busy = false;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(t.approvalTitle),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.approvalBody),
          const SizedBox(height: 12),
          TextField(
            key: const Key('approval-pin'),
            controller: pin,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: t.approvalPin, errorText: error),
          ),
        ]),
        actions: [
          TextButton(onPressed: busy ? null : () => Navigator.pop(ctx), child: Text(t.cancel)),
          FilledButton(
            key: const Key('approval-ok'),
            onPressed: busy
                ? null
                : () async {
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      final r = await backend.approveSupervisorAction(action: action, refId: refId, pin: pin.text.trim());
                      if (r.ok) {
                        if (ctx.mounted) Navigator.pop(ctx, r.approvalId);
                        return;
                      }
                      setState(() {
                        busy = false;
                        error = switch (r.hint) {
                          'pin_wrong' => t.approvalWrongPin,
                          'pin_locked' => t.approvalLocked,
                          'pin_not_set' => t.approvalNoPin,
                          _ => t.approvalRefused,
                        };
                      });
                    } catch (_) {
                      setState(() {
                        busy = false;
                        error = t.approvalNeedsSignal;
                      });
                    }
                  },
            child: Text(t.approvalApprove),
          ),
        ],
      ),
    ),
  );
}

/// A refused expense or day-close op (approval missing, used or expired): ask for a PIN, then send it again with the
/// new approval. Does nothing when the user cancels.
Future<void> retryWithApproval(BuildContext context, Backend backend, String entityId) async {
  final scope = CatalogScope.of(context);
  final failed = (await scope.store.failedOps()).where((o) => o.entityId == entityId && needsApproval(o.lastError));
  if (failed.isEmpty || !context.mounted) return;
  final op = failed.first;
  final approval = await askSupervisorApproval(context, backend, action: op.kind, refId: entityId);
  if (approval == null) return;
  await scope.store.requeueWithApproval(opId: op.opId, approvalId: approval);
  scope.engine.poke();
}
