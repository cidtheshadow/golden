import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError('Admin app is web only');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDPv73xM2mVrMKP91i17yxej6d24tSUbXc',
    appId: '1:143097198020:web:1bfefba8807c95495b2091',
    messagingSenderId: '143097198020',
    projectId: 'golden-care-d4863',
    authDomain: 'golden-care-d4863.firebaseapp.com',
    storageBucket: 'golden-care-d4863.firebasestorage.app',
    measurementId: 'G-1E46FR6MEM',
  );
}
