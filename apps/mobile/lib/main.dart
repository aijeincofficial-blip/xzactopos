import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'backend.dart';
import 'data/db.dart';
import 'data/drift_store.dart';
import 'l10n/app_localizations.dart';

// Anon key only. Never the service role key. Pass with --dart-define (see run-web.ps1).
const _url = String.fromEnvironment('SUPABASE_URL');
const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_url.isEmpty || _anonKey.isEmpty) {
    runApp(const _NotConfigured());
    return;
  }
  await Supabase.initialize(url: _url, publishableKey: _anonKey);
  runApp(App(backend: SupabaseBackend(), openStore: ({bool safeMode = false}) => DriftStore(AppDatabase.open(safeMode: safeMode))));
}

class _NotConfigured extends StatelessWidget {
  const _NotConfigured();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (c) => Text(AppLocalizations.of(c).errNotConfigured),
          ),
        ),
      ),
    );
  }
}
