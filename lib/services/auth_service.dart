import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/student.dart';

/// A user-facing auth failure. [message] is always safe to show directly —
/// callers don't need their own switch over Firebase error codes.
class AuthFailure implements Exception {
  AuthFailure(this.message, {this.isEmailTaken = false});

  final String message;

  /// Set when account creation failed because the email is already
  /// registered — lets the Create Account screen show the special
  /// "log in instead / reset password" banner instead of a generic error.
  final bool isEmailTaken;

  @override
  String toString() => message;
}

const _networkFailureMessage =
    "Couldn't reach Tadarab. Check your connection and try again.";
const _genericFailureMessage = 'Something went wrong. Please try again.';

/// The message [AuthService.signIn] throws for any credential-related
/// failure. Exposed so LoginScreen can render the design's specific "wrong
/// credentials" banner for this case and a generic one for anything else
/// (e.g. a network failure), rather than always showing this text.
const kWrongCredentialsMessage = 'Email or password is incorrect';

/// Wraps FirebaseAuth calls with error handling the auth screens can render
/// directly, per the NFR that every network/API call surfaces a clear,
/// actionable message rather than a raw exception or a silent failure.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _authOverride = auth,
      _firestoreOverride = firestore;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;

  // Resolved lazily (not in the constructor) so building an auth screen
  // never depends on Firebase already being initialized — only actually
  // calling sign-in/create-account/etc. does.
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signOut() => _auth.signOut();

  /// Signs in with email/password. On any credential-related failure this
  /// throws the same generic message regardless of which part was wrong,
  /// so the error can't be used to enumerate valid accounts.
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        throw AuthFailure(_networkFailureMessage);
      }
      if (const [
        'user-not-found',
        'wrong-password',
        'invalid-credential',
        'invalid-email',
      ].contains(e.code)) {
        throw AuthFailure(kWrongCredentialsMessage);
      }
      throw AuthFailure(_genericFailureMessage);
    }
  }

  /// Creates an account, sets the display name, and writes the matching
  /// Student profile document (users/{uid}) — the account isn't usable by
  /// the rest of the app until that document exists.
  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        throw AuthFailure(_networkFailureMessage);
      }
      if (e.code == 'email-already-in-use') {
        throw AuthFailure(
          '${email.trim()} is already registered.',
          isEmailTaken: true,
        );
      }
      if (e.code == 'weak-password' || e.code == 'invalid-email') {
        throw AuthFailure(
          'That email or password isn\'t valid. Please check and try again.',
        );
      }
      throw AuthFailure(_genericFailureMessage);
    }

    final user = credential.user;
    if (user == null) throw AuthFailure(_genericFailureMessage);

    await user.updateDisplayName(name.trim());

    final student = Student(
      uid: user.uid,
      email: email.trim(),
      name: name.trim(),
    );
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(student.toFirestore());
    } on FirebaseException {
      throw AuthFailure(_networkFailureMessage);
    }
  }

  /// Sends a password reset email. Deliberately treats "no account with
  /// this email" as success — surfacing it would let anyone probe which
  /// emails are registered, which is exactly what the Forgot Password
  /// design's "same confirmation either way" message is meant to prevent.
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return;
      if (e.code == 'network-request-failed') {
        throw AuthFailure(_networkFailureMessage);
      }
      if (e.code == 'invalid-email') {
        throw AuthFailure('Enter a valid email, like name@example.com');
      }
      throw AuthFailure(_genericFailureMessage);
    }
  }
}
