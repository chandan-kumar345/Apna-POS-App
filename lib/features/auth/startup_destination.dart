import 'package:flutter/widgets.dart';

import '../../core/models/user_model.dart';
import '../dashboard/main_layout.dart';
import '../onboarding/add_business_address_screen.dart';
import '../onboarding/business_settings_screen.dart';
import '../onboarding/restaurant_onboarding_screen.dart';
import 'create_profile_screen.dart';
import 'get_started_screen.dart';
import 'login_screen.dart';

/// Resolve the locally restored session after startup, without a network gate.
/// Keep incomplete owners on their saved setup step, as at interactive login.
({Widget screen, String routeName}) resolveStartupDestination({
  required UserModel? user,
  bool businessOnboarded = false,
  bool openLoginWhenSignedOut = false,
}) {
  if (user == null || user.id.trim().isEmpty) {
    if (openLoginWhenSignedOut) {
      return (screen: const LoginScreen(), routeName: '/login');
    }
    return (screen: const GetStartedScreen(), routeName: '/get-started');
  }
  if (!user.isOwner || user.onboardingCompleted || businessOnboarded) {
    return (screen: const MainLayout(), routeName: '/dashboard');
  }
  return switch (user.onboardingStep) {
    1 => (
      screen: const RestaurantOnboardingScreen(),
      routeName: '/onboarding/business',
    ),
    2 => (
      screen: const AddBusinessAddressScreen(),
      routeName: '/onboarding/address',
    ),
    3 || 4 => (
      screen: const BusinessSettingsScreen(),
      routeName: '/onboarding/settings',
    ),
    _ => (
      screen: const CreateProfileScreen(),
      routeName: '/onboarding/profile',
    ),
  };
}
