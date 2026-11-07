import 'package:flutter/material.dart';

/// The two colour sets the owner can pick from (light and dark exist for both).
enum AppPalette { freshTide, goldenIndigo }

/// Spacing and radius scale for the whole app.
class Gap {
  static const double xs = 4, s = 8, m = 12, l = 16, xl = 20, xxl = 28;
  static const double radiusS = 12, radiusM = 18, radiusL = 24, radiusXL = 30;
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
    required this.cardBorder,
    required this.text,
    required this.textMuted,
  });
  final Color primary, primaryContainer, onPrimaryContainer;
  final Color secondary, onSecondary, secondaryContainer, onSecondaryContainer;
  final Color tertiary; // warning (low stock)
  final Color background, surface, cardBorder, text, textMuted;
}

// Utang owed, void, errors
const _errorLight = Color(0xFFD6334A);
const _errorDark = Color(0xFFFF8A94);

// Fresh cool porcelain aesthetic inspired by modern fintech/Web3
const _freshLight = _P(
  primary: Color(0xFF1E6FF2),
  primaryContainer: Color(0xFFEDF4FF),
  onPrimaryContainer: Color(0xFF0F3980),
  secondary: Color(0xFF0A8268), // mint / emerald
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFE4F7F2),
  onSecondaryContainer: Color(0xFF064839),
  tertiary: Color(0xFFF59E0B), // amber
  background: Color(0xFFF1F4F9), // cool porcelain mist
  surface: Colors.white,
  cardBorder: Color(0xFFE4E9F2),
  text: Color(0xFF0F172A),
  textMuted: Color(0xFF64748B),
);

const _freshDark = _P(
  primary: Color(0xFF5B9BFF),
  primaryContainer: Color(0xFF152A4A),
  onPrimaryContainer: Color(0xFFD6E5FF),
  secondary: Color(0xFF2FD9B2),
  onSecondary: Color(0xFF04241C),
  secondaryContainer: Color(0xFF0F3B32),
  onSecondaryContainer: Color(0xFFC6F5EA),
  tertiary: Color(0xFFFFB84D),
  background: Color(0xFF0B101D),
  surface: Color(0xFF131B2E),
  cardBorder: Color(0xFF1E2B45),
  text: Color(0xFFF1F5F9),
  textMuted: Color(0xFF94A3B8),
);

const _goldLight = _P(
  primary: Color(0xFF3B52E8),
  primaryContainer: Color(0xFFEEF1FF),
  onPrimaryContainer: Color(0xFF1A277A),
  secondary: Color(0xFFF59E0B),
  onSecondary: Color(0xFF261900),
  secondaryContainer: Color(0xFFFEF3C7),
  onSecondaryContainer: Color(0xFF78350F),
  tertiary: Color(0xFFEA580C),
  background: Color(0xFFF2F4FA),
  surface: Colors.white,
  cardBorder: Color(0xFFE5E8F3),
  text: Color(0xFF0F172A),
  textMuted: Color(0xFF64748B),
);

const _goldDark = _P(
  primary: Color(0xFF8197FF),
  primaryContainer: Color(0xFF222B60),
  onPrimaryContainer: Color(0xFFDDE2FF),
  secondary: Color(0xFFFFD25E),
  onSecondary: Color(0xFF2B2000),
  secondaryContainer: Color(0xFF4D3800),
  onSecondaryContainer: Color(0xFFFFEFC2),
  tertiary: Color(0xFFFF9D5C),
  background: Color(0xFF0C1021),
  surface: Color(0xFF151C36),
  cardBorder: Color(0xFF222D52),
  text: Color(0xFFF1F5F9),
  textMuted: Color(0xFF94A3B8),
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
    outline: p.textMuted,
    outlineVariant: p.cardBorder,
  );

  const shape = StadiumBorder();
  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Gap.radiusXL),
    side: BorderSide(color: p.cardBorder, width: 1.0),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: p.text),
    ),
    cardTheme: CardThemeData(color: p.surface, elevation: 0, surfaceTintColor: Colors.transparent, shape: cardShape),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        shape: shape,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(64, 56),
        shape: shape,
        elevation: 0,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 56),
        shape: shape,
        side: BorderSide(color: p.cardBorder, width: 1.5),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.secondary,
      foregroundColor: p.onSecondary,
      shape: const StadiumBorder(),
      elevation: 4,
    ),
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      filled: true,
      fillColor: p.surface,
      hintStyle: TextStyle(color: p.textMuted, fontSize: 15),
      prefixIconColor: p.textMuted,
      suffixIconColor: p.textMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Gap.radiusXL),
        borderSide: BorderSide(color: p.cardBorder, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Gap.radiusXL),
        borderSide: BorderSide(color: p.cardBorder, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Gap.radiusXL),
        borderSide: BorderSide(color: p.primary, width: 2.0),
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: p.primaryContainer,
      labelStyle: TextStyle(color: p.text, fontWeight: FontWeight.w600, fontSize: 14),
      shape: const StadiumBorder(),
      side: BorderSide(color: p.cardBorder, width: 1.0),
      backgroundColor: p.surface,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.surface, surfaceTintColor: Colors.transparent, shape: cardShape),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Gap.radiusXL))),
    ),
  );
}

/// Chosen palette and brightness, with a way to change them.
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
