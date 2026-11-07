import 'package:flutter/material.dart';

import '../app.dart' show LocaleScope;
import '../backend.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../core/theme_picker.dart';
import '../l10n/app_localizations.dart';
import '../sync/sync_badge.dart';
import 'password_screens.dart';

/// Dedicated Settings Screen for Solo POS.
/// Houses theme customization, light/dark mode, language preferences,
/// sync and offline telemetry, security credentials, and account sign out.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.backend, required this.storeName});
  final Backend backend;
  final String storeName;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final locale = Localizations.localeOf(context).languageCode;
    final themeScope = ThemeScope.maybeOf(context);
    final localeScope = LocaleScope.maybeOf(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t.settingsTitle,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.s, Gap.xl, Gap.xxl),
          children: [
            // Store Identity Card
            AppCard(
              padding: const EdgeInsets.all(Gap.l),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [scheme.primary, scheme.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        storeName.isNotEmpty ? storeName[0].toUpperCase() : 'X',
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storeName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: scheme.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              t.activeStore,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.outline),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SyncBadge(),
                ],
              ),
            ),

            const SizedBox(height: Gap.l),

            // Appearance & Theme Card
            _SectionHeader(title: t.settingsAppearance.toUpperCase()),
            AppCard(
              padding: const EdgeInsets.all(Gap.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (themeScope != null) ...[
                    Row(
                      children: [
                        CoinBadge(icon: Icons.palette_outlined, color: scheme.primary, size: 36),
                        const SizedBox(width: Gap.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.themeTitle,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                              Text(
                                themeScope.palette == AppPalette.goldenIndigo ? t.paletteGoldenIndigo : t.paletteFreshTide,
                                style: TextStyle(fontSize: 12, color: scheme.outline),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonal(
                          key: const Key('settings-change-theme'),
                          style: FilledButton.styleFrom(
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            minimumSize: const Size(0, 36),
                          ),
                          onPressed: () => showThemeSheet(context),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.tune_rounded, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                t.change,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.l),
                    Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
                    const SizedBox(height: Gap.l),

                    // Light / Dark Mode Segmented Controller
                    Row(
                      children: [
                        CoinBadge(
                          icon: dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          color: scheme.secondary,
                          size: 36,
                        ),
                        const SizedBox(width: Gap.m),
                        Expanded(
                          child: Text(
                            t.themeMode,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ),
                        SegmentedButton<ThemeMode>(
                          key: const Key('settings-theme-mode'),
                          showSelectedIcon: false,
                          style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
                          segments: [
                            ButtonSegment(value: ThemeMode.light, label: Text(t.themeLight, style: const TextStyle(fontSize: 12))),
                            ButtonSegment(value: ThemeMode.dark, label: Text(t.themeDark, style: const TextStyle(fontSize: 12))),
                          ],
                          selected: {themeScope.mode == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light},
                          onSelectionChanged: (s) => themeScope.setMode(s.first),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: Gap.l),

            // Regional & Language Card
            _SectionHeader(title: t.settingsLanguageRegion.toUpperCase()),
            AppCard(
              padding: const EdgeInsets.all(Gap.l),
              child: Row(
                children: [
                  CoinBadge(icon: Icons.translate_rounded, color: scheme.accent, size: 36),
                  const SizedBox(width: Gap.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.systemLanguage,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        Text(
                          t.languageCurrentName,
                          style: TextStyle(fontSize: 12, color: scheme.outline),
                        ),
                      ],
                    ),
                  ),
                  if (localeScope != null)
                    FilledButton.tonal(
                      key: const Key('settings-language-toggle'),
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: const Size(0, 36),
                      ),
                      onPressed: () => localeScope.setLocale(locale == 'fil' ? 'en' : 'fil'),
                      child: Text(
                        t.switchLanguage,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: Gap.l),

            // Security & Credentials Card
            _SectionHeader(title: t.settingsSecurity.toUpperCase()),
            AppCard(
              padding: const EdgeInsets.all(Gap.l),
              child: Column(
                children: [
                  Row(
                    children: [
                      CoinBadge(icon: Icons.lock_reset_rounded, color: scheme.primary, size: 36),
                      const SizedBox(width: Gap.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.changePassword,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                            Text(
                              t.updatePasswordHint,
                              style: TextStyle(fontSize: 12, color: scheme.outline),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        key: const Key('settings-change-password'),
                        style: OutlinedButton.styleFrom(
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: const Size(0, 36),
                        ),
                        onPressed: () => showChangePasswordDialog(context, backend),
                        child: Text(
                          t.change,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.l),
                  Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: Gap.l),

                  // Sign Out Row
                  Row(
                    children: [
                      CoinBadge(icon: Icons.logout_rounded, color: scheme.error, size: 36),
                      const SizedBox(width: Gap.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.signOut,
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: scheme.error),
                            ),
                            Text(
                              t.endSessionHint,
                              style: TextStyle(fontSize: 12, color: scheme.outline),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        key: const Key('settings-sign-out'),
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.error,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: const Size(0, 36),
                        ),
                        onPressed: backend.signOut,
                        icon: const Icon(Icons.exit_to_app_rounded, size: 16),
                        label: Text(
                          t.signOut,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: Gap.xl),

            // App Version & Offline Telemetry Footer
            Center(
              child: Column(
                children: [
                  Text(
                    'XZACTOPOS SOLO • v1.0.0',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: scheme.outline.withValues(alpha: 0.7),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.localDbNote,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.outline.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: Gap.xs, bottom: Gap.s),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.outline,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
