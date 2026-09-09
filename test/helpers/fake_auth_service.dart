import 'package:tadarab_app/services/auth_service.dart';

/// A controllable stand-in for [AuthService] used across the auth screen
/// widget tests, so they never depend on a real Firebase app. Configure the
/// `*Error` fields to simulate a failure, or [delay] to simulate an
/// in-flight request so loading states can be asserted before it resolves.
class FakeAuthService extends AuthService {
  FakeAuthService({
    this.signInError,
    this.createAccountError,
    this.sendPasswordResetError,
    this.delay = Duration.zero,
  });

  final AuthFailure? signInError;
  final AuthFailure? createAccountError;
  final AuthFailure? sendPasswordResetError;
  final Duration delay;

  int signInCalls = 0;
  int createAccountCalls = 0;
  int sendPasswordResetCalls = 0;
  String? lastSignInEmail;
  String? lastResetEmail;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    lastSignInEmail = email;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (signInError != null) throw signInError!;
  }

  @override
  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    createAccountCalls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (createAccountError != null) throw createAccountError!;
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    sendPasswordResetCalls++;
    lastResetEmail = email;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (sendPasswordResetError != null) throw sendPasswordResetError!;
  }
}
