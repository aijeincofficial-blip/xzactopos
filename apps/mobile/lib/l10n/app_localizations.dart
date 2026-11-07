import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fil.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fil'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'My Store'**
  String get appTitle;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signUp;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get haveAccount;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'I am new here'**
  String get noAccount;

  /// No description provided for @nameYourStore.
  ///
  /// In en, this message translates to:
  /// **'Name your store'**
  String get nameYourStore;

  /// No description provided for @storeNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Aling Nena\'s Store'**
  String get storeNameHint;

  /// No description provided for @startSelling.
  ///
  /// In en, this message translates to:
  /// **'Start selling'**
  String get startSelling;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {store}!'**
  String welcome(String store);

  /// No description provided for @homeReady.
  ///
  /// In en, this message translates to:
  /// **'Your store is ready. Selling is coming next.'**
  String get homeReady;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @errRequired.
  ///
  /// In en, this message translates to:
  /// **'Please fill this in'**
  String get errRequired;

  /// No description provided for @errPasswordShort.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get errPasswordShort;

  /// No description provided for @errGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errGeneric;

  /// No description provided for @errAlreadyHasStore.
  ///
  /// In en, this message translates to:
  /// **'This account already has a store.'**
  String get errAlreadyHasStore;

  /// No description provided for @errBadLogin.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password.'**
  String get errBadLogin;

  /// No description provided for @errNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'App is not connected. Start it with the Supabase settings.'**
  String get errNotConfigured;

  /// No description provided for @checkEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email to confirm, then sign in.'**
  String get checkEmail;

  /// No description provided for @syncSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get syncSynced;

  /// No description provided for @syncSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncSyncing;

  /// No description provided for @syncOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get syncOffline;

  /// No description provided for @syncPending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} waiting to send} other{{count} waiting to send}}'**
  String syncPending(int count);

  /// No description provided for @syncOfflinePending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Offline, {count} saved on this phone} other{Offline, {count} saved on this phone}}'**
  String syncOfflinePending(int count);

  /// No description provided for @syncNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} needs attention} other{{count} need attention}}'**
  String syncNeedsAttention(int count);

  /// No description provided for @productsOnDevice.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No products on this phone yet} =1{{count} product on this phone} other{{count} products on this phone}}'**
  String productsOnDevice(int count);

  /// No description provided for @errStoreOpen.
  ///
  /// In en, this message translates to:
  /// **'Could not open the data on this phone.'**
  String get errStoreOpen;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// No description provided for @sell.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get sell;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get addProduct;

  /// No description provided for @editProduct.
  ///
  /// In en, this message translates to:
  /// **'Edit product'**
  String get editProduct;

  /// No description provided for @searchProducts.
  ///
  /// In en, this message translates to:
  /// **'Search name or barcode'**
  String get searchProducts;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @noProductsYet.
  ///
  /// In en, this message translates to:
  /// **'No products yet. Tap \"Add product\" to add your first one.'**
  String get noProductsYet;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'Nothing found.'**
  String get noMatches;

  /// No description provided for @notSentYet.
  ///
  /// In en, this message translates to:
  /// **'Not sent yet'**
  String get notSentYet;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @needsAttentionTitle.
  ///
  /// In en, this message translates to:
  /// **'Changes the server did not accept'**
  String get needsAttentionTitle;

  /// No description provided for @nothingToFix.
  ///
  /// In en, this message translates to:
  /// **'Nothing to fix.'**
  String get nothingToFix;

  /// No description provided for @removedProduct.
  ///
  /// In en, this message translates to:
  /// **'Removed product'**
  String get removedProduct;

  /// No description provided for @discardChange.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardChange;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get archive;

  /// No description provided for @archiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String archiveTitle(String name);

  /// No description provided for @archiveBody.
  ///
  /// In en, this message translates to:
  /// **'It will disappear from your list. Past sales keep it.'**
  String get archiveBody;

  /// No description provided for @productName.
  ///
  /// In en, this message translates to:
  /// **'Product name'**
  String get productName;

  /// No description provided for @productNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Kape 3-in-1'**
  String get productNameHint;

  /// No description provided for @sellingPrice.
  ///
  /// In en, this message translates to:
  /// **'Selling price'**
  String get sellingPrice;

  /// No description provided for @barcodeOptional.
  ///
  /// In en, this message translates to:
  /// **'Barcode (optional)'**
  String get barcodeOptional;

  /// No description provided for @barcodeUsedBy.
  ///
  /// In en, this message translates to:
  /// **'This barcode is already used by {name}'**
  String barcodeUsedBy(String name);

  /// No description provided for @openingStockOptional.
  ///
  /// In en, this message translates to:
  /// **'How many do you have now? (optional)'**
  String get openingStockOptional;

  /// No description provided for @openingStockHelp.
  ///
  /// In en, this message translates to:
  /// **'You can fix this later.'**
  String get openingStockHelp;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @unitHelp.
  ///
  /// In en, this message translates to:
  /// **'pc, pack, kg, bottle…'**
  String get unitHelp;

  /// No description provided for @costOptional.
  ///
  /// In en, this message translates to:
  /// **'Your cost (optional)'**
  String get costOptional;

  /// No description provided for @errBadAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a number, like 12.50'**
  String get errBadAmount;

  /// No description provided for @errDuplicateBarcode.
  ///
  /// In en, this message translates to:
  /// **'Another product already has this barcode.'**
  String get errDuplicateBarcode;

  /// No description provided for @errLimitProducts.
  ///
  /// In en, this message translates to:
  /// **'You reached the product limit of your plan.'**
  String get errLimitProducts;

  /// No description provided for @errNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Your account cannot change products.'**
  String get errNotAllowed;

  /// No description provided for @errProductArchived.
  ///
  /// In en, this message translates to:
  /// **'This product was removed.'**
  String get errProductArchived;

  /// No description provided for @scanBarcode.
  ///
  /// In en, this message translates to:
  /// **'Scan barcode'**
  String get scanBarcode;

  /// No description provided for @unknownBarcodeTitle.
  ///
  /// In en, this message translates to:
  /// **'New barcode'**
  String get unknownBarcodeTitle;

  /// No description provided for @unknownBarcodeBody.
  ///
  /// In en, this message translates to:
  /// **'No product has barcode {code} yet. Add it now?'**
  String unknownBarcodeBody(String code);

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @choosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get choosePhoto;

  /// No description provided for @photoFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not use that photo. Try another one.'**
  String get photoFailed;

  /// No description provided for @errPhotoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The photo is too large.'**
  String get errPhotoTooLarge;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @sellSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search or scan to add'**
  String get sellSearchHint;

  /// No description provided for @sellCartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tap an item to add it'**
  String get sellCartEmpty;

  /// No description provided for @sellPay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get sellPay;

  /// No description provided for @sellNoPrice.
  ///
  /// In en, this message translates to:
  /// **'Set a price for this product first'**
  String get sellNoPrice;

  /// No description provided for @sellUnknownBarcode.
  ///
  /// In en, this message translates to:
  /// **'No product has barcode {code}'**
  String sellUnknownBarcode(String code);

  /// No description provided for @sellQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get sellQuantity;

  /// No description provided for @sellClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear this sale?'**
  String get sellClearTitle;

  /// No description provided for @sellClearBody.
  ///
  /// In en, this message translates to:
  /// **'Everything in the list will be removed.'**
  String get sellClearBody;

  /// No description provided for @sellItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} item} other{{count} items}}'**
  String sellItems(int count);

  /// No description provided for @sellStockLeft.
  ///
  /// In en, this message translates to:
  /// **'{n} left'**
  String sellStockLeft(String n);

  /// No description provided for @sellOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'None left (you can still sell)'**
  String get sellOutOfStock;

  /// No description provided for @payTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payTitle;

  /// No description provided for @payTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get payTotal;

  /// No description provided for @payCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get payCash;

  /// No description provided for @payEwallet.
  ///
  /// In en, this message translates to:
  /// **'GCash / Maya'**
  String get payEwallet;

  /// No description provided for @payReceivedCash.
  ///
  /// In en, this message translates to:
  /// **'Cash received (leave empty if exact)'**
  String get payReceivedCash;

  /// No description provided for @payReceivedEwallet.
  ///
  /// In en, this message translates to:
  /// **'Amount received'**
  String get payReceivedEwallet;

  /// No description provided for @payExact.
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get payExact;

  /// No description provided for @payChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get payChange;

  /// No description provided for @payAllUtang.
  ///
  /// In en, this message translates to:
  /// **'All on utang'**
  String get payAllUtang;

  /// No description provided for @payOnUtang.
  ///
  /// In en, this message translates to:
  /// **'{amount} goes on utang'**
  String payOnUtang(String amount);

  /// No description provided for @payChooseCustomer.
  ///
  /// In en, this message translates to:
  /// **'Choose who owes'**
  String get payChooseCustomer;

  /// No description provided for @payDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get payDiscount;

  /// No description provided for @payDiscountHint.
  ///
  /// In en, this message translates to:
  /// **'Pesos off the total'**
  String get payDiscountHint;

  /// No description provided for @payDone.
  ///
  /// In en, this message translates to:
  /// **'Finish sale'**
  String get payDone;

  /// No description provided for @customerNew.
  ///
  /// In en, this message translates to:
  /// **'New customer'**
  String get customerNew;

  /// No description provided for @customerName.
  ///
  /// In en, this message translates to:
  /// **'Customer name'**
  String get customerName;

  /// No description provided for @customerPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get customerPhone;

  /// No description provided for @customerSearch.
  ///
  /// In en, this message translates to:
  /// **'Search customers'**
  String get customerSearch;

  /// No description provided for @receiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receiptTitle;

  /// No description provided for @receiptNumber.
  ///
  /// In en, this message translates to:
  /// **'Receipt no. {no}'**
  String receiptNumber(String no);

  /// No description provided for @receiptSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get receiptSubtotal;

  /// No description provided for @receiptDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get receiptDiscount;

  /// No description provided for @receiptCashReceived.
  ///
  /// In en, this message translates to:
  /// **'Cash received'**
  String get receiptCashReceived;

  /// No description provided for @receiptOnUtang.
  ///
  /// In en, this message translates to:
  /// **'On utang'**
  String get receiptOnUtang;

  /// No description provided for @receiptBalance.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s utang balance: {amount}'**
  String receiptBalance(String name, String amount);

  /// No description provided for @receiptNewSale.
  ///
  /// In en, this message translates to:
  /// **'New sale'**
  String get receiptNewSale;

  /// No description provided for @receiptCancelled.
  ///
  /// In en, this message translates to:
  /// **'CANCELLED'**
  String get receiptCancelled;

  /// No description provided for @receiptThanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you!'**
  String get receiptThanks;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fil'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fil':
      return AppLocalizationsFil();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
