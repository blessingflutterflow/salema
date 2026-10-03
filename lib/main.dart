import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/brand.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    // Per-brand Firebase project, selected by the build-time BRAND define.
    options: Brand.current.firebaseOptions,
  );

  // Crash reporting — release builds only; debug crashes stay in the console.
  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // App Check guards the callable functions against abuse. Debug builds use
  // the debug provider (prints a token to register once); release uses Play
  // Integrity on Android.
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? AndroidDebugProvider()
        : AndroidPlayIntegrityProvider(),
  );

  // In debug, force the App Check debug token to print at startup so it can be
  // registered once in the Firebase console (no need to trigger a call first).
  if (kDebugMode) {
    unawaited(
      FirebaseAppCheck.instance.getToken().then((_) {}, onError: (_) {}),
    );
  }

  runApp(const ProviderScope(child: SiftApp()));
}

class SiftApp extends StatelessWidget {
  const SiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: Brand.current.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: AppRouter.router,
    );
  }
}
