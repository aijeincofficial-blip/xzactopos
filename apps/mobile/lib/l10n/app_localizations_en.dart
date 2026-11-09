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
  String get tabToday => 'Today';

  @override
  String get tabPos => 'POS';

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

  @override
  String sellPinned(String name) {
    return 'Pinned $name to the top';
  }

  @override
  String sellUnpinned(String name) {
    return 'Unpinned $name';
  }

  @override
  String get sellPinHint => 'Hold an item to pin it as a favorite';

  @override
  String get restockTitle => 'Restock list';

  @override
  String get restockEmpty => 'Nothing to buy. Nothing is running low.';

  @override
  String get restockShareHeader => 'Shopping list';

  @override
  String get restockCopy => 'Copy list';

  @override
  String get restockCopied => 'List copied. Paste it into a message.';

  @override
  String restockNow(String n) {
    return 'Now: $n';
  }

  @override
  String restockBuy(int count) {
    return 'Buy $count';
  }

  @override
  String restockItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String restockEstimate(String amount) {
    return 'About $amount';
  }

  @override
  String get exportSection => 'Export & backup';

  @override
  String get exportHint =>
      'Send as a spreadsheet file (CSV) by message or email';

  @override
  String get exportSales => 'Sales';

  @override
  String get exportUtang => 'Utang';

  @override
  String get exportStock => 'Stock';

  @override
  String get exportFailed => 'Could not share the file. Try again.';

  @override
  String get expensesTitle => 'Expenses';

  @override
  String get expensesSpentToday => 'Spent today';

  @override
  String get expensesNone => 'No expenses today';

  @override
  String get expenseAdd => 'Add expense';

  @override
  String get expenseAmount => 'Amount';

  @override
  String get expenseNote => 'Note (optional)';

  @override
  String get expensePaidFrom => 'Paid from';

  @override
  String get expensePaidCash => 'Cash';

  @override
  String get expensePaidEwallet => 'E-wallet';

  @override
  String get expenseCategoryStockPurchase => 'Stock purchase';

  @override
  String get expenseCategoryUtilities => 'Electric, water';

  @override
  String get expenseCategoryTransport => 'Transport';

  @override
  String get expenseCategoryWages => 'Wages';

  @override
  String get expenseCategoryRent => 'Rent';

  @override
  String get expenseCategoryOther => 'Other';

  @override
  String get expenseVoidTitle => 'Cancel this expense?';

  @override
  String get expenseVoidBody =>
      'It stays in the list, crossed out, and no longer counts.';

  @override
  String get expenseVoidReason => 'Reason (optional)';

  @override
  String get expenseVoidYes => 'Cancel expense';

  @override
  String get expenseCancelled => 'Cancelled';

  @override
  String get expenseNeedsPin => 'Needs supervisor PIN';

  @override
  String get approvalTitle => 'Supervisor PIN';

  @override
  String get approvalBody =>
      'A supervisor must approve this. Enter the supervisor\'s PIN (needs signal).';

  @override
  String get approvalPin => 'PIN';

  @override
  String get approvalApprove => 'Approve';

  @override
  String get approvalWrongPin => 'Wrong PIN. Try again.';

  @override
  String get approvalLocked => 'Too many wrong tries. Wait a few minutes.';

  @override
  String get approvalNoPin => 'This person has not set a PIN yet.';

  @override
  String get approvalNeedsSignal =>
      'No signal. The PIN can only be checked online.';

  @override
  String get approvalRefused => 'This approval was refused.';

  @override
  String get dayCloseTitle => 'Close the day';

  @override
  String get dayCloseExpected => 'Cash that should be in the drawer';

  @override
  String get dayCloseHelp =>
      'Opening cash + cash sales + utang payments - cash expenses';

  @override
  String get dayCloseCounted => 'Cash you counted';

  @override
  String get dayCloseNote => 'Note (optional)';

  @override
  String get dayCloseExact => 'Exact. Nothing short or over.';

  @override
  String get dayCloseSave => 'Save count';

  @override
  String get dayCloseSaved => 'Day closed';

  @override
  String get dayCloseAgain => 'Count again';

  @override
  String get dayCloseNeedsPin => 'Needs supervisor PIN';

  @override
  String dayCloseShort(String amount) {
    return 'Short by $amount';
  }

  @override
  String dayCloseOver(String amount) {
    return 'Over by $amount';
  }

  @override
  String dayCloseLast(String amount, String time) {
    return 'Last count: $amount at $time';
  }

  @override
  String expensesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expenses',
      one: '$count expense',
    );
    return '$_temp0';
  }

  @override
  String get reportsExpensesNote =>
      'Stock you bought is already in your cost of goods, so it is not taken off twice.';

  @override
  String reportsExpenses(String amount) {
    return 'Expenses (not stock): $amount';
  }

  @override
  String reportsNetProfit(String amount) {
    return 'Profit after expenses: $amount';
  }

  @override
  String reportsStockBought(String amount) {
    return 'Stock bought: $amount';
  }

  @override
  String get servicesTitle => 'Load & e-wallet';

  @override
  String get servicesFeesToday => 'Earned today (fees)';

  @override
  String get servicesFloat => 'Wallet float';

  @override
  String get servicesNeedsTopup => 'Needs a top-up';

  @override
  String get servicesNone => 'No load or e-wallet entries today';

  @override
  String get serviceCashIn => 'Cash in';

  @override
  String get serviceCashOut => 'Cash out';

  @override
  String get serviceLoad => 'Sell load';

  @override
  String get serviceMoveFloat => 'Move float';

  @override
  String get serviceCashInHint =>
      'Customer gives cash, you send e-wallet money';

  @override
  String get serviceCashOutHint =>
      'Customer sends e-wallet money, you give cash';

  @override
  String get serviceFloatTopup => 'Top up from the drawer';

  @override
  String get serviceFloatWithdraw => 'Withdraw to the drawer';

  @override
  String get serviceFloatAdjust => 'Correct the balance';

  @override
  String get walletGcash => 'GCash';

  @override
  String get walletMaya => 'Maya';

  @override
  String get walletLoad => 'Load';

  @override
  String get walletOther => 'Other';

  @override
  String get serviceWallet => 'Wallet';

  @override
  String get serviceAmount => 'Amount';

  @override
  String get serviceLoadAmount => 'Load amount';

  @override
  String get serviceFee => 'Fee you charge';

  @override
  String get servicePrice => 'Customer pays (cash)';

  @override
  String get serviceRef => 'Phone or reference (optional)';

  @override
  String get serviceNote => 'Note';

  @override
  String get serviceNoteRequired => 'A note is needed';

  @override
  String get servicePriceTooLow => 'The price must be at least the load amount';

  @override
  String get serviceAdjustHint => 'Use a minus for less, e.g. -50';

  @override
  String get serviceVoidTitle => 'Cancel this entry?';

  @override
  String get serviceVoidBody =>
      'It stays in the list, crossed out, and the money moves back.';

  @override
  String get serviceVoidYes => 'Cancel entry';

  @override
  String get serviceNeedsPin => 'Needs supervisor PIN';

  @override
  String serviceEarned(String amount) {
    return 'Earned $amount';
  }

  @override
  String get tingiSection => 'Sold by piece too';

  @override
  String get tingiHelp => 'Open a pack to add the pieces to your stock';

  @override
  String get tingiPieces => 'Pieces in one pack';

  @override
  String get tingiPieceName => 'Piece name';

  @override
  String get tingiPiecePrice => 'Price per piece';

  @override
  String get tingiFailed =>
      'Could not link the pieces. This product may already be a piece of another pack.';

  @override
  String get tingiOpenPack => 'Open a pack';

  @override
  String get tingiPacks => 'How many packs?';

  @override
  String get tingiLowWarn =>
      'You counted fewer packs than this. You can still go ahead.';

  @override
  String get tingiHistory => 'Opened packs';

  @override
  String get tingiHistoryNone => 'No packs opened yet';

  @override
  String get tingiVoidTitle => 'Undo this opening?';

  @override
  String get tingiVoidBody =>
      'The pieces leave your stock and the pack comes back.';

  @override
  String get tingiVoidYes => 'Undo';

  @override
  String get tingiLinkChanged =>
      'The pieces per pack changed. Check the product.';

  @override
  String get tingiCancelled => 'Undone';

  @override
  String tingiPieceSuffix(String name) {
    return '$name (piece)';
  }

  @override
  String tingiLinkedTo(String name) {
    return 'Pieces are sold as $name';
  }

  @override
  String tingiOpenTitle(String name) {
    return 'Open a pack: $name';
  }

  @override
  String tingiPreview(int count, String name) {
    return 'That makes $count × $name';
  }

  @override
  String tingiOpened(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pieces added to stock',
      one: '$count piece added to stock',
    );
    return '$_temp0';
  }

  @override
  String tingiHistoryRow(int packs, int pieces, String name) {
    return '$packs pack → $pieces × $name';
  }

  @override
  String get utangDueSet => 'Set pay-by date';

  @override
  String get utangDueChange => 'Change date';

  @override
  String get utangDueClear => 'Clear date';

  @override
  String get utangSendStatement => 'Send statement';

  @override
  String get utangOverdueNone => 'Nobody is overdue';

  @override
  String get stmtTitle => 'Utang statement';

  @override
  String get stmtBalance => 'Balance';

  @override
  String get stmtDueOn => 'Pay by';

  @override
  String get stmtRecent => 'Recent';

  @override
  String get stmtCharge => 'Utang';

  @override
  String get stmtPayment => 'Payment';

  @override
  String get stmtAdjust => 'Adjustment';

  @override
  String get stockExpirySet => 'Set expiry date';

  @override
  String get stockExpiryClear => 'Clear expiry date';

  @override
  String get stockInExpiry => 'Expiry date (optional)';

  @override
  String get stockNoneExpiring => 'Nothing is close to expiring.';

  @override
  String utangDueOn(String date) {
    return 'Pay by $date';
  }

  @override
  String utangOverdueDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days overdue',
      one: '$count day overdue',
    );
    return '$_temp0';
  }

  @override
  String utangOverdueFilter(int count) {
    return 'Overdue ($count)';
  }

  @override
  String tileUtangOverdue(int count) {
    return '$count overdue';
  }

  @override
  String stockExpiringFilter(int count) {
    return 'Expiring ($count)';
  }

  @override
  String stockExpiresIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Expires in $count days',
      one: 'Expires tomorrow',
      zero: 'Expires today',
    );
    return '$_temp0';
  }

  @override
  String stockExpiredAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Expired $count days ago',
      one: 'Expired yesterday',
    );
    return '$_temp0';
  }

  @override
  String tileStockExpiring(int count) {
    return '$count expiring';
  }

  @override
  String get dataTitle => 'Import & export';

  @override
  String get dataExportSection => 'Export';

  @override
  String get dataImportSection => 'Import products';

  @override
  String get dataImportHint =>
      'Copy rows from a spreadsheet and paste them here. Columns: name, price, barcode, cost, stock.';

  @override
  String get dataImportOpen => 'Paste products';

  @override
  String get dataImportTemplate => 'Copy the column names';

  @override
  String get dataTemplateCopied =>
      'Column names copied. Paste them into a spreadsheet.';

  @override
  String get dataImportPaste => 'Paste the rows here';

  @override
  String get dataTooMany =>
      'Only the first 500 rows are read at a time. Import the rest in another batch.';

  @override
  String get dataProbName => 'name is missing';

  @override
  String get dataProbPrice => 'price is not a number';

  @override
  String get dataProbCost => 'cost is not a number';

  @override
  String get dataProbStock => 'stock is not a number';

  @override
  String get exportProducts => 'Products';

  @override
  String dataImportReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products ready',
      one: '$count product ready',
    );
    return '$_temp0';
  }

  @override
  String dataImportProblems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows have a problem and are left out',
      one: '$count row has a problem and is left out',
    );
    return '$_temp0';
  }

  @override
  String dataImportLine(int line, String problem) {
    return 'Row $line: $problem';
  }

  @override
  String dataImportGo(int count) {
    return 'Import $count';
  }

  @override
  String dataImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products added',
      one: '$count product added',
    );
    return '$_temp0';
  }

  @override
  String dataSkipped(int count) {
    return '$count skipped: barcode already used';
  }

  @override
  String get dayCloseOpening => 'Cash you started with (sukli)';

  @override
  String dayCloseOpeningLine(String amount) {
    return 'Started with $amount';
  }

  @override
  String get keypadAdd => 'Add to sale';

  @override
  String get sellModeItems => 'Items';

  @override
  String get sellModeKeypad => 'Keypad';

  @override
  String get openAmountName => 'Other item';

  @override
  String get payWalletTitle => 'Which wallet?';

  @override
  String get noProductsHere =>
      'You have no products yet. Add one, or import a list under More > Import & export.';

  @override
  String get storePickerTitle => 'Switch store';

  @override
  String storeSwitched(String name) {
    return 'Now selling at $name';
  }

  @override
  String get storeSwitchAsk => 'Switch store?';

  @override
  String get storeSwitchKeep => 'Switch and keep the sale';

  @override
  String get storeSwitchClear => 'Switch and clear the sale';

  @override
  String storeSwitchBody(int count, String store) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return 'A sale is in progress ($_temp0). If you keep it, it will be paid at $store and the stock comes off there.';
  }

  @override
  String get upgradeFullSection => 'Full Mode';

  @override
  String get upgradeFullTitle => 'Upgrade to Full Mode';

  @override
  String get upgradeFullSubtitle =>
      'Add more stores, warehouse, and cashier staff. Your solo data stays 100% intact.';

  @override
  String get upgradeFullAction => 'Learn More';

  @override
  String get upgradeFullDialogTitle => 'Full Mode Upgrade';

  @override
  String get upgradeFullDialogBody =>
      'Full Mode unlocks multiple branches, a central warehouse, and role-based staff accounts (Cashier, Manager, Supervisor). All your current sales, products, stock, and utang records are safely retained in place.\n\nTo upgrade, open the XZACTO POS web app in any browser and use the Upgrade Wizard.';

  @override
  String get upgradeFullClose => 'Got it';

  @override
  String get whTabReceive => 'Receive';

  @override
  String get whTabCount => 'Count';

  @override
  String get whTabStock => 'Stock';

  @override
  String get whTabMore => 'More';

  @override
  String get whNoWarehouse =>
      'No warehouse yet. Connect to the internet once so your warehouses can load.';

  @override
  String get whSwitchTitle => 'Choose warehouse';

  @override
  String whSwitched(String name) {
    return 'Working in $name';
  }

  @override
  String get whSwitchAction => 'Switch warehouse';

  @override
  String get whOpenOrders => 'Open orders';

  @override
  String get whNoOrders => 'No open orders in this warehouse.';

  @override
  String whOrderLeft(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count left to receive',
      one: '$count left to receive',
    );
    return '$_temp0';
  }

  @override
  String get whOrderComplete => 'Fully received';

  @override
  String get whWaitingSync => 'Waiting to sync';

  @override
  String get whStatusOrdered => 'Ordered';

  @override
  String get whStatusPartly => 'Partly received';

  @override
  String get whOrderLines => 'Items on this order';

  @override
  String whLineProgress(String received, String ordered) {
    return '$received of $ordered received';
  }

  @override
  String get whReceipts => 'Receipts from this phone';

  @override
  String get whNoReceipts => 'Nothing received on this phone yet.';

  @override
  String get whReceiptWalkin => 'Delivery without an order';

  @override
  String get whSearchStock => 'Search stock';

  @override
  String get whNoStock => 'No stock in this warehouse yet.';

  @override
  String whStockPending(String qty) {
    return '$qty on the way in';
  }

  @override
  String get whCountSoon =>
      'Counting on the phone is coming soon. Use the web app for stock counts for now.';

  @override
  String get whUnknownProduct => 'Unknown product';

  @override
  String get whReceiveStart => 'Receive goods';

  @override
  String get whReceiveTitle => 'Receive';

  @override
  String get whReceiveSave => 'Save receipt';

  @override
  String get whReceiptSaved =>
      'Receipt saved. It will sync when you are online.';

  @override
  String get whQtyReceived => 'Quantity received';

  @override
  String get whInvoiceCost => 'Cost each (optional)';

  @override
  String get whDeliveryRef => 'Delivery or invoice no. (optional)';

  @override
  String get whNotes => 'Notes (optional)';

  @override
  String get whOverDelivery => 'More than ordered. The extra will be flagged.';

  @override
  String get whWalkInStart => 'Delivery without an order';

  @override
  String get whWalkInTitle => 'Delivery without an order';

  @override
  String get whWalkInHint =>
      'Add what arrived. It will be flagged for review because there is no order.';

  @override
  String get whSupplier => 'Supplier';

  @override
  String get whNoSupplier => 'No supplier';

  @override
  String get whScanUnknown => 'No product has that barcode.';

  @override
  String get whErrUnknownOrder =>
      'This order is no longer on the phone. Pull to refresh and try again.';

  @override
  String get whErrOrderClosed => 'This order is already closed.';

  @override
  String get whErrNotOnOrder => 'That product is not on this order.';

  @override
  String get whErrDuplicateLine => 'Each product can only appear once.';

  @override
  String get whErrQtyInvalid => 'Enter a quantity greater than zero.';

  @override
  String get whErrCostInvalid => 'The cost is not a valid amount.';

  @override
  String get whErrNoLines => 'Enter a quantity for at least one product.';

  @override
  String get whErrUnknownWarehouse => 'This warehouse is not available to you.';
}
