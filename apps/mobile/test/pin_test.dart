import 'package:flutter_test/flutter_test.dart';
import 'package:xzactopos_mobile/core/pin.dart';

void main() {
  group('verifyPinPbkdf2', () {
    test('rejects invalid hash formats', () {
      expect(verifyPinPbkdf2('1234', ''), isFalse);
      expect(verifyPinPbkdf2('1234', 'invalid_format'), isFalse);
      expect(verifyPinPbkdf2('1234', 'bcrypt\$10\$abc\$def'), isFalse);
      expect(verifyPinPbkdf2('1234', 'pbkdf2_sha256\$not_a_number\$salt\$hash'), isFalse);
    });

    test('verifies matching PIN with 1,000 iterations', () {
      const saltB64 = 'c2FsdHNhbHRzYWx0MTIz'; // 16 bytes base64
      const pin = '5678';
      final hashStr = hashPinPbkdf2(pin, saltB64, 1000);

      expect(verifyPinPbkdf2('5678', hashStr), isTrue);
      expect(verifyPinPbkdf2('0000', hashStr), isFalse);
      expect(verifyPinPbkdf2('5679', hashStr), isFalse);
    });

    test('verifies 20,000 iterations default database hash', () {
      const saltB64 = 'YWJjZGVmZ2hpamtsbW5vcA==';
      const pin = '1111';
      final hashStr = hashPinPbkdf2(pin, saltB64, 20000);

      expect(verifyPinPbkdf2('1111', hashStr), isTrue);
      expect(verifyPinPbkdf2('2222', hashStr), isFalse);
    });
  });
}
