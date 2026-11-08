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
}
