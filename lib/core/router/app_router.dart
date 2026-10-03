import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/otp_screen.dart';
import '../../features/auth/profile_setup_screen.dart';
import '../../features/auth/role_select_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/driver/driver_home_screen.dart';
import '../../features/driver/driver_trip_screen.dart';
import '../../features/driver/earnings_screen.dart';
import '../../features/driver/payout_details_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/onboarding/driver/driver_documents_screen.dart';
import '../../features/onboarding/driver/vehicle_details_screen.dart';
import '../../features/onboarding/status/pending_screen.dart';
import '../../features/onboarding/status/rejected_screen.dart';
import '../../data/models/ride.dart';
import '../../features/auth/edit_profile_screen.dart';
import '../../features/auth/update_required_screen.dart';
import '../../features/escort/escort_setup_screen.dart';
import '../../features/escort/escort_tier_screen.dart';
import '../../features/onboarding/security/security_onboarding_screen.dart';
import '../../features/history/receipt_screen.dart';
import '../../features/history/trip_history_screen.dart';
import '../../features/onboarding/verification_screen.dart';
import '../../features/payments/payment_methods_screen.dart';
import '../../features/places/saved_places_screen.dart';
import '../../features/ride_request/destination_screen.dart';
import '../../features/ride_request/matching_screen.dart';
import '../../features/ride_request/ride_options_screen.dart';
import '../../features/ride_request/searching_screen.dart';

/// App routes.
///
/// Flow: Splash → Verification(phone) → OTP → Role select → Profile
///   rider  → Home  (auto-approved)
///   driver → Documents → Vehicle → Pending → (admin) → Driver home / Rejected
class AppRouter {
  AppRouter._();

  static const String splash = '/';
  static const String verification = '/verification';
  static const String otp = '/otp';
  static const String roleSelect = '/role';
  static const String profile = '/profile';
  static const String home = '/home';

  // Rider ride-request flow
  static const String destination = '/destination';
  static const String searching = '/searching';
  static const String rideOptions = '/ride-options';
  static const String matching = '/matching';

  // Escort (security ride-along)
  static const String escortSetup = '/escort';
  static const String escortTiers = '/escort/tiers';
  static const String securityOnboarding = '/security/onboarding';

  // Payments
  static const String payments = '/payments';

  // Account
  static const String updateRequired = '/update';
  static const String trips = '/trips';
  static const String receipt = '/trips/receipt';
  static const String savedPlaces = '/places';
  static const String editProfile = '/profile/edit';

  // Driver onboarding
  static const String driverDocuments = '/driver/documents';
  static const String vehicleDetails = '/driver/vehicle';
  static const String pending = '/driver/pending';
  static const String rejected = '/driver/rejected';
  static const String driverHome = '/driver/home';
  static const String driverTrip = '/driver/trip';
  static const String driverEarnings = '/driver/earnings';
  static const String payoutDetails = '/driver/payout';

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    routes: [
      _route(splash, const SplashScreen()),
      _route(verification, const VerificationScreen()),
      _route(otp, const OtpScreen()),
      _route(roleSelect, const RoleSelectScreen()),
      _route(profile, const ProfileSetupScreen()),
      _route(home, const HomeScreen()),
      _route(destination, const DestinationScreen()),
      _route(escortSetup, const EscortSetupScreen()),
      GoRoute(
        path: escortTiers,
        builder: (context, state) =>
            EscortTierScreen(args: state.extra as Map<String, dynamic>?),
      ),
      _route(securityOnboarding, const SecurityOnboardingScreen()),
      GoRoute(
        path: searching,
        builder: (context, state) =>
            SearchingScreen(args: state.extra as Map<String, dynamic>?),
      ),
      _route(rideOptions, const RideOptionsScreen()),
      _route(payments, const PaymentMethodsScreen()),
      _route(updateRequired, const UpdateRequiredScreen()),
      _route(trips, const TripHistoryScreen()),
      GoRoute(
        path: receipt,
        builder: (context, state) =>
            ReceiptScreen(ride: state.extra as Ride),
      ),
      _route(savedPlaces, const SavedPlacesScreen()),
      _route(editProfile, const EditProfileScreen()),
      GoRoute(
        path: matching,
        builder: (context, state) =>
            MatchingScreen(rideId: state.extra as String?),
      ),
      _route(driverDocuments, const DriverDocumentsScreen()),
      _route(vehicleDetails, const VehicleDetailsScreen()),
      _route(pending, const PendingScreen()),
      _route(rejected, const RejectedScreen()),
      _route(driverHome, const DriverHomeScreen()),
      _route(driverEarnings, const EarningsScreen()),
      _route(payoutDetails, const PayoutDetailsScreen()),
      GoRoute(
        path: driverTrip,
        builder: (context, state) =>
            DriverTripScreen(rideId: state.extra as String),
      ),
    ],
  );

  /// A route with a soft fade + slight rise transition.
  static GoRoute _route(String path, Widget child) {
    return GoRoute(
      path: path,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: child,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved =
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
