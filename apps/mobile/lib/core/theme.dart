import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The two colour sets the owner can pick from (light and dark exist for both).
enum AppPalette { freshTide, goldenIndigo }

/// Spacing (4, 8, 12, 16, 24, 32) and soft sculptural mobile corner radii.
class Gap {
  static const double xs = 4, s = 8, m = 12, l = 16, xl = 24, xxl = 32;
  static const double radiusS = 14, radiusM = 16, radiusL = 18, radiusXL = 24;
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

// Danger 600 (light) and Danger 400 (dark) matching Web tokens (>= 4.5:1)
const _errorLight = Color(0xFFDC2626);
const _errorDark = Color(0xFFF87171);

// Default Cobalt Royal (#2563EB) + Cool Neutral Slate (#F4F7FB - #0F172A) matching Web UI
const _goldLight = _P(
  primary: Color(0xFF2563EB), // Cobalt 600 (5.17:1 on white)
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFEFF6FF), // Cobalt 50
  onPrimaryContainer: Color(0xFF1E40AF), // Cobalt 800
  secondary: Color(0xFF047857), // Emerald 700 (5.14:1 on white)
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFECFDF5), // Emerald 50
  onSecondaryContainer: Color(0xFF065F46), // Emerald 800
  tertiary: Color(0xFFF59E0B), // Amber 500
  background: Color(0xFFF4F7FB), // Airy Cool Slate-Ice Canvas
  surface: Colors.white,
  cardBorder: Color(0xFFE2E8F0), // Cool Slate 200
  text: Color(0xFF0F172A), // Cool Slate 900
  textMuted: Color(0xFF475569), // Cool Slate 600 (>= 6.9:1)
);

const _goldDark = _P(
  primary: Color(0xFF60A5FA), // Cobalt 400
  onPrimary: Color(0xFF08142C), // Deep Navy
  primaryContainer: Color(0xFF172554), // Cobalt 950
  onPrimaryContainer: Color(0xFFDBEAFE), // Cobalt 100
  secondary: Color(0xFF34D399), // Emerald 400
  onSecondary: Color(0xFF022C22), // Emerald 950
  secondaryContainer: Color(0xFF064E3B), // Emerald 900
  onSecondaryContainer: Color(0xFFD1FAE5), // Emerald 100
  tertiary: Color(0xFFFBBF24), // Amber 400
  background: Color(0xFF0B1120), // Obsidian Slate 950
  surface: Color(0xFF131C2E), // Deep Frosted Slate Card
  cardBorder: Color(0xFF1E293B), // Cool Slate 800
  text: Color(0xFFF8FAFC), // Cool Slate 50
  textMuted: Color(0xFF94A3B8), // Cool Slate 400 (>= 6.4:1)
);

// Fresh Tide alternative palette (Ocean Sky + Mint on Cool Neutral Slate surfaces)
const _freshLight = _P(
  primary: Color(0xFF0369A1), // Sky 700 (5.9:1 on white)
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFF0F9FF), // Sky 50
  onPrimaryContainer: Color(0xFF075985), // Sky 800
  secondary: Color(0xFF047857), // Emerald 700
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFECFDF5),
  onSecondaryContainer: Color(0xFF065F46),
  tertiary: Color(0xFFF59E0B),
  background: Color(0xFFF4F7FB),
  surface: Colors.white,
  cardBorder: Color(0xFFE2E8F0),
  text: Color(0xFF0F172A),
  textMuted: Color(0xFF475569),
);

const _freshDark = _P(
  primary: Color(0xFF38BDF8), // Sky 400
  onPrimary: Color(0xFF082F49),
  primaryContainer: Color(0xFF0C4A6E),
  onPrimaryContainer: Color(0xFFE0F2FE),
  secondary: Color(0xFF34D399),
  onSecondary: Color(0xFF022C22),
  secondaryContainer: Color(0xFF064E3B),
  onSecondaryContainer: Color(0xFFD1FAE5),
  tertiary: Color(0xFFFBBF24),
  background: Color(0xFF0B1120),
  surface: Color(0xFF131C2E),
  cardBorder: Color(0xFF1E293B),
  text: Color(0xFFF8FAFC),
  textMuted: Color(0xFF94A3B8),
);

/// Semantic colors derived from the active palette, so screens never hard-code hex values.
extension AppColors on ColorScheme {
  bool get isDark => brightness == Brightness.dark;

  /// Positive state (online, healthy, paid).
  Color get success => isDark ? const Color(0xFF34D399) : const Color(0xFF059669);

  /// Solid surface of primary brand action buttons (Cobalt Royal matching Web).
  Color get obsidian => const Color(0xFF2563EB);

  /// Text/icons on [obsidian].
  Color get onObsidian => Colors.white;

  /// Crisp white / subtle cobalt accent on primary action buttons.
  Color get glow => Colors.white;

  /// Quiet fill for small chips and stat containers.
  Color get chipFill => isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

  /// Accent used for the language/reports badges (follows the palette).
  Color get accent => tertiary;

  /// Payment-type colors for reports: cash, e-wallet, utang, expenses.
  Color get payCash => isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
  Color get payEwallet => isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
  Color get payUtang => isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
  Color get payExpense => isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
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
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: p.text),
    ),
    dividerTheme: DividerThemeData(color: p.cardBorder, thickness: 1, space: 1),
    cardTheme: CardThemeData(color: p.surface, elevation: 0, surfaceTintColor: Colors.transparent, shape: cardShape),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: controlShape,
        elevation: 0,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: controlShape,
        elevation: 0,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: controlShape,
        foregroundColor: p.text,
        backgroundColor: p.surface,
        side: BorderSide(color: p.cardBorder, width: 1.0),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF2563EB),
      foregroundColor: Colors.white,
      shape: StadiumBorder(),
      elevation: 3,
      extendedTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      isDense: true,
      filled: true,
      fillColor: p.surface,
      hintStyle: TextStyle(color: p.textMuted, fontSize: 14, fontWeight: FontWeight.w400),
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
        borderSide: BorderSide(color: p.primary, width: 1.6),
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: p.primaryContainer,
      secondarySelectedColor: p.primaryContainer,
      checkmarkColor: p.onPrimaryContainer,
      labelStyle: TextStyle(color: p.text, fontWeight: FontWeight.w600, fontSize: 13),
      secondaryLabelStyle: TextStyle(color: p.onPrimaryContainer, fontWeight: FontWeight.w600, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: p.cardBorder, width: 1.0),
      backgroundColor: p.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.primaryContainer,
      elevation: 0,
      height: 64,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 22,
          color: s.contains(WidgetState.selected) ? p.primary : p.textMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11.5,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? p.primary : p.textMuted,
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
