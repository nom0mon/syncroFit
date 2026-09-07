import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchrofit/data/repositories/auth_repository.dart';
import 'package:synchrofit/data/repositories/profile_repository.dart';
import 'package:synchrofit/features/profile/providers/profile_provider.dart';
import 'package:synchrofit/features/profile/screens/profile_edit_screen.dart';
import 'package:synchrofit/features/profile/screens/profile_view_screen.dart';
import 'package:synchrofit/features/settings/providers/settings_provider.dart';
import 'package:synchrofit/features/settings/screens/change_password_screen.dart';
import 'package:synchrofit/features/settings/screens/notification_settings_screen.dart';
import 'package:synchrofit/features/settings/screens/settings_main_screen.dart';
import 'package:synchrofit/shared/models/models.dart';

import '../../support/responsive_test_harness.dart';

const _longProfile = UserProfile(
  userId: 'responsive-user',
  firstName: 'Alexandria-Cassandra-Montgomery-Wellington',
  lastName: 'Internationalized-Profile-Name-Example',
  age: 30,
  heightCm: 175,
  weightKg: 75,
  gender: Gender.other,
  fitnessGoal: FitnessGoal.improveEndurance,
  fitnessLevel: FitnessLevel.intermediate,
  workoutPreference: WorkoutPreference.outdoor,
  workoutAvailability: [
    DayOfWeek.monday,
    DayOfWeek.tuesday,
    DayOfWeek.wednesday,
    DayOfWeek.thursday,
    DayOfWeek.friday,
    DayOfWeek.saturday,
    DayOfWeek.sunday,
  ],
);

void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();
  });

  group('profile and settings release viewport matrix', () {
    for (final configuration
        in ResponsiveTestConfiguration.requiredConfigurations) {
      testWidgets('profile view fits ${configuration.name}', (tester) async {
        await tester.pumpResponsiveWidget(
          ProviderScope(
            overrides: [
              profileProvider.overrideWith(_LoadedProfileNotifier.new),
            ],
            child: const ProfileViewScreen(),
          ),
          configuration: configuration,
          settle: true,
        );

        expect(find.text(_longProfile.name), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('settings rows fit ${configuration.name}', (tester) async {
        await tester.pumpResponsiveWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(preferences),
            ],
            child: const SettingsMainScreen(),
          ),
          configuration: configuration,
          settle: true,
        );

        expect(find.text('Notification Settings'), findsOneWidget);
        expect(find.text('Change Password'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('notification rows fit ${configuration.name}',
          (tester) async {
        await tester.pumpResponsiveWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(preferences),
            ],
            child: const NotificationSettingsScreen(),
          ),
          configuration: configuration,
          settle: true,
        );

        expect(find.text('Workout Reminders'), findsOneWidget);
        expect(find.text('Achievement Alerts'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('profile edit save stays visible above a large keyboard',
      (tester) async {
    const saveKey = Key('profile-edit-save');

    await tester.pumpResponsiveWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(_LoadedProfileNotifier.new),
          profileRepositoryProvider.overrideWithValue(
            _SuccessfulProfileRepository(),
          ),
        ],
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              viewInsets: const EdgeInsets.only(bottom: 300),
            ),
            child: const ProfileEditScreen(),
          ),
        ),
      ),
      configuration: ResponsiveTestConfiguration.largeText,
      settle: true,
      mustRemainVisible: <Finder>[find.byKey(saveKey)],
    );

    expect(find.text('Save Changes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('change-password action stays visible above a large keyboard',
      (tester) async {
    const submitKey = Key('change-password-submit');

    await tester.pumpResponsiveWidget(
      ProviderScope(
        overrides: [
          settingsAuthRepositoryProvider.overrideWithValue(
            _SuccessfulAuthRepository(),
          ),
        ],
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              viewInsets: const EdgeInsets.only(bottom: 300),
            ),
            child: const ChangePasswordScreen(),
          ),
        ),
      ),
      configuration: ResponsiveTestConfiguration.largeText,
      settle: true,
      mustRemainVisible: <Finder>[find.byKey(submitKey)],
    );

    expect(find.text('Change Password'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('large-text sign-out dialog remains scrollable and visible',
      (tester) async {
    await tester.pumpResponsiveWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const SettingsMainScreen(),
      ),
      configuration: ResponsiveTestConfiguration.largeText,
      settle: true,
    );

    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();

    expect(find.text('Are you sure you want to sign out?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _LoadedProfileNotifier extends ProfileNotifier {
  @override
  Future<UserProfile?> build() async => _longProfile;
}

class _SuccessfulProfileRepository implements ProfileRepository {
  @override
  Future<Result<UserProfile, AppError>> getProfile(String userId) async =>
      const Success(_longProfile);

  @override
  Future<Result<UserProfile, AppError>> saveProfile(
    UserProfile profile,
  ) async =>
      Success(profile);

  @override
  Future<Result<UserProfile, AppError>> updateProfile(
    UserProfile profile,
  ) async =>
      Success(profile);
}

class _SuccessfulAuthRepository implements AuthRepository {
  @override
  Future<Result<User, AppError>> login(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<Result<User, AppError>> register(
    String username,
    String email,
    String password,
  ) =>
      throw UnimplementedError();

  @override
  Future<Result<void, AppError>> forgotPassword(String email) =>
      throw UnimplementedError();

  @override
  Future<Result<void, AppError>> changePassword(
    String currentPassword,
    String newPassword,
  ) async =>
      const Success<void, AppError>(null);
}
