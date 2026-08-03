// Generated from the Firebase console registration for project
// `livy-fed-on-time` (iOS app com.hizwayz.livyfedontime).
//
// If you add more platforms (Android, macOS), re-run `flutterfire configure`
// — it will regenerate this file with every platform's options.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Firebase is only configured for iOS so far — run `flutterfire configure` '
          'to add this platform. The app will run in demo mode.',
        );
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCGwsEKzQvWYQCm2Or1qr_kee28Rf2n_TY',
    appId: '1:167423727024:ios:39b4fd0cf6c250fe0b3275',
    messagingSenderId: '167423727024',
    projectId: 'livy-fed-on-time',
    storageBucket: 'livy-fed-on-time.firebasestorage.app',
    iosBundleId: 'com.hizwayz.livyfedontime',
  );
}
