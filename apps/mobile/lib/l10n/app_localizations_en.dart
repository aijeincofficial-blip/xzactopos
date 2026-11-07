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

  @override
  String get stockTitle => 'Stock';

  @override
  String get stockAll => 'All';

  @override
  String stockLowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count low',
      one: '$count low',
      zero: 'Low',
    );
    return '$_temp0';
  }

  @override
  String get stockNoneLow => 'Nothing is running low.';

  @override
  String get stockNotCounted => 'Not counted';

  @override
  String get stockRunningLow => 'Running low';

  @override
  String stockNow(String n) {
    return 'Now: $n';
  }

  @override
  String get stockIn => 'Stock in';

  @override
  String get stockCount => 'Count';

  @override
  String stockInTitle(String name) {
    return 'Stock in: $name';
  }

  @override
  String get stockInQty => 'How many came in?';

  @override
  String get stockInCost => 'Cost each (optional)';

  @override
  String stockCountTitle(String name) {
    return 'Count: $name';
  }

  @override
  String get stockCountQty => 'How many do you have now?';

  @override
  String get reasonCounted => 'Counted';

  @override
  String get reasonDamage => 'Damaged / expired';

  @override
  String get reasonOther => 'Other';

  @override
  String get reorderPoint => 'Warn me when stock is at or below';

  @override
  String get reorderPointHelp => 'Leave empty for no warning';

  @override
  String sellStockLow(String n) {
    return '$n left, running low';
  }

  @override
  String get reportsTitle => 'Reports';

  @override
  String get reportsRefresh => 'Refresh';

  @override
  String reportsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '$count day',
    );
    return '$_temp0';
  }

  @override
  String get reportsSales => 'Sales';

  @override
  String reportsProfit(String amount) {
    return 'Estimated profit: $amount';
  }

  @override
  String get reportsPerDay => 'Per day';

  @override
  String get reportsTopItems => 'Best sellers';

  @override
  String get reportsNothingYet => 'No sales in this period.';

  @override
  String reportsQty(String n) {
    return '$n sold';
  }

  @override
  String reportsUtangOwed(String amount) {
    return 'Owed to you: $amount';
  }

  @override
  String reportsAsOf(String when) {
    return 'No signal. Showing the last report from $when.';
  }

  @override
  String get reportsNeedSignal =>
      'Reports need a signal the first time. Connect and try again.';

  @override
  String reportsNotSent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sales or changes are not sent yet and are not included.',
      one: '$count sale or change is not sent yet and is not included.',
    );
    return '$_temp0';
  }

  @override
  String get syncSignIn =>
      'Session ended. Sign out and sign in again; nothing is lost.';

  @override
  String get unsentTitle => 'Unsent changes';

  @override
  String unsentBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'This phone still has $count changes from another business that were never sent.',
      one:
          'This phone still has $count change from another business that was never sent.',
    );
    return '$_temp0 Sign in to that business to send them, or discard them and continue.';
  }

  @override
  String get unsentDiscard => 'Discard them and continue';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get forgotTitle => 'Reset your password';

  @override
  String get forgotSend => 'Send link';

  @override
  String get forgotSent =>
      'If that email has an account, we sent a link to reset the password.';

  @override
  String get newPasswordTitle => 'Choose a new password';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmPassword => 'Type it again';

  @override
  String get passwordsDiffer => 'The two passwords are different';

  @override
  String get passwordSaved => 'Password changed';

  @override
  String get changePassword => 'Change password';

  @override
  String get themeTitle => 'Look of the app';

  @override
  String get themeColors => 'Colors';

  @override
  String get themeMode => 'Brightness';

  @override
  String get paletteFreshTide => 'Fresh Tide (blue and mint)';

  @override
  String get paletteGoldenIndigo => 'Golden Indigo (blue and gold)';

  @override
  String get themeSystem => 'Same as phone';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get utangAdjust => 'Adjust balance';

  @override
  String utangAdjustTitle(String name) {
    return 'Adjust $name\'s balance';
  }

  @override
  String get utangWriteOff => 'Owes less (write off)';

  @override
  String get utangAddMore => 'Owes more (correction)';

  @override
  String get utangAdjustAmount => 'How much?';

  @override
  String get utangAdjusted => 'Balance adjusted';

  @override
  String get scanTitle => 'Scan a barcode';

  @override
  String get scanHint => 'Point the camera at the barcode';

  @override
  String get scanDone => 'Done';

  @override
  String get scanLight => 'Light';

  @override
  String get scanCameraDenied =>
      'The camera is not available. Allow it in the phone settings, then try again.';

  @override
  String scanAdded(String name) {
    return 'Added: $name';
  }

  @override
  String get scanWithCamera => 'Scan with camera';

  @override
  String get receiptPrint => 'Print';

  @override
  String get receiptShare => 'Share';

  @override
  String get receiptPrintFailed =>
      'Could not open the printer. Try Share instead.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get activeStore => 'Active store';

  @override
  String get settingsAppearance => 'Appearance & theme';

  @override
  String get change => 'Change';

  @override
  String get settingsLanguageRegion => 'Language & region';

  @override
  String get systemLanguage => 'System language';

  @override
  String get languageCurrentName => 'English (US)';

  @override
  String get switchLanguage => 'Lumipat sa FIL';

  @override
  String get settingsSecurity => 'Security & account';

  @override
  String get updatePasswordHint => 'Update your login password';

  @override
  String get endSessionHint => 'End session on this phone';

  @override
  String get localDbNote => 'Local database: encrypted & synced';

  @override
  String get storeSettings => 'Store settings';

  @override
  String get storeSettingsHint => 'Theme, mode, language & account';

  @override
  String get startFirstSale => 'Start your first sale';

  @override
  String get totalSalesToday => 'Total sales today';

  @override
  String get tileUtangSub => 'Who owes you';

  @override
  String get tileStockSub => 'What you have left';

  @override
  String get tileProductsSub => 'Catalog & prices';

  @override
  String get tileReportsSub => 'Sales & profit';

  @override
  String get reportsRevenueSub => 'Total store revenue';

  @override
  String get reportsAvgOrder => 'Average order';

  @override
  String get reportsTotalOrders => 'Total orders';

  @override
  String get reportsInventoryHealth => 'Inventory health';

  @override
  String get reportsAllHealthy => 'All tracked stocks healthy';

  @override
  String tileStockLow(int count) {
    return '$count low';
  }

  @override
  String reportsNeedReorder(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items need reordering',
      one: '$count item needs reordering',
    );
    return '$_temp0';
  }
}
