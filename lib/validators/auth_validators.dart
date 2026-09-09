/// Validation rules for the auth screens (Login, Create Account, Forgot
/// Password). Kept separate from the widgets so the rule is one obvious
/// place to check or change, per CLAUDE.md.
class AuthValidators {
  AuthValidators._();

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Whether [email] has a plausible "name@example.com" shape. This is a
  /// format check only — it doesn't confirm the address exists or is
  /// reachable.
  static bool isValidEmailFormat(String email) =>
      _emailPattern.hasMatch(email.trim());

  /// The password rule, matching the mockup's own copy exactly: at least 8
  /// characters, including at least one digit. Uppercase, lowercase and
  /// symbols are all allowed but never required — a password must not be
  /// rejected for containing them.
  static bool isValidPassword(String password) {
    return password.length >= 8 && password.contains(RegExp(r'[0-9]'));
  }

  static bool passwordsMatch(String password, String confirmPassword) {
    return password.isNotEmpty && password == confirmPassword;
  }
}

/// Weak / Medium / Strong password strength, for the strength bar shown on
/// Create Account. This is a purely cosmetic signal on top of
/// [AuthValidators.isValidPassword] — it never makes a password that meets
/// the real rule fail, and never makes one that doesn't meet it pass.
enum PasswordStrength { weak, medium, strong }

PasswordStrength passwordStrength(String password) {
  if (!AuthValidators.isValidPassword(password)) return PasswordStrength.weak;

  var varietyCount = 0;
  if (password.contains(RegExp(r'[a-z]'))) varietyCount++;
  if (password.contains(RegExp(r'[A-Z]'))) varietyCount++;
  if (password.contains(RegExp(r'[0-9]'))) varietyCount++;
  if (password.contains(RegExp(r'[^a-zA-Z0-9]'))) varietyCount++;

  final isLong = password.length >= 12;
  if (isLong && varietyCount >= 3) return PasswordStrength.strong;
  if (password.length >= 10 && varietyCount >= 3) {
    return PasswordStrength.strong;
  }
  return PasswordStrength.medium;
}
