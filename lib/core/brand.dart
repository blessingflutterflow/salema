import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Salema brand configuration — name, Android package, Play Store id, and the
/// Firebase project the app talks to. Centralised so a rename is a one-file
/// change rather than a hunt through the UI.
class Brand {
  const Brand({
    required this.name,
    required this.tierPrefix,
    required this.androidPackage,
    required this.firebaseOptions,
  });

  /// Display name shown throughout the UI.
  final String name;

  /// Ride-tier name prefix ("Salema Go" / "Salema XL").
  final String tierPrefix;

  /// Android applicationId — also the Play Store id for store links.
  final String androidPackage;

  final FirebaseOptions firebaseOptions;

  /// The active brand.
  static const Brand current = Brand(
    name: 'Salema',
    tierPrefix: 'Salema',
    androidPackage: 'za.co.salema.app',
    firebaseOptions: FirebaseOptions(
      apiKey: 'AIzaSyCd0xK54zN66vcMxLKPsGAWg8WpFuvkXrk',
      appId: '1:999264263184:android:f643a85754d9189e103e95',
      messagingSenderId: '999264263184',
      projectId: 'mansalema-fce68',
      storageBucket: 'mansalema-fce68.firebasestorage.app',
    ),
  );
}
