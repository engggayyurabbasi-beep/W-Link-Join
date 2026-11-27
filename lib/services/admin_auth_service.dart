import 'package:firebase_auth/firebase_auth.dart';

class AdminAuthService {
  AdminAuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  static Future<User> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw StateError('Admin authentication failed.');
    }

    if (!user.emailVerified) {
      await _auth.signOut();
      throw StateError('Please verify your email before Admin login.');
    }

    final token = await user.getIdTokenResult(true);
    final claims = token.claims ?? const <String, dynamic>{};

    if (claims['role'] != 'super_admin' || claims['admin'] != true) {
      await _auth.signOut();
      throw StateError('Access denied. Super Admin permission required.');
    }

    return user;
  }

  static Future<void> resendVerificationEmail({
    required String email,
    required String password,
  }) async {
    UserCredential? credential;

    try {
      credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw StateError('Unable to authenticate this account.');
      }

      await user.reload();
      final refreshedUser = _auth.currentUser;

      if (refreshedUser == null) {
        throw StateError('Unable to refresh the account.');
      }

      if (refreshedUser.emailVerified) {
        throw StateError('This email address is already verified.');
      }

      await refreshedUser.sendEmailVerification();
    } finally {
      if (_auth.currentUser != null) {
        await _auth.signOut();
      }
    }
  }

  static Future<bool> isSuperAdmin() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous || !user.emailVerified) {
      return false;
    }

    final token = await user.getIdTokenResult(true);
    final claims = token.claims ?? const <String, dynamic>{};

    return claims['role'] == 'super_admin' && claims['admin'] == true;
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }
}
