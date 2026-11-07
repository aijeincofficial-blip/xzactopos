// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Filipino Pilipino (`fil`).
class AppLocalizationsFil extends AppLocalizations {
  AppLocalizationsFil([String locale = 'fil']) : super(locale);

  @override
  String get appTitle => 'Aking Tindahan';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Mag-sign in';

  @override
  String get signUp => 'Gumawa ng account';

  @override
  String get haveAccount => 'May account na ako';

  @override
  String get noAccount => 'Bago ako dito';

  @override
  String get nameYourStore => 'Ano ang pangalan ng tindahan mo?';

  @override
  String get storeNameHint => 'hal. Tindahan ni Aling Nena';

  @override
  String get startSelling => 'Simulan ang pagbebenta';

  @override
  String welcome(String store) {
    return 'Maligayang pagdating, $store!';
  }

  @override
  String get homeReady => 'Handa na ang tindahan mo. Susunod ang pagbebenta.';

  @override
  String get signOut => 'Mag-sign out';

  @override
  String get errRequired => 'Pakisulat po ito';

  @override
  String get errPasswordShort => 'Hindi bababa sa 6 na letra';

  @override
  String get errGeneric => 'May nangyaring mali. Subukan ulit.';

  @override
  String get errAlreadyHasStore => 'May tindahan na ang account na ito.';

  @override
  String get errBadLogin => 'Mali ang email o password.';

  @override
  String get errNotConfigured =>
      'Hindi nakakonekta ang app. Simulan ito gamit ang Supabase settings.';

  @override
  String get checkEmail =>
      'Tingnan ang email mo para kumpirmahin, tapos mag-sign in.';
}
