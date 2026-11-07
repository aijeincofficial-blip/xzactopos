import 'package:flutter/material.dart';

import '../data/local_store.dart';
import '../l10n/app_localizations.dart';
import 'store_session.dart';
import 'sync_engine.dart';

/// Synced / syncing / N waiting / offline / N need attention. Tap to sync now.
class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = CatalogScope.of(context);
    final t = AppLocalizations.of(context);
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: scope.engine.status,
      builder: (context, status, _) => StreamBuilder<OutboxCounts>(
        stream: scope.store.watchOutboxCounts(),
        builder: (context, snap) {
          final counts = snap.data ?? const OutboxCounts(0, 0);
          final (IconData icon, String label, Color? color) = switch (status.phase) {
            SyncPhase.needsSignIn => (Icons.lock_outline, t.syncSignIn, Colors.red),
            _ when counts.failed > 0 => (Icons.error_outline, t.syncNeedsAttention(counts.failed), Colors.red),
            SyncPhase.syncing => (Icons.sync, t.syncSyncing, null),
            SyncPhase.idle when status.lastSyncedAt == null => (Icons.sync, t.syncSyncing, null),
            SyncPhase.offline => (Icons.cloud_off, counts.pending > 0 ? t.syncOfflinePending(counts.pending) : t.syncOffline, Colors.orange),
            SyncPhase.idle when counts.pending > 0 => (Icons.cloud_upload_outlined, t.syncPending(counts.pending), null),
            SyncPhase.idle => (Icons.cloud_done_outlined, t.syncSynced, Colors.green),
          };
          return TextButton.icon(
            key: const Key('sync-badge'),
            onPressed: scope.engine.syncNow,
            icon: Icon(icon, color: color, size: 18),
            label: Text(label, style: TextStyle(color: color)),
          );
        },
      ),
    );
  }
}
