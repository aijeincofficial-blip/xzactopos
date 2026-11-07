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

  @override
  String get syncSynced => 'Synced';

  @override
  String get syncSyncing => 'Syncing…';

  @override
  String get syncOffline => 'Offline';

  @override
  String syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count waiting to send',
      one: '$count waiting to send',
    );
    return '$_temp0';
  }

  @override
  String syncOfflinePending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Offline, $count saved on this phone',
      one: 'Offline, $count saved on this phone',
    );
    return '$_temp0';
  }

  @override
  String syncNeedsAttention(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count need attention',
      one: '$count needs attention',
    );
    return '$_temp0';
  }

  @override
  String productsOnDevice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products on this phone',
      one: '$count product on this phone',
      zero: 'No products on this phone yet',
    );
    return '$_temp0';
  }

  @override
  String get errStoreOpen => 'Could not open the data on this phone.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get products => 'Products';

  @override
  String get sell => 'Sell';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get addProduct => 'Add product';

  @override
  String get editProduct => 'Edit product';

  @override
  String get searchProducts => 'Search name or barcode';

  @override
  String get clear => 'Clear';

  @override
  String get noProductsYet =>
      'No products yet. Tap \"Add product\" to add your first one.';

  @override
  String get noMatches => 'Nothing found.';

  @override
  String get notSentYet => 'Not sent yet';

  @override
  String get review => 'Review';

  @override
  String get needsAttentionTitle => 'Changes the server did not accept';

  @override
  String get nothingToFix => 'Nothing to fix.';

  @override
  String get removedProduct => 'Removed product';

  @override
  String get discardChange => 'Discard';

  @override
  String get close => 'Close';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get archive => 'Remove';

  @override
  String archiveTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get archiveBody =>
      'It will disappear from your list. Past sales keep it.';

  @override
  String get productName => 'Product name';

  @override
  String get productNameHint => 'e.g. Kape 3-in-1';

  @override
  String get sellingPrice => 'Selling price';

  @override
  String get barcodeOptional => 'Barcode (optional)';

  @override
  String barcodeUsedBy(String name) {
    return 'This barcode is already used by $name';
  }

  @override
  String get openingStockOptional => 'How many do you have now? (optional)';

  @override
  String get openingStockHelp => 'You can fix this later.';

  @override
  String get more => 'More';

  @override
  String get unit => 'Unit';

  @override
  String get unitHelp => 'pc, pack, kg, bottle…';

  @override
  String get costOptional => 'Your cost (optional)';

  @override
  String get errBadAmount => 'Enter a number, like 12.50';

  @override
  String get errDuplicateBarcode => 'Another product already has this barcode.';

  @override
  String get errLimitProducts => 'You reached the product limit of your plan.';

  @override
  String get errNotAllowed => 'Your account cannot change products.';

  @override
  String get errProductArchived => 'This product was removed.';

  @override
  String get scanBarcode => 'Scan barcode';

  @override
  String get unknownBarcodeTitle => 'New barcode';

  @override
  String unknownBarcodeBody(String code) {
    return 'No product has barcode $code yet. Add it now?';
  }
}
