import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The two colour sets the owner can pick from (light and dark exist for both).
enum AppPalette { freshTide, goldenIndigo }

/// Refactoring UI spacing (4, 8, 12, 16, 24, 32) and corner radius scale (6px controls, 10px cards).
class Gap {
  static const double xs = 4, s = 8, m = 12, l = 16, xl = 24, xxl = 32;
  static const double radiusS = 6, radiusM = 8, radiusL = 10, radiusXL = 12;
}

/// Persisted UI preferences across launches (palette, theme mode, and UI language).
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
    required this.background,
    required this.surface,
    required this.cardBorder,
    required this.text,
    required this.textMuted,
  });
  final Color primary, onPrimary, primaryContainer, onPrimaryContainer;
  final Color secondary, onSecondary, secondaryContainer, onSecondaryContainer;
  final Color tertiary; // warning (low stock)
  final Color background, surface, cardBorder, text, textMuted;
}

// Danger 600 (light) and Danger 300 (dark) from Vibecheck / Refactoring UI kit (>= 4.5:1)
const _errorLight = Color(0xFFCD201D);
const _errorDark = Color(0xFFF5978E);

// Unified Refactoring UI / Vibecheck Warm Gray + Primary Indigo (#3419d2)
const _goldLight = _P(
  primary: Color(0xFF3419D2), // Primary 600
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFF4F0FF), // Primary 50
  onPrimaryContainer: Color(0xFF160A8A), // Primary 800
  secondary: Color(0xFF31B973), // Success 600
  onSecondary: Color(0xFF062915),
  secondaryContainer: Color(0xFFF1FDF9), // Success 50
  onSecondaryContainer: Color(0xFF0E532A), // Success 900
  tertiary: Color(0xFFF7AE1D), // Warning 500
  background: Color(0xFFFBFAF9), // Warm Gray 50
  surface: Colors.white,
  cardBorder: Color(0xFFE3DDD3), // Warm Gray 200
  text: Color(0xFF3B3226), // Warm Gray 900
  textMuted: Color(0xFF716450), // Warm Gray 700
);

const _goldDark = _P(
  primary: Color(0xFFA38CF8), // Primary 300
  onPrimary: Color(0xFF0A045D), // Primary 900
  primaryContainer: Color(0xFF191438),
  onPrimaryContainer: Color(0xFFE5DCFE), // Primary 100
  secondary: Color(0xFF6BDBA7), // Success 400
  onSecondary: Color(0xFF072B16),
  secondaryContainer: Color(0xFF0E532A), // Success 900
  onSecondaryContainer: Color(0xFFE0FBF0), // Success 100
  tertiary: Color(0xFFFDC749), // Warning 400
  background: Color(0xFF12100E), // Warm Dark 50
  surface: Color(0xFF1E1B18), // Warm Dark Card
  cardBorder: Color(0xFF2B2721), // Warm Dark 200
  text: Color(0xFFFBFAF9), // Warm Gray 50
  textMuted: Color(0xFFB3A694), // Warm Gray 400
);

// Fresh Tide alternative palette (electric blue + mint on warm-compatible surfaces)
const _freshLight = _P(
  primary: Color(0xFF1A5ED4),
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFEDF4FF),
  onPrimaryContainer: Color(0xFF0F3980),
  secondary: Color(0xFF31B973),
  onSecondary: Color(0xFF062915),
  secondaryContainer: Color(0xFFF1FDF9),
  onSecondaryContainer: Color(0xFF0E532A),
  tertiary: Color(0xFFF7AE1D),
  background: Color(0xFFFBFAF9),
  surface: Colors.white,
  cardBorder: Color(0xFFE3DDD3),
  text: Color(0xFF3B3226),
  textMuted: Color(0xFF716450),
);

const _freshDark = _P(
  primary: Color(0xFF60C5FA),
  onPrimary: Color(0xFF061E38),
  primaryContainer: Color(0xFF0C2444),
  onPrimaryContainer: Color(0xFFBAE6FD),
  secondary: Color(0xFF6BDBA7),
  onSecondary: Color(0xFF072B16),
  secondaryContainer: Color(0xFF0E532A),
  onSecondaryContainer: Color(0xFFE0FBF0),
  tertiary: Color(0xFFFDC749),
  background: Color(0xFF12100E),
  surface: Color(0xFF1E1B18),
  cardBorder: Color(0xFF2B2721),
  text: Color(0xFFFBFAF9),
  textMuted: Color(0xFFB3A694),
);

/// Semantic colors derived from the active palette, so screens never hard-code hex values.
extension AppColors on ColorScheme {
  bool get isDark => brightness == Brightness.dark;

  /// Positive state (online, healthy, paid).
  Color get success => secondary;

  /// Solid surface of primary brand action buttons (Primary 600 in light, Primary 300/dark surface in dark).
  Color get obsidian => isDark ? const Color(0xFF261F59) : const Color(0xFF3419D2);

  /// Text/icons on [obsidian].
  Color get onObsidian => Colors.white;

  /// Accent border for raised POS action buttons.
  Color get glow => isDark ? const Color(0xFFA38CF8) : const Color(0xFF7658EE);

  /// Quiet fill for small chips (arrows, counters).
  Color get chipFill => isDark ? surface : primaryContainer;

  /// Accent used for the language/reports badges (follows the palette).
  Color get accent => tertiary;

  /// Payment-type colors for reports: cash, e-wallet, utang, expenses.
  Color get payCash => const Color(0xFF31B973); // Success 600
  Color get payEwallet => const Color(0xFF4D2FE4); // Primary 500
  Color get payUtang => const Color(0xFFF7AE1D); // Warning 500
  Color get payExpense => const Color(0xFFDF3A34); // Danger 500
}

ThemeData buildTheme(AppPalette palette, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final p = switch (palette) {
    AppPalette.freshTide => dark ? _freshDark : _freshLight,
    AppPalette.goldenIndigo => dark ? _goldDark : _goldLight,
  };
  final scheme = ColorScheme.fromSeed(seedColor: p.primary, brightness: brightness).copyWith(
    primary: p.primary,
    onPrimary: p.onPrimary,
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

  final controlShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gap.radiusS));
  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Gap.radiusL),
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
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: p.text),
    ),
    cardTheme: CardThemeData(color: p.surface, elevation: 0, surfaceTintColor: Colors.transparent, shape: cardShape),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: controlShape,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: controlShape,
        elevation: 0,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: controlShape,
        side: BorderSide(color: p.cardBorder, width: 1.0),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.primary,
      foregroundColor: p.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gap.radiusL)),
      elevation: 3,
      extendedTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.onPrimary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: p.surface,
      hintStyle: TextStyle(color: p.textMuted, fontSize: 14),
      prefixIconColor: p.textMuted,
      suffixIconColor: p.textMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Gap.radiusS),
        borderSide: BorderSide(color: p.cardBorder, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Gap.radiusS),
        borderSide: BorderSide(color: p.cardBorder, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Gap.radiusS),
        borderSide: BorderSide(color: p.primary, width: 2.0),
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: p.primaryContainer,
      labelStyle: TextStyle(color: p.text, fontWeight: FontWeight.w600, fontSize: 14),
      shape: controlShape,
      side: BorderSide(color: p.cardBorder, width: 1.0),
      backgroundColor: p.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.primaryContainer,
      elevation: 0,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
          color: s.contains(WidgetState.selected) ? p.text : p.textMuted,
        ),
      ),
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
