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

  @override
  String get syncSynced => 'Naka-sync';

  @override
  String get syncSyncing => 'Nagsi-sync…';

  @override
  String get syncOffline => 'Walang signal';

  @override
  String syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count naghihintay ipadala',
      one: '$count naghihintay ipadala',
    );
    return '$_temp0';
  }

  @override
  String syncOfflinePending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Walang signal, $count naka-save sa phone',
      one: 'Walang signal, $count naka-save sa phone',
    );
    return '$_temp0';
  }

  @override
  String syncNeedsAttention(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kailangang ayusin',
      one: '$count kailangang ayusin',
    );
    return '$_temp0';
  }

  @override
  String productsOnDevice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count produkto sa phone na ito',
      one: '$count produkto sa phone na ito',
      zero: 'Wala pang produkto sa phone na ito',
    );
    return '$_temp0';
  }

  @override
  String get errStoreOpen => 'Hindi mabuksan ang data sa phone na ito.';

  @override
  String get tryAgain => 'Subukan ulit';

  @override
  String get products => 'Mga Produkto';

  @override
  String get sell => 'Magbenta';

  @override
  String get comingSoon => 'Malapit na';

  @override
  String get addProduct => 'Magdagdag';

  @override
  String get editProduct => 'Ayusin ang produkto';

  @override
  String get searchProducts => 'Hanapin ang pangalan o barcode';

  @override
  String get clear => 'Burahin';

  @override
  String get noProductsYet =>
      'Wala ka pang produkto. Pindutin ang \"Magdagdag\" para sa una mo.';

  @override
  String get noMatches => 'Walang nahanap.';

  @override
  String get notSentYet => 'Hindi pa naipadala';

  @override
  String get review => 'Tingnan';

  @override
  String get needsAttentionTitle => 'Mga pagbabagong hindi tinanggap ng server';

  @override
  String get nothingToFix => 'Walang aayusin.';

  @override
  String get removedProduct => 'Tinanggal na produkto';

  @override
  String get discardChange => 'Itapon';

  @override
  String get close => 'Isara';

  @override
  String get cancel => 'Huwag na';

  @override
  String get save => 'I-save';

  @override
  String get archive => 'Tanggalin';

  @override
  String archiveTitle(String name) {
    return 'Tanggalin ang $name?';
  }

  @override
  String get archiveBody =>
      'Mawawala ito sa listahan mo. Mananatili ito sa mga lumang benta.';

  @override
  String get productName => 'Pangalan ng produkto';

  @override
  String get productNameHint => 'hal. Kape 3-in-1';

  @override
  String get sellingPrice => 'Presyo';

  @override
  String get barcodeOptional => 'Barcode (kung meron)';

  @override
  String barcodeUsedBy(String name) {
    return 'Ginagamit na ang barcode na ito ng $name';
  }

  @override
  String get openingStockOptional => 'Ilan ang meron ka ngayon? (kung gusto)';

  @override
  String get openingStockHelp => 'Puwede mo itong ayusin mamaya.';

  @override
  String get more => 'Iba pa';

  @override
  String get unit => 'Yunit';

  @override
  String get unitHelp => 'piraso, pakete, kilo, bote…';

  @override
  String get costOptional => 'Puhunan (kung gusto)';

  @override
  String get errBadAmount => 'Maglagay ng numero, hal. 12.50';

  @override
  String get errDuplicateBarcode =>
      'May ibang produkto na may ganitong barcode.';

  @override
  String get errLimitProducts =>
      'Naabot mo na ang limit ng produkto sa plan mo.';

  @override
  String get errNotAllowed =>
      'Hindi puwedeng magbago ng produkto ang account mo.';

  @override
  String get errProductArchived => 'Tinanggal na ang produktong ito.';

  @override
  String get scanBarcode => 'I-scan ang barcode';

  @override
  String get unknownBarcodeTitle => 'Bagong barcode';

  @override
  String unknownBarcodeBody(String code) {
    return 'Wala pang produkto na may barcode na $code. Idagdag ngayon?';
  }
}
