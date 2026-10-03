import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand.dart';
import '../../core/config.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import 'auth_routing.dart';

/// Branded splash that auto-logs-in returning users: it checks Firebase Auth,
/// loads their Firestore profile, restores the session, and routes them to the
/// right place — so a signed-in user never re-onboards.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final start = DateTime.now();
    String destination;
    try {
      destination = await _resolveDestination();
    } catch (_) {
      destination = AppRouter.verification;
    }

    // Keep the splash visible long enough for the logo animation to read.
    final elapsed = DateTime.now().difference(start);
    final remaining = const Duration(milliseconds: 900) - elapsed;
    if (remaining > Duration.zero) await Future.delayed(remaining);

    if (mounted) context.go(destination);
  }

  Future<String> _resolveDestination() async {
    if (!AppConfig.useBackend) return AppRouter.verification;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return AppRouter.verification;

    // Force-update gate: builds older than minVersion predate money-critical
    // contracts and must not run. Best effort — read failures skip the gate.
    try {
      final cfg = await FirebaseFirestore.instance
          .collection('config')
          .doc('pricing')
          .get();
      final min = cfg.data()?['minVersion'] as String?;
      if (min != null && _versionBelow(AppConfig.appVersion, min)) {
        return AppRouter.updateRequired;
      }
    } catch (_) {}

    // Signed in — load profile and route to the right place.
    return resolvePostAuthDestination(ref, user.uid);
  }

  static bool _versionBelow(String version, String min) {
    List<int> parse(String s) =>
        s.split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();
    final a = parse(version);
    final b = parse(min);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x < y;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.green,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutBack,
          builder: (context, t, child) {
            return Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Image.asset('assets/brand/logo.png'),
              ),
              const SizedBox(height: 20),
              Text(
                Brand.current.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
