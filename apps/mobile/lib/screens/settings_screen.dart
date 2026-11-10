import 'package:flutter/material.dart';

import '../app.dart' show LocaleScope;
import '../backend.dart';
import '../core/esc_pos_printer.dart';
import '../core/printer_config.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../core/theme_picker.dart';
import '../l10n/app_localizations.dart';
import '../sync/store_session.dart';
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.s, Gap.xl, Gap.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              (CatalogScope.maybeOf(context)?.isWarehouse ?? false) ? t.activeWarehouse : t.activeStore,
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

            // Receipt & Thermal Printer Card
            _SectionHeader(title: t.printerSection.toUpperCase()),
            _PrinterSettingsCard(storeName: storeName),

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

            if (CatalogScope.maybeOf(context)?.isAdminOrSuperadmin ?? true) ...[
              const SizedBox(height: Gap.l),

              // Upgrade to Full Mode Card
              _SectionHeader(title: t.upgradeFullSection.toUpperCase()),
              AppCard(
                padding: const EdgeInsets.all(Gap.l),
                child: Row(
                  children: [
                    CoinBadge(
                      icon: Icons.rocket_launch_rounded,
                      color: scheme.primary,
                      size: 36,
                    ),
                    const SizedBox(width: Gap.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.upgradeFullTitle,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          Text(
                            t.upgradeFullSubtitle,
                            style: TextStyle(fontSize: 12, color: scheme.outline),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Gap.s),
                    FilledButton.tonal(
                      key: const Key('settings-upgrade-full'),
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: const Size(0, 36),
                      ),
                      onPressed: () => _showUpgradeDialog(context, t),
                      child: Text(
                        t.upgradeFullAction,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: Gap.xl),

            // App Version & Offline Telemetry Footer
            Center(
              child: Column(
                children: [
                  Image.asset(
                    'assets/brand/logo_round.png',
                    key: const Key('settings-logo'),
                    width: 44,
                    height: 44,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: Gap.s),
                  Text(
                    'XZACTO POS • v1.0.0',
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
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context, AppLocalizations t) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.rocket_launch_rounded, color: Theme.of(ctx).colorScheme.primary),
            const SizedBox(width: Gap.s),
            Expanded(child: Text(t.upgradeFullDialogTitle)),
          ],
        ),
        content: Text(t.upgradeFullDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.upgradeFullClose),
          ),
        ],
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

class _PrinterSettingsCard extends StatefulWidget {
  const _PrinterSettingsCard({required this.storeName});
  final String storeName;

  @override
  State<_PrinterSettingsCard> createState() => _PrinterSettingsCardState();
}

class _PrinterSettingsCardState extends State<_PrinterSettingsCard> {
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final cfg = activePrinterConfig;
    final isEscPos = cfg.engine == PrinterEngineType.networkEscPos;
    final subtitle = isEscPos ? 'ESC/POS (${cfg.ipAddress}:${cfg.port})' : t.printerEnginePdf;

    return AppCard(
      padding: const EdgeInsets.all(Gap.l),
      child: Row(
        children: [
          CoinBadge(icon: Icons.print_rounded, color: scheme.primary, size: 36),
          const SizedBox(width: Gap.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.printerSection,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: scheme.outline),
                ),
              ],
            ),
          ),
          OutlinedButton(
            key: const Key('settings-configure-printer'),
            style: OutlinedButton.styleFrom(
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 36),
            ),
            onPressed: () async {
              await showPrinterSettingsSheet(context, widget.storeName);
              if (mounted) setState(() {});
            },
            child: Text(
              t.change,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showPrinterSettingsSheet(BuildContext context, String storeName) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(Gap.l),
          child: _PrinterSettingsSheetContent(storeName: storeName),
        ),
      ),
    ),
  );
}

class _PrinterSettingsSheetContent extends StatefulWidget {
  const _PrinterSettingsSheetContent({required this.storeName});
  final String storeName;

  @override
  State<_PrinterSettingsSheetContent> createState() => _PrinterSettingsSheetContentState();
}

class _PrinterSettingsSheetContentState extends State<_PrinterSettingsSheetContent> {
  late PrinterConfig _config;
  late TextEditingController _ipController;
  late TextEditingController _portController;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _config = activePrinterConfig;
    _ipController = TextEditingController(text: _config.ipAddress);
    _portController = TextEditingController(text: _config.port.toString());
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _update(PrinterConfig next) async {
    setState(() => _config = next);
    await next.save();
    applyPrinterConfig(next);
  }

  Future<void> _testPrint() async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _testing = true);
    try {
      await printTestSlip(config: _config, storeName: widget.storeName);
      messenger.showSnackBar(SnackBar(content: Text(t.printerTestSuccess)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(t.printerTestFailed)));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isEscPos = _config.engine == PrinterEngineType.networkEscPos;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CoinBadge(icon: Icons.print_rounded, color: scheme.primary, size: 36),
            const SizedBox(width: Gap.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.printerSection,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  Text(
                    t.printerSectionHint,
                    style: TextStyle(fontSize: 12, color: scheme.outline),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.m),

        // Engine Selector
        SegmentedButton<PrinterEngineType>(
          key: const Key('printer-engine-selector'),
          segments: [
            ButtonSegment(
              value: PrinterEngineType.systemPdf,
              label: Text(t.printerEnginePdf, style: const TextStyle(fontSize: 12)),
            ),
            ButtonSegment(
              value: PrinterEngineType.networkEscPos,
              label: Text(t.printerEngineEscPos, style: const TextStyle(fontSize: 12)),
            ),
          ],
          selected: {_config.engine},
          onSelectionChanged: (s) {
            if (s.isNotEmpty) {
              _update(_config.copyWith(engine: s.first));
            }
          },
        ),

        if (isEscPos) ...[
          const SizedBox(height: Gap.m),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  key: const Key('printer-ip-field'),
                  controller: _ipController,
                  decoration: InputDecoration(
                    labelText: t.printerIp,
                    hintText: '192.168.1.100',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.datetime,
                  onChanged: (v) => _update(_config.copyWith(ipAddress: v.trim())),
                ),
              ),
              const SizedBox(width: Gap.m),
              Expanded(
                flex: 2,
                child: TextField(
                  key: const Key('printer-port-field'),
                  controller: _portController,
                  decoration: InputDecoration(
                    labelText: t.printerPort,
                    hintText: '9100',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final p = int.tryParse(v.trim());
                    if (p != null && p > 0) {
                      _update(_config.copyWith(port: p));
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.m),

          // Roll width selector
          Text(t.printerWidth, style: TextStyle(fontSize: 12, color: scheme.outline, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          SegmentedButton<PaperWidth>(
            key: const Key('printer-width-picker'),
            segments: const [
              ButtonSegment(value: PaperWidth.mm58, label: Text('58 mm (32 col)')),
              ButtonSegment(value: PaperWidth.mm80, label: Text('80 mm (48 col)')),
            ],
            selected: {_config.paperWidth},
            onSelectionChanged: (s) {
              if (s.isNotEmpty) {
                _update(_config.copyWith(paperWidth: s.first));
              }
            },
          ),
          const SizedBox(height: Gap.s),

          // Switches
          SwitchListTile(
            key: const Key('printer-drawer-switch'),
            contentPadding: EdgeInsets.zero,
            title: Text(t.printerDrawerKick, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            value: _config.drawerKick,
            onChanged: (v) => _update(_config.copyWith(drawerKick: v)),
          ),
          SwitchListTile(
            key: const Key('printer-autoprint-switch'),
            contentPadding: EdgeInsets.zero,
            title: Text(t.printerAutoPrint, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            value: _config.autoPrint,
            onChanged: (v) => _update(_config.copyWith(autoPrint: v)),
          ),

          const SizedBox(height: Gap.s),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('printer-test-button'),
              icon: _testing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.print_outlined, size: 18),
              label: Text(t.printerTestPrint),
              onPressed: _testing ? null : _testPrint,
            ),
          ),
        ],
      ],
    );
  }
}
