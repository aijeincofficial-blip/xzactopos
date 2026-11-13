import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'design_tokens.g.dart';
import 'theme.dart';
import 'ui.dart';

/// Opens the Night Market look picker: palette variant + brightness (system/light/dark).
void showThemeSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _ThemeSheet(),
  );
}

/// Palette icon button for app bars and auth header.
class ThemeButton extends StatelessWidget {
  const ThemeButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (ThemeScope.maybeOf(context) == null) return const SizedBox.shrink();
    final t = AppLocalizations.of(context);
    return IconButton(
      key: const Key('theme-button'),
      icon: const Icon(Icons.palette_outlined),
      tooltip: t.themeTitle,
      onPressed: () => showThemeSheet(context),
    );
  }
}

class _ThemeSheet extends StatefulWidget {
  const _ThemeSheet();

  @override
  State<_ThemeSheet> createState() => _ThemeSheetState();
}

class _ThemeSheetState extends State<_ThemeSheet> {
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scope = ThemeScope.maybeOf(context)!;
    final paletteNames = {
      AppPalette.goldenIndigo: t.paletteGoldenIndigo,
      AppPalette.freshTide: t.paletteFreshTide,
    };
    final paletteSwatches = {
      AppPalette.goldenIndigo: (DesignTokens.ink, DesignTokens.lime, DesignTokens.sand),
      AppPalette.freshTide: (DesignTokens.okFg, DesignTokens.okBg, DesignTokens.swCoffee),
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.themeTitle, style: NightMarketText.display(context, size: 20)),
            const SizedBox(height: Gap.m),
            Text(t.themeColors.toUpperCase(), style: NightMarketText.eyebrow(context)),
            const SizedBox(height: Gap.s),
            for (final p in AppPalette.values) ...[
              _PaletteChoice(
                label: paletteNames[p]!,
                swatches: paletteSwatches[p]!,
                selected: scope.palette == p,
                onTap: () {
                  scope.setPalette(p);
                  setState(() {});
                },
              ),
              const SizedBox(height: Gap.s),
            ],
            const SizedBox(height: Gap.m),
            Text(t.themeMode.toUpperCase(), style: NightMarketText.eyebrow(context)),
            const SizedBox(height: Gap.s),
            SegmentedPillBar<ThemeMode>(
              selected: scope.mode,
              onChanged: (m) {
                scope.setMode(m);
                setState(() {});
              },
              items: [
                SegmentedPillItem(
                  value: ThemeMode.system,
                  label: t.themeSystem,
                  icon: Icons.brightness_auto_rounded,
                ),
                SegmentedPillItem(
                  value: ThemeMode.light,
                  label: t.themeLight,
                  icon: Icons.light_mode_rounded,
                ),
                SegmentedPillItem(
                  value: ThemeMode.dark,
                  label: t.themeDark,
                  icon: Icons.dark_mode_rounded,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaletteChoice extends StatelessWidget {
  const _PaletteChoice({
    required this.label,
    required this.swatches,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final (Color, Color, Color) swatches;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (c1, c2, c3) = swatches;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.m),
      radius: Gap.radiusM,
      color: selected ? (scheme.isDark ? scheme.nmInkLine : scheme.nmOkBg.withValues(alpha: 0.4)) : scheme.surface,
      borderColor: selected ? (scheme.isDark ? scheme.nmLime : scheme.nmInk) : scheme.outlineVariant,
      borderWidth: selected ? 2.0 : Gap.border,
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SwatchDot(c1),
              const SizedBox(width: 4),
              _SwatchDot(c2),
              const SizedBox(width: 4),
              _SwatchDot(c3),
            ],
          ),
          const SizedBox(width: Gap.m),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 15, fontWeight: selected ? FontWeight.w700 : FontWeight.w600),
            ),
          ),
          if (selected)
            Icon(
              Icons.check_circle_rounded,
              color: scheme.isDark ? scheme.nmLime : scheme.nmInk,
              size: 20,
            ),
        ],
      ),
    );
  }
}

class _SwatchDot extends StatelessWidget {
  const _SwatchDot(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1.0),
        ),
      );
}
