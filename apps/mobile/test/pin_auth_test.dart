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

    test('rejects cashier and warehouse staff PINs as offline store approvers', () async {
      SharedPreferences.setMockInitialValues({});
      SupervisorPinStorage.resetInMemoryFailures();
      const locId = 'loc-cashier-check';
      const saltB64 = 'c2FsdHNhbHRzYWx0MTIz';

      await SupervisorPinStorage.savePins(locId, [
        SupervisorPin.fromJson({
          'user_id': 'usr-cashier',
          'full_name': 'Juan Cashier',
          'role': 'cashier',
          'position': null,
          'pin_hash': PinCrypto.hashPin('4444', saltB64, iterations: 1000),
        }),
        SupervisorPin.fromJson({
          'user_id': 'usr-wh',
          'full_name': 'Carlo Warehouse',
          'role': 'warehouse',
          'position': null,
          'pin_hash': PinCrypto.hashPin('5555', saltB64, iterations: 1000),
        }),
        SupervisorPin.fromJson({
          'user_id': 'usr-super',
          'full_name': 'Sara Supervisor',
          'role': 'admin',
          'position': 'supervisor',
          'pin_hash': PinCrypto.hashPin('3333', saltB64, iterations: 1000),
        }),
      ]);

      expect(await SupervisorPinStorage.verifyOfflinePin(locationId: locId, pin: '4444'), isNull);
      expect(await SupervisorPinStorage.verifyOfflinePin(locationId: locId, pin: '5555'), isNull);
      final ok = await SupervisorPinStorage.verifyOfflinePin(locationId: locId, pin: '3333');
      expect(ok, isNotNull);
      expect(ok!.userId, 'usr-super');
      expect(ok.displayName, 'Sara Supervisor');
    });

    test('enforces 5-strike 15-minute local offline PIN lockout', () async {
      SharedPreferences.setMockInitialValues({});
      SupervisorPinStorage.resetInMemoryFailures();
      const locId = 'loc-lockout';
      const saltB64 = 'c2FsdHNhbHRzYWx0MTIz';
      final baseNow = DateTime.utc(2026, 11, 12, 8, 0, 0);

      await SupervisorPinStorage.savePins(locId, [
        SupervisorPin(
          userId: 'usr-owner',
          displayName: 'Owner Boss',
          role: 'superadmin',
          pinHash: PinCrypto.hashPin('1111', saltB64, iterations: 1000),
        ),
      ]);

      for (var i = 1; i <= 4; i++) {
        final r = await SupervisorPinStorage.verifyOfflinePinDetailed(
          locationId: locId,
          pin: '0000',
          now: baseNow.add(Duration(seconds: i * 10)),
        );
        expect(r.status, OfflinePinVerifyStatus.wrongPin);
      }

      // 5th wrong attempt triggers lockout
      final fifth = await SupervisorPinStorage.verifyOfflinePinDetailed(
        locationId: locId,
        pin: '0000',
        now: baseNow.add(const Duration(seconds: 50)),
      );
      expect(fifth.status, OfflinePinVerifyStatus.locked);

      // Even the right PIN is refused while locked within 15 minutes
      final blocked = await SupervisorPinStorage.verifyOfflinePinDetailed(
        locationId: locId,
        pin: '1111',
        now: baseNow.add(const Duration(minutes: 5)),
      );
      expect(blocked.status, OfflinePinVerifyStatus.locked);

      // After 16 minutes the window expires and the right PIN succeeds
      final recovered = await SupervisorPinStorage.verifyOfflinePinDetailed(
        locationId: locId,
        pin: '1111',
        now: baseNow.add(const Duration(minutes: 16)),
      );
      expect(recovered.status, OfflinePinVerifyStatus.matched);
      expect(recovered.approver!.userId, 'usr-owner');
    });
  });
}
