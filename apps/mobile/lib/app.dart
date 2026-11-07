import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'backend.dart';
import 'l10n/app_localizations.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/store_name_screen.dart';

class App extends StatefulWidget {
  const App({super.key, required this.backend, this.initialLocale = 'fil'});
  final Backend backend;
  final String initialLocale;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late String _locale = widget.initialLocale;

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
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      builder: (context, child) => Stack(children: [
        child!,
        Positioned(
          right: 8,
          bottom: 8,
          child: SafeArea(
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'fil', label: Text('FIL')),
                ButtonSegment(value: 'en', label: Text('EN')),
              ],
              selected: {_locale},
              onSelectionChanged: (s) => setState(() => _locale = s.first),
            ),
          ),
        ),
      ]),
      home: Gate(backend: widget.backend, locale: _locale),
    );
  }
}

/// Signed out -> sign in. Signed in with no store -> name your store. Otherwise Home.
class Gate extends StatefulWidget {
  const Gate({super.key, required this.backend, required this.locale});
  final Backend backend;
  final String locale;

  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  late bool _signedIn = widget.backend.signedIn;
  StreamSubscription<bool>? _sub;
  Future<Map<String, dynamic>?>? _access;

  @override
  void initState() {
    super.initState();
    _sub = widget.backend.signedInChanges.listen((v) {
      if (!mounted) return;
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
        return HomeScreen(backend: widget.backend, storeName: name);
      },
    );
  }
}
