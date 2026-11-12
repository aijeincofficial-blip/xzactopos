import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'theme.dart';
import 'ui.dart';

/// Opens the modal bottom sheet for choosing theme colors and mode.
void showThemeSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _ThemeSheet(),
  );
}

/// App-bar or card button that opens the colours / brightness chooser.
class ThemeButton extends StatelessWidget {
  const ThemeButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (ThemeScope.maybeOf(context) == null) return const SizedBox.shrink();
    return IconButton(
      key: const Key('theme-button'),
      tooltip: AppLocalizations.of(context).themeTitle,
      icon: const Icon(Icons.palette_outlined),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: const EdgeInsets.all(4),
      visualDensity: VisualDensity.compact,
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
    final scope = ThemeScope.maybeOf(context)!;
    final t = AppLocalizations.of(context);
    final palettes = {
      AppPalette.freshTide: t.paletteFreshTide,
      AppPalette.goldenIndigo: t.paletteGoldenIndigo,
    };
    final modes = {
      ThemeMode.system: t.themeSystem,
      ThemeMode.light: t.themeLight,
      ThemeMode.dark: t.themeDark,
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.l),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.themeTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Gap.m),
          Text(t.themeColors, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: Gap.s),
          for (final e in palettes.entries)
            _Choice(
              key: Key('palette-${e.key.name}'),
              label: e.value,
              selected: scope.palette == e.key,
              swatch: buildTheme(e.key, Brightness.light).colorScheme,
              onTap: () {
                scope.setPalette(e.key);
                setState(() {});
              },
            ),
          const SizedBox(height: Gap.m),
          Text(t.themeMode, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: Gap.s),
          SegmentedPillBar<ThemeMode>(
            key: const Key('theme-mode'),
            items: [for (final e in modes.entries) SegmentedPillItem(value: e.key, label: e.value)],
            selected: scope.mode,
            onChanged: (m) {
              scope.setMode(m);
              setState(() {});
            },
          ),
        ]),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({super.key, required this.label, required this.selected, required this.swatch, required this.onTap});
  final String label;
  final bool selected;
  final ColorScheme swatch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final c in [swatch.primary, swatch.secondary, swatch.tertiary])
          Container(width: 18, height: 18, margin: const EdgeInsets.only(right: 3), decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      ]),
      title: Text(label),
      trailing: selected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : const Icon(Icons.circle_outlined),
    );
  }
}
