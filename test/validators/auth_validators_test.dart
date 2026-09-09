import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/validators/auth_validators.dart';

void main() {
  group('AuthValidators.isValidPassword', () {
    test('rejects fewer than 8 characters', () {
      expect(AuthValidators.isValidPassword('abc123'), isFalse);
    });

    test('rejects 8+ characters with no digit', () {
      expect(AuthValidators.isValidPassword('abcdefgh'), isFalse);
    });

    test('accepts 8+ characters with a digit, lowercase only', () {
      expect(AuthValidators.isValidPassword('abcdefg1'), isTrue);
    });

    test('does not require uppercase, lowercase, or symbols', () {
      expect(AuthValidators.isValidPassword('12345678'), isTrue);
      expect(AuthValidators.isValidPassword('ABCDEFG1'), isTrue);
    });

    test(
      'does not reject a password just because it has uppercase/symbols',
      () {
        expect(AuthValidators.isValidPassword('Abcdef1!'), isTrue);
      },
    );
  });

  group('AuthValidators.isValidEmailFormat', () {
    test('accepts a plausible email', () {
      expect(AuthValidators.isValidEmailFormat('name@example.com'), isTrue);
    });

    test('rejects missing @ or domain', () {
      expect(AuthValidators.isValidEmailFormat('name'), isFalse);
      expect(AuthValidators.isValidEmailFormat('name@example'), isFalse);
    });
  });

  group('AuthValidators.passwordsMatch', () {
    test('rejects when either is empty', () {
      expect(AuthValidators.passwordsMatch('', ''), isFalse);
      expect(AuthValidators.passwordsMatch('abcdefg1', ''), isFalse);
    });

    test('true only when equal and non-empty', () {
      expect(AuthValidators.passwordsMatch('abcdefg1', 'abcdefg1'), isTrue);
      expect(AuthValidators.passwordsMatch('abcdefg1', 'abcdefg2'), isFalse);
    });
  });

  group('passwordStrength', () {
    test('weak when the base rule fails', () {
      expect(passwordStrength('abc'), PasswordStrength.weak);
      expect(passwordStrength('abcdefgh'), PasswordStrength.weak);
    });

    test('never reports weak once the base rule passes', () {
      expect(passwordStrength('abcdefg1'), isNot(PasswordStrength.weak));
    });

    test('strong for a long password with high character variety', () {
      expect(passwordStrength('Abcdefgh1!'), PasswordStrength.strong);
    });
  });
}
