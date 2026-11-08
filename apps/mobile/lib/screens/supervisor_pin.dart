import 'package:flutter/material.dart';

import '../backend.dart';
import '../core/pin.dart';
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

class SupervisorApprovalResult {
  final String? approvalId;
  final Map<String, dynamic>? offlineApproval;
  final String approvedBy;

  const SupervisorApprovalResult({
    this.approvalId,
    this.offlineApproval,
    required this.approvedBy,
  });

  bool get isOffline => offlineApproval != null;
}

/// Asks for a supervisor PIN and exchanges it for a one-time approval.
/// When online: exchanges with server for approval_id.
/// When offline: validates against locally cached offline PIN hashes (via verifyPinPbkdf2)
/// and creates an offline_approval payload.
Future<SupervisorApprovalResult?> askSupervisorApproval(
  BuildContext context,
  Backend backend, {
  required String action,
  required String refId,
  String? locationId,
  String? approverId,
}) async {
  final t = AppLocalizations.of(context);
  final scope = CatalogScope.of(context);
  final loc = locationId ?? await scope.store.activeStoreNow();

  // Background refresh of offline PINs if online
  backend.pullOfflinePins(locationId: loc).then((pins) {
    if (pins.isNotEmpty && loc != null) {
      scope.store.saveOfflinePins(loc, pins);
    }
  }).catchError((_) {});

  if (!context.mounted) return null;

  final pin = TextEditingController();
  String? error;
  var busy = false;
  return showDialog<SupervisorApprovalResult>(
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
                    final enteredPin = pin.text.trim();
                    try {
                      final r = await backend.approveSupervisorAction(
                        action: action,
                        refId: refId,
                        pin: enteredPin,
                        locationId: loc,
                        approverId: approverId,
                      );
                      if (r.ok && r.approvalId != null) {
                        if (ctx.mounted) {
                          Navigator.pop(
                            ctx,
                            SupervisorApprovalResult(
                              approvalId: r.approvalId,
                              approvedBy: r.approvedBy ?? '',
                            ),
                          );
                        }
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
                      // Offline fallback: verify against cached store approver PIN hashes
                      final cachedPins = await scope.store.getOfflinePins(locationId: loc);
                      Map<String, dynamic>? matched;
                      for (final u in cachedPins) {
                        if (approverId != null && u['user_id'] != approverId) continue;
                        final hash = (u['pin_hash'] as String?) ?? '';
                        if (verifyPinPbkdf2(enteredPin, hash)) {
                          matched = u;
                          break;
                        }
                      }

                      if (matched != null) {
                        final offlineApproval = {
                          'approver_id': matched['user_id'],
                          'approved_at': DateTime.now().toUtc().toIso8601String(),
                          'action': action,
                          'ref_id': refId,
                        };
                        if (ctx.mounted) {
                          Navigator.pop(
                            ctx,
                            SupervisorApprovalResult(
                              offlineApproval: offlineApproval,
                              approvedBy: (matched['user_id'] as String?) ?? '',
                            ),
                          );
                        }
                        return;
                      }

                      setState(() {
                        busy = false;
                        error = cachedPins.isEmpty ? t.approvalNeedsSignal : t.approvalWrongPin;
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
  // the refused op knows its store; a supervisor with several stores needs it named
  final approval = await askSupervisorApproval(context, backend,
      action: op.kind, refId: entityId, locationId: op.payload['location_id'] as String?);
  if (approval == null) return;
  await scope.store.requeueWithApproval(
    opId: op.opId,
    approvalId: approval.approvalId,
    offlineApproval: approval.offlineApproval,
  );
  scope.engine.poke();
}
