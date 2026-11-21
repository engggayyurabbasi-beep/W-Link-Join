import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web is not configured.');
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    throw UnsupportedError('This platform is not configured.');
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyAjn4G1nr66M_DWfA5upxf3CyvtUjyVVl0",
    appId: "1:136898054022:android:18dd38b91bc1e23f380e07",
    messagingSenderId: "136898054022",
    projectId: "w-link-join",
    storageBucket: "w-link-join.firebasestorage.app",
  );
}
