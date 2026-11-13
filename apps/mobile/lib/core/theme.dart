import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design_tokens.g.dart';

/// Night Market palette variants ("Night Market Classic" default & "Night Market Sage").
/// Enum identifiers stay stable for persisted user preferences across upgrades.
enum AppPalette { freshTide, goldenIndigo }

/// Spacing, radius, and stroke tokens derived from docs/tokens.json.
class Gap {
  static const double xs = 4, s = 8, m = 12, l = 16, xl = 24, xxl = 32;
  static const double radiusS = 10; // control
  static const double radiusM = 14; // input
  static const double radiusL = 24; // card
  static const double radiusXL = 24; // bottom sheet
  static const double radiusBlock = 40; // hero display block
  static const double border = DesignTokens.borderWidth; // 1.5px hairline ink/sand stroke
  static const double touchMin = 44;
  static const double touchTile = 64;
}

/// Font families & helpers bundled offline in assets/fonts/.
abstract final class NightMarketFont {
  static const String display = 'BricolageGrotesque';
  static const String sans = 'Inter';
  static const String mono = 'JetBrainsMono';
}

abstract final class NightMarketText {
  static TextStyle display(
    BuildContext context, {
    double size = 24,
    FontWeight weight = FontWeight.w800,
    Color? color,
    double? height,
    double letterSpacing = -0.6,
  }) =>
      TextStyle(
        fontFamily: NightMarketFont.display,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        height: height,
        color: color ?? Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle mono(
    BuildContext context, {
    double size = 14,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double? height,
    double letterSpacing = -0.2,
  }) =>
      TextStyle(
        fontFamily: NightMarketFont.mono,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        height: height,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color ?? Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle eyebrow(
    BuildContext context, {
    double size = 11.5,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: NightMarketFont.sans,
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.9,
        color: color ?? Theme.of(context).colorScheme.outline,
      );
}

/// Deterministic Night Market category swatch pairing for tiles/receipt thumbs.
class CategorySwatch {
  const CategorySwatch(this.background, this.foreground);
  final Color background;
  final Color foreground;
}

CategorySwatch categorySwatchFor(String name, {String? category}) {
  final haystack = '${category ?? ''} $name'.toLowerCase();
  if (RegExp(r'kape|coffee|espresso|latte|mocha|americano|choc|milo').hasMatch(haystack)) {
    return const CategorySwatch(DesignTokens.swCoffee, DesignTokens.swCoffeeFg);
  }
  if (RegExp(r'tea|matcha|milk|juice|soda|coke|sprite|water|tubig|drink|noncoffee|shake').hasMatch(haystack)) {
    return const CategorySwatch(DesignTokens.swNoncoffee, DesignTokens.swNoncoffeeFg);
  }
  if (RegExp(r'bread|pan|pastry|cake|donut|cookie|biscuit|tinapay|cracker').hasMatch(haystack)) {
    return const CategorySwatch(DesignTokens.swPastry, DesignTokens.swPastryFg);
  }
  if (RegExp(r'rice|bigas|noodle|sardinas|ulam|meal|can|oil|mantika|egg|itlog|asukal|sugar').hasMatch(haystack)) {
    return const CategorySwatch(DesignTokens.swMeal, DesignTokens.swMealFg);
  }
  const ring = [
    CategorySwatch(DesignTokens.swCoffee, DesignTokens.swCoffeeFg),
    CategorySwatch(DesignTokens.swNoncoffee, DesignTokens.swNoncoffeeFg),
    CategorySwatch(DesignTokens.swPastry, DesignTokens.swPastryFg),
    CategorySwatch(DesignTokens.swMeal, DesignTokens.swMealFg),
  ];
  final hash = name.codeUnits.fold<int>(0, (acc, c) => (acc * 31 + c) & 0x7fffffff);
  return ring[hash % ring.length];
}

String productMonogram(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '--';
  if (words.length >= 2) {
    final a = words[0].characters.firstOrNull ?? '';
    final b = words[1].characters.firstOrNull ?? '';
    final code = '$a$b'.toUpperCase();
    if (code.isNotEmpty) return code;
  }
  final chars = words.first.characters.take(2).toString().toUpperCase();
  return chars.isEmpty ? '--' : chars;
}

class AppPreferences {
  const AppPreferences({
    this.palette = AppPalette.goldenIndigo,
    this.mode = ThemeMode.system,
    this.locale = 'en',
  });

  final AppPalette palette;
  final ThemeMode mode;
  final String locale;

  AppPreferences copyWith({AppPalette? palette, ThemeMode? mode, String? locale}) => AppPreferences(
        palette: palette ?? this.palette,
        mode: mode ?? this.mode,
        locale: locale ?? this.locale,
      );
}

class AppPreferencesStorage {
  const AppPreferencesStorage();

  static const _keyPalette = 'ui_palette';
  static const _keyMode = 'ui_theme_mode';
  static const _keyLocale = 'ui_locale';

  Future<AppPreferences> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final rawPalette = p.getString(_keyPalette);
      final palette = rawPalette == AppPalette.freshTide.name ? AppPalette.freshTide : AppPalette.goldenIndigo;
      final rawMode = p.getString(_keyMode);
      final mode = switch (rawMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      final rawLocale = p.getString(_keyLocale);
      final locale = (rawLocale == 'fil' || rawLocale == 'en') ? rawLocale! : 'en';
      return AppPreferences(palette: palette, mode: mode, locale: locale);
    } catch (_) {
      return const AppPreferences();
    }
  }

  Future<void> save(AppPreferences prefs) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_keyPalette, prefs.palette.name);
      await p.setString(
        _keyMode,
        switch (prefs.mode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        },
      );
      await p.setString(_keyLocale, prefs.locale);
    } catch (_) {}
  }
}

class _P {
  const _P({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.cardBorder,
    required this.text,
    required this.textMuted,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
  });

  final Color primary, onPrimary, primaryContainer, onPrimaryContainer;
  final Color secondary, onSecondary, secondaryContainer, onSecondaryContainer;
  final Color tertiary, onTertiary, tertiaryContainer, onTertiaryContainer;
  final Color background, surface, surfaceAlt, cardBorder, text, textMuted;
  final Color error, onError, errorContainer, onErrorContainer;
}

const _errorInk = Color(0xFFA91D0F);

// Night Market Classic (Sand canvas, Ivory paper cards, Forest Ink & Electric Lime)
const _nmClassicLight = _P(
  primary: DesignTokens.ink,
  onPrimary: DesignTokens.lime,
  primaryContainer: DesignTokens.lime,
  onPrimaryContainer: DesignTokens.ink,
  secondary: DesignTokens.okDot,
  onSecondary: DesignTokens.paper,
  secondaryContainer: DesignTokens.okBg,
  onSecondaryContainer: DesignTokens.okFg,
  tertiary: DesignTokens.swPastryFg,
  onTertiary: DesignTokens.paper,
  tertiaryContainer: DesignTokens.swPastry,
  onTertiaryContainer: DesignTokens.swPastryFg,
  background: DesignTokens.sand,
  surface: DesignTokens.paper,
  surfaceAlt: DesignTokens.sand,
  cardBorder: DesignTokens.sandLine,
  text: DesignTokens.textOnLight,
  textMuted: DesignTokens.mutedOnLight,
  error: _errorInk,
  onError: DesignTokens.paper,
  errorContainer: DesignTokens.swMeal,
  onErrorContainer: DesignTokens.swMealFg,
);

const _nmClassicDark = _P(
  primary: DesignTokens.lime,
  onPrimary: DesignTokens.ink,
  primaryContainer: DesignTokens.inkLine,
  onPrimaryContainer: DesignTokens.lime,
  secondary: DesignTokens.okBg,
  onSecondary: DesignTokens.okFg,
  secondaryContainer: DesignTokens.okFg,
  onSecondaryContainer: DesignTokens.okBg,
  tertiary: DesignTokens.swPastry,
  onTertiary: DesignTokens.swPastryFg,
  tertiaryContainer: DesignTokens.swCoffee,
  onTertiaryContainer: DesignTokens.swCoffeeFg,
  background: DesignTokens.ink,
  surface: DesignTokens.ink2,
  surfaceAlt: DesignTokens.inkLine,
  cardBorder: DesignTokens.inkLine,
  text: DesignTokens.textOnDark,
  textMuted: DesignTokens.mutedOnDark,
  error: DesignTokens.swMeal,
  onError: DesignTokens.swMealFg,
  errorContainer: DesignTokens.swMealFg,
  onErrorContainer: DesignTokens.swMeal,
);

// Night Market Sage (Deep leaf primary on paper / sage leaf on deep charcoal ink)
const _nmSageLight = _P(
  primary: DesignTokens.okFg,
  onPrimary: DesignTokens.lime,
  primaryContainer: DesignTokens.okBg,
  onPrimaryContainer: DesignTokens.okFg,
  secondary: DesignTokens.swCoffee,
  onSecondary: DesignTokens.swCoffeeFg,
  secondaryContainer: DesignTokens.swPastry,
  onSecondaryContainer: DesignTokens.swPastryFg,
  tertiary: DesignTokens.swMealFg,
  onTertiary: DesignTokens.paper,
  tertiaryContainer: DesignTokens.swMeal,
  onTertiaryContainer: DesignTokens.swMealFg,
  background: DesignTokens.sand,
  surface: DesignTokens.paper,
  surfaceAlt: DesignTokens.sand,
  cardBorder: DesignTokens.sandLine,
  text: DesignTokens.textOnLight,
  textMuted: DesignTokens.mutedOnLight,
  error: _errorInk,
  onError: DesignTokens.paper,
  errorContainer: DesignTokens.swMeal,
  onErrorContainer: DesignTokens.swMealFg,
);

const _nmSageDark = _P(
  primary: DesignTokens.swNoncoffee,
  onPrimary: DesignTokens.okFg,
  primaryContainer: DesignTokens.inkLine2,
  onPrimaryContainer: DesignTokens.swNoncoffee,
  secondary: DesignTokens.swPastry,
  onSecondary: DesignTokens.swPastryFg,
  secondaryContainer: DesignTokens.swCoffee,
  onSecondaryContainer: DesignTokens.swCoffeeFg,
  tertiary: DesignTokens.swCoffeeFg,
  onTertiary: DesignTokens.swCoffee,
  tertiaryContainer: DesignTokens.swCoffee,
  onTertiaryContainer: DesignTokens.swCoffeeFg,
  background: DesignTokens.ink,
  surface: DesignTokens.ink2,
  surfaceAlt: DesignTokens.inkLine,
  cardBorder: DesignTokens.inkLine,
  text: DesignTokens.textOnDark,
  textMuted: DesignTokens.mutedOnDark,
  error: DesignTokens.swMeal,
  onError: DesignTokens.swMealFg,
  errorContainer: DesignTokens.swMealFg,
  onErrorContainer: DesignTokens.swMeal,
);

extension AppColors on ColorScheme {
  bool get isDark => brightness == Brightness.dark;

  // Night Market token surface shortcuts
  Color get nmInk => DesignTokens.ink;
  Color get nmInk2 => DesignTokens.ink2;
  Color get nmInkLine => DesignTokens.inkLine;
  Color get nmInkLine2 => DesignTokens.inkLine2;
  Color get nmPaper => DesignTokens.paper;
  Color get nmSand => DesignTokens.sand;
  Color get nmSandLine => DesignTokens.sandLine;
  Color get nmDash => isDark ? DesignTokens.inkLine2 : DesignTokens.dash;
  Color get nmLime => DesignTokens.lime;
  Color get nmLimeHover => DesignTokens.limeHover;
  Color get nmOkBg => DesignTokens.okBg;
  Color get nmOkFg => DesignTokens.okFg;
  Color get nmOkDot => DesignTokens.okDot;
  Color get nmDisabledBg => isDark ? DesignTokens.disabledBg : DesignTokens.sandLine;
  Color get nmDisabledFg => isDark ? DesignTokens.disabledFg : DesignTokens.mutedOnLight;

  /// High-contrast leaf green status foreground on the current surface.
  Color get success => isDark ? DesignTokens.okBg : DesignTokens.okDot;

  /// Night Market primary conversion surface: electric lime CTA (`onObsidian` is dark ink).
  Color get obsidian => DesignTokens.lime;

  /// Foreground ink/icons on [obsidian] (lime CTA).
  Color get onObsidian => DesignTokens.ink;

  /// Subtle highlight stroke for Night Market pill controls.
  Color get glow => DesignTokens.lime;

  /// Neutral recessed fill for unselected chips and qty badges.
  Color get chipFill => isDark ? DesignTokens.inkLine : DesignTokens.sand;

  /// Night Market emphasis accent readable on the current surface.
  Color get accent => isDark ? DesignTokens.lime : DesignTokens.okDot;

  // Payment method semantic colors harmonized with Night Market swatches
  Color get payCash => isDark ? DesignTokens.okBg : DesignTokens.okDot;
  Color get payEwallet => isDark ? DesignTokens.lime : DesignTokens.ink;
  Color get payUtang => isDark ? DesignTokens.swPastry : DesignTokens.swPastryFg;
  Color get payExpense => isDark ? DesignTokens.swMeal : _errorInk;
}

ThemeData buildTheme(AppPalette palette, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final p = switch (palette) {
    AppPalette.freshTide => dark ? _nmSageDark : _nmSageLight,
    AppPalette.goldenIndigo => dark ? _nmClassicDark : _nmClassicLight,
  };

  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.primary,
    onPrimary: p.onPrimary,
    primaryContainer: p.primaryContainer,
    onPrimaryContainer: p.onPrimaryContainer,
    secondary: p.secondary,
    onSecondary: p.onSecondary,
    secondaryContainer: p.secondaryContainer,
    onSecondaryContainer: p.onSecondaryContainer,
    tertiary: p.tertiary,
    onTertiary: p.onTertiary,
    tertiaryContainer: p.tertiaryContainer,
    onTertiaryContainer: p.onTertiaryContainer,
    error: p.error,
    onError: p.onError,
    errorContainer: p.errorContainer,
    onErrorContainer: p.onErrorContainer,
    surface: p.surface,
    onSurface: p.text,
    onSurfaceVariant: p.textMuted,
    surfaceContainerLowest: p.background,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surfaceAlt,
    surfaceContainerHigh: dark ? DesignTokens.inkLine : DesignTokens.sand,
    surfaceContainerHighest: dark ? DesignTokens.inkLine2 : DesignTokens.sandLine,
    outline: p.textMuted,
    outlineVariant: p.cardBorder,
    shadow: DesignTokens.ink,
    scrim: DesignTokens.ink,
    inverseSurface: dark ? DesignTokens.paper : DesignTokens.ink,
    onInverseSurface: dark ? DesignTokens.textOnLight : DesignTokens.textOnDark,
    inversePrimary: dark ? DesignTokens.ink : DesignTokens.lime,
  );

  final controlShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gap.radiusS));
  final inputShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gap.radiusM));
  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Gap.radiusL),
    side: BorderSide(color: p.cardBorder, width: Gap.border),
  );

  final baseText = Typography.material2021().englishLike.apply(
        fontFamily: NightMarketFont.sans,
        bodyColor: p.text,
        displayColor: p.text,
      );

  final textTheme = baseText.copyWith(
    displayLarge: baseText.displayLarge?.copyWith(
      fontFamily: NightMarketFont.display,
      fontSize: 40,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.2,
      color: p.text,
    ),
    headlineLarge: baseText.headlineLarge?.copyWith(
      fontFamily: NightMarketFont.display,
      fontSize: 30,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.9,
      color: p.text,
    ),
    headlineMedium: baseText.headlineMedium?.copyWith(
      fontFamily: NightMarketFont.display,
      fontSize: 24,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      color: p.text,
    ),
    titleLarge: baseText.titleLarge?.copyWith(
      fontFamily: NightMarketFont.display,
      fontSize: 21,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: p.text,
    ),
    titleMedium: baseText.titleMedium?.copyWith(
      fontFamily: NightMarketFont.sans,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: p.text,
    ),
    bodyLarge: baseText.bodyLarge?.copyWith(fontSize: 16, height: 1.38, color: p.text),
    bodyMedium: baseText.bodyMedium?.copyWith(fontSize: 14, height: 1.38, color: p.text),
    bodySmall: baseText.bodySmall?.copyWith(fontSize: 12.5, height: 1.35, color: p.textMuted),
    labelLarge: baseText.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.1),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: NightMarketFont.sans,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: p.background,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: NightMarketFont.display,
        fontSize: 21,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: p.text,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: cardShape,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        backgroundColor: DesignTokens.lime,
        foregroundColor: DesignTokens.ink,
        disabledBackgroundColor: dark ? DesignTokens.disabledBg : DesignTokens.sandLine,
        disabledForegroundColor: dark ? DesignTokens.disabledFg : DesignTokens.mutedOnLight,
        shape: const StadiumBorder(),
        side: BorderSide(
          color: dark ? DesignTokens.inkLine2 : DesignTokens.ink.withValues(alpha: 0.16),
          width: Gap.border,
        ),
        textStyle: const TextStyle(fontFamily: NightMarketFont.sans, fontSize: 15.5, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        foregroundColor: p.text,
        backgroundColor: p.surface,
        side: BorderSide(color: p.cardBorder, width: Gap.border),
        shape: inputShape,
        textStyle: const TextStyle(fontFamily: NightMarketFont.sans, fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        foregroundColor: p.primary,
        shape: controlShape,
        textStyle: const TextStyle(fontFamily: NightMarketFont.sans, fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 0,
      highlightElevation: 0,
      backgroundColor: DesignTokens.lime,
      foregroundColor: DesignTokens.ink,
      shape: StadiumBorder(side: BorderSide(color: DesignTokens.ink.withValues(alpha: 0.2), width: Gap.border)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      hintStyle: TextStyle(color: p.textMuted, fontSize: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Gap.radiusM),
        borderSide: BorderSide(color: p.cardBorder, width: Gap.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Gap.radiusM),
        borderSide: BorderSide(color: p.cardBorder, width: Gap.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Gap.radiusM),
        borderSide: BorderSide(color: dark ? DesignTokens.lime : DesignTokens.ink, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Gap.radiusM),
        borderSide: BorderSide(color: p.error, width: Gap.border),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surfaceAlt,
      selectedColor: DesignTokens.ink,
      side: BorderSide(color: p.cardBorder, width: Gap.border),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.text),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: DesignTokens.ink,
      surfaceTintColor: Colors.transparent,
      indicatorColor: DesignTokens.lime,
      elevation: 0,
      height: 68,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 24,
          color: s.contains(WidgetState.selected) ? DesignTokens.ink : DesignTokens.mutedOnDark,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: NightMarketFont.sans,
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? DesignTokens.textOnDark : DesignTokens.mutedOnDark,
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gap.radiusM)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: DesignTokens.ink,
      contentTextStyle: const TextStyle(fontFamily: NightMarketFont.sans, fontSize: 14, color: DesignTokens.textOnDark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Gap.radiusM),
        side: const BorderSide(color: DesignTokens.inkLine2, width: Gap.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      elevation: 0,
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Gap.radiusL),
        side: BorderSide(color: p.cardBorder, width: Gap.border),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      elevation: 0,
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Gap.radiusXL)),
      ),
    ),
    dividerTheme: DividerThemeData(color: p.cardBorder, thickness: 1, space: 1),
  );
}

/// Live theme state supplied by [App] so any screen can open the theme picker without passing callbacks around.
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
