import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'app_environment.dart';

/// Firebase project config per environment, selected at RUNTIME (from the
/// test/prod choice on the login screen) so the FCM token is minted under the
/// same project the matching backend pushes through.
///
/// Android values come from the two google-services.json files supplied by the
/// backend dev (crmapi-test / crmapi-prod). iOS is not wired for multi-env yet
/// — it falls back to the bundled GoogleService-Info.plist via a bare
/// initializeApp(); revisit when the iOS Firebase apps exist.
class FirebaseEnvOptions {
  const FirebaseEnvOptions._();

  static const FirebaseOptions testAndroid = FirebaseOptions(
    apiKey: 'AIzaSyAycLDJu_0ja9svZZ0qXqs1aDvEWDY6k3g',
    appId: '1:459900154131:android:61ce25a73c3a06a33baae6',
    messagingSenderId: '459900154131',
    projectId: 'crmapi-test',
    storageBucket: 'crmapi-test.firebasestorage.app',
  );

  static const FirebaseOptions prodAndroid = FirebaseOptions(
    apiKey: 'AIzaSyDpRsVeRTdDdHiQO-2qXgHFcFlFhaJmwJQ',
    appId: '1:161426921420:android:b2c2c5e427819df72baf69',
    messagingSenderId: '161426921420',
    projectId: 'crmapi-prod',
    storageBucket: 'crmapi-prod.firebasestorage.app',
  );

  static FirebaseOptions androidFor(AppEnvironment env) {
    switch (env) {
      case AppEnvironment.test:
        return testAndroid;
      case AppEnvironment.prod:
        return prodAndroid;
    }
  }
}

/// Ensures the default Firebase app is initialized for [env]. On Android this
/// uses explicit per-environment options and, if a DIFFERENT project is
/// already initialized (the user switched test↔prod at login), tears the old
/// default app down and re-initializes with the new project so the next FCM
/// token belongs to the right one. On iOS/others it just ensures a single
/// default app from the bundled config.
///
/// No-ops (returns quietly) when the correct project is already active.
Future<void> initFirebaseForEnvironment(AppEnvironment env) async {
  if (Platform.isAndroid) {
    final desired = FirebaseEnvOptions.androidFor(env);
    if (Firebase.apps.isNotEmpty) {
      final current = Firebase.app();
      if (current.options.projectId == desired.projectId) return;
      // Switching projects mid-session: drop the old default app first.
      await current.delete();
    }
    await Firebase.initializeApp(options: desired);
    if (kDebugMode) debugPrint('[Firebase] initialized ${desired.projectId}');
  } else {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  }
}
