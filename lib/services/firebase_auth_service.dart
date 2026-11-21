import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  FirebaseAuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  static String? get currentUid => _auth.currentUser?.uid;

  static Future<User> ensureGuestSignIn() async {
    final existingUser = _auth.currentUser;

    if (existingUser != null) {
      return existingUser;
    }

    final credential = await _auth.signInAnonymously();

    final user = credential.user;
    if (user == null) {
      throw StateError('Firebase guest sign-in returned no user.');
    }

    return user;
  }
}
