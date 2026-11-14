import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'backend.dart';
import 'core/access_cache.dart';
import 'core/pin_auth.dart';
import 'core/theme.dart';
import 'l10n/app_localizations.dart';
import 'screens/auth_screen.dart';
import 'screens/password_screens.dart';
import 'screens/home_shell.dart';
import 'screens/warehouse_shell.dart';
import 'screens/store_name_screen.dart';
import 'sync/store_session.dart';

class App extends StatefulWidget {
  const App({
    super.key,
    required this.backend,
    required this.openStore,
    this.initialLocale = 'en',
    this.initialPalette = AppPalette.goldenIndigo,
    this.initialMode = ThemeMode.system,
    this.prefsStorage,
  });
  final Backend backend;

  /// Opens the device database; called once per signed-in session (again with safeMode if that fails).
  final OpenStore openStore;
  final String initialLocale;
  final AppPalette initialPalette;
  final ThemeMode initialMode;
  final AppPreferencesStorage? prefsStorage;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late String _locale = widget.initialLocale;
  late AppPalette _palette = widget.initialPalette;
  late ThemeMode _mode = widget.initialMode;

  void _persist() {
    final storage = widget.prefsStorage;
    if (storage != null) {
      unawaited(storage.save(AppPreferences(palette: _palette, mode: _mode, locale: _locale)));
    }
  }

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
        setPalette: (p) {
          setState(() => _palette = p);
          _persist();
        },
        setMode: (m) {
          setState(() => _mode = m);
          _persist();
        },
        child: LocaleScope(
          locale: _locale,
          setLocale: (l) {
            setState(() => _locale = l);
            _persist();
          },
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
  Timer? _refresh;
  Map<String, dynamic>? _shown;
  Object? _revalidationError;

  @override
  void initState() {
    super.initState();
    _recoverySub = widget.backend.passwordRecovery.listen((_) {
      if (mounted) setState(() => _recovering = true);
    });
    _sub = widget.backend.signedInChanges.listen((v) {
      // the stream repeats the current state on start and on token refresh; only real changes matter
      if (!mounted || v == _signedIn) return;
      if (!v) {
        // signing out takes saved access, cached offline PINs, and closes any screen opened over the old session
        _refresh?.cancel();
        _shown = null;
        unawaited(accessCache.clear());
        unawaited(SupervisorPinStorage.clearAll());
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
      setState(() {
        _signedIn = v;
        _revalidationError = null;
        _access = v ? _loadAccess() : null;
      });
    });
    if (_signedIn) _access = _loadAccess();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _recoverySub?.cancel();
    _refresh?.cancel();
    super.dispose();
  }

  /// Opens from the saved copy immediately when present and still valid, and confirms with the server in the
  /// background (stale-while-revalidate). Falls back to blocking fetch only when no saved copy exists.
  Future<Map<String, dynamic>?> _loadAccess() async {
    final saved = await accessCache.read(widget.backend.userId);
    if (saved != null) {
      _shown = saved;
      _refresh?.cancel();
      _refresh = Timer.periodic(const Duration(seconds: 60), (_) => _confirmSavedAccess());
      unawaited(_confirmSavedAccess());
      return saved;
    }
    return _fetchFreshAccess();
  }

  Future<Map<String, dynamic>?> _fetchFreshAccess() async {
    final a = await widget.backend.myAccess();
    final id = widget.backend.userId;
    if (a == null) {
      await accessCache.clear();
    } else if (id != null) {
      await accessCache.write(id, a);
    }
    _refresh?.cancel();
    _revalidationError = null;
    return _shown = a;
  }

  /// Confirms the saved copy with the server; swaps in updates or surfaces server errors (non-network failures).
  Future<void> _confirmSavedAccess() async {
    final Map<String, dynamic>? a;
    try {
      a = await widget.backend.myAccess();
    } catch (e) {
      if (serverAnswered(e)) {
        _refresh?.cancel();
        if (!mounted) return;
        setState(() {
          _shown = null;
          _revalidationError = e;
        });
      }
      return; // still no answer: stay on the saved copy
    }
    _refresh?.cancel();
    final id = widget.backend.userId;
    if (a == null) {
      await accessCache.clear();
    } else if (id != null) {
      await accessCache.write(id, a);
    }
    if (!mounted) return;
    if (_revalidationError == null && jsonEncode(a) == jsonEncode(_shown)) return;
    final fresh = a;
    setState(() {
      _revalidationError = null;
      _shown = fresh;
      _access = Future.value(fresh);
    });
  }

  void _reload() {
    final next = _fetchFreshAccess();
    setState(() {
      _revalidationError = null;
      _access = next;
    });
  }

  Widget _accessErrorScaffold(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(AppLocalizations.of(context).errGeneric),
            TextButton(onPressed: _reload, child: const Icon(Icons.refresh)),
          ]),
        ),
      );

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
    if (_revalidationError != null) return _accessErrorScaffold(context);
    return FutureBuilder<Map<String, dynamic>?>(
      future: _access,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return _accessErrorScaffold(context);
        }
        final access = snap.data;
        if (access == null) {
          return StoreNameScreen(
              backend: widget.backend, locale: widget.locale, onDone: _reload);
        }
        final name = ((access['tenant'] as Map?)?['name'] as String?) ?? '';
        final role = access['role'] as String?;
        final posEnabled = posEnabledForAccess(access);
        if (role == 'cashier' && !posEnabled) {
          return PosDisabledScreen(backend: widget.backend, storeName: name);
        }
        return StoreSession(
          backend: widget.backend,
          access: access,
          openStore: widget.openStore,
          child: syncScopeForRole(role, posEnabled: posEnabled).warehouse
              ? WarehouseShell(backend: widget.backend, storeName: name)
              : HomeShell(backend: widget.backend, storeName: name),
        );
      },
    );
  }
}
