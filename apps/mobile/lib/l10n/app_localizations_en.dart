// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'My Store';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get signUp => 'Create account';

  @override
  String get haveAccount => 'I already have an account';

  @override
  String get noAccount => 'I am new here';

  @override
  String get nameYourStore => 'Name your store';

  @override
  String get storeNameHint => 'e.g. Aling Nena\'s Store';

  @override
  String get startSelling => 'Start selling';

  @override
  String welcome(String store) {
    return 'Welcome, $store!';
  }

  @override
  String get homeReady => 'Your store is ready. Selling is coming next.';

  @override
  String get signOut => 'Sign out';

  @override
  String get errRequired => 'Please fill this in';

  @override
  String get errPasswordShort => 'At least 6 characters';

  @override
  String get errGeneric => 'Something went wrong. Please try again.';

  @override
  String get errAlreadyHasStore => 'This account already has a store.';

  @override
  String get errBadLogin => 'Wrong email or password.';

  @override
  String get errNotConfigured =>
      'App is not connected. Start it with the Supabase settings.';

  @override
  String get checkEmail => 'Check your email to confirm, then sign in.';
}
