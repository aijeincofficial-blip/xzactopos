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

  @override
  String get takePhoto => 'Take photo';

  @override
  String get choosePhoto => 'Choose photo';

  @override
  String get photoFailed => 'Could not use that photo. Try another one.';

  @override
  String get errPhotoTooLarge => 'The photo is too large.';

  @override
  String get ok => 'OK';

  @override
  String get sellSearchHint => 'Search or scan to add';

  @override
  String get sellCartEmpty => 'Tap an item to add it';

  @override
  String get sellPay => 'Pay';

  @override
  String get sellNoPrice => 'Set a price for this product first';

  @override
  String sellUnknownBarcode(String code) {
    return 'No product has barcode $code';
  }

  @override
  String get sellQuantity => 'Quantity';

  @override
  String get sellClearTitle => 'Clear this sale?';

  @override
  String get sellClearBody => 'Everything in the list will be removed.';

  @override
  String sellItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String sellStockLeft(String n) {
    return '$n left';
  }

  @override
  String get sellOutOfStock => 'None left (you can still sell)';

  @override
  String get payTitle => 'Payment';

  @override
  String get payTotal => 'Total';

  @override
  String get payCash => 'Cash';

  @override
  String get payEwallet => 'GCash / Maya';

  @override
  String get payReceivedCash => 'Cash received (leave empty if exact)';

  @override
  String get payReceivedEwallet => 'Amount received';

  @override
  String get payExact => 'Exact';

  @override
  String get payChange => 'Change';

  @override
  String get payAllUtang => 'All on utang';

  @override
  String payOnUtang(String amount) {
    return '$amount goes on utang';
  }

  @override
  String get payChooseCustomer => 'Choose who owes';

  @override
  String get payDiscount => 'Discount';

  @override
  String get payDiscountHint => 'Pesos off the total';

  @override
  String get payDone => 'Finish sale';

  @override
  String get customerNew => 'New customer';

  @override
  String get customerName => 'Customer name';

  @override
  String get customerPhone => 'Phone (optional)';

  @override
  String get customerSearch => 'Search customers';

  @override
  String get receiptTitle => 'Receipt';

  @override
  String receiptNumber(String no) {
    return 'Receipt no. $no';
  }

  @override
  String get receiptSubtotal => 'Subtotal';

  @override
  String get receiptDiscount => 'Discount';

  @override
  String get receiptCashReceived => 'Cash received';

  @override
  String get receiptOnUtang => 'On utang';

  @override
  String receiptBalance(String name, String amount) {
    return '$name\'s utang balance: $amount';
  }

  @override
  String get receiptNewSale => 'New sale';

  @override
  String get receiptCancelled => 'CANCELLED';

  @override
  String get receiptThanks => 'Thank you!';

  @override
  String get utangTitle => 'Utang';

  @override
  String get utangTotalOwed => 'Total owed to you';

  @override
  String get utangEmpty =>
      'Nobody owes you yet. Customers show up here when you sell on utang.';

  @override
  String get utangSettled => 'Fully paid';

  @override
  String get utangOwes => 'Owes';

  @override
  String get utangPaid => 'Record payment';

  @override
  String utangPayTitle(String name) {
    return '$name paid';
  }

  @override
  String get utangAmountPaid => 'Amount paid';

  @override
  String get utangNote => 'Note (optional)';

  @override
  String utangTooMuch(String amount) {
    return 'That is more than they owe ($amount)';
  }

  @override
  String get ledgerCharge => 'Took on utang';

  @override
  String get ledgerPayment => 'Paid';

  @override
  String get ledgerAdjust => 'Adjustment';

  @override
  String get ledgerVoid => 'Sale cancelled';

  @override
  String get todayTitle => 'Today';

  @override
  String get todaySales => 'Sales today';

  @override
  String todayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sales',
      one: '$count sale',
      zero: 'No sales',
    );
    return '$_temp0';
  }

  @override
  String get todayCash => 'Cash in';

  @override
  String get todayUtang => 'On utang';

  @override
  String get todayNone => 'No sales yet today.';

  @override
  String get saleCancelButton => 'Cancel this sale';

  @override
  String get saleCancelTitle => 'Cancel this sale?';

  @override
  String get saleCancelBody =>
      'The items go back to your stock and any utang from this sale is removed.';

  @override
  String get saleCancelYes => 'Yes, cancel it';

  @override
  String get saleCancelNo => 'No, keep it';
}
