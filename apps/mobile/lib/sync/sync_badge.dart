import 'package:flutter/material.dart';

import '../core/design_tokens.g.dart';
import '../core/theme.dart';
import '../data/local_store.dart';
import '../l10n/app_localizations.dart';
import 'store_session.dart';
import 'sync_engine.dart';

/// Night Market sync chip (`SyncBadge`):
/// - Synced -> okBg pill with green dot (`okDot`)
/// - Offline / offline pending -> deep ink pill with lime dot & tabular count
/// - Syncing / pending -> crisp paper pill
/// - Error / needs attention -> warm meal red pill
/// Keeps `Key('sync-badge')` and full sentence tooltips for phone compactness.
class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key});

  /// Screens narrower than this (phones) get the compact badge.
  static const compactBelowWidth = 600.0;

  @override
  Widget build(BuildContext context) {
    final scope = CatalogScope.of(context);
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.isDark;

    return ValueListenableBuilder<SyncStatus>(
      valueListenable: scope.engine.status,
      builder: (context, status, _) => StreamBuilder<OutboxCounts>(
        stream: scope.store.watchOutboxCounts(),
        builder: (context, snap) {
          final counts = snap.data ?? const OutboxCounts(0, 0);
          final n = counts.failed > 0 ? counts.failed : counts.pending;

          final (
            IconData icon,
            String label,
            Color bg,
            Color fg,
            Color dot,
            Color border,
          ) = switch (status.phase) {
            SyncPhase.needsSignIn => (
                Icons.lock_outline_rounded,
                t.syncSignIn,
                DesignTokens.swMeal,
                DesignTokens.swMealFg,
                DesignTokens.swMealFg,
                DesignTokens.swMealFg.withValues(alpha: 0.35),
              ),
            _ when counts.failed > 0 => (
                Icons.error_outline_rounded,
                t.syncNeedsAttention(counts.failed),
                DesignTokens.swMeal,
                DesignTokens.swMealFg,
                DesignTokens.swMealFg,
                DesignTokens.swMealFg.withValues(alpha: 0.35),
              ),
            SyncPhase.offline => (
                Icons.cloud_off_rounded,
                counts.pending > 0 ? t.syncOfflinePending(counts.pending) : t.syncOffline,
                DesignTokens.ink,
                DesignTokens.textOnDark,
                DesignTokens.lime,
                DesignTokens.inkLine2,
              ),
            SyncPhase.syncing => (
                Icons.sync_rounded,
                t.syncSyncing,
                dark ? DesignTokens.inkLine : DesignTokens.paper,
                dark ? DesignTokens.textOnDark : DesignTokens.ink,
                DesignTokens.lime,
                scheme.outlineVariant,
              ),
            SyncPhase.idle when status.lastSyncedAt == null => (
                Icons.sync_rounded,
                t.syncSyncing,
                dark ? DesignTokens.inkLine : DesignTokens.paper,
                dark ? DesignTokens.textOnDark : DesignTokens.ink,
                DesignTokens.lime,
                scheme.outlineVariant,
              ),
            SyncPhase.idle when counts.pending > 0 => (
                Icons.cloud_upload_outlined,
                t.syncPending(counts.pending),
                DesignTokens.swPastry,
                DesignTokens.swPastryFg,
                DesignTokens.swPastryFg,
                DesignTokens.swPastryFg.withValues(alpha: 0.30),
              ),
            SyncPhase.idle => (
                Icons.cloud_done_outlined,
                t.syncSynced,
                dark ? DesignTokens.inkLine : DesignTokens.okBg,
                dark ? DesignTokens.okBg : DesignTokens.okFg,
                dark ? DesignTokens.lime : DesignTokens.okDot,
                dark ? DesignTokens.inkLine2 : DesignTokens.okDot.withValues(alpha: 0.32),
              ),
          };

          final isCompact = MediaQuery.sizeOf(context).width < compactBelowWidth;

          return Tooltip(
            message: label,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('sync-badge'),
                  onTap: scope.engine.syncNow,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 34),
                    padding: EdgeInsets.symmetric(horizontal: isCompact ? 9 : 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: border, width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Icon(icon, color: fg, size: isCompact ? 16 : 15, semanticLabel: isCompact ? label : null),
                        if (isCompact && n > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '$n',
                            style: NightMarketText.mono(context, size: 12, weight: FontWeight.w600, color: fg),
                          ),
                        ] else if (!isCompact) ...[
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: TextStyle(
                              fontFamily: NightMarketFont.sans,
                              color: fg,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
