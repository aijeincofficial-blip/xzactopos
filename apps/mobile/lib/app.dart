import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'backend.dart';
import 'core/theme.dart';
import 'l10n/app_localizations.dart';
import 'screens/auth_screen.dart';
import 'screens/password_screens.dart';
import 'screens/home_shell.dart';
import 'screens/store_name_screen.dart';
import 'sync/store_session.dart';

class App extends StatefulWidget {
  const App({super.key, required this.backend, required this.openStore, this.initialLocale = 'fil'});
  final Backend backend;

  /// Opens the device database; called once per signed-in session (again with safeMode if that fails).
  final OpenStore openStore;
  final String initialLocale;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late String _locale = widget.initialLocale;
  // Not saved between launches yet (follow-up: store the choice on the device).
  AppPalette _palette = AppPalette.freshTide;
  ThemeMode _mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
      locale: Locale(_locale),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTheme(_palette, Brightness.light),
      darkTheme: buildTheme(_palette, Brightness.dark),
      themeMode: _mode,
      builder: (context, child) => ThemeScope(
        palette: _palette,
        mode: _mode,
        setPalette: (p) => setState(() => _palette = p),
        setMode: (m) => setState(() => _mode = m),
        child: LocaleScope(
          locale: _locale,
          setLocale: (l) => setState(() => _locale = l),
          child: child!,
        ),
      ),
      home: Gate(backend: widget.backend, locale: _locale, openStore: widget.openStore),
    );
  }
}

/// Current UI language and a way to change it, for the language button in app bars.
class LocaleScope extends InheritedWidget {
  const LocaleScope({super.key, required this.locale, required this.setLocale, required super.child});
  final String locale;
  final void Function(String) setLocale;

  static LocaleScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<LocaleScope>();

  @override
  bool updateShouldNotify(LocaleScope old) => locale != old.locale;
}

/// App-bar button that shows the other language (FIL <-> EN) and switches to it.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = LocaleScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();
    final other = scope.locale == 'fil' ? 'en' : 'fil';
    return TextButton(
      key: const Key('language-button'),
      style: TextButton.styleFrom(
        minimumSize: const Size(36, 36),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () => scope.setLocale(other),
      child: Text(other.toUpperCase()),
    );
  }
}

/// Signed out -> sign in. Signed in with no store -> name your store. Otherwise Home.
class Gate extends StatefulWidget {
  const Gate({super.key, required this.backend, required this.locale, required this.openStore});
  final Backend backend;
  final String locale;
  final OpenStore openStore;

  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  late bool _signedIn = widget.backend.signedIn;
  StreamSubscription<bool>? _sub;
  StreamSubscription<void>? _recoverySub;
  bool _recovering = false;
  Future<Map<String, dynamic>?>? _access;

  @override
  void initState() {
    super.initState();
    _recoverySub = widget.backend.passwordRecovery.listen((_) {
      if (mounted) setState(() => _recovering = true);
    });
    _sub = widget.backend.signedInChanges.listen((v) {
      // the stream repeats the current state on start and on token refresh; only real changes matter
      if (!mounted || v == _signedIn) return;
      setState(() {
        _signedIn = v;
        _access = v ? widget.backend.myAccess() : null;
      });
    });
    if (_signedIn) _access = widget.backend.myAccess();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _recoverySub?.cancel();
    super.dispose();
  }

  void _reload() {
    final next = widget.backend.myAccess();
    setState(() {
      _access = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_recovering) {
      return SetPasswordScreen(
        backend: widget.backend,
        onDone: () => setState(() {
          _recovering = false;
        }),
      );
    }
    if (!_signedIn) return AuthScreen(backend: widget.backend);
    return FutureBuilder<Map<String, dynamic>?>(
      future: _access,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(AppLocalizations.of(context).errGeneric),
                TextButton(onPressed: _reload, child: const Icon(Icons.refresh)),
              ]),
            ),
          );
        }
        final access = snap.data;
        if (access == null) {
          return StoreNameScreen(
              backend: widget.backend, locale: widget.locale, onDone: _reload);
        }
        final name = ((access['tenant'] as Map?)?['name'] as String?) ?? '';
        return StoreSession(
          backend: widget.backend,
          access: access,
          openStore: widget.openStore,
          child: HomeShell(backend: widget.backend, storeName: name),
        );
      },
    );
  }
}
