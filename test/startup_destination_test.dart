import 'package:apna_pos/core/models/user_model.dart';
import 'package:apna_pos/features/auth/create_profile_screen.dart';
import 'package:apna_pos/features/auth/get_started_screen.dart';
import 'package:apna_pos/features/auth/startup_destination.dart';
import 'package:apna_pos/features/dashboard/main_layout.dart';
import 'package:apna_pos/features/onboarding/add_business_address_screen.dart';
import 'package:apna_pos/features/onboarding/business_settings_screen.dart';
import 'package:apna_pos/features/onboarding/restaurant_onboarding_screen.dart';
import 'package:flutter_test/flutter_test.dart';

UserModel _user({
  String id = 'saved-user',
  String role = 'Owner',
  bool completed = false,
  int step = 0,
}) => UserModel(
  id: id,
  name: 'Saved User',
  email: 'saved@example.test',
  role: role,
  pin: '',
  restaurantId: 'saved-business',
  onboardingCompleted: completed,
  onboardingStep: step,
);

void main() {
  test('signed-out and invalid cached users get the welcome screen', () {
    for (final user in [null, _user(id: '')]) {
      final destination = resolveStartupDestination(user: user);
      expect(destination.screen, isA<GetStartedScreen>());
      expect(destination.routeName, '/get-started');
    }
  });

  test('a completed user restored from the stored snapshot opens POS', () {
    final restored = UserModel.fromJson(_user(completed: true).toJson());
    final destination = resolveStartupDestination(user: restored);
    expect(destination.screen, isA<MainLayout>());
    expect(destination.routeName, '/dashboard');
  });

  test('a completed cached business also resumes the owner session', () {
    final destination = resolveStartupDestination(
      user: _user(),
      businessOnboarded: true,
    );
    expect(destination.screen, isA<MainLayout>());
    expect(destination.routeName, '/dashboard');
  });

  test('staff resumes without owner onboarding', () {
    final destination = resolveStartupDestination(user: _user(role: 'Cashier'));
    expect(destination.screen, isA<MainLayout>());
    expect(destination.routeName, '/dashboard');
  });

  final setupScreens = <int, Type>{
    0: CreateProfileScreen,
    1: RestaurantOnboardingScreen,
    2: AddBusinessAddressScreen,
    3: BusinessSettingsScreen,
    4: BusinessSettingsScreen,
  };
  for (final step in setupScreens.entries) {
    test('an unfinished owner resumes saved setup step ${step.key}', () {
      final destination = resolveStartupDestination(
        user: _user(step: step.key),
      );
      expect(destination.screen.runtimeType, step.value);
      expect(destination.routeName, startsWith('/onboarding/'));
    });
  }
}
