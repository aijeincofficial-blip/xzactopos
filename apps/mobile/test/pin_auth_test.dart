import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzactopos_mobile/core/pin_auth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PinCrypto PBKDF2 tests', () {
    test('rejects invalid hash formats', () {
      expect(PinCrypto.verifyPin('1234', ''), isFalse);
      expect(PinCrypto.verifyPin('1234', 'invalid_format'), isFalse);
      expect(PinCrypto.verifyPin('1234', 'bcrypt\$10\$abc\$def'), isFalse);
      expect(PinCrypto.verifyPin('1234', 'pbkdf2_sha256\$not_a_number\$salt\$hash'), isFalse);
    });

    test('verifies matching PIN with 1,000 iterations', () {
      const saltB64 = 'c2FsdHNhbHRzYWx0MTIz'; // 16 bytes base64
      const pin = '5678';
      final hashStr = PinCrypto.hashPin(pin, saltB64, iterations: 1000);

      expect(PinCrypto.verifyPin('5678', hashStr), isTrue);
      expect(PinCrypto.verifyPin('0000', hashStr), isFalse);
      expect(PinCrypto.verifyPin('5679', hashStr), isFalse);
    });

    test('verifies 20,000 iterations default database hash', () {
      const saltB64 = 'YWJjZGVmZ2hpamtsbW5vcA==';
      const pin = '1111';
      final hashStr = PinCrypto.hashPin(pin, saltB64, iterations: 20000);

      expect(PinCrypto.verifyPin('1111', hashStr), isTrue);
      expect(PinCrypto.verifyPin('2222', hashStr), isFalse);
    });
  });

  group('SupervisorPinStorage tests', () {
    test('saves, reloads and verifies offline supervisor pins', () async {
      SharedPreferences.setMockInitialValues({});
      const locId = 'loc-test-1';

      const saltB64 = 'c2FsdHNhbHRzYWx0MTIz';
      final hash1 = PinCrypto.hashPin('1234', saltB64, iterations: 1000);
      final hash2 = PinCrypto.hashPin('9999', saltB64, iterations: 1000);

      final pins = [
        SupervisorPin(
          userId: 'usr-1',
          displayName: 'Boss Maria',
          role: 'admin',
          pinHash: hash1,
        ),
        SupervisorPin(
          userId: 'usr-2',
          displayName: 'Lead Carlo',
          role: 'supervisor',
          pinHash: hash2,
        ),
      ];

      await SupervisorPinStorage.savePins(locId, pins);
      final loaded = await SupervisorPinStorage.loadPins(locId);

      expect(loaded.length, 2);
      expect(loaded[0].displayName, 'Boss Maria');
      expect(loaded[1].displayName, 'Lead Carlo');

      // Verify correct PIN matches
      final match1 = await SupervisorPinStorage.verifyOfflinePin(locationId: locId, pin: '1234');
      expect(match1, isNotNull);
      expect(match1!.userId, 'usr-1');

      final match2 = await SupervisorPinStorage.verifyOfflinePin(locationId: locId, pin: '9999');
      expect(match2, isNotNull);
      expect(match2!.userId, 'usr-2');

      // Verify incorrect PIN returns null
      final badMatch = await SupervisorPinStorage.verifyOfflinePin(locationId: locId, pin: '0000');
      expect(badMatch, isNull);
    });
  });
}
