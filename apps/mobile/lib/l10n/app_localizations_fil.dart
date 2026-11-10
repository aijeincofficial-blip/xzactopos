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
  String get tabToday => 'Ngayon';

  @override
  String get tabPos => 'POS';

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

  @override
  String get takePhoto => 'Kumuha ng litrato';

  @override
  String get choosePhoto => 'Pumili ng litrato';

  @override
  String get photoFailed =>
      'Hindi magamit ang litratong iyan. Subukan ang iba.';

  @override
  String get errPhotoTooLarge => 'Masyadong malaki ang litrato.';

  @override
  String get ok => 'OK';

  @override
  String get sellSearchHint => 'Hanapin o i-scan para idagdag';

  @override
  String get sellCartEmpty => 'Pindutin ang produkto para idagdag';

  @override
  String get sellPay => 'Bayad';

  @override
  String get sellNoPrice => 'Lagyan muna ng presyo ang produktong ito';

  @override
  String sellUnknownBarcode(String code) {
    return 'Walang produktong may barcode na $code';
  }

  @override
  String get sellQuantity => 'Dami';

  @override
  String get sellClearTitle => 'Burahin ang benta na ito?';

  @override
  String get sellClearBody => 'Aalisin ang lahat sa listahan.';

  @override
  String sellItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count produkto',
      one: '$count produkto',
    );
    return '$_temp0';
  }

  @override
  String sellStockLeft(String n) {
    return '$n ang natira';
  }

  @override
  String get sellOutOfStock => 'Ubos na (pwede pa ring ibenta)';

  @override
  String get payTitle => 'Bayad';

  @override
  String get payTotal => 'Kabuuan';

  @override
  String get payCash => 'Cash';

  @override
  String get payEwallet => 'GCash / Maya';

  @override
  String get payReceivedCash =>
      'Perang tinanggap (iwanang walang laman kung eksakto)';

  @override
  String get payReceivedEwallet => 'Halagang tinanggap';

  @override
  String get payExact => 'Eksakto';

  @override
  String get payChange => 'Sukli';

  @override
  String get payAllUtang => 'Lahat utang';

  @override
  String payOnUtang(String amount) {
    return '$amount ang uutangin';
  }

  @override
  String get payChooseCustomer => 'Piliin kung sino ang may utang';

  @override
  String get payDiscount => 'Bawas';

  @override
  String get payDiscountHint => 'Pisong ibabawas sa kabuuan';

  @override
  String get payDone => 'Tapusin ang benta';

  @override
  String get customerNew => 'Bagong customer';

  @override
  String get customerName => 'Pangalan ng customer';

  @override
  String get customerPhone => 'Telepono (kung meron)';

  @override
  String get customerSearch => 'Hanapin ang customer';

  @override
  String get receiptTitle => 'Resibo';

  @override
  String receiptNumber(String no) {
    return 'Resibo blg. $no';
  }

  @override
  String get receiptSubtotal => 'Subtotal';

  @override
  String get receiptDiscount => 'Bawas';

  @override
  String get receiptCashReceived => 'Cash na tinanggap';

  @override
  String get receiptOnUtang => 'Utang';

  @override
  String receiptBalance(String name, String amount) {
    return 'Utang ni $name: $amount';
  }

  @override
  String get receiptNewSale => 'Bagong benta';

  @override
  String get receiptCancelled => 'KINANSELA';

  @override
  String get receiptThanks => 'Salamat po!';

  @override
  String get utangTitle => 'Utang';

  @override
  String get utangTotalOwed => 'Kabuuang utang sa iyo';

  @override
  String get utangEmpty =>
      'Wala pang may utang sa iyo. Lalabas dito ang mga customer kapag nag-utang sila.';

  @override
  String get utangSettled => 'Bayad na';

  @override
  String get utangOwes => 'May utang';

  @override
  String get utangPaid => 'Nagbayad';

  @override
  String utangPayTitle(String name) {
    return 'Nagbayad si $name';
  }

  @override
  String get utangAmountPaid => 'Halagang binayad';

  @override
  String get utangNote => 'Tala (kung meron)';

  @override
  String utangTooMuch(String amount) {
    return 'Sobra ito sa utang niya ($amount)';
  }

  @override
  String get ledgerCharge => 'Umutang';

  @override
  String get ledgerPayment => 'Nagbayad';

  @override
  String get ledgerAdjust => 'Pagwawasto';

  @override
  String get ledgerVoid => 'Kinansela ang benta';

  @override
  String get todayTitle => 'Ngayong araw';

  @override
  String get todaySales => 'Benta ngayon';

  @override
  String todayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count benta',
      one: '$count benta',
      zero: 'Walang benta',
    );
    return '$_temp0';
  }

  @override
  String get todayCash => 'Pumasok na cash';

  @override
  String get todayUtang => 'Naging utang';

  @override
  String get todayNone => 'Wala pang benta ngayon.';

  @override
  String get saleCancelButton => 'Kanselahin ang benta';

  @override
  String get saleCancelTitle => 'Kanselahin ang benta na ito?';

  @override
  String get saleCancelBody =>
      'Ibabalik sa stock ang mga item at aalisin ang utang mula sa benta na ito.';

  @override
  String get saleCancelYes => 'Oo, kanselahin';

  @override
  String get saleCancelNo => 'Hindi, ituloy';

  @override
  String get stockTitle => 'Stock';

  @override
  String get stockAll => 'Lahat';

  @override
  String stockLowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paubos',
      one: '$count paubos',
      zero: 'Paubos',
    );
    return '$_temp0';
  }

  @override
  String get stockNoneLow => 'Walang paubos na.';

  @override
  String get stockNotCounted => 'Hindi pa nabibilang';

  @override
  String get stockRunningLow => 'Paubos na';

  @override
  String stockNow(String n) {
    return 'Ngayon: $n';
  }

  @override
  String get stockIn => 'Dagdag stock';

  @override
  String get stockCount => 'Bilangin';

  @override
  String stockInTitle(String name) {
    return 'Dagdag stock: $name';
  }

  @override
  String get stockInQty => 'Ilan ang dumating?';

  @override
  String get stockInCost => 'Puhunan bawat isa (kung meron)';

  @override
  String stockCountTitle(String name) {
    return 'Bilang: $name';
  }

  @override
  String get stockCountQty => 'Ilan ang meron ka ngayon?';

  @override
  String get reasonCounted => 'Binilang';

  @override
  String get reasonDamage => 'Sira / expired';

  @override
  String get reasonOther => 'Iba pa';

  @override
  String get reorderPoint => 'Pagsabihan ako kapag ang stock ay';

  @override
  String get reorderPointHelp => 'Iwanang walang laman kung ayaw ng paalala';

  @override
  String sellStockLow(String n) {
    return '$n na lang, paubos na';
  }

  @override
  String get reportsTitle => 'Ulat';

  @override
  String get reportsRefresh => 'I-refresh';

  @override
  String reportsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count araw',
      one: '$count araw',
    );
    return '$_temp0';
  }

  @override
  String get reportsSales => 'Benta';

  @override
  String reportsProfit(String amount) {
    return 'Tinatayang kita: $amount';
  }

  @override
  String get reportsPerDay => 'Bawat araw';

  @override
  String get reportsTopItems => 'Pinakamabenta';

  @override
  String get reportsNothingYet => 'Walang benta sa panahong ito.';

  @override
  String reportsQty(String n) {
    return '$n ang nabenta';
  }

  @override
  String reportsUtangOwed(String amount) {
    return 'Utang sa iyo: $amount';
  }

  @override
  String reportsAsOf(String when) {
    return 'Walang signal. Ipinapakita ang huling ulat noong $when.';
  }

  @override
  String get reportsNeedSignal =>
      'Kailangan ng signal sa unang beses. Kumonekta at subukan ulit.';

  @override
  String reportsNotSent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count benta o pagbabago ang hindi pa naipapadala kaya wala pa sa ulat.',
      one:
          '$count benta o pagbabago ang hindi pa naipapadala kaya wala pa sa ulat.',
    );
    return '$_temp0';
  }

  @override
  String get syncSignIn =>
      'Tapos na ang session. Mag-sign out at mag-sign in ulit; walang mawawala.';

  @override
  String get unsentTitle => 'Hindi pa naipapadala';

  @override
  String unsentBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'May $count pagbabago pa sa phone na ito mula sa ibang negosyo na hindi naipadala.',
      one:
          'May $count pagbabago pa sa phone na ito mula sa ibang negosyo na hindi naipadala.',
    );
    return '$_temp0 Mag-sign in sa negosyong iyon para maipadala, o itapon ang mga ito at magpatuloy.';
  }

  @override
  String get unsentDiscard => 'Itapon at magpatuloy';

  @override
  String get forgotPassword => 'Nakalimutan ang password?';

  @override
  String get forgotTitle => 'I-reset ang password';

  @override
  String get forgotSend => 'Ipadala ang link';

  @override
  String get forgotSent =>
      'Kung may account ang email na iyon, nagpadala kami ng link para i-reset ang password.';

  @override
  String get newPasswordTitle => 'Pumili ng bagong password';

  @override
  String get newPassword => 'Bagong password';

  @override
  String get confirmPassword => 'Ulitin';

  @override
  String get passwordsDiffer => 'Hindi magkapareho ang dalawang password';

  @override
  String get passwordSaved => 'Napalitan na ang password';

  @override
  String get changePassword => 'Palitan ang password';

  @override
  String get themeTitle => 'Itsura ng app';

  @override
  String get themeColors => 'Kulay';

  @override
  String get themeMode => 'Liwanag';

  @override
  String get paletteFreshTide => 'Fresh Tide (asul at mint)';

  @override
  String get paletteGoldenIndigo => 'Golden Indigo (asul at ginto)';

  @override
  String get themeSystem => 'Sundin ang phone';

  @override
  String get themeLight => 'Maliwanag';

  @override
  String get themeDark => 'Madilim';

  @override
  String get utangAdjust => 'Ayusin ang utang';

  @override
  String utangAdjustTitle(String name) {
    return 'Ayusin ang utang ni $name';
  }

  @override
  String get utangWriteOff => 'Bawasan ang utang (burahin)';

  @override
  String get utangAddMore => 'Dagdagan ang utang (pagwawasto)';

  @override
  String get utangAdjustAmount => 'Magkano?';

  @override
  String get utangAdjusted => 'Naayos na ang utang';

  @override
  String get scanTitle => 'I-scan ang barcode';

  @override
  String get scanHint => 'Itutok ang camera sa barcode';

  @override
  String get scanDone => 'Tapos na';

  @override
  String get scanLight => 'Ilaw';

  @override
  String get scanCameraDenied =>
      'Hindi magamit ang camera. Payagan ito sa settings ng phone, tapos subukan ulit.';

  @override
  String scanAdded(String name) {
    return 'Naidagdag: $name';
  }

  @override
  String get scanWithCamera => 'I-scan gamit ang camera';

  @override
  String get receiptPrint => 'I-print';

  @override
  String get receiptShare => 'Ipadala';

  @override
  String get receiptPrintFailed =>
      'Hindi mabuksan ang printer. Subukan ang Ipadala.';

  @override
  String get settingsTitle => 'Mga Setting';

  @override
  String get activeStore => 'Aktibong tindahan';

  @override
  String get settingsAppearance => 'Itsura at tema';

  @override
  String get change => 'Baguhin';

  @override
  String get settingsLanguageRegion => 'Wika at rehiyon';

  @override
  String get systemLanguage => 'Wika ng sistema';

  @override
  String get languageCurrentName => 'Filipino (Tagalog)';

  @override
  String get switchLanguage => 'Switch to EN';

  @override
  String get settingsSecurity => 'Seguridad at account';

  @override
  String get updatePasswordHint => 'I-update ang login password';

  @override
  String get endSessionHint => 'Tapusin ang sesyon sa phone na ito';

  @override
  String get localDbNote => 'Lokal na database: naka-sync at protektado';

  @override
  String get storeSettings => 'Mga setting ng tindahan';

  @override
  String get storeSettingsHint => 'Tema, liwanag, wika, at account';

  @override
  String get startFirstSale => 'Simulan ang unang benta';

  @override
  String get totalSalesToday => 'Kabuuang benta ngayong araw';

  @override
  String get tileUtangSub => 'Talaan ng pautang';

  @override
  String get tileStockSub => 'Balanse ng gamit';

  @override
  String get tileProductsSub => 'Katalogo at presyo';

  @override
  String get tileReportsSub => 'Benta at kita';

  @override
  String get reportsRevenueSub => 'Kabuuang benta ng tindahan';

  @override
  String get reportsAvgOrder => 'Karaniwang benta';

  @override
  String get reportsTotalOrders => 'Kabuuang transaksyon';

  @override
  String get reportsInventoryHealth => 'Kalagayan ng imbentaryo';

  @override
  String get reportsAllHealthy => 'Sapat ang lahat ng produkto';

  @override
  String tileStockLow(int count) {
    return '$count paubos';
  }

  @override
  String reportsNeedReorder(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count produkto ang dapat nang i-reorder',
    );
    return '$_temp0';
  }

  @override
  String sellPinned(String name) {
    return 'Naka-pin sa taas ang $name';
  }

  @override
  String sellUnpinned(String name) {
    return 'Tinanggal sa pin ang $name';
  }

  @override
  String get sellPinHint =>
      'Pindutin nang matagal ang item para i-pin bilang paborito';

  @override
  String get restockTitle => 'Pasuyo';

  @override
  String get restockEmpty => 'Walang bibilhin. Walang paubos.';

  @override
  String get restockShareHeader => 'Listahan ng bibilhin';

  @override
  String get restockCopy => 'Kopyahin';

  @override
  String get restockCopied => 'Nakopya na. I-paste sa mensahe.';

  @override
  String restockNow(String n) {
    return 'Ngayon: $n';
  }

  @override
  String restockBuy(int count) {
    return 'Bilhin: $count';
  }

  @override
  String restockItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count item',
    );
    return '$_temp0';
  }

  @override
  String restockEstimate(String amount) {
    return 'Mga $amount';
  }

  @override
  String get exportSection => 'I-export at backup';

  @override
  String get exportHint =>
      'Ipadala bilang spreadsheet (CSV) sa mensahe o email';

  @override
  String get exportSales => 'Mga benta';

  @override
  String get exportUtang => 'Utang';

  @override
  String get exportStock => 'Stock';

  @override
  String get exportFailed => 'Hindi naipadala ang file. Subukan ulit.';

  @override
  String get expensesTitle => 'Mga gastos';

  @override
  String get expensesSpentToday => 'Nagastos ngayon';

  @override
  String get expensesNone => 'Wala pang gastos ngayon';

  @override
  String get expenseAdd => 'Magdagdag ng gastos';

  @override
  String get expenseAmount => 'Halaga';

  @override
  String get expenseNote => 'Paalala (opsyonal)';

  @override
  String get expensePaidFrom => 'Galing sa';

  @override
  String get expensePaidCash => 'Cash';

  @override
  String get expensePaidEwallet => 'E-wallet';

  @override
  String get expenseCategoryStockPurchase => 'Pambili ng paninda';

  @override
  String get expenseCategoryUtilities => 'Kuryente, tubig';

  @override
  String get expenseCategoryTransport => 'Pamasahe';

  @override
  String get expenseCategoryWages => 'Sahod';

  @override
  String get expenseCategoryRent => 'Upa';

  @override
  String get expenseCategoryOther => 'Iba pa';

  @override
  String get expenseVoidTitle => 'Kanselahin ang gastos na ito?';

  @override
  String get expenseVoidBody =>
      'Mananatili ito sa listahan, may guhit, at hindi na bibilangin.';

  @override
  String get expenseVoidReason => 'Dahilan (opsyonal)';

  @override
  String get expenseVoidYes => 'Kanselahin';

  @override
  String get expenseCancelled => 'Kanselado';

  @override
  String get expenseNeedsPin => 'Kailangan ng PIN ng supervisor';

  @override
  String get approvalTitle => 'PIN ng supervisor';

  @override
  String get approvalBody =>
      'Kailangang aprubahan ito ng supervisor. Ilagay ang PIN ng supervisor (kailangan ng signal).';

  @override
  String get approvalPin => 'PIN';

  @override
  String get approvalApprove => 'Aprubahan';

  @override
  String get approvalWrongPin => 'Maling PIN. Subukan ulit.';

  @override
  String get approvalLocked =>
      'Sobra ang maling subok. Maghintay ng ilang minuto.';

  @override
  String get approvalNoPin => 'Wala pang PIN ang taong ito.';

  @override
  String get approvalNeedsSignal =>
      'Walang signal. Online lang ma-check ang PIN.';

  @override
  String get approvalRefused => 'Hindi pinayagan ang approval.';

  @override
  String get dayCloseTitle => 'Isara ang araw';

  @override
  String get dayCloseExpected => 'Dapat nasa kaha';

  @override
  String get dayCloseHelp =>
      'Panimulang cash + cash na benta + bayad sa utang - gastos na cash';

  @override
  String get dayCloseCounted => 'Binilang mong cash';

  @override
  String get dayCloseNote => 'Paalala (opsyonal)';

  @override
  String get dayCloseExact => 'Tama. Walang kulang o sobra.';

  @override
  String get dayCloseSave => 'I-save ang bilang';

  @override
  String get dayCloseSaved => 'Naisara na ang araw';

  @override
  String get dayCloseAgain => 'Bilangin ulit';

  @override
  String get dayCloseNeedsPin => 'Kailangan ng PIN ng supervisor';

  @override
  String dayCloseShort(String amount) {
    return 'Kulang ng $amount';
  }

  @override
  String dayCloseOver(String amount) {
    return 'Sobra ng $amount';
  }

  @override
  String dayCloseLast(String amount, String time) {
    return 'Huling bilang: $amount nang $time';
  }

  @override
  String expensesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gastos',
    );
    return '$_temp0';
  }

  @override
  String get reportsExpensesNote =>
      'Kasama na sa puhunan ang binili mong paninda, kaya hindi ito ibinabawas ulit.';

  @override
  String reportsExpenses(String amount) {
    return 'Gastos (di kasama ang paninda): $amount';
  }

  @override
  String reportsNetProfit(String amount) {
    return 'Kita pagkatapos ng gastos: $amount';
  }

  @override
  String reportsStockBought(String amount) {
    return 'Pinambili ng paninda: $amount';
  }

  @override
  String get servicesTitle => 'Load at e-wallet';

  @override
  String get servicesFeesToday => 'Kita ngayon (fee)';

  @override
  String get servicesFloat => 'Laman ng wallet';

  @override
  String get servicesNeedsTopup => 'Kailangan ng dagdag';

  @override
  String get servicesNone => 'Wala pang load o e-wallet ngayon';

  @override
  String get serviceCashIn => 'Cash in';

  @override
  String get serviceCashOut => 'Cash out';

  @override
  String get serviceLoad => 'Magbenta ng load';

  @override
  String get serviceMoveFloat => 'Galawin ang float';

  @override
  String get serviceCashInHint =>
      'Cash ang bigay ng customer, ikaw ang magpapadala';

  @override
  String get serviceCashOutHint =>
      'E-wallet ang padala ng customer, ikaw ang magbibigay ng cash';

  @override
  String get serviceFloatTopup => 'Dagdag mula sa kaha';

  @override
  String get serviceFloatWithdraw => 'Kunin papunta sa kaha';

  @override
  String get serviceFloatAdjust => 'Ayusin ang balanse';

  @override
  String get walletGcash => 'GCash';

  @override
  String get walletMaya => 'Maya';

  @override
  String get walletLoad => 'Load';

  @override
  String get walletOther => 'Iba pa';

  @override
  String get serviceWallet => 'Wallet';

  @override
  String get serviceAmount => 'Halaga';

  @override
  String get serviceLoadAmount => 'Halaga ng load';

  @override
  String get serviceFee => 'Singil mo (fee)';

  @override
  String get servicePrice => 'Binayad ng customer (cash)';

  @override
  String get serviceRef => 'Numero o reference (opsyonal)';

  @override
  String get serviceNote => 'Paalala';

  @override
  String get serviceNoteRequired => 'Kailangan ng paalala';

  @override
  String get servicePriceTooLow =>
      'Hindi dapat mas mababa sa halaga ng load ang presyo';

  @override
  String get serviceAdjustHint => 'Gamitin ang minus kung bawas, hal. -50';

  @override
  String get serviceVoidTitle => 'Kanselahin ang entry na ito?';

  @override
  String get serviceVoidBody =>
      'Mananatili ito sa listahan, may guhit, at ibabalik ang pera.';

  @override
  String get serviceVoidYes => 'Kanselahin';

  @override
  String get serviceNeedsPin => 'Kailangan ng PIN ng supervisor';

  @override
  String serviceEarned(String amount) {
    return 'Kita $amount';
  }

  @override
  String get tingiSection => 'Ibinebenta rin nang tingi';

  @override
  String get tingiHelp =>
      'Magbukas ng pack para madagdagan ang piraso sa stock';

  @override
  String get tingiPieces => 'Ilang piraso sa isang pack';

  @override
  String get tingiPieceName => 'Pangalan ng piraso';

  @override
  String get tingiPiecePrice => 'Presyo bawat piraso';

  @override
  String get tingiFailed =>
      'Hindi na-link ang piraso. Baka piraso na ito ng ibang pack.';

  @override
  String get tingiOpenPack => 'Magbukas ng pack';

  @override
  String get tingiPacks => 'Ilang pack?';

  @override
  String get tingiLowWarn =>
      'Mas kaunti ang nabilang mong pack. Maaari pa ring ituloy.';

  @override
  String get tingiHistory => 'Mga nabuksang pack';

  @override
  String get tingiHistoryNone => 'Wala pang nabuksang pack';

  @override
  String get tingiVoidTitle => 'Bawiin ang pagbukas na ito?';

  @override
  String get tingiVoidBody =>
      'Aalis sa stock ang mga piraso at babalik ang pack.';

  @override
  String get tingiVoidYes => 'Bawiin';

  @override
  String get tingiLinkChanged =>
      'Nagbago ang piraso kada pack. Tingnan ang produkto.';

  @override
  String get tingiCancelled => 'Binawi';

  @override
  String tingiPieceSuffix(String name) {
    return '$name (piraso)';
  }

  @override
  String tingiLinkedTo(String name) {
    return 'Ibinebenta ang piraso bilang $name';
  }

  @override
  String tingiOpenTitle(String name) {
    return 'Magbukas ng pack: $name';
  }

  @override
  String tingiPreview(int count, String name) {
    return 'Magiging $count × $name';
  }

  @override
  String tingiOpened(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nadagdag ang $count piraso sa stock',
    );
    return '$_temp0';
  }

  @override
  String tingiHistoryRow(int packs, int pieces, String name) {
    return '$packs pack → $pieces × $name';
  }

  @override
  String get utangDueSet => 'Maglagay ng petsa ng bayad';

  @override
  String get utangDueChange => 'Palitan ang petsa';

  @override
  String get utangDueClear => 'Alisin ang petsa';

  @override
  String get utangSendStatement => 'Ipadala ang statement';

  @override
  String get utangOverdueNone => 'Walang lampas na sa petsa';

  @override
  String get stmtTitle => 'Statement ng utang';

  @override
  String get stmtBalance => 'Balanse';

  @override
  String get stmtDueOn => 'Magbabayad sa';

  @override
  String get stmtRecent => 'Kamakailan';

  @override
  String get stmtCharge => 'Utang';

  @override
  String get stmtPayment => 'Bayad';

  @override
  String get stmtAdjust => 'Ayos';

  @override
  String get stockExpirySet => 'Ilagay ang expiry date';

  @override
  String get stockExpiryClear => 'Alisin ang expiry date';

  @override
  String get stockInExpiry => 'Expiry date (opsyonal)';

  @override
  String get stockNoneExpiring => 'Walang malapit nang mag-expire.';

  @override
  String utangDueOn(String date) {
    return 'Magbabayad sa $date';
  }

  @override
  String utangOverdueDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count araw nang lampas',
    );
    return '$_temp0';
  }

  @override
  String utangOverdueFilter(int count) {
    return 'Lampas na ($count)';
  }

  @override
  String tileUtangOverdue(int count) {
    return '$count lampas na';
  }

  @override
  String stockExpiringFilter(int count) {
    return 'Malapit mag-expire ($count)';
  }

  @override
  String stockExpiresIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mag-eexpire sa $count araw',
      one: 'Mag-eexpire bukas',
      zero: 'Mag-eexpire ngayon',
    );
    return '$_temp0';
  }

  @override
  String stockExpiredAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nag-expire $count araw na ang nakaraan',
      one: 'Nag-expire kahapon',
    );
    return '$_temp0';
  }

  @override
  String tileStockExpiring(int count) {
    return '$count malapit mag-expire';
  }

  @override
  String get dataTitle => 'I-import at i-export';

  @override
  String get dataExportSection => 'I-export';

  @override
  String get dataImportSection => 'Mag-import ng produkto';

  @override
  String get dataImportHint =>
      'Kopyahin ang mga row mula sa spreadsheet at i-paste dito. Mga column: name, price, barcode, cost, stock.';

  @override
  String get dataImportOpen => 'I-paste ang produkto';

  @override
  String get dataImportTemplate => 'Kopyahin ang mga column';

  @override
  String get dataTemplateCopied =>
      'Nakopya ang mga column. I-paste sa spreadsheet.';

  @override
  String get dataImportPaste => 'I-paste dito ang mga row';

  @override
  String get dataTooMany =>
      'Unang 500 row lang ang binabasa kada batch. I-import ang iba sa susunod.';

  @override
  String get dataProbName => 'walang pangalan';

  @override
  String get dataProbPrice => 'hindi numero ang presyo';

  @override
  String get dataProbCost => 'hindi numero ang puhunan';

  @override
  String get dataProbStock => 'hindi numero ang stock';

  @override
  String get exportProducts => 'Mga produkto';

  @override
  String dataImportReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count produkto ang handa',
    );
    return '$_temp0';
  }

  @override
  String dataImportProblems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count row ang may problema at hindi isasama',
    );
    return '$_temp0';
  }

  @override
  String dataImportLine(int line, String problem) {
    return 'Row $line: $problem';
  }

  @override
  String dataImportGo(int count) {
    return 'I-import ang $count';
  }

  @override
  String dataImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nadagdag ang $count produkto',
    );
    return '$_temp0';
  }

  @override
  String dataSkipped(int count) {
    return '$count ang nilaktawan: gamit na ang barcode';
  }

  @override
  String get dayCloseOpening => 'Panimulang cash (sukli)';

  @override
  String dayCloseOpeningLine(String amount) {
    return 'Nagsimula sa $amount';
  }

  @override
  String get keypadAdd => 'Idagdag sa benta';

  @override
  String get sellModeItems => 'Mga item';

  @override
  String get sellModeKeypad => 'Keypad';

  @override
  String get openAmountName => 'Iba pang item';

  @override
  String get payWalletTitle => 'Anong wallet?';

  @override
  String get noProductsHere =>
      'Wala ka pang produkto. Magdagdag ng isa, o mag-import ng listahan sa Iba pa > I-import at i-export.';

  @override
  String get storePickerTitle => 'Palitan ang tindahan';

  @override
  String storeSwitched(String name) {
    return 'Nagbebenta na sa $name';
  }

  @override
  String get storeSwitchAsk => 'Palitan ang tindahan?';

  @override
  String get storeSwitchKeep => 'Palitan at panatilihin ang benta';

  @override
  String get storeSwitchClear => 'Palitan at burahin ang benta';

  @override
  String storeSwitchBody(int count, String store) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count item',
    );
    return 'May benta na isinasagawa ($_temp0). Kapag itinuloy, babayaran ito sa $store at doon ibabawas ang stock.';
  }

  @override
  String get upgradeFullSection => 'Full Mode';

  @override
  String get upgradeFullTitle => 'Mag-upgrade sa Full Mode';

  @override
  String get upgradeFullSubtitle =>
      'Magdagdag ng mga sangay, bodega, at kahera. Mananatili ang lahat ng iyong solo data.';

  @override
  String get upgradeFullAction => 'Alamin Pa';

  @override
  String get upgradeFullDialogTitle => 'Full Mode Upgrade';

  @override
  String get upgradeFullDialogBody =>
      'Binubuksan ng Full Mode ang maraming tindahan, gitnang bodega, at mga account ng kawani (Kahera, Manager, Supervisor). Ang lahat ng iyong kasalukuyang benta, produkto, stock, at utang ay ligtas na mananatili.\n\nUpang mag-upgrade, buksan ang XZACTO POS web app sa anumang browser at gamitin ang Upgrade Wizard.';

  @override
  String get upgradeFullClose => 'Naintindihan';

  @override
  String get whTabReceive => 'Tanggapin';

  @override
  String get whTabCount => 'Bilang';

  @override
  String get whTabStock => 'Stock';

  @override
  String get whTabMore => 'Iba pa';

  @override
  String get whNoWarehouse =>
      'Wala pang bodega. Mag-online muna para ma-load ang mga bodega mo.';

  @override
  String get whSwitchTitle => 'Pumili ng bodega';

  @override
  String whSwitched(String name) {
    return 'Nasa $name ka na';
  }

  @override
  String get whSwitchAction => 'Palitan ang bodega';

  @override
  String get whOpenOrders => 'Mga bukas na order';

  @override
  String get whNoOrders => 'Walang bukas na order sa bodegang ito.';

  @override
  String whOrderLeft(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count na lang ang tatanggapin',
      one: '$count na lang ang tatanggapin',
    );
    return '$_temp0';
  }

  @override
  String get whOrderComplete => 'Natanggap na lahat';

  @override
  String get whWaitingSync => 'Hinihintay i-sync';

  @override
  String get whStatusOrdered => 'Na-order na';

  @override
  String get whStatusPartly => 'Bahagyang natanggap';

  @override
  String get whOrderLines => 'Mga item sa order na ito';

  @override
  String whLineProgress(String received, String ordered) {
    return '$received sa $ordered ang natanggap';
  }

  @override
  String get whReceipts => 'Mga resibo mula sa teleponong ito';

  @override
  String get whNoReceipts => 'Wala pang natanggap sa teleponong ito.';

  @override
  String get whReceiptWalkin => 'Delivery na walang order';

  @override
  String get whSearchStock => 'Hanapin ang stock';

  @override
  String get whNoStock => 'Wala pang stock sa bodegang ito.';

  @override
  String whStockPending(String qty) {
    return '$qty ang papasok';
  }

  @override
  String get whCountSoon =>
      'Malapit nang magamit ang pagbibilang sa telepono. Sa ngayon, gamitin ang web app para sa stock count.';

  @override
  String get whUnknownProduct => 'Hindi kilalang produkto';

  @override
  String get whReceiveStart => 'Tanggapin ang mga paninda';

  @override
  String get whReceiveTitle => 'Tanggapin';

  @override
  String get whReceiveSave => 'I-save ang resibo';

  @override
  String get whReceiptSaved =>
      'Na-save ang resibo. Mase-sync ito kapag online ka.';

  @override
  String get whQtyReceived => 'Dami na natanggap';

  @override
  String get whInvoiceCost => 'Presyo bawat isa (opsyonal)';

  @override
  String get whDeliveryRef => 'Delivery o invoice no. (opsyonal)';

  @override
  String get whNotes => 'Tala (opsyonal)';

  @override
  String get whOverDelivery =>
      'Mas marami kaysa sa order. Mamarkahan ang sobra.';

  @override
  String get whWalkInStart => 'Delivery na walang order';

  @override
  String get whWalkInTitle => 'Delivery na walang order';

  @override
  String get whWalkInHint =>
      'Idagdag ang dumating. Mamarkahan ito para suriin dahil walang order.';

  @override
  String get whSupplier => 'Supplier';

  @override
  String get whNoSupplier => 'Walang supplier';

  @override
  String get whScanUnknown => 'Walang produktong may ganyang barcode.';

  @override
  String get whErrUnknownOrder =>
      'Wala na ang order na ito sa telepono. Mag-sync at subukan ulit.';

  @override
  String get whErrOrderClosed => 'Sarado na ang order na ito.';

  @override
  String get whErrNotOnOrder => 'Wala sa order na ito ang produktong iyon.';

  @override
  String get whErrDuplicateLine =>
      'Isang beses lang puwedeng lumabas ang bawat produkto.';

  @override
  String get whErrQtyInvalid => 'Maglagay ng dami na higit sa zero.';

  @override
  String get whErrCostInvalid => 'Hindi tamang halaga ang presyo.';

  @override
  String get whErrNoLines => 'Maglagay ng dami para sa kahit isang produkto.';

  @override
  String get whErrUnknownWarehouse =>
      'Hindi available sa iyo ang bodegang ito.';

  @override
  String get whCountOffline =>
      'Kailangan ng koneksyon para magbilang ng stock. Tingnan ang signal at subukan ulit.';

  @override
  String get whCountRetry => 'Subukan ulit';

  @override
  String get whCountNone => 'Walang kasalukuyang bilang.';

  @override
  String get whCountScope => 'Ano ang bibilangin';

  @override
  String get whCountWhole => 'Buong bodega';

  @override
  String get whCountStart => 'Simulan ang pagbibilang';

  @override
  String get whCountBin => 'Bin';

  @override
  String get whCountQty => 'Dami na nabilang';

  @override
  String get whCountSaveLine => 'I-save ang bilang';

  @override
  String get whCountNoLines =>
      'Wala pang nabilang. Maghanap o mag-scan ng produkto.';

  @override
  String whCountSystemWas(String qty) {
    return '$qty ang nasa system';
  }

  @override
  String get whCountFinish => 'Tapusin ang bilang';

  @override
  String get whCountFinishAsk => 'Tapusin ang bilang na ito?';

  @override
  String get whCountFinishBody =>
      'Itatama ang stock ayon sa nabilang mo. Hindi na ito mababawi.';

  @override
  String get whCountZeroUncounted =>
      'Ituring na zero ang mga hindi ko nabilang';

  @override
  String get whCountCancel => 'Kanselahin ang bilang';

  @override
  String get whCountCancelAsk => 'Kanselahin ang bilang na ito?';

  @override
  String get whCountCancelBody =>
      'Aalisin ang mga nabilang mo. Mananatili ang stock.';

  @override
  String get whCountKeep => 'Ituloy ang pagbibilang';

  @override
  String get whCountErrInProgress => 'May bukas nang bilang sa bodegang ito.';

  @override
  String get whCountErrBinRequired =>
      'Piliin ang bin kung saan mo ito nabilang.';

  @override
  String get whCountErrBin =>
      'Hindi available ang bin na iyon sa bilang na ito.';

  @override
  String get whCountErrBinsOff => 'Hindi gumagamit ng bin ang bodegang ito.';

  @override
  String get whCountErrNothing => 'Wala pang nabilang.';

  @override
  String get whCountErrNotAllowed => 'Hindi ka puwedeng magbilang dito.';

  @override
  String get whCountErrClosed => 'Sarado o kinansela na ang bilang na ito.';

  @override
  String get whCountErrSnapshot =>
      'Hindi ma-verify ang binilang stock laban sa mga paggalaw ng imbentaryo.';

  @override
  String get whNoBinStock => 'Walang stock sa anumang bin.';

  @override
  String whCountDone(int count, String net) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ang itinama.',
      one: '$count ang itinama.',
      zero: 'Walang itinama.',
    );
    return 'Tapos na ang bilang. $_temp0 Netong pagbabago: $net';
  }

  @override
  String get activeWarehouse => 'Aktibong bodega';

  @override
  String get shiftTitle => 'Shift';

  @override
  String get shiftNoneOpen => 'Walang bukas na shift';

  @override
  String get shiftNoneHelp =>
      'Magsimula ng shift kapag ikaw na ang hahawak ng kaha, at bilangin ang panimulang cash.';

  @override
  String get shiftOpeningField => 'Cash sa kaha sa pagsisimula mo';

  @override
  String get shiftStart => 'Simulan ang shift';

  @override
  String shiftOpenSince(String time) {
    return 'Bukas mula $time';
  }

  @override
  String get shiftOpeningLabel => 'Panimulang cash';

  @override
  String get shiftCashSales => 'Benta sa cash';

  @override
  String get shiftUtangTaken => 'Bayad sa utang (cash)';

  @override
  String get shiftPaidOut => 'Cash na nailabas (gastos)';

  @override
  String get shiftLoadCash => 'Load at e-wallet (cash)';

  @override
  String shiftSalesLine(int count, String total) {
    return 'Mga benta: $count · Kabuuan: $total';
  }

  @override
  String shiftOtherTenders(String ewallet, String utang) {
    return 'E-wallet: $ewallet · Sa utang: $utang';
  }

  @override
  String get shiftEstimateNote =>
      'Ito ang bilang ng teleponong ito. Hindi kasama ang mga benta sa ibang telepono.';

  @override
  String get shiftShareX => 'Ibahagi ang bilang na ito';

  @override
  String get shiftClose => 'Isara ang shift';

  @override
  String get shiftCloseAsk => 'Bilangin ang kaha';

  @override
  String get shiftChecking => 'Tinitingnan sa server...';

  @override
  String get shiftServerFigure => 'Bilang mula sa server';

  @override
  String get shiftPhoneFigure => 'Bilang mula sa teleponong ito';

  @override
  String get shiftConfirmClose => 'Isara ang shift na ito';

  @override
  String get shiftClosed => 'Naisara na ang shift';

  @override
  String get shiftZTitle => 'Ulat ng shift';

  @override
  String shiftOpenedLine(String time) {
    return 'Binuksan $time';
  }

  @override
  String shiftClosedLine(String time) {
    return 'Isinara $time';
  }

  @override
  String shiftServerDiffers(String amount) {
    return 'Ang nakuha ng server ay $amount para sa shift na ito. Maaaring gustong suriin ng supervisor.';
  }

  @override
  String get shiftHistory => 'Mga huling shift';

  @override
  String get shiftNoHistory => 'Wala pang shift.';

  @override
  String get shiftStillOpen => 'Bukas';

  @override
  String get shiftErrAlreadyOpen => 'May bukas ka nang shift.';

  @override
  String get shiftErrAmount => 'Maglagay ng halaga.';

  @override
  String get shiftChipOpen => 'Bukas ang shift';

  @override
  String get shiftChipNone => 'Walang shift';

  @override
  String get staffTitle => 'Mga tauhan';

  @override
  String get staffAdd => 'Magdagdag ng kahera';

  @override
  String get staffNone => 'Wala pang tauhan.';

  @override
  String get staffOffline =>
      'Kailangan ng signal. Subukan ulit kapag online ka.';

  @override
  String get staffUsername => 'Username (letra, numero, tuldok, gitling)';

  @override
  String get staffFullName => 'Pangalan';

  @override
  String get staffPassword => 'Password (hindi bababa sa 8 karakter)';

  @override
  String get staffStore => 'Tindahan';

  @override
  String get staffCreate => 'Gumawa ng account';

  @override
  String staffCreated(String name, String login) {
    return 'Nagawa na ang account. Sabihin kay $name na mag-sign in bilang $login.';
  }

  @override
  String staffSignIn(String login) {
    return 'Nagsa-sign in bilang $login';
  }

  @override
  String get staffInactive => 'Naka-off';

  @override
  String get staffDeactivate => 'I-off';

  @override
  String get staffActivate => 'I-on';

  @override
  String get staffResetPin => 'Burahin ang PIN';

  @override
  String get staffPinCleared => 'Nabura na ang PIN.';

  @override
  String get staffRoleSuperadmin => 'May-ari';

  @override
  String get staffRoleAdmin => 'Manager';

  @override
  String get staffRoleWarehouse => 'Bodega';

  @override
  String get staffRoleCashier => 'Kahera';

  @override
  String get staffErrDuplicate => 'May gumagamit na ng username na iyan.';

  @override
  String get staffErrInvalid => 'Suriin ang username at password.';

  @override
  String get staffErrDenied => 'Hindi mo ito magagawa.';

  @override
  String get staffErrSelf => 'Hindi mo maaaring i-off ang sarili mo.';

  @override
  String get staffErrLimit =>
      'Walang espasyo para sa dagdag na user sa planong ito.';

  @override
  String get loginHelper => 'Tauhan: username.storecode';

  @override
  String get shiftPrint => 'I-print ang slip';

  @override
  String get shiftPrintPdf => 'PDF na slip';

  @override
  String get shiftOtherOpen => 'Iba pang nakabukas na shift';

  @override
  String get shiftSupervisorClose => 'Isara ang shift (Superbisor)';

  @override
  String shiftCashierLabel(String name) {
    return 'Kahera: $name';
  }

  @override
  String get printerSection => 'Resibo at Thermal Printer';

  @override
  String get printerSectionHint =>
      'Ikonekta sa thermal ESC/POS network printer o gamitin ang system print';

  @override
  String get printerEngine => 'Modo ng printer';

  @override
  String get printerEnginePdf => 'System print dialog / PDF';

  @override
  String get printerEngineEscPos => 'Thermal ESC/POS (Network/LAN)';

  @override
  String get printerIp => 'IP address ng printer';

  @override
  String get printerPort => 'Port';

  @override
  String get printerWidth => 'Lapad ng papel';

  @override
  String get printerDrawerKick => 'Buksan ang drawer kapag nag-print';

  @override
  String get printerAutoPrint => 'Kusang mag-print pagkatapos ng benta';

  @override
  String get printerTestPrint => 'Subukan ang Pag-print';

  @override
  String get printerTestSuccess => 'Matagumpay na naipadala ang test print!';

  @override
  String get printerTestFailed => 'Hindi makakonekta sa thermal printer.';

  @override
  String get transfersTitle => 'Mga Paglipat ng Imbentaryo';

  @override
  String get transfersIncoming => 'Papasok';

  @override
  String get transfersHistory => 'Kasaysayan';

  @override
  String get transfersEmptyIncoming =>
      'Walang papasok na paglipat na naghihintay matanggap.';

  @override
  String get transfersEmptyHistory => 'Walang nakitang kasaysayan ng paglipat.';

  @override
  String get transferManifest => 'Manifest #';

  @override
  String get transferFrom => 'Galing sa';

  @override
  String get transferTo => 'Papunta sa';

  @override
  String get transferShipped => 'Ipinadala';

  @override
  String get transferReceived => 'Natanggap';

  @override
  String get transferReceive => 'Tanggapin ang Kargamento';

  @override
  String get transferReceiveTitle => 'Pagtanggap ng Paglipat';

  @override
  String get transferReceivePrompt =>
      'Suriin ang mga natanggap na aytem laban sa shipping manifest.';

  @override
  String transferItemShipped(num count) {
    return 'Ipinadala: $count';
  }

  @override
  String get transferItemCounted => 'Nabilang';

  @override
  String get transferDiscrepancyWarning =>
      'May mga dami na iba kaysa sa nakasaad sa manifest.';

  @override
  String get transferConfirmReceive => 'Kumpirmahin ang Pagtanggap';

  @override
  String get transferReceivedSuccess => 'Matagumpay na natanggap ang paglipat.';

  @override
  String get transferReceivedDiscrepancy =>
      'Natanggap ang paglipat na may naitalang diperensya.';

  @override
  String get transferScanItem => 'I-scan ang barcode ng aytem para mabilang';

  @override
  String get putawayTitle => 'Lipat sa Bin';

  @override
  String get putawayAvailable => 'Meron';

  @override
  String get putawayAction => 'Ilipat';

  @override
  String get putawayDialogTitle => 'Paglipat ng Item sa Bin';

  @override
  String get putawayDestinationBin => 'Patutunguhang Storage Bin';

  @override
  String get putawayScanBin => 'I-scan ang Bin';

  @override
  String get putawayQuantity => 'Dami na Ililipat';

  @override
  String get putawayConfirm => 'Kumpirmahin ang Paglipat';

  @override
  String get putawaySuccess => 'Matagumpay na nailipat ang stock sa bin.';

  @override
  String get putawayError => 'Nabigong i-load ang mga ililipat na stock.';

  @override
  String get putawayEmptyTitle => 'Lahat ng Stock ay Nailipat Na';

  @override
  String get putawayEmptyBody =>
      'Walang stock na naghihintay sa Receiving. Lahat ay nakaimbak na sa mga bin.';

  @override
  String get transferCreateTitle => 'Bagong Paglilipat ng Stock';

  @override
  String get transferOrigin => 'Pinagmulang Lokasyon';

  @override
  String get transferDestination => 'Patutunguhang Lokasyon';

  @override
  String get transferSelectDestination => 'Pumili ng patutunguhang lokasyon';

  @override
  String get transferItemsSection => 'Mga Item na Ililipat';

  @override
  String get transferAddItem => 'Magdagdag ng Produkto';

  @override
  String get transferEmptyItems =>
      'Wala pang item. Pindutin ang Magdagdag o I-scan ang Barcode.';

  @override
  String get transferSelectProduct => 'Pumili ng Item na Ililipat';

  @override
  String get transferNotesOptional => 'Tala sa Paglipat (Opsyonal)';

  @override
  String get transferNotesHint => 'Dahilan, drayber, o tagubilin';

  @override
  String get transferShipAction => 'Ipadala ang Paglilipat';

  @override
  String get transferNoItemsError =>
      'Magdagdag ng kahit isang item para maipadala';

  @override
  String get transferDestinationsError => 'Nabigong i-load ang mga lokasyon';

  @override
  String get transferCreatedSuccess =>
      'Matagumpay na naipadala ang paglilipat ng stock.';

  @override
  String get transferNewAction => 'Bagong Paglipat';

  @override
  String get supervisorPinDiscountTitle => 'Override ng Supervisor';

  @override
  String supervisorPinDiscountSubtitle(String amount) {
    return 'Kailangan ng pag-apruba ng supervisor para sa diskwentong $amount';
  }

  @override
  String get supervisorPinRequiredDiscount =>
      'Kailangan ang PIN ng supervisor para sa diskwento';

  @override
  String get supervisorPinApproveBtn => 'Aprubahan';

  @override
  String supervisorPinApprovedBy(String name) {
    return 'Inaprubahan ni $name';
  }

  @override
  String get pickListTitle => 'Mga Listahan ng Pagkuha';

  @override
  String get pickListDraftTransfers => 'Mga Outbound Transfer para Kunin';

  @override
  String get pickListNoDrafts =>
      'Walang draft transfer na naghihintay ng pagkuha.';

  @override
  String get pickListGenerate => 'Gumawa ng Pick List';

  @override
  String get pickListGenerating => 'Ginagawa...';

  @override
  String get pickListWalkingRoute => 'Mga Bin ayon sa Rutang Paglakad';

  @override
  String pickListItemsCount(int count) {
    return '$count mga aytem';
  }

  @override
  String get pickListItemPick => 'Kunin ang Aytem';

  @override
  String get pickListScanItem => 'I-scan ang Aytem / Bin';

  @override
  String get pickListQtyToPick => 'Dami na Kukunin';

  @override
  String get pickListShortReason => 'Dahilan kung Kulang';

  @override
  String get pickListShortReasonHint => 'hal. Sira, nawawala sa bin';

  @override
  String get pickListConfirmPick => 'Kumpirmahin ang Pagkuha';

  @override
  String get pickListPicking => 'Kinukumpirma...';

  @override
  String get pickListCompleted => 'Tapos Na';

  @override
  String get pickListInProgress => 'Kasalukuyang Ginagawa';

  @override
  String get pickListPending => 'Nakabinbin';

  @override
  String pickListProgress(int picked, int total) {
    return '$picked sa $total ang nakuha';
  }

  @override
  String get pickListStagingNotice =>
      'Ang mga aytem ay inililipat sa STAGING bin para sa pagpapadala.';

  @override
  String pickListBinCoord(String aisle, String rack, String shelf) {
    return 'Aisle $aisle • Rack $rack • Shelf $shelf';
  }

  @override
  String get pickListAllPicked =>
      'Lahat ng aytem ay nakuha at nailipat na sa staging';

  @override
  String get pickListAction => 'Listahan ng Pagkuha';

  @override
  String get shiftCashDrop => 'Cash Drop / Skim';

  @override
  String get shiftCashDropSubtitle =>
      'Maglipat ng sobrang pera mula sa drawer papuntang safe o kustodiya';

  @override
  String get shiftCashDropAmount => 'Halaga ng Drop';

  @override
  String get shiftCashDropAmountHint => '0.00';

  @override
  String get shiftCashDropReason => 'Dahilan / Destinasyon';

  @override
  String get shiftCashDropReasonHint => 'hal. Mid-day safe drop, bangko';

  @override
  String get shiftCashDropChipSafe => 'Safe Drop';

  @override
  String get shiftCashDropChipBank => 'Para sa Bangko';

  @override
  String get shiftCashDropChipSkim => 'Drawer Skim';

  @override
  String get shiftCashDropConfirm => 'Itala ang Cash Drop';

  @override
  String shiftCashDropSuccess(String amount) {
    return 'Naitala ang cash drop na $amount';
  }

  @override
  String get shiftCashDropSlipTitle => 'RESAPIS NG CASH DROP';

  @override
  String get shiftCashDropSlipCashier => 'Kahero';

  @override
  String get shiftCashDropSlipWitness => 'Saksi / Supervisor';

  @override
  String get shiftCashDropShare => 'Ibahagi ang Slip';

  @override
  String get shiftCashDropPrint => 'I-print ang Slip';

  @override
  String get shiftCashDropErrAmount =>
      'Maglagay ng wastong halaga na higit sa zero';

  @override
  String get shiftCashDropErrExceeds =>
      'Hindi maaaring lumampas ang drop sa inaasahang laman ng drawer';

  @override
  String get payCard => 'Kard';

  @override
  String get payCardRef => 'Trace o approval code ng kard';

  @override
  String get payCardRefHint => 'hal. 123456';

  @override
  String get payCardSuccess => 'Naitala ang bayad gamit ang kard';

  @override
  String get payCardReceived => 'Halaga sa kard';

  @override
  String get cartLineDiscount => 'Bawas sa presyo ng item';

  @override
  String get cartLineDiscountHint => 'Halaga ng bawas (₱)';

  @override
  String get cartEditItem => 'Baguhin ang item';

  @override
  String cartLineDiscountShort(String amount) {
    return '-$amount bawas';
  }

  @override
  String get cartUnitPrice => 'Presyo bawat piraso';

  @override
  String get cartUnitPriceOverride => 'Palitan ang presyo';

  @override
  String stockReorderAlert(String current, String min) {
    return 'Mababa sa reorder point ($current / min $min)';
  }

  @override
  String get stockLowStockBadge => 'Mababang Stock';

  @override
  String get stockRequestTransfer => 'Humiling ng Transfer para sa Stock';
}
