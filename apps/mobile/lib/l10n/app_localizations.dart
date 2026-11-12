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

  /// No description provided for @tabToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tabToday;

  /// No description provided for @tabPos.
  ///
  /// In en, this message translates to:
  /// **'POS'**
  String get tabPos;

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

  /// No description provided for @utangTitle.
  ///
  /// In en, this message translates to:
  /// **'Utang'**
  String get utangTitle;

  /// No description provided for @utangTotalOwed.
  ///
  /// In en, this message translates to:
  /// **'Total owed to you'**
  String get utangTotalOwed;

  /// No description provided for @utangEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nobody owes you yet. Customers show up here when you sell on utang.'**
  String get utangEmpty;

  /// No description provided for @utangSettled.
  ///
  /// In en, this message translates to:
  /// **'Fully paid'**
  String get utangSettled;

  /// No description provided for @utangOwes.
  ///
  /// In en, this message translates to:
  /// **'Owes'**
  String get utangOwes;

  /// No description provided for @utangPaid.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get utangPaid;

  /// No description provided for @utangPayTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} paid'**
  String utangPayTitle(String name);

  /// No description provided for @utangAmountPaid.
  ///
  /// In en, this message translates to:
  /// **'Amount paid'**
  String get utangAmountPaid;

  /// No description provided for @utangNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get utangNote;

  /// No description provided for @utangTooMuch.
  ///
  /// In en, this message translates to:
  /// **'That is more than they owe ({amount})'**
  String utangTooMuch(String amount);

  /// No description provided for @ledgerCharge.
  ///
  /// In en, this message translates to:
  /// **'Took on utang'**
  String get ledgerCharge;

  /// No description provided for @ledgerPayment.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get ledgerPayment;

  /// No description provided for @ledgerAdjust.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get ledgerAdjust;

  /// No description provided for @ledgerVoid.
  ///
  /// In en, this message translates to:
  /// **'Sale cancelled'**
  String get ledgerVoid;

  /// No description provided for @todayTitle.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayTitle;

  /// No description provided for @todaySales.
  ///
  /// In en, this message translates to:
  /// **'Sales today'**
  String get todaySales;

  /// No description provided for @todayCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No sales} =1{{count} sale} other{{count} sales}}'**
  String todayCount(int count);

  /// No description provided for @todayCash.
  ///
  /// In en, this message translates to:
  /// **'Cash in'**
  String get todayCash;

  /// No description provided for @todayUtang.
  ///
  /// In en, this message translates to:
  /// **'On utang'**
  String get todayUtang;

  /// No description provided for @todayNone.
  ///
  /// In en, this message translates to:
  /// **'No sales yet today.'**
  String get todayNone;

  /// No description provided for @saleCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel this sale'**
  String get saleCancelButton;

  /// No description provided for @saleCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this sale?'**
  String get saleCancelTitle;

  /// No description provided for @saleCancelBody.
  ///
  /// In en, this message translates to:
  /// **'The items go back to your stock and any utang from this sale is removed.'**
  String get saleCancelBody;

  /// No description provided for @saleCancelYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, cancel it'**
  String get saleCancelYes;

  /// No description provided for @saleCancelNo.
  ///
  /// In en, this message translates to:
  /// **'No, keep it'**
  String get saleCancelNo;

  /// No description provided for @stockTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get stockTitle;

  /// No description provided for @stockAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get stockAll;

  /// No description provided for @stockLowCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Low} =1{{count} low} other{{count} low}}'**
  String stockLowCount(int count);

  /// No description provided for @stockNoneLow.
  ///
  /// In en, this message translates to:
  /// **'Nothing is running low.'**
  String get stockNoneLow;

  /// No description provided for @stockNotCounted.
  ///
  /// In en, this message translates to:
  /// **'Not counted'**
  String get stockNotCounted;

  /// No description provided for @stockRunningLow.
  ///
  /// In en, this message translates to:
  /// **'Running low'**
  String get stockRunningLow;

  /// No description provided for @stockNow.
  ///
  /// In en, this message translates to:
  /// **'Now: {n}'**
  String stockNow(String n);

  /// No description provided for @stockIn.
  ///
  /// In en, this message translates to:
  /// **'Stock in'**
  String get stockIn;

  /// No description provided for @stockCount.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get stockCount;

  /// No description provided for @stockInTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock in: {name}'**
  String stockInTitle(String name);

  /// No description provided for @stockInQty.
  ///
  /// In en, this message translates to:
  /// **'How many came in?'**
  String get stockInQty;

  /// No description provided for @stockInCost.
  ///
  /// In en, this message translates to:
  /// **'Cost each (optional)'**
  String get stockInCost;

  /// No description provided for @stockCountTitle.
  ///
  /// In en, this message translates to:
  /// **'Count: {name}'**
  String stockCountTitle(String name);

  /// No description provided for @stockCountQty.
  ///
  /// In en, this message translates to:
  /// **'How many do you have now?'**
  String get stockCountQty;

  /// No description provided for @reasonCounted.
  ///
  /// In en, this message translates to:
  /// **'Counted'**
  String get reasonCounted;

  /// No description provided for @reasonDamage.
  ///
  /// In en, this message translates to:
  /// **'Damaged / expired'**
  String get reasonDamage;

  /// No description provided for @reasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reasonOther;

  /// No description provided for @reorderPoint.
  ///
  /// In en, this message translates to:
  /// **'Warn me when stock is at or below'**
  String get reorderPoint;

  /// No description provided for @reorderPointHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for no warning'**
  String get reorderPointHelp;

  /// No description provided for @sellStockLow.
  ///
  /// In en, this message translates to:
  /// **'{n} left, running low'**
  String sellStockLow(String n);

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// No description provided for @reportsAllStores.
  ///
  /// In en, this message translates to:
  /// **'All stores'**
  String get reportsAllStores;

  /// No description provided for @reportsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get reportsRefresh;

  /// No description provided for @reportsDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} day} other{{count} days}}'**
  String reportsDays(int count);

  /// No description provided for @reportsSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get reportsSales;

  /// No description provided for @reportsProfit.
  ///
  /// In en, this message translates to:
  /// **'Estimated profit: {amount}'**
  String reportsProfit(String amount);

  /// No description provided for @reportsPerDay.
  ///
  /// In en, this message translates to:
  /// **'Per day'**
  String get reportsPerDay;

  /// No description provided for @reportsTopItems.
  ///
  /// In en, this message translates to:
  /// **'Best sellers'**
  String get reportsTopItems;

  /// No description provided for @reportsNothingYet.
  ///
  /// In en, this message translates to:
  /// **'No sales in this period.'**
  String get reportsNothingYet;

  /// No description provided for @reportsQty.
  ///
  /// In en, this message translates to:
  /// **'{n} sold'**
  String reportsQty(String n);

  /// No description provided for @reportsUtangOwed.
  ///
  /// In en, this message translates to:
  /// **'Owed to you: {amount}'**
  String reportsUtangOwed(String amount);

  /// No description provided for @reportsAsOf.
  ///
  /// In en, this message translates to:
  /// **'No signal. Showing the last report from {when}.'**
  String reportsAsOf(String when);

  /// No description provided for @reportsNeedSignal.
  ///
  /// In en, this message translates to:
  /// **'Reports need a signal the first time. Connect and try again.'**
  String get reportsNeedSignal;

  /// No description provided for @reportsNotSent.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} sale or change is not sent yet and is not included.} other{{count} sales or changes are not sent yet and are not included.}}'**
  String reportsNotSent(int count);

  /// No description provided for @syncSignIn.
  ///
  /// In en, this message translates to:
  /// **'Session ended. Sign out and sign in again; nothing is lost.'**
  String get syncSignIn;

  /// No description provided for @unsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsent changes'**
  String get unsentTitle;

  /// No description provided for @unsentBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This phone still has {count} change from another business that was never sent.} other{This phone still has {count} changes from another business that were never sent.}} Sign in to that business to send them, or discard them and continue.'**
  String unsentBody(int count);

  /// No description provided for @unsentDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard them and continue'**
  String get unsentDiscard;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @forgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get forgotTitle;

  /// No description provided for @forgotSend.
  ///
  /// In en, this message translates to:
  /// **'Send link'**
  String get forgotSend;

  /// No description provided for @forgotSent.
  ///
  /// In en, this message translates to:
  /// **'If that email has an account, we sent a link to reset the password.'**
  String get forgotSent;

  /// No description provided for @newPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password'**
  String get newPasswordTitle;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Type it again'**
  String get confirmPassword;

  /// No description provided for @passwordsDiffer.
  ///
  /// In en, this message translates to:
  /// **'The two passwords are different'**
  String get passwordsDiffer;

  /// No description provided for @passwordSaved.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get passwordSaved;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @themeTitle.
  ///
  /// In en, this message translates to:
  /// **'Look of the app'**
  String get themeTitle;

  /// No description provided for @themeColors.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get themeColors;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get themeMode;

  /// No description provided for @paletteFreshTide.
  ///
  /// In en, this message translates to:
  /// **'Fresh Tide (blue and mint)'**
  String get paletteFreshTide;

  /// No description provided for @paletteGoldenIndigo.
  ///
  /// In en, this message translates to:
  /// **'Golden Indigo (blue and gold)'**
  String get paletteGoldenIndigo;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Same as phone'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @utangAdjust.
  ///
  /// In en, this message translates to:
  /// **'Adjust balance'**
  String get utangAdjust;

  /// No description provided for @utangAdjustTitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust {name}\'s balance'**
  String utangAdjustTitle(String name);

  /// No description provided for @utangWriteOff.
  ///
  /// In en, this message translates to:
  /// **'Owes less (write off)'**
  String get utangWriteOff;

  /// No description provided for @utangAddMore.
  ///
  /// In en, this message translates to:
  /// **'Owes more (correction)'**
  String get utangAddMore;

  /// No description provided for @utangAdjustAmount.
  ///
  /// In en, this message translates to:
  /// **'How much?'**
  String get utangAdjustAmount;

  /// No description provided for @utangAdjusted.
  ///
  /// In en, this message translates to:
  /// **'Balance adjusted'**
  String get utangAdjusted;

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan a barcode'**
  String get scanTitle;

  /// No description provided for @scanHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the barcode'**
  String get scanHint;

  /// No description provided for @scanDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get scanDone;

  /// No description provided for @scanLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get scanLight;

  /// No description provided for @scanCameraDenied.
  ///
  /// In en, this message translates to:
  /// **'The camera is not available. Allow it in the phone settings, then try again.'**
  String get scanCameraDenied;

  /// No description provided for @scanAdded.
  ///
  /// In en, this message translates to:
  /// **'Added: {name}'**
  String scanAdded(String name);

  /// No description provided for @scanWithCamera.
  ///
  /// In en, this message translates to:
  /// **'Scan with camera'**
  String get scanWithCamera;

  /// No description provided for @receiptPrint.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get receiptPrint;

  /// No description provided for @receiptShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get receiptShare;

  /// No description provided for @receiptPrintFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the printer. Try Share instead.'**
  String get receiptPrintFailed;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @activeStore.
  ///
  /// In en, this message translates to:
  /// **'Active store'**
  String get activeStore;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance & theme'**
  String get settingsAppearance;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @settingsLanguageRegion.
  ///
  /// In en, this message translates to:
  /// **'Language & region'**
  String get settingsLanguageRegion;

  /// No description provided for @systemLanguage.
  ///
  /// In en, this message translates to:
  /// **'System language'**
  String get systemLanguage;

  /// No description provided for @languageCurrentName.
  ///
  /// In en, this message translates to:
  /// **'English (US)'**
  String get languageCurrentName;

  /// No description provided for @switchLanguage.
  ///
  /// In en, this message translates to:
  /// **'Lumipat sa FIL'**
  String get switchLanguage;

  /// No description provided for @settingsSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security & account'**
  String get settingsSecurity;

  /// No description provided for @updatePasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Update your login password'**
  String get updatePasswordHint;

  /// No description provided for @endSessionHint.
  ///
  /// In en, this message translates to:
  /// **'End session on this phone'**
  String get endSessionHint;

  /// No description provided for @localDbNote.
  ///
  /// In en, this message translates to:
  /// **'Local database: encrypted & synced'**
  String get localDbNote;

  /// No description provided for @storeSettings.
  ///
  /// In en, this message translates to:
  /// **'Store settings'**
  String get storeSettings;

  /// No description provided for @storeSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Theme, mode, language & account'**
  String get storeSettingsHint;

  /// No description provided for @startFirstSale.
  ///
  /// In en, this message translates to:
  /// **'Start your first sale'**
  String get startFirstSale;

  /// No description provided for @totalSalesToday.
  ///
  /// In en, this message translates to:
  /// **'Total sales today'**
  String get totalSalesToday;

  /// No description provided for @tileUtangSub.
  ///
  /// In en, this message translates to:
  /// **'Who owes you'**
  String get tileUtangSub;

  /// No description provided for @tileStockSub.
  ///
  /// In en, this message translates to:
  /// **'What you have left'**
  String get tileStockSub;

  /// No description provided for @tileProductsSub.
  ///
  /// In en, this message translates to:
  /// **'Catalog & prices'**
  String get tileProductsSub;

  /// No description provided for @tileReportsSub.
  ///
  /// In en, this message translates to:
  /// **'Sales & profit'**
  String get tileReportsSub;

  /// No description provided for @reportsRevenueSub.
  ///
  /// In en, this message translates to:
  /// **'Total store revenue'**
  String get reportsRevenueSub;

  /// No description provided for @reportsAvgOrder.
  ///
  /// In en, this message translates to:
  /// **'Average order'**
  String get reportsAvgOrder;

  /// No description provided for @reportsTotalOrders.
  ///
  /// In en, this message translates to:
  /// **'Total orders'**
  String get reportsTotalOrders;

  /// No description provided for @reportsInventoryHealth.
  ///
  /// In en, this message translates to:
  /// **'Inventory health'**
  String get reportsInventoryHealth;

  /// No description provided for @reportsAllHealthy.
  ///
  /// In en, this message translates to:
  /// **'All tracked stocks healthy'**
  String get reportsAllHealthy;

  /// No description provided for @tileStockLow.
  ///
  /// In en, this message translates to:
  /// **'{count} low'**
  String tileStockLow(int count);

  /// No description provided for @reportsNeedReorder.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} item needs reordering} other{{count} items need reordering}}'**
  String reportsNeedReorder(int count);

  /// No description provided for @sellPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned {name} to the top'**
  String sellPinned(String name);

  /// No description provided for @sellUnpinned.
  ///
  /// In en, this message translates to:
  /// **'Unpinned {name}'**
  String sellUnpinned(String name);

  /// No description provided for @sellPinHint.
  ///
  /// In en, this message translates to:
  /// **'Hold an item to pin it as a favorite'**
  String get sellPinHint;

  /// No description provided for @restockTitle.
  ///
  /// In en, this message translates to:
  /// **'Restock list'**
  String get restockTitle;

  /// No description provided for @restockEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to buy. Nothing is running low.'**
  String get restockEmpty;

  /// No description provided for @restockShareHeader.
  ///
  /// In en, this message translates to:
  /// **'Shopping list'**
  String get restockShareHeader;

  /// No description provided for @restockCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy list'**
  String get restockCopy;

  /// No description provided for @restockCopied.
  ///
  /// In en, this message translates to:
  /// **'List copied. Paste it into a message.'**
  String get restockCopied;

  /// No description provided for @restockNow.
  ///
  /// In en, this message translates to:
  /// **'Now: {n}'**
  String restockNow(String n);

  /// No description provided for @restockBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy {count}'**
  String restockBuy(int count);

  /// No description provided for @restockItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} item} other{{count} items}}'**
  String restockItems(int count);

  /// No description provided for @restockEstimate.
  ///
  /// In en, this message translates to:
  /// **'About {amount}'**
  String restockEstimate(String amount);

  /// No description provided for @exportSection.
  ///
  /// In en, this message translates to:
  /// **'Export & backup'**
  String get exportSection;

  /// No description provided for @exportHint.
  ///
  /// In en, this message translates to:
  /// **'Send as a spreadsheet file (CSV) by message or email'**
  String get exportHint;

  /// No description provided for @exportSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get exportSales;

  /// No description provided for @exportUtang.
  ///
  /// In en, this message translates to:
  /// **'Utang'**
  String get exportUtang;

  /// No description provided for @exportStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get exportStock;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not share the file. Try again.'**
  String get exportFailed;

  /// No description provided for @expensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expensesTitle;

  /// No description provided for @expensesSpentToday.
  ///
  /// In en, this message translates to:
  /// **'Spent today'**
  String get expensesSpentToday;

  /// No description provided for @expensesNone.
  ///
  /// In en, this message translates to:
  /// **'No expenses today'**
  String get expensesNone;

  /// No description provided for @expenseAdd.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get expenseAdd;

  /// No description provided for @expenseAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get expenseAmount;

  /// No description provided for @expenseNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get expenseNote;

  /// No description provided for @expensePaidFrom.
  ///
  /// In en, this message translates to:
  /// **'Paid from'**
  String get expensePaidFrom;

  /// No description provided for @expensePaidCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get expensePaidCash;

  /// No description provided for @expensePaidEwallet.
  ///
  /// In en, this message translates to:
  /// **'E-wallet'**
  String get expensePaidEwallet;

  /// No description provided for @expenseCategoryStockPurchase.
  ///
  /// In en, this message translates to:
  /// **'Stock purchase'**
  String get expenseCategoryStockPurchase;

  /// No description provided for @expenseCategoryUtilities.
  ///
  /// In en, this message translates to:
  /// **'Electric, water'**
  String get expenseCategoryUtilities;

  /// No description provided for @expenseCategoryTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get expenseCategoryTransport;

  /// No description provided for @expenseCategoryWages.
  ///
  /// In en, this message translates to:
  /// **'Wages'**
  String get expenseCategoryWages;

  /// No description provided for @expenseCategoryRent.
  ///
  /// In en, this message translates to:
  /// **'Rent'**
  String get expenseCategoryRent;

  /// No description provided for @expenseCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get expenseCategoryOther;

  /// No description provided for @expenseVoidTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this expense?'**
  String get expenseVoidTitle;

  /// No description provided for @expenseVoidBody.
  ///
  /// In en, this message translates to:
  /// **'It stays in the list, crossed out, and no longer counts.'**
  String get expenseVoidBody;

  /// No description provided for @expenseVoidReason.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get expenseVoidReason;

  /// No description provided for @expenseVoidYes.
  ///
  /// In en, this message translates to:
  /// **'Cancel expense'**
  String get expenseVoidYes;

  /// No description provided for @expenseCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get expenseCancelled;

  /// No description provided for @expenseNeedsPin.
  ///
  /// In en, this message translates to:
  /// **'Needs supervisor PIN'**
  String get expenseNeedsPin;

  /// No description provided for @approvalTitle.
  ///
  /// In en, this message translates to:
  /// **'Supervisor PIN'**
  String get approvalTitle;

  /// No description provided for @approvalBody.
  ///
  /// In en, this message translates to:
  /// **'A supervisor must approve this. Enter the supervisor\'s PIN (needs signal).'**
  String get approvalBody;

  /// No description provided for @approvalPin.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get approvalPin;

  /// No description provided for @approvalApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approvalApprove;

  /// No description provided for @approvalWrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN. Try again.'**
  String get approvalWrongPin;

  /// No description provided for @approvalLocked.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong tries. Wait a few minutes.'**
  String get approvalLocked;

  /// No description provided for @approvalNoPin.
  ///
  /// In en, this message translates to:
  /// **'This person has not set a PIN yet.'**
  String get approvalNoPin;

  /// No description provided for @approvalNeedsSignal.
  ///
  /// In en, this message translates to:
  /// **'No signal. The PIN can only be checked online.'**
  String get approvalNeedsSignal;

  /// No description provided for @approvalRefused.
  ///
  /// In en, this message translates to:
  /// **'This approval was refused.'**
  String get approvalRefused;

  /// No description provided for @dayCloseTitle.
  ///
  /// In en, this message translates to:
  /// **'Close the day'**
  String get dayCloseTitle;

  /// No description provided for @dayCloseExpected.
  ///
  /// In en, this message translates to:
  /// **'Cash that should be in the drawer'**
  String get dayCloseExpected;

  /// No description provided for @dayCloseHelp.
  ///
  /// In en, this message translates to:
  /// **'Opening cash + cash sales + utang payments - cash expenses'**
  String get dayCloseHelp;

  /// No description provided for @dayCloseCounted.
  ///
  /// In en, this message translates to:
  /// **'Cash you counted'**
  String get dayCloseCounted;

  /// No description provided for @dayCloseNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get dayCloseNote;

  /// No description provided for @dayCloseExact.
  ///
  /// In en, this message translates to:
  /// **'Exact. Nothing short or over.'**
  String get dayCloseExact;

  /// No description provided for @dayCloseSave.
  ///
  /// In en, this message translates to:
  /// **'Save count'**
  String get dayCloseSave;

  /// No description provided for @dayCloseSaved.
  ///
  /// In en, this message translates to:
  /// **'Day closed'**
  String get dayCloseSaved;

  /// No description provided for @dayCloseAgain.
  ///
  /// In en, this message translates to:
  /// **'Count again'**
  String get dayCloseAgain;

  /// No description provided for @dayCloseNeedsPin.
  ///
  /// In en, this message translates to:
  /// **'Needs supervisor PIN'**
  String get dayCloseNeedsPin;

  /// No description provided for @dayCloseShort.
  ///
  /// In en, this message translates to:
  /// **'Short by {amount}'**
  String dayCloseShort(String amount);

  /// No description provided for @dayCloseOver.
  ///
  /// In en, this message translates to:
  /// **'Over by {amount}'**
  String dayCloseOver(String amount);

  /// No description provided for @dayCloseLast.
  ///
  /// In en, this message translates to:
  /// **'Last count: {amount} at {time}'**
  String dayCloseLast(String amount, String time);

  /// No description provided for @expensesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} expense} other{{count} expenses}}'**
  String expensesCount(int count);

  /// No description provided for @reportsExpensesNote.
  ///
  /// In en, this message translates to:
  /// **'Stock you bought is already in your cost of goods, so it is not taken off twice.'**
  String get reportsExpensesNote;

  /// No description provided for @reportsExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses (not stock): {amount}'**
  String reportsExpenses(String amount);

  /// No description provided for @reportsNetProfit.
  ///
  /// In en, this message translates to:
  /// **'Profit after expenses: {amount}'**
  String reportsNetProfit(String amount);

  /// No description provided for @reportsStockBought.
  ///
  /// In en, this message translates to:
  /// **'Stock bought: {amount}'**
  String reportsStockBought(String amount);

  /// No description provided for @servicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Load & e-wallet'**
  String get servicesTitle;

  /// No description provided for @servicesFeesToday.
  ///
  /// In en, this message translates to:
  /// **'Earned today (fees)'**
  String get servicesFeesToday;

  /// No description provided for @servicesFloat.
  ///
  /// In en, this message translates to:
  /// **'Wallet float'**
  String get servicesFloat;

  /// No description provided for @servicesNeedsTopup.
  ///
  /// In en, this message translates to:
  /// **'Needs a top-up'**
  String get servicesNeedsTopup;

  /// No description provided for @servicesNone.
  ///
  /// In en, this message translates to:
  /// **'No load or e-wallet entries today'**
  String get servicesNone;

  /// No description provided for @serviceCashIn.
  ///
  /// In en, this message translates to:
  /// **'Cash in'**
  String get serviceCashIn;

  /// No description provided for @serviceCashOut.
  ///
  /// In en, this message translates to:
  /// **'Cash out'**
  String get serviceCashOut;

  /// No description provided for @serviceLoad.
  ///
  /// In en, this message translates to:
  /// **'Sell load'**
  String get serviceLoad;

  /// No description provided for @serviceMoveFloat.
  ///
  /// In en, this message translates to:
  /// **'Move float'**
  String get serviceMoveFloat;

  /// No description provided for @serviceCashInHint.
  ///
  /// In en, this message translates to:
  /// **'Customer gives cash, you send e-wallet money'**
  String get serviceCashInHint;

  /// No description provided for @serviceCashOutHint.
  ///
  /// In en, this message translates to:
  /// **'Customer sends e-wallet money, you give cash'**
  String get serviceCashOutHint;

  /// No description provided for @serviceFloatTopup.
  ///
  /// In en, this message translates to:
  /// **'Top up from the drawer'**
  String get serviceFloatTopup;

  /// No description provided for @serviceFloatWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw to the drawer'**
  String get serviceFloatWithdraw;

  /// No description provided for @serviceFloatAdjust.
  ///
  /// In en, this message translates to:
  /// **'Correct the balance'**
  String get serviceFloatAdjust;

  /// No description provided for @walletGcash.
  ///
  /// In en, this message translates to:
  /// **'GCash'**
  String get walletGcash;

  /// No description provided for @walletMaya.
  ///
  /// In en, this message translates to:
  /// **'Maya'**
  String get walletMaya;

  /// No description provided for @walletLoad.
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get walletLoad;

  /// No description provided for @walletOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get walletOther;

  /// No description provided for @serviceWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get serviceWallet;

  /// No description provided for @serviceAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get serviceAmount;

  /// No description provided for @serviceLoadAmount.
  ///
  /// In en, this message translates to:
  /// **'Load amount'**
  String get serviceLoadAmount;

  /// No description provided for @serviceFee.
  ///
  /// In en, this message translates to:
  /// **'Fee you charge'**
  String get serviceFee;

  /// No description provided for @servicePrice.
  ///
  /// In en, this message translates to:
  /// **'Customer pays (cash)'**
  String get servicePrice;

  /// No description provided for @serviceRef.
  ///
  /// In en, this message translates to:
  /// **'Phone or reference (optional)'**
  String get serviceRef;

  /// No description provided for @serviceNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get serviceNote;

  /// No description provided for @serviceNoteRequired.
  ///
  /// In en, this message translates to:
  /// **'A note is needed'**
  String get serviceNoteRequired;

  /// No description provided for @servicePriceTooLow.
  ///
  /// In en, this message translates to:
  /// **'The price must be at least the load amount'**
  String get servicePriceTooLow;

  /// No description provided for @serviceAdjustHint.
  ///
  /// In en, this message translates to:
  /// **'Use a minus for less, e.g. -50'**
  String get serviceAdjustHint;

  /// No description provided for @serviceVoidTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this entry?'**
  String get serviceVoidTitle;

  /// No description provided for @serviceVoidBody.
  ///
  /// In en, this message translates to:
  /// **'It stays in the list, crossed out, and the money moves back.'**
  String get serviceVoidBody;

  /// No description provided for @serviceVoidYes.
  ///
  /// In en, this message translates to:
  /// **'Cancel entry'**
  String get serviceVoidYes;

  /// No description provided for @serviceNeedsPin.
  ///
  /// In en, this message translates to:
  /// **'Needs supervisor PIN'**
  String get serviceNeedsPin;

  /// No description provided for @serviceEarned.
  ///
  /// In en, this message translates to:
  /// **'Earned {amount}'**
  String serviceEarned(String amount);

  /// No description provided for @tingiSection.
  ///
  /// In en, this message translates to:
  /// **'Sold by piece too'**
  String get tingiSection;

  /// No description provided for @tingiHelp.
  ///
  /// In en, this message translates to:
  /// **'Open a pack to add the pieces to your stock'**
  String get tingiHelp;

  /// No description provided for @tingiPieces.
  ///
  /// In en, this message translates to:
  /// **'Pieces in one pack'**
  String get tingiPieces;

  /// No description provided for @tingiPieceName.
  ///
  /// In en, this message translates to:
  /// **'Piece name'**
  String get tingiPieceName;

  /// No description provided for @tingiPiecePrice.
  ///
  /// In en, this message translates to:
  /// **'Price per piece'**
  String get tingiPiecePrice;

  /// No description provided for @tingiFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not link the pieces. This product may already be a piece of another pack.'**
  String get tingiFailed;

  /// No description provided for @tingiOpenPack.
  ///
  /// In en, this message translates to:
  /// **'Open a pack'**
  String get tingiOpenPack;

  /// No description provided for @tingiPacks.
  ///
  /// In en, this message translates to:
  /// **'How many packs?'**
  String get tingiPacks;

  /// No description provided for @tingiLowWarn.
  ///
  /// In en, this message translates to:
  /// **'You counted fewer packs than this. You can still go ahead.'**
  String get tingiLowWarn;

  /// No description provided for @tingiHistory.
  ///
  /// In en, this message translates to:
  /// **'Opened packs'**
  String get tingiHistory;

  /// No description provided for @tingiHistoryNone.
  ///
  /// In en, this message translates to:
  /// **'No packs opened yet'**
  String get tingiHistoryNone;

  /// No description provided for @tingiVoidTitle.
  ///
  /// In en, this message translates to:
  /// **'Undo this opening?'**
  String get tingiVoidTitle;

  /// No description provided for @tingiVoidBody.
  ///
  /// In en, this message translates to:
  /// **'The pieces leave your stock and the pack comes back.'**
  String get tingiVoidBody;

  /// No description provided for @tingiVoidYes.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get tingiVoidYes;

  /// No description provided for @tingiLinkChanged.
  ///
  /// In en, this message translates to:
  /// **'The pieces per pack changed. Check the product.'**
  String get tingiLinkChanged;

  /// No description provided for @tingiCancelled.
  ///
  /// In en, this message translates to:
  /// **'Undone'**
  String get tingiCancelled;

  /// No description provided for @tingiPieceSuffix.
  ///
  /// In en, this message translates to:
  /// **'{name} (piece)'**
  String tingiPieceSuffix(String name);

  /// No description provided for @tingiLinkedTo.
  ///
  /// In en, this message translates to:
  /// **'Pieces are sold as {name}'**
  String tingiLinkedTo(String name);

  /// No description provided for @tingiOpenTitle.
  ///
  /// In en, this message translates to:
  /// **'Open a pack: {name}'**
  String tingiOpenTitle(String name);

  /// No description provided for @tingiPreview.
  ///
  /// In en, this message translates to:
  /// **'That makes {count} × {name}'**
  String tingiPreview(int count, String name);

  /// No description provided for @tingiOpened.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} piece added to stock} other{{count} pieces added to stock}}'**
  String tingiOpened(int count);

  /// No description provided for @tingiHistoryRow.
  ///
  /// In en, this message translates to:
  /// **'{packs} pack → {pieces} × {name}'**
  String tingiHistoryRow(int packs, int pieces, String name);

  /// No description provided for @utangDueSet.
  ///
  /// In en, this message translates to:
  /// **'Set pay-by date'**
  String get utangDueSet;

  /// No description provided for @utangDueChange.
  ///
  /// In en, this message translates to:
  /// **'Change date'**
  String get utangDueChange;

  /// No description provided for @utangDueClear.
  ///
  /// In en, this message translates to:
  /// **'Clear date'**
  String get utangDueClear;

  /// No description provided for @utangSendStatement.
  ///
  /// In en, this message translates to:
  /// **'Send statement'**
  String get utangSendStatement;

  /// No description provided for @utangOverdueNone.
  ///
  /// In en, this message translates to:
  /// **'Nobody is overdue'**
  String get utangOverdueNone;

  /// No description provided for @stmtTitle.
  ///
  /// In en, this message translates to:
  /// **'Utang statement'**
  String get stmtTitle;

  /// No description provided for @stmtBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get stmtBalance;

  /// No description provided for @stmtDueOn.
  ///
  /// In en, this message translates to:
  /// **'Pay by'**
  String get stmtDueOn;

  /// No description provided for @stmtRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get stmtRecent;

  /// No description provided for @stmtCharge.
  ///
  /// In en, this message translates to:
  /// **'Utang'**
  String get stmtCharge;

  /// No description provided for @stmtPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get stmtPayment;

  /// No description provided for @stmtAdjust.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get stmtAdjust;

  /// No description provided for @stockExpirySet.
  ///
  /// In en, this message translates to:
  /// **'Set expiry date'**
  String get stockExpirySet;

  /// No description provided for @stockExpiryClear.
  ///
  /// In en, this message translates to:
  /// **'Clear expiry date'**
  String get stockExpiryClear;

  /// No description provided for @stockInExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expiry date (optional)'**
  String get stockInExpiry;

  /// No description provided for @stockNoneExpiring.
  ///
  /// In en, this message translates to:
  /// **'Nothing is close to expiring.'**
  String get stockNoneExpiring;

  /// No description provided for @utangDueOn.
  ///
  /// In en, this message translates to:
  /// **'Pay by {date}'**
  String utangDueOn(String date);

  /// No description provided for @utangOverdueDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} day overdue} other{{count} days overdue}}'**
  String utangOverdueDays(int count);

  /// No description provided for @utangOverdueFilter.
  ///
  /// In en, this message translates to:
  /// **'Overdue ({count})'**
  String utangOverdueFilter(int count);

  /// No description provided for @tileUtangOverdue.
  ///
  /// In en, this message translates to:
  /// **'{count} overdue'**
  String tileUtangOverdue(int count);

  /// No description provided for @stockExpiringFilter.
  ///
  /// In en, this message translates to:
  /// **'Expiring ({count})'**
  String stockExpiringFilter(int count);

  /// No description provided for @stockExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Expires today} =1{Expires tomorrow} other{Expires in {count} days}}'**
  String stockExpiresIn(int count);

  /// No description provided for @stockExpiredAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Expired yesterday} other{Expired {count} days ago}}'**
  String stockExpiredAgo(int count);

  /// No description provided for @tileStockExpiring.
  ///
  /// In en, this message translates to:
  /// **'{count} expiring'**
  String tileStockExpiring(int count);

  /// No description provided for @dataTitle.
  ///
  /// In en, this message translates to:
  /// **'Import & export'**
  String get dataTitle;

  /// No description provided for @dataExportSection.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get dataExportSection;

  /// No description provided for @dataImportSection.
  ///
  /// In en, this message translates to:
  /// **'Import products'**
  String get dataImportSection;

  /// No description provided for @dataImportHint.
  ///
  /// In en, this message translates to:
  /// **'Copy rows from a spreadsheet and paste them here. Columns: name, price, barcode, cost, stock.'**
  String get dataImportHint;

  /// No description provided for @dataImportOpen.
  ///
  /// In en, this message translates to:
  /// **'Paste products'**
  String get dataImportOpen;

  /// No description provided for @dataImportTemplate.
  ///
  /// In en, this message translates to:
  /// **'Copy the column names'**
  String get dataImportTemplate;

  /// No description provided for @dataTemplateCopied.
  ///
  /// In en, this message translates to:
  /// **'Column names copied. Paste them into a spreadsheet.'**
  String get dataTemplateCopied;

  /// No description provided for @dataImportPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste the rows here'**
  String get dataImportPaste;

  /// No description provided for @dataTooMany.
  ///
  /// In en, this message translates to:
  /// **'Only the first 500 rows are read at a time. Import the rest in another batch.'**
  String get dataTooMany;

  /// No description provided for @dataProbName.
  ///
  /// In en, this message translates to:
  /// **'name is missing'**
  String get dataProbName;

  /// No description provided for @dataProbPrice.
  ///
  /// In en, this message translates to:
  /// **'price is not a number'**
  String get dataProbPrice;

  /// No description provided for @dataProbCost.
  ///
  /// In en, this message translates to:
  /// **'cost is not a number'**
  String get dataProbCost;

  /// No description provided for @dataProbStock.
  ///
  /// In en, this message translates to:
  /// **'stock is not a number'**
  String get dataProbStock;

  /// No description provided for @exportProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get exportProducts;

  /// No description provided for @dataImportReady.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} product ready} other{{count} products ready}}'**
  String dataImportReady(int count);

  /// No description provided for @dataImportProblems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} row has a problem and is left out} other{{count} rows have a problem and are left out}}'**
  String dataImportProblems(int count);

  /// No description provided for @dataImportLine.
  ///
  /// In en, this message translates to:
  /// **'Row {line}: {problem}'**
  String dataImportLine(int line, String problem);

  /// No description provided for @dataImportGo.
  ///
  /// In en, this message translates to:
  /// **'Import {count}'**
  String dataImportGo(int count);

  /// No description provided for @dataImported.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} product added} other{{count} products added}}'**
  String dataImported(int count);

  /// No description provided for @dataSkipped.
  ///
  /// In en, this message translates to:
  /// **'{count} skipped: barcode already used'**
  String dataSkipped(int count);

  /// No description provided for @dayCloseOpening.
  ///
  /// In en, this message translates to:
  /// **'Cash you started with (sukli)'**
  String get dayCloseOpening;

  /// No description provided for @dayCloseOpeningLine.
  ///
  /// In en, this message translates to:
  /// **'Started with {amount}'**
  String dayCloseOpeningLine(String amount);

  /// No description provided for @keypadAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to sale'**
  String get keypadAdd;

  /// No description provided for @sellModeItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get sellModeItems;

  /// No description provided for @sellModeKeypad.
  ///
  /// In en, this message translates to:
  /// **'Keypad'**
  String get sellModeKeypad;

  /// No description provided for @openAmountName.
  ///
  /// In en, this message translates to:
  /// **'Other item'**
  String get openAmountName;

  /// No description provided for @payWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'Which wallet?'**
  String get payWalletTitle;

  /// No description provided for @noProductsHere.
  ///
  /// In en, this message translates to:
  /// **'You have no products yet. Add one, or import a list under More > Import & export.'**
  String get noProductsHere;

  /// No description provided for @storePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch store'**
  String get storePickerTitle;

  /// No description provided for @storeSwitched.
  ///
  /// In en, this message translates to:
  /// **'Now selling at {name}'**
  String storeSwitched(String name);

  /// No description provided for @storeSwitchAsk.
  ///
  /// In en, this message translates to:
  /// **'Switch store?'**
  String get storeSwitchAsk;

  /// No description provided for @storeSwitchKeep.
  ///
  /// In en, this message translates to:
  /// **'Switch and keep the sale'**
  String get storeSwitchKeep;

  /// No description provided for @storeSwitchClear.
  ///
  /// In en, this message translates to:
  /// **'Switch and clear the sale'**
  String get storeSwitchClear;

  /// No description provided for @storeSwitchBody.
  ///
  /// In en, this message translates to:
  /// **'A sale is in progress ({count, plural, =1{{count} item} other{{count} items}}). If you keep it, it will be paid at {store} and the stock comes off there.'**
  String storeSwitchBody(int count, String store);

  /// No description provided for @upgradeFullSection.
  ///
  /// In en, this message translates to:
  /// **'Full Mode'**
  String get upgradeFullSection;

  /// No description provided for @upgradeFullTitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Full Mode'**
  String get upgradeFullTitle;

  /// No description provided for @upgradeFullSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add more stores, warehouse, and cashier staff. Your solo data stays 100% intact.'**
  String get upgradeFullSubtitle;

  /// No description provided for @upgradeFullAction.
  ///
  /// In en, this message translates to:
  /// **'Learn More'**
  String get upgradeFullAction;

  /// No description provided for @upgradeFullDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Full Mode Upgrade'**
  String get upgradeFullDialogTitle;

  /// No description provided for @upgradeFullDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Full Mode unlocks multiple branches, a central warehouse, and role-based staff accounts (Cashier, Manager, Supervisor). All your current sales, products, stock, and utang records are safely retained in place.\n\nTo upgrade, open the XZACTO POS web app in any browser and use the Upgrade Wizard.'**
  String get upgradeFullDialogBody;

  /// No description provided for @upgradeFullClose.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get upgradeFullClose;

  /// No description provided for @whTabReceive.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get whTabReceive;

  /// No description provided for @whTabCount.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get whTabCount;

  /// No description provided for @whTabStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get whTabStock;

  /// No description provided for @whTabMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get whTabMore;

  /// No description provided for @whNoWarehouse.
  ///
  /// In en, this message translates to:
  /// **'No warehouse yet. Connect to the internet once so your warehouses can load.'**
  String get whNoWarehouse;

  /// No description provided for @whSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose warehouse'**
  String get whSwitchTitle;

  /// No description provided for @whSwitched.
  ///
  /// In en, this message translates to:
  /// **'Working in {name}'**
  String whSwitched(String name);

  /// No description provided for @whSwitchAction.
  ///
  /// In en, this message translates to:
  /// **'Switch warehouse'**
  String get whSwitchAction;

  /// No description provided for @whOpenOrders.
  ///
  /// In en, this message translates to:
  /// **'Open orders'**
  String get whOpenOrders;

  /// No description provided for @whNoOrders.
  ///
  /// In en, this message translates to:
  /// **'No open orders in this warehouse.'**
  String get whNoOrders;

  /// No description provided for @whOrderLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} left to receive} other{{count} left to receive}}'**
  String whOrderLeft(num count);

  /// No description provided for @whOrderComplete.
  ///
  /// In en, this message translates to:
  /// **'Fully received'**
  String get whOrderComplete;

  /// No description provided for @whWaitingSync.
  ///
  /// In en, this message translates to:
  /// **'Waiting to sync'**
  String get whWaitingSync;

  /// No description provided for @whStatusOrdered.
  ///
  /// In en, this message translates to:
  /// **'Ordered'**
  String get whStatusOrdered;

  /// No description provided for @whStatusPartly.
  ///
  /// In en, this message translates to:
  /// **'Partly received'**
  String get whStatusPartly;

  /// No description provided for @whOrderLines.
  ///
  /// In en, this message translates to:
  /// **'Items on this order'**
  String get whOrderLines;

  /// No description provided for @whLineProgress.
  ///
  /// In en, this message translates to:
  /// **'{received} of {ordered} received'**
  String whLineProgress(String received, String ordered);

  /// No description provided for @whReceipts.
  ///
  /// In en, this message translates to:
  /// **'Receipts from this phone'**
  String get whReceipts;

  /// No description provided for @whNoReceipts.
  ///
  /// In en, this message translates to:
  /// **'Nothing received on this phone yet.'**
  String get whNoReceipts;

  /// No description provided for @whReceiptWalkin.
  ///
  /// In en, this message translates to:
  /// **'Delivery without an order'**
  String get whReceiptWalkin;

  /// No description provided for @whSearchStock.
  ///
  /// In en, this message translates to:
  /// **'Search stock'**
  String get whSearchStock;

  /// No description provided for @whNoStock.
  ///
  /// In en, this message translates to:
  /// **'No stock in this warehouse yet.'**
  String get whNoStock;

  /// No description provided for @whStockPending.
  ///
  /// In en, this message translates to:
  /// **'{qty} on the way in'**
  String whStockPending(String qty);

  /// No description provided for @whCountSoon.
  ///
  /// In en, this message translates to:
  /// **'Counting on the phone is coming soon. Use the web app for stock counts for now.'**
  String get whCountSoon;

  /// No description provided for @whUnknownProduct.
  ///
  /// In en, this message translates to:
  /// **'Unknown product'**
  String get whUnknownProduct;

  /// No description provided for @whReceiveStart.
  ///
  /// In en, this message translates to:
  /// **'Receive goods'**
  String get whReceiveStart;

  /// No description provided for @whReceiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get whReceiveTitle;

  /// No description provided for @whReceiveSave.
  ///
  /// In en, this message translates to:
  /// **'Save receipt'**
  String get whReceiveSave;

  /// No description provided for @whReceiptSaved.
  ///
  /// In en, this message translates to:
  /// **'Receipt saved. It will sync when you are online.'**
  String get whReceiptSaved;

  /// No description provided for @whQtyReceived.
  ///
  /// In en, this message translates to:
  /// **'Quantity received'**
  String get whQtyReceived;

  /// No description provided for @whInvoiceCost.
  ///
  /// In en, this message translates to:
  /// **'Cost each (optional)'**
  String get whInvoiceCost;

  /// No description provided for @whDeliveryRef.
  ///
  /// In en, this message translates to:
  /// **'Delivery or invoice no. (optional)'**
  String get whDeliveryRef;

  /// No description provided for @whNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get whNotes;

  /// No description provided for @whOverDelivery.
  ///
  /// In en, this message translates to:
  /// **'More than ordered. The extra will be flagged.'**
  String get whOverDelivery;

  /// No description provided for @whWalkInStart.
  ///
  /// In en, this message translates to:
  /// **'Delivery without an order'**
  String get whWalkInStart;

  /// No description provided for @whWalkInTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery without an order'**
  String get whWalkInTitle;

  /// No description provided for @whWalkInHint.
  ///
  /// In en, this message translates to:
  /// **'Add what arrived. It will be flagged for review because there is no order.'**
  String get whWalkInHint;

  /// No description provided for @whSupplier.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get whSupplier;

  /// No description provided for @whNoSupplier.
  ///
  /// In en, this message translates to:
  /// **'No supplier'**
  String get whNoSupplier;

  /// No description provided for @whScanUnknown.
  ///
  /// In en, this message translates to:
  /// **'No product has that barcode.'**
  String get whScanUnknown;

  /// No description provided for @whErrUnknownOrder.
  ///
  /// In en, this message translates to:
  /// **'This order is no longer on the phone. Pull to refresh and try again.'**
  String get whErrUnknownOrder;

  /// No description provided for @whErrOrderClosed.
  ///
  /// In en, this message translates to:
  /// **'This order is already closed.'**
  String get whErrOrderClosed;

  /// No description provided for @whErrNotOnOrder.
  ///
  /// In en, this message translates to:
  /// **'That product is not on this order.'**
  String get whErrNotOnOrder;

  /// No description provided for @whErrDuplicateLine.
  ///
  /// In en, this message translates to:
  /// **'Each product can only appear once.'**
  String get whErrDuplicateLine;

  /// No description provided for @whErrQtyInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a quantity greater than zero.'**
  String get whErrQtyInvalid;

  /// No description provided for @whErrCostInvalid.
  ///
  /// In en, this message translates to:
  /// **'The cost is not a valid amount.'**
  String get whErrCostInvalid;

  /// No description provided for @whErrNoLines.
  ///
  /// In en, this message translates to:
  /// **'Enter a quantity for at least one product.'**
  String get whErrNoLines;

  /// No description provided for @whErrUnknownWarehouse.
  ///
  /// In en, this message translates to:
  /// **'This warehouse is not available to you.'**
  String get whErrUnknownWarehouse;

  /// No description provided for @whCountOffline.
  ///
  /// In en, this message translates to:
  /// **'You need a connection to count stock. Check your signal and try again.'**
  String get whCountOffline;

  /// No description provided for @whCountRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get whCountRetry;

  /// No description provided for @whCountStartOffline.
  ///
  /// In en, this message translates to:
  /// **'Start offline count'**
  String get whCountStartOffline;

  /// No description provided for @whCountOfflineBanner.
  ///
  /// In en, this message translates to:
  /// **'Offline count · Saved locally, will sync when connected'**
  String get whCountOfflineBanner;

  /// No description provided for @whCountOfflineDone.
  ///
  /// In en, this message translates to:
  /// **'Count finished offline and saved to device. It will sync automatically when connected.'**
  String get whCountOfflineDone;

  /// No description provided for @whCountNone.
  ///
  /// In en, this message translates to:
  /// **'No count in progress.'**
  String get whCountNone;

  /// No description provided for @whCountScope.
  ///
  /// In en, this message translates to:
  /// **'What to count'**
  String get whCountScope;

  /// No description provided for @whCountWhole.
  ///
  /// In en, this message translates to:
  /// **'Whole warehouse'**
  String get whCountWhole;

  /// No description provided for @whCountStart.
  ///
  /// In en, this message translates to:
  /// **'Start counting'**
  String get whCountStart;

  /// No description provided for @whCountBin.
  ///
  /// In en, this message translates to:
  /// **'Bin'**
  String get whCountBin;

  /// No description provided for @whCountQty.
  ///
  /// In en, this message translates to:
  /// **'Quantity counted'**
  String get whCountQty;

  /// No description provided for @whCountSaveLine.
  ///
  /// In en, this message translates to:
  /// **'Save count'**
  String get whCountSaveLine;

  /// No description provided for @whCountNoLines.
  ///
  /// In en, this message translates to:
  /// **'Nothing counted yet. Search or scan a product.'**
  String get whCountNoLines;

  /// No description provided for @whCountSystemWas.
  ///
  /// In en, this message translates to:
  /// **'system had {qty}'**
  String whCountSystemWas(String qty);

  /// No description provided for @whCountFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish count'**
  String get whCountFinish;

  /// No description provided for @whCountFinishAsk.
  ///
  /// In en, this message translates to:
  /// **'Finish this count?'**
  String get whCountFinishAsk;

  /// No description provided for @whCountFinishBody.
  ///
  /// In en, this message translates to:
  /// **'Stock will be corrected to what you counted. This cannot be undone.'**
  String get whCountFinishBody;

  /// No description provided for @whCountZeroUncounted.
  ///
  /// In en, this message translates to:
  /// **'Treat products I did not count as zero'**
  String get whCountZeroUncounted;

  /// No description provided for @whCountCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel count'**
  String get whCountCancel;

  /// No description provided for @whCountCancelAsk.
  ///
  /// In en, this message translates to:
  /// **'Cancel this count?'**
  String get whCountCancelAsk;

  /// No description provided for @whCountCancelBody.
  ///
  /// In en, this message translates to:
  /// **'What you counted will be dropped. Stock stays as it is.'**
  String get whCountCancelBody;

  /// No description provided for @whCountKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep counting'**
  String get whCountKeep;

  /// No description provided for @whCountErrInProgress.
  ///
  /// In en, this message translates to:
  /// **'A count is already open in this warehouse.'**
  String get whCountErrInProgress;

  /// No description provided for @whCountErrBinRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose the bin where you counted it.'**
  String get whCountErrBinRequired;

  /// No description provided for @whCountErrBin.
  ///
  /// In en, this message translates to:
  /// **'That bin is not available for this count.'**
  String get whCountErrBin;

  /// No description provided for @whCountErrBinsOff.
  ///
  /// In en, this message translates to:
  /// **'This warehouse does not use bins.'**
  String get whCountErrBinsOff;

  /// No description provided for @whCountErrNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing was counted yet.'**
  String get whCountErrNothing;

  /// No description provided for @whCountErrNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'You are not allowed to count here.'**
  String get whCountErrNotAllowed;

  /// No description provided for @whCountErrClosed.
  ///
  /// In en, this message translates to:
  /// **'This count is already closed or cancelled.'**
  String get whCountErrClosed;

  /// No description provided for @whCountErrSnapshot.
  ///
  /// In en, this message translates to:
  /// **'The counted stock could not be verified against inventory movements.'**
  String get whCountErrSnapshot;

  /// No description provided for @whNoBinStock.
  ///
  /// In en, this message translates to:
  /// **'No stock in any bin.'**
  String get whNoBinStock;

  /// No description provided for @whCountDone.
  ///
  /// In en, this message translates to:
  /// **'Count finished. {count, plural, =0{No corrections.} =1{{count} correction made.} other{{count} corrections made.}} Net change: {net}'**
  String whCountDone(int count, String net);

  /// No description provided for @activeWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Active warehouse'**
  String get activeWarehouse;

  /// No description provided for @shiftTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift'**
  String get shiftTitle;

  /// No description provided for @shiftNoneOpen.
  ///
  /// In en, this message translates to:
  /// **'No shift open'**
  String get shiftNoneOpen;

  /// No description provided for @shiftNoneHelp.
  ///
  /// In en, this message translates to:
  /// **'Start a shift when you take over the till, and count the cash you start with.'**
  String get shiftNoneHelp;

  /// No description provided for @shiftOpeningField.
  ///
  /// In en, this message translates to:
  /// **'Cash in the drawer when you start'**
  String get shiftOpeningField;

  /// No description provided for @shiftStart.
  ///
  /// In en, this message translates to:
  /// **'Start shift'**
  String get shiftStart;

  /// No description provided for @shiftOpenSince.
  ///
  /// In en, this message translates to:
  /// **'Open since {time}'**
  String shiftOpenSince(String time);

  /// No description provided for @shiftOpeningLabel.
  ///
  /// In en, this message translates to:
  /// **'Opening cash'**
  String get shiftOpeningLabel;

  /// No description provided for @shiftCashSales.
  ///
  /// In en, this message translates to:
  /// **'Cash sales'**
  String get shiftCashSales;

  /// No description provided for @shiftUtangTaken.
  ///
  /// In en, this message translates to:
  /// **'Utang paid in cash'**
  String get shiftUtangTaken;

  /// No description provided for @shiftPaidOut.
  ///
  /// In en, this message translates to:
  /// **'Cash paid out (expenses)'**
  String get shiftPaidOut;

  /// No description provided for @shiftLoadCash.
  ///
  /// In en, this message translates to:
  /// **'Load and e-wallet (cash)'**
  String get shiftLoadCash;

  /// No description provided for @shiftSalesLine.
  ///
  /// In en, this message translates to:
  /// **'Sales: {count} · Total: {total}'**
  String shiftSalesLine(int count, String total);

  /// No description provided for @shiftOtherTenders.
  ///
  /// In en, this message translates to:
  /// **'E-wallet: {ewallet} · On utang: {utang}'**
  String shiftOtherTenders(String ewallet, String utang);

  /// No description provided for @shiftEstimateNote.
  ///
  /// In en, this message translates to:
  /// **'This is this phone\'s figure. Sales made on other phones are not included.'**
  String get shiftEstimateNote;

  /// No description provided for @shiftShareX.
  ///
  /// In en, this message translates to:
  /// **'Share this reading'**
  String get shiftShareX;

  /// No description provided for @shiftClose.
  ///
  /// In en, this message translates to:
  /// **'Close shift'**
  String get shiftClose;

  /// No description provided for @shiftCloseAsk.
  ///
  /// In en, this message translates to:
  /// **'Count the drawer'**
  String get shiftCloseAsk;

  /// No description provided for @shiftChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking with the server...'**
  String get shiftChecking;

  /// No description provided for @shiftServerFigure.
  ///
  /// In en, this message translates to:
  /// **'Figure from the server'**
  String get shiftServerFigure;

  /// No description provided for @shiftPhoneFigure.
  ///
  /// In en, this message translates to:
  /// **'Figure from this phone'**
  String get shiftPhoneFigure;

  /// No description provided for @shiftConfirmClose.
  ///
  /// In en, this message translates to:
  /// **'Close this shift'**
  String get shiftConfirmClose;

  /// No description provided for @shiftClosed.
  ///
  /// In en, this message translates to:
  /// **'Shift closed'**
  String get shiftClosed;

  /// No description provided for @shiftZTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift report'**
  String get shiftZTitle;

  /// No description provided for @shiftOpenedLine.
  ///
  /// In en, this message translates to:
  /// **'Opened {time}'**
  String shiftOpenedLine(String time);

  /// No description provided for @shiftClosedLine.
  ///
  /// In en, this message translates to:
  /// **'Closed {time}'**
  String shiftClosedLine(String time);

  /// No description provided for @shiftServerDiffers.
  ///
  /// In en, this message translates to:
  /// **'The server worked out {amount} for this shift. A supervisor may want to look.'**
  String shiftServerDiffers(String amount);

  /// No description provided for @shiftHistory.
  ///
  /// In en, this message translates to:
  /// **'Recent shifts'**
  String get shiftHistory;

  /// No description provided for @shiftNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No shifts yet.'**
  String get shiftNoHistory;

  /// No description provided for @shiftStillOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get shiftStillOpen;

  /// No description provided for @shiftErrAlreadyOpen.
  ///
  /// In en, this message translates to:
  /// **'You already have a shift open.'**
  String get shiftErrAlreadyOpen;

  /// No description provided for @shiftErrAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount.'**
  String get shiftErrAmount;

  /// No description provided for @shiftChipOpen.
  ///
  /// In en, this message translates to:
  /// **'Shift open'**
  String get shiftChipOpen;

  /// No description provided for @shiftChipNone.
  ///
  /// In en, this message translates to:
  /// **'No shift'**
  String get shiftChipNone;

  /// No description provided for @staffTitle.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get staffTitle;

  /// No description provided for @staffAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a cashier'**
  String get staffAdd;

  /// No description provided for @staffNone.
  ///
  /// In en, this message translates to:
  /// **'No staff yet.'**
  String get staffNone;

  /// No description provided for @staffOffline.
  ///
  /// In en, this message translates to:
  /// **'Staff needs a signal. Try again when you are online.'**
  String get staffOffline;

  /// No description provided for @staffUsername.
  ///
  /// In en, this message translates to:
  /// **'Username (letters, numbers, dot, dash)'**
  String get staffUsername;

  /// No description provided for @staffFullName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get staffFullName;

  /// No description provided for @staffPassword.
  ///
  /// In en, this message translates to:
  /// **'Password (at least 8 characters)'**
  String get staffPassword;

  /// No description provided for @staffStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get staffStore;

  /// No description provided for @staffCreate.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get staffCreate;

  /// No description provided for @staffCreated.
  ///
  /// In en, this message translates to:
  /// **'Account created. Tell {name} to sign in as {login}.'**
  String staffCreated(String name, String login);

  /// No description provided for @staffSignIn.
  ///
  /// In en, this message translates to:
  /// **'Signs in as {login}'**
  String staffSignIn(String login);

  /// No description provided for @staffInactive.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get staffInactive;

  /// No description provided for @staffDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Switch off'**
  String get staffDeactivate;

  /// No description provided for @staffActivate.
  ///
  /// In en, this message translates to:
  /// **'Switch on'**
  String get staffActivate;

  /// No description provided for @staffResetPin.
  ///
  /// In en, this message translates to:
  /// **'Clear PIN'**
  String get staffResetPin;

  /// No description provided for @staffPinCleared.
  ///
  /// In en, this message translates to:
  /// **'PIN cleared.'**
  String get staffPinCleared;

  /// No description provided for @staffRoleSuperadmin.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get staffRoleSuperadmin;

  /// No description provided for @staffRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get staffRoleAdmin;

  /// No description provided for @staffRoleWarehouse.
  ///
  /// In en, this message translates to:
  /// **'Warehouse'**
  String get staffRoleWarehouse;

  /// No description provided for @staffRoleCashier.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get staffRoleCashier;

  /// No description provided for @staffErrDuplicate.
  ///
  /// In en, this message translates to:
  /// **'That username is taken.'**
  String get staffErrDuplicate;

  /// No description provided for @staffErrInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check the username and password.'**
  String get staffErrInvalid;

  /// No description provided for @staffErrDenied.
  ///
  /// In en, this message translates to:
  /// **'You cannot do this.'**
  String get staffErrDenied;

  /// No description provided for @staffErrSelf.
  ///
  /// In en, this message translates to:
  /// **'You cannot switch yourself off.'**
  String get staffErrSelf;

  /// No description provided for @staffErrLimit.
  ///
  /// In en, this message translates to:
  /// **'This plan has no room for more users.'**
  String get staffErrLimit;

  /// No description provided for @loginHelper.
  ///
  /// In en, this message translates to:
  /// **'Staff: username.storecode'**
  String get loginHelper;

  /// No description provided for @shiftPrint.
  ///
  /// In en, this message translates to:
  /// **'Print slip'**
  String get shiftPrint;

  /// No description provided for @shiftPrintPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF slip'**
  String get shiftPrintPdf;

  /// No description provided for @shiftOtherOpen.
  ///
  /// In en, this message translates to:
  /// **'Open shifts of other cashiers'**
  String get shiftOtherOpen;

  /// No description provided for @shiftSupervisorClose.
  ///
  /// In en, this message translates to:
  /// **'Close shift (Supervisor)'**
  String get shiftSupervisorClose;

  /// No description provided for @shiftCashierLabel.
  ///
  /// In en, this message translates to:
  /// **'Cashier: {name}'**
  String shiftCashierLabel(String name);

  /// No description provided for @printerSection.
  ///
  /// In en, this message translates to:
  /// **'Receipt & Thermal Printer'**
  String get printerSection;

  /// No description provided for @printerSectionHint.
  ///
  /// In en, this message translates to:
  /// **'Connect a thermal ESC/POS network printer or use system print'**
  String get printerSectionHint;

  /// No description provided for @printerEngine.
  ///
  /// In en, this message translates to:
  /// **'Printer mode'**
  String get printerEngine;

  /// No description provided for @printerEnginePdf.
  ///
  /// In en, this message translates to:
  /// **'System print dialog / PDF'**
  String get printerEnginePdf;

  /// No description provided for @printerEngineEscPos.
  ///
  /// In en, this message translates to:
  /// **'Thermal ESC/POS (Network/LAN)'**
  String get printerEngineEscPos;

  /// No description provided for @printerIp.
  ///
  /// In en, this message translates to:
  /// **'Printer IP address'**
  String get printerIp;

  /// No description provided for @printerPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get printerPort;

  /// No description provided for @printerWidth.
  ///
  /// In en, this message translates to:
  /// **'Paper roll width'**
  String get printerWidth;

  /// No description provided for @printerDrawerKick.
  ///
  /// In en, this message translates to:
  /// **'Kick cash drawer on print'**
  String get printerDrawerKick;

  /// No description provided for @printerAutoPrint.
  ///
  /// In en, this message translates to:
  /// **'Auto-print receipt after sale'**
  String get printerAutoPrint;

  /// No description provided for @printerTestPrint.
  ///
  /// In en, this message translates to:
  /// **'Test Print'**
  String get printerTestPrint;

  /// No description provided for @printerTestSuccess.
  ///
  /// In en, this message translates to:
  /// **'Test print sent successfully!'**
  String get printerTestSuccess;

  /// No description provided for @printerTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to thermal printer.'**
  String get printerTestFailed;

  /// No description provided for @transfersTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock Transfers'**
  String get transfersTitle;

  /// No description provided for @transfersIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming'**
  String get transfersIncoming;

  /// No description provided for @transfersHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get transfersHistory;

  /// No description provided for @transfersEmptyIncoming.
  ///
  /// In en, this message translates to:
  /// **'No incoming transfers waiting to be received.'**
  String get transfersEmptyIncoming;

  /// No description provided for @transfersEmptyHistory.
  ///
  /// In en, this message translates to:
  /// **'No transfer history found.'**
  String get transfersEmptyHistory;

  /// No description provided for @transferManifest.
  ///
  /// In en, this message translates to:
  /// **'Manifest #'**
  String get transferManifest;

  /// No description provided for @transferFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get transferFrom;

  /// No description provided for @transferTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get transferTo;

  /// No description provided for @transferShipped.
  ///
  /// In en, this message translates to:
  /// **'Shipped'**
  String get transferShipped;

  /// No description provided for @transferReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get transferReceived;

  /// No description provided for @transferReceive.
  ///
  /// In en, this message translates to:
  /// **'Receive Shipment'**
  String get transferReceive;

  /// No description provided for @transferReceiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Receive Transfer'**
  String get transferReceiveTitle;

  /// No description provided for @transferReceivePrompt.
  ///
  /// In en, this message translates to:
  /// **'Verify items received against the shipping manifest.'**
  String get transferReceivePrompt;

  /// No description provided for @transferItemShipped.
  ///
  /// In en, this message translates to:
  /// **'Shipped: {count}'**
  String transferItemShipped(num count);

  /// No description provided for @transferItemCounted.
  ///
  /// In en, this message translates to:
  /// **'Counted'**
  String get transferItemCounted;

  /// No description provided for @transferDiscrepancyWarning.
  ///
  /// In en, this message translates to:
  /// **'Some quantities differ from the shipping manifest.'**
  String get transferDiscrepancyWarning;

  /// No description provided for @transferConfirmReceive.
  ///
  /// In en, this message translates to:
  /// **'Confirm Receipt'**
  String get transferConfirmReceive;

  /// No description provided for @transferReceivedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Transfer received successfully.'**
  String get transferReceivedSuccess;

  /// No description provided for @transferReceivedDiscrepancy.
  ///
  /// In en, this message translates to:
  /// **'Transfer received with discrepancies recorded.'**
  String get transferReceivedDiscrepancy;

  /// No description provided for @transferScanItem.
  ///
  /// In en, this message translates to:
  /// **'Scan item barcode to count'**
  String get transferScanItem;

  /// No description provided for @putawayTitle.
  ///
  /// In en, this message translates to:
  /// **'Put-Away'**
  String get putawayTitle;

  /// No description provided for @putawayAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get putawayAvailable;

  /// No description provided for @putawayAction.
  ///
  /// In en, this message translates to:
  /// **'Put Away'**
  String get putawayAction;

  /// No description provided for @putawayDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Put Away Item to Bin'**
  String get putawayDialogTitle;

  /// No description provided for @putawayDestinationBin.
  ///
  /// In en, this message translates to:
  /// **'Destination Storage Bin'**
  String get putawayDestinationBin;

  /// No description provided for @putawayScanBin.
  ///
  /// In en, this message translates to:
  /// **'Scan Bin'**
  String get putawayScanBin;

  /// No description provided for @putawayQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity to Put Away'**
  String get putawayQuantity;

  /// No description provided for @putawayConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm Put-Away'**
  String get putawayConfirm;

  /// No description provided for @putawaySuccess.
  ///
  /// In en, this message translates to:
  /// **'Stock put away successfully.'**
  String get putawaySuccess;

  /// No description provided for @putawayError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load put-away items.'**
  String get putawayError;

  /// No description provided for @putawayEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'All Stock Put Away'**
  String get putawayEmptyTitle;

  /// No description provided for @putawayEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'No items waiting in Receiving. All inventory is stored in bins.'**
  String get putawayEmptyBody;

  /// No description provided for @transferCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New Outbound Transfer'**
  String get transferCreateTitle;

  /// No description provided for @transferOrigin.
  ///
  /// In en, this message translates to:
  /// **'Origin Location'**
  String get transferOrigin;

  /// No description provided for @transferDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination Location'**
  String get transferDestination;

  /// No description provided for @transferSelectDestination.
  ///
  /// In en, this message translates to:
  /// **'Please select a destination'**
  String get transferSelectDestination;

  /// No description provided for @transferItemsSection.
  ///
  /// In en, this message translates to:
  /// **'Transfer Items'**
  String get transferItemsSection;

  /// No description provided for @transferAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get transferAddItem;

  /// No description provided for @transferEmptyItems.
  ///
  /// In en, this message translates to:
  /// **'No items added yet. Tap Add Product or Scan Barcode.'**
  String get transferEmptyItems;

  /// No description provided for @transferSelectProduct.
  ///
  /// In en, this message translates to:
  /// **'Select Product to Transfer'**
  String get transferSelectProduct;

  /// No description provided for @transferNotesOptional.
  ///
  /// In en, this message translates to:
  /// **'Transfer Notes (Optional)'**
  String get transferNotesOptional;

  /// No description provided for @transferNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Reason, driver, or special instructions'**
  String get transferNotesHint;

  /// No description provided for @transferShipAction.
  ///
  /// In en, this message translates to:
  /// **'Dispatch & Ship Transfer'**
  String get transferShipAction;

  /// No description provided for @transferNoItemsError.
  ///
  /// In en, this message translates to:
  /// **'Add at least one item to ship'**
  String get transferNoItemsError;

  /// No description provided for @transferDestinationsError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load branches'**
  String get transferDestinationsError;

  /// No description provided for @transferCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Transfer dispatched and shipped successfully.'**
  String get transferCreatedSuccess;

  /// No description provided for @transferNewAction.
  ///
  /// In en, this message translates to:
  /// **'New Transfer'**
  String get transferNewAction;

  /// No description provided for @supervisorPinDiscountTitle.
  ///
  /// In en, this message translates to:
  /// **'Supervisor Override'**
  String get supervisorPinDiscountTitle;

  /// No description provided for @supervisorPinDiscountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Supervisor approval needed for {amount} discount'**
  String supervisorPinDiscountSubtitle(String amount);

  /// No description provided for @supervisorPinRequiredDiscount.
  ///
  /// In en, this message translates to:
  /// **'Supervisor PIN required for discount'**
  String get supervisorPinRequiredDiscount;

  /// No description provided for @supervisorPinApproveBtn.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get supervisorPinApproveBtn;

  /// No description provided for @supervisorPinApprovedBy.
  ///
  /// In en, this message translates to:
  /// **'Approved by {name}'**
  String supervisorPinApprovedBy(String name);

  /// No description provided for @pickListTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick Lists'**
  String get pickListTitle;

  /// No description provided for @pickListDraftTransfers.
  ///
  /// In en, this message translates to:
  /// **'Outbound Transfer Pick Lists'**
  String get pickListDraftTransfers;

  /// No description provided for @pickListNoDrafts.
  ///
  /// In en, this message translates to:
  /// **'No draft transfers awaiting picking.'**
  String get pickListNoDrafts;

  /// No description provided for @pickListGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate Pick List'**
  String get pickListGenerate;

  /// No description provided for @pickListGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get pickListGenerating;

  /// No description provided for @pickListWalkingRoute.
  ///
  /// In en, this message translates to:
  /// **'Walking Route Bins'**
  String get pickListWalkingRoute;

  /// No description provided for @pickListItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String pickListItemsCount(int count);

  /// No description provided for @pickListItemPick.
  ///
  /// In en, this message translates to:
  /// **'Pick Item'**
  String get pickListItemPick;

  /// No description provided for @pickListScanItem.
  ///
  /// In en, this message translates to:
  /// **'Scan Item / Bin'**
  String get pickListScanItem;

  /// No description provided for @pickListQtyToPick.
  ///
  /// In en, this message translates to:
  /// **'Quantity to Pick'**
  String get pickListQtyToPick;

  /// No description provided for @pickListShortReason.
  ///
  /// In en, this message translates to:
  /// **'Short Reason (if less than requested)'**
  String get pickListShortReason;

  /// No description provided for @pickListShortReasonHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Damaged, missing in bin'**
  String get pickListShortReasonHint;

  /// No description provided for @pickListConfirmPick.
  ///
  /// In en, this message translates to:
  /// **'Confirm Pick'**
  String get pickListConfirmPick;

  /// No description provided for @pickListPicking.
  ///
  /// In en, this message translates to:
  /// **'Confirming...'**
  String get pickListPicking;

  /// No description provided for @pickListCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get pickListCompleted;

  /// No description provided for @pickListInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get pickListInProgress;

  /// No description provided for @pickListPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pickListPending;

  /// No description provided for @pickListProgress.
  ///
  /// In en, this message translates to:
  /// **'{picked} of {total} picked'**
  String pickListProgress(int picked, int total);

  /// No description provided for @pickListStagingNotice.
  ///
  /// In en, this message translates to:
  /// **'Items are moved to STAGING bin for dispatch.'**
  String get pickListStagingNotice;

  /// No description provided for @pickListBinCoord.
  ///
  /// In en, this message translates to:
  /// **'Aisle {aisle} • Rack {rack} • Shelf {shelf}'**
  String pickListBinCoord(String aisle, String rack, String shelf);

  /// No description provided for @pickListAllPicked.
  ///
  /// In en, this message translates to:
  /// **'All items picked and staged'**
  String get pickListAllPicked;

  /// No description provided for @pickListAction.
  ///
  /// In en, this message translates to:
  /// **'Pick List'**
  String get pickListAction;

  /// No description provided for @shiftCashDrop.
  ///
  /// In en, this message translates to:
  /// **'Cash Drop / Skim'**
  String get shiftCashDrop;

  /// No description provided for @shiftCashDropSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Move excess cash from drawer to safe or custody'**
  String get shiftCashDropSubtitle;

  /// No description provided for @shiftCashDropAmount.
  ///
  /// In en, this message translates to:
  /// **'Drop Amount'**
  String get shiftCashDropAmount;

  /// No description provided for @shiftCashDropAmountHint.
  ///
  /// In en, this message translates to:
  /// **'0.00'**
  String get shiftCashDropAmountHint;

  /// No description provided for @shiftCashDropReason.
  ///
  /// In en, this message translates to:
  /// **'Reason / Destination'**
  String get shiftCashDropReason;

  /// No description provided for @shiftCashDropReasonHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Mid-day safe drop, bank run'**
  String get shiftCashDropReasonHint;

  /// No description provided for @shiftCashDropChipSafe.
  ///
  /// In en, this message translates to:
  /// **'Safe Drop'**
  String get shiftCashDropChipSafe;

  /// No description provided for @shiftCashDropChipBank.
  ///
  /// In en, this message translates to:
  /// **'Bank Run'**
  String get shiftCashDropChipBank;

  /// No description provided for @shiftCashDropChipSkim.
  ///
  /// In en, this message translates to:
  /// **'Drawer Skim'**
  String get shiftCashDropChipSkim;

  /// No description provided for @shiftCashDropConfirm.
  ///
  /// In en, this message translates to:
  /// **'Record Cash Drop'**
  String get shiftCashDropConfirm;

  /// No description provided for @shiftCashDropSuccess.
  ///
  /// In en, this message translates to:
  /// **'Cash drop of {amount} recorded'**
  String shiftCashDropSuccess(String amount);

  /// No description provided for @shiftCashDropSlipTitle.
  ///
  /// In en, this message translates to:
  /// **'CASH DROP RECEIPT'**
  String get shiftCashDropSlipTitle;

  /// No description provided for @shiftCashDropSlipCashier.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get shiftCashDropSlipCashier;

  /// No description provided for @shiftCashDropSlipWitness.
  ///
  /// In en, this message translates to:
  /// **'Witness / Supervisor'**
  String get shiftCashDropSlipWitness;

  /// No description provided for @shiftCashDropShare.
  ///
  /// In en, this message translates to:
  /// **'Share Slip'**
  String get shiftCashDropShare;

  /// No description provided for @shiftCashDropPrint.
  ///
  /// In en, this message translates to:
  /// **'Print Slip'**
  String get shiftCashDropPrint;

  /// No description provided for @shiftCashDropErrAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid drop amount greater than zero'**
  String get shiftCashDropErrAmount;

  /// No description provided for @shiftCashDropErrExceeds.
  ///
  /// In en, this message translates to:
  /// **'Drop amount cannot exceed expected drawer cash'**
  String get shiftCashDropErrExceeds;

  /// No description provided for @payCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get payCard;

  /// No description provided for @payCardRef.
  ///
  /// In en, this message translates to:
  /// **'Card trace / approval code'**
  String get payCardRef;

  /// No description provided for @payCardRefHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 123456'**
  String get payCardRefHint;

  /// No description provided for @payCardSuccess.
  ///
  /// In en, this message translates to:
  /// **'Card payment recorded'**
  String get payCardSuccess;

  /// No description provided for @payCardReceived.
  ///
  /// In en, this message translates to:
  /// **'Card amount'**
  String get payCardReceived;

  /// No description provided for @cartLineDiscount.
  ///
  /// In en, this message translates to:
  /// **'Item discount'**
  String get cartLineDiscount;

  /// No description provided for @cartLineDiscountHint.
  ///
  /// In en, this message translates to:
  /// **'Amount off (₱)'**
  String get cartLineDiscountHint;

  /// No description provided for @cartEditItem.
  ///
  /// In en, this message translates to:
  /// **'Edit item'**
  String get cartEditItem;

  /// No description provided for @cartLineDiscountShort.
  ///
  /// In en, this message translates to:
  /// **'-{amount} off'**
  String cartLineDiscountShort(String amount);

  /// No description provided for @cartUnitPrice.
  ///
  /// In en, this message translates to:
  /// **'Unit price'**
  String get cartUnitPrice;

  /// No description provided for @cartUnitPriceOverride.
  ///
  /// In en, this message translates to:
  /// **'Override price'**
  String get cartUnitPriceOverride;

  /// No description provided for @stockReorderAlert.
  ///
  /// In en, this message translates to:
  /// **'Below reorder threshold ({current} / min {min})'**
  String stockReorderAlert(String current, String min);

  /// No description provided for @stockLowStockBadge.
  ///
  /// In en, this message translates to:
  /// **'Low Stock'**
  String get stockLowStockBadge;

  /// No description provided for @stockRequestTransfer.
  ///
  /// In en, this message translates to:
  /// **'Request Restock Transfer'**
  String get stockRequestTransfer;

  /// No description provided for @denominationCalculator.
  ///
  /// In en, this message translates to:
  /// **'Bills & Coins Counter'**
  String get denominationCalculator;

  /// No description provided for @bills.
  ///
  /// In en, this message translates to:
  /// **'Banknotes'**
  String get bills;

  /// No description provided for @coins.
  ///
  /// In en, this message translates to:
  /// **'Coins'**
  String get coins;

  /// No description provided for @applyCount.
  ///
  /// In en, this message translates to:
  /// **'Use Count'**
  String get applyCount;

  /// No description provided for @clearCount.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearCount;

  /// No description provided for @totalCalculated.
  ///
  /// In en, this message translates to:
  /// **'Total Cash Counted'**
  String get totalCalculated;

  /// No description provided for @printerEngineBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get printerEngineBluetooth;

  /// No description provided for @printerBtNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth (No printer selected)'**
  String get printerBtNotSelected;

  /// No description provided for @printerBtPairedTitle.
  ///
  /// In en, this message translates to:
  /// **'Paired Bluetooth Printers'**
  String get printerBtPairedTitle;

  /// No description provided for @printerBtScan.
  ///
  /// In en, this message translates to:
  /// **'Scan Paired'**
  String get printerBtScan;

  /// No description provided for @printerBtHint.
  ///
  /// In en, this message translates to:
  /// **'Turn on Bluetooth and pair your 58mm/80mm printer in Android Settings first.'**
  String get printerBtHint;

  /// No description provided for @printerBtEmpty.
  ///
  /// In en, this message translates to:
  /// **'No paired Bluetooth printers found yet.'**
  String get printerBtEmpty;

  /// No description provided for @printerBtAddress.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth MAC Address'**
  String get printerBtAddress;

  /// No description provided for @saleReturnButton.
  ///
  /// In en, this message translates to:
  /// **'Return Items'**
  String get saleReturnButton;

  /// No description provided for @saleReturnTitle.
  ///
  /// In en, this message translates to:
  /// **'Return Items & Refund'**
  String get saleReturnTitle;

  /// No description provided for @saleReturnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select quantities returning to stock and refund method.'**
  String get saleReturnSubtitle;

  /// No description provided for @saleReturnMethod.
  ///
  /// In en, this message translates to:
  /// **'Refund Method'**
  String get saleReturnMethod;

  /// No description provided for @saleReturnReason.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get saleReturnReason;

  /// No description provided for @saleReturnReasonHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Defective item, wrong size'**
  String get saleReturnReasonHint;

  /// No description provided for @saleReturnTotal.
  ///
  /// In en, this message translates to:
  /// **'Total Refund'**
  String get saleReturnTotal;

  /// No description provided for @saleReturnConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm Return'**
  String get saleReturnConfirm;

  /// No description provided for @saleReturnRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded: -{amount}'**
  String saleReturnRefunded(String amount);

  /// No description provided for @saleReturnSuccess.
  ///
  /// In en, this message translates to:
  /// **'Return recorded ({amount} refunded)'**
  String saleReturnSuccess(String amount);

  /// No description provided for @saleReturnRemaining.
  ///
  /// In en, this message translates to:
  /// **'{qty} returnable'**
  String saleReturnRemaining(String qty);
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
