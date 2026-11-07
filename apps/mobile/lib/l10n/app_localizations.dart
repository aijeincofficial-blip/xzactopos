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
