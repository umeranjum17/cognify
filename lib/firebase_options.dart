// Placeholder Firebase options to allow compilation until you run `flutterfire configure`.
// Replace this file with the generated one from FlutterFire: lib/firebase_options.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class FirebaseOptionsPlaceholder extends InheritedWidget {
  const FirebaseOptionsPlaceholder({super.key, required super.child});

  static const bool isPlaceholder = true;

  static const options = _DefaultFirebaseOptions();

  static FirebaseOptionsPlaceholder of(BuildContext context) {
    final FirebaseOptionsPlaceholder? result =
        context.dependOnInheritedWidgetOfExactType<FirebaseOptionsPlaceholder>();
    assert(result != null, 'No FirebaseOptionsPlaceholder found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(FirebaseOptionsPlaceholder old) => false;
}

// This mirrors the interface of FlutterFire's DefaultFirebaseOptions,
// so main.dart can import and call DefaultFirebaseOptions.currentPlatform
class DefaultFirebaseOptions {
  static _DefaultFirebaseOptions get currentPlatform => const _DefaultFirebaseOptions();
}

class _DefaultFirebaseOptions {
  const _DefaultFirebaseOptions();

  // Dummy getters to keep code compiling; real values come from FlutterFire generator
  String get apiKey => '';
  String get appId => '';
  String get messagingSenderId => '';
  String get projectId => '';
  String? get databaseURL => null;
  String? get storageBucket => null;
  String? get androidClientId => null;
  String? get iosBundleId => null;
  String? get iosClientId => null;
  String? get iosAppId => null;
}