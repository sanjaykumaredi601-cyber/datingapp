// File generated for Aura Firebase configuration across Android, iOS, Web, and Desktop.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC4XQqxCaydjj3zk9LfEmadeB9ldAdAREw',
    appId: '1:880696511232:web:bd3bf4fb67b14dbf5641e5',
    messagingSenderId: '880696511232',
    projectId: 'aura-b033d',
    authDomain: 'aura-b033d.firebaseapp.com',
    storageBucket: 'aura-b033d.firebasestorage.app',
    measurementId: 'G-WLXBVCD2BW',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCuMt-wyZb0PlbReSIaaMGmWYuKoL4ejhY',
    appId: '1:880696511232:android:61f272ee99787b895641e5',
    messagingSenderId: '880696511232',
    projectId: 'aura-b033d',
    storageBucket: 'aura-b033d.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCuMt-wyZb0PlbReSIaaMGmWYuKoL4ejhY',
    appId: '1:880696511232:ios:d4b1a8f9c2e0b5a1',
    messagingSenderId: '880696511232',
    projectId: 'aura-b033d',
    storageBucket: 'aura-b033d.firebasestorage.app',
    iosBundleId: 'com.aura.dating.auraApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyC4XQqxCaydjj3zk9LfEmadeB9ldAdAREw',
    appId: '1:880696511232:web:bd3bf4fb67b14dbf5641e5',
    messagingSenderId: '880696511232',
    projectId: 'aura-b033d',
    authDomain: 'aura-b033d.firebaseapp.com',
    storageBucket: 'aura-b033d.firebasestorage.app',
  );
}
