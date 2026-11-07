import 'package:flutter/material.dart';

/// The two colour sets the owner can pick from (light and dark exist for both).
/// See docs/plan-solo-design.md (D-02) and docs/design-audit/palettes.png.
enum AppPalette { freshTide, goldenIndigo }

/// Spacing and radius scale; screens should use these instead of typed numbers.
class Gap {
  static const double xs = 4, s = 8, m = 12, l = 16, xl = 24;
  static const double radiusS = 12, radiusM = 16, radiusL = 22, radiusXL = 28;
}

class _P {
  const _P({
    required this.primary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.background,
    required this.surface,
    required this.text,
  });
  final Color primary, primaryContainer, onPrimaryContainer;
  final Color secondary, onSecondary, secondaryContainer, onSecondaryContainer;
  final Color tertiary; // warning (low stock)
  final Color background, surface, text;
}

// utang owed, void, errors (deeper in light themes, lighter with dark text in dark themes, for contrast)
const _errorLight = Color(0xFFD6334A);
const _errorDark = Color(0xFFFF8A94);

const _freshLight = _P(
  primary: Color(0xFF1E6FF2),
  primaryContainer: Color(0xFFDCE9FF),
  onPrimaryContainer: Color(0xFF0B2F6B),
  secondary: Color(0xFF0A8268), // mint, deep enough for white text (4.5:1)
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFCCF3E9),
  onSecondaryContainer: Color(0xFF05382C),
  tertiary: Color(0xFFF5A524),
  background: Color(0xFFF3F8FF),
  surface: Colors.white,
  text: Color(0xFF0F2038),
);
const _freshDark = _P(
  primary: Color(0xFF5B9BFF),
  primaryContainer: Color(0xFF163A73),
  onPrimaryContainer: Color(0xFFD6E5FF),
  secondary: Color(0xFF2FD9B2),
  onSecondary: Color(0xFF04241C),
  secondaryContainer: Color(0xFF0F4A3D),
  onSecondaryContainer: Color(0xFFC6F5EA),
  tertiary: Color(0xFFFFB84D),
  background: Color(0xFF0A1424),
  surface: Color(0xFF14233A),
  text: Color(0xFFE8F0FF),
);
const _goldLight = _P(
  primary: Color(0xFF3D5AFE),
  primaryContainer: Color(0xFFE0E5FF),
  onPrimaryContainer: Color(0xFF1B2A8A),
  secondary: Color(0xFFFFC63D),
  onSecondary: Color(0xFF2B2000),
  secondaryContainer: Color(0xFFFFEFC2),
  onSecondaryContainer: Color(0xFF3F2F00),
  tertiary: Color(0xFFFF8A3D),
  background: Color(0xFFF6F7FF),
  surface: Colors.white,
  text: Color(0xFF14183A),
);
const _goldDark = _P(
  primary: Color(0xFF8197FF),
  primaryContainer: Color(0xFF27307A),
  onPrimaryContainer: Color(0xFFDDE2FF),
  secondary: Color(0xFFFFD25E),
  onSecondary: Color(0xFF2B2000),
  secondaryContainer: Color(0xFF5A4500),
  onSecondaryContainer: Color(0xFFFFEFC2),
  tertiary: Color(0xFFFF9D5C),
  background: Color(0xFF0D1024),
  surface: Color(0xFF191E3F),
  text: Color(0xFFECEEFF),
);

ThemeData buildTheme(AppPalette palette, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final p = switch (palette) {
    AppPalette.freshTide => dark ? _freshDark : _freshLight,
    AppPalette.goldenIndigo => dark ? _goldDark : _goldLight,
  };
  final scheme = ColorScheme.fromSeed(seedColor: p.primary, brightness: brightness).copyWith(
    primary: p.primary,
    onPrimary: dark ? const Color(0xFF06122E) : Colors.white,
    primaryContainer: p.primaryContainer,
    onPrimaryContainer: p.onPrimaryContainer,
    secondary: p.secondary,
    onSecondary: p.onSecondary,
    secondaryContainer: p.secondaryContainer,
    onSecondaryContainer: p.onSecondaryContainer,
    tertiary: p.tertiary,
    onTertiary: const Color(0xFF2B1C00),
    error: dark ? _errorDark : _errorLight,
    onError: dark ? const Color(0xFF3B0008) : Colors.white,
    surface: p.surface,
    onSurface: p.text,
  );
  const shape = StadiumBorder(); // pill buttons
  final cardShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gap.radiusXL));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: p.text,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(color: p.surface, elevation: 0, surfaceTintColor: Colors.transparent, shape: cardShape),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(64, 56), shape: shape),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(minimumSize: const Size(64, 56), shape: shape),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 56), shape: shape),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.secondary,
      foregroundColor: p.onSecondary,
      shape: shape,
    ),
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.l),
      filled: true,
      fillColor: p.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Gap.radiusL), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Gap.radiusL),
        borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Gap.radiusL),
        borderSide: BorderSide(color: p.primary, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: p.secondaryContainer,
      labelStyle: TextStyle(color: p.text),
      shape: const StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: p.surface,
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.surface, surfaceTintColor: Colors.transparent, shape: cardShape),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Gap.radiusXL))),
    ),
  );
}

/// Chosen palette and brightness, with a way to change them (like [LocaleScope]).
class ThemeScope extends InheritedWidget {
  const ThemeScope({
    super.key,
    required this.palette,
    required this.mode,
    required this.setPalette,
    required this.setMode,
    required super.child,
  });
  final AppPalette palette;
  final ThemeMode mode;
  final void Function(AppPalette) setPalette;
  final void Function(ThemeMode) setMode;

  static ThemeScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ThemeScope>();

  @override
  bool updateShouldNotify(ThemeScope old) => palette != old.palette || mode != old.mode;
}
