import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_router.dart';
import '../../data/models/session.dart';
import '../../data/repositories/application_repository.dart';
import '../../data/repositories/user_repository.dart';
import 'session_controller.dart';

/// Given a freshly-authenticated [uid], load the user's profile and decide
/// where they belong — restoring the session along the way. Used by both the
/// splash (cold start) and the OTP screen (active sign-in) so returning users
/// never re-onboard.
Future<String> resolvePostAuthDestination(WidgetRef ref, String uid) async {
  final snap = await ref.read(userRepositoryProvider).fetch(uid);

  // Authenticated but no profile yet → finish onboarding.
  if (snap == null || snap.role == null) {
    ref.read(sessionProvider.notifier).setUid(uid);
    return AppRouter.roleSelect;
  }

  ref.read(sessionProvider.notifier).hydrate(
        uid: uid,
        phone: snap.phone,
        role: snap.role,
        name: snap.name,
        email: snap.email,
        status: snap.status,
        providerType: snap.providerType,
      );

  if (snap.role == UserRole.rider) return AppRouter.home;

  // Provider (driver or security) — route by their application status. An
  // unstarted security provider goes to PSIRA onboarding; a driver to docs.
  final appStatus =
      await ref.read(applicationRepositoryProvider).fetchStatus(uid);
  final onboardingStart = snap.providerType == 'security'
      ? AppRouter.securityOnboarding
      : AppRouter.driverDocuments;
  return switch (appStatus) {
    ApprovalStatus.approved => AppRouter.driverHome,
    ApprovalStatus.pending => AppRouter.pending,
    ApprovalStatus.rejected => AppRouter.rejected,
    ApprovalStatus.none => onboardingStart,
  };
}
