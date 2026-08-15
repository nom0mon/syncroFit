import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:synchrofit/core/theme/app_theme.dart';
import 'package:synchrofit/features/community/providers/community_provider.dart';
import 'package:synchrofit/features/community/screens/feed_screen.dart';
import 'package:synchrofit/features/profile/providers/profile_provider.dart';
import 'package:synchrofit/features/profile/screens/profile_edit_screen.dart';
import 'package:synchrofit/features/progress/providers/progress_provider.dart';
import 'package:synchrofit/features/progress/screens/progress_summary_screen.dart';
import 'package:synchrofit/features/settings/screens/settings_main_screen.dart';
import 'package:synchrofit/features/settings/providers/settings_provider.dart';
import 'package:synchrofit/shared/models/models.dart';
import 'package:synchrofit/shared/widgets/edge_fade_gradient.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bug condition exploration test for light mode fade, missing overlays,
/// navigation, and profile back button issues.
///
/// **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7**
///
/// These tests encode the EXPECTED (correct) behavior. They are designed
/// to FAIL on unfixed code, proving the bugs exist. Once the code is fixed,
/// these same tests will PASS.
void main() {
  setUpAll(() {
    // Prevent google_fonts from making HTTP requests in tests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Bug Condition Exploration: Light Mode Fade and Profile Back', () {
    // ─── Bug 1: EdgeFadeGradient uses hardcoded black instead of theme color ───

    testWidgets(
      'EdgeFadeGradient in light theme renders nothing (no visible overlay)',
      (tester) async {
        // Render EdgeFadeGradient inside a light-theme MaterialApp
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: EdgeFadeGradient(isTop: true),
            ),
          ),
        );

        // In light mode, the widget should render a SizedBox.shrink() — no
        // Container with gradient decoration should exist.
        final containerFinder = find.descendant(
          of: find.byType(EdgeFadeGradient),
          matching: find.byType(Container),
        );
        expect(
          containerFinder,
          findsNothing,
          reason:
              'EdgeFadeGradient should render nothing in light mode to avoid '
              'obscuring content with a white overlay band',
        );
      },
    );

    testWidgets(
      'EdgeFadeGradient bottom in light theme renders nothing (no visible overlay)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: EdgeFadeGradient(isTop: false),
            ),
          ),
        );

        // In light mode, the widget should render a SizedBox.shrink()
        final containerFinder = find.descendant(
          of: find.byType(EdgeFadeGradient),
          matching: find.byType(Container),
        );
        expect(
          containerFinder,
          findsNothing,
          reason:
              'EdgeFadeGradient (bottom) should render nothing in light mode to avoid '
              'obscuring content with a white overlay band',
        );
      },
    );

    // ─── Bug 2: ProgressSummaryScreen missing EdgeFadeGradient overlays ────────

    testWidgets(
      'ProgressSummaryScreen contains at least 2 EdgeFadeGradient instances (top and bottom)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              progressProvider.overrideWith(() => _FakeProgressNotifier()),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const ProgressSummaryScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final gradients = find.byType(EdgeFadeGradient);
        expect(
          gradients,
          findsAtLeastNWidgets(2),
          reason:
              'ProgressSummaryScreen should have at least 2 EdgeFadeGradient overlays '
              '(top and bottom) for consistent UX with other module screens',
        );
      },
    );

    // ─── Bug 3: FeedScreen missing EdgeFadeGradient overlays ────────────────────

    testWidgets(
      'FeedScreen contains at least 2 EdgeFadeGradient instances (top and bottom)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              communityProvider.overrideWith(() => _FakeCommunityNotifier()),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const FeedScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final gradients = find.byType(EdgeFadeGradient);
        expect(
          gradients,
          findsAtLeastNWidgets(2),
          reason: 'FeedScreen should have at least 2 EdgeFadeGradient overlays '
              '(top and bottom) for consistent UX with other module screens',
        );
      },
    );

    // ─── Bug 4: Settings sub-screen navigation uses go() instead of push() ─────

    testWidgets(
      'SettingsMainScreen navigates to /settings/notifications with push (allows pop back)',
      (tester) async {
        SharedPreferences.setMockInitialValues({'theme_mode': 2});
        final prefs = await SharedPreferences.getInstance();

        // Track whether push or go was used by examining the GoRouter's
        // ability to pop after navigation
        final router = GoRouter(
          initialLocation: '/settings',
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsMainScreen(),
            ),
            GoRoute(
              path: '/settings/notifications',
              builder: (context, state) => Scaffold(
                appBar: AppBar(title: const Text('Notification Settings')),
                body: const Text('Notification Settings Page'),
              ),
            ),
            GoRoute(
              path: '/settings/edit-profile',
              builder: (context, state) => Scaffold(
                body: const Text('Edit Profile Page'),
              ),
            ),
            GoRoute(
              path: '/settings/change-password',
              builder: (context, state) => Scaffold(
                body: const Text('Change Password Page'),
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: MaterialApp.router(
              theme: AppTheme.darkTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap on "Notification Settings" in the settings screen
        await tester.tap(find.text('Notification Settings'));
        await tester.pumpAndSettle();

        // Verify we navigated to the notifications page
        expect(find.text('Notification Settings Page'), findsOneWidget);

        // The bug: context.go() replaces the stack, so canPop() is false.
        // Expected (correct) behavior: context.push() preserves the stack,
        // so canPop() should be true.
        expect(
          router.canPop(),
          isTrue,
          reason:
              'After navigating to /settings/notifications, the router should be '
              'able to pop back to /settings. Using context.go() replaces the stack, '
              'making back navigation impossible.',
        );
      },
    );

    testWidgets(
      'SettingsMainScreen navigates to /settings/change-password with push (allows pop back)',
      (tester) async {
        SharedPreferences.setMockInitialValues({'theme_mode': 2});
        final prefs = await SharedPreferences.getInstance();

        final router = GoRouter(
          initialLocation: '/settings',
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsMainScreen(),
            ),
            GoRoute(
              path: '/settings/notifications',
              builder: (context, state) => Scaffold(
                body: const Text('Notification Settings Page'),
              ),
            ),
            GoRoute(
              path: '/settings/edit-profile',
              builder: (context, state) => Scaffold(
                body: const Text('Edit Profile Page'),
              ),
            ),
            GoRoute(
              path: '/settings/change-password',
              builder: (context, state) => Scaffold(
                appBar: AppBar(title: const Text('Change Password')),
                body: const Text('Change Password Page'),
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: MaterialApp.router(
              theme: AppTheme.darkTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap on "Change Password" in the settings screen
        await tester.tap(find.text('Change Password'));
        await tester.pumpAndSettle();

        // Verify we navigated to the change password page
        expect(find.text('Change Password Page'), findsOneWidget);

        // The bug: context.go() replaces the stack, so canPop() is false.
        // Expected behavior: context.push() preserves the stack.
        expect(
          router.canPop(),
          isTrue,
          reason:
              'After navigating to /settings/change-password, the router should be '
              'able to pop back to /settings. Using context.go() replaces the stack, '
              'making back navigation impossible.',
        );
      },
    );

    // ─── Bug 5: ProfileEditScreen missing explicit back button ─────────────────

    testWidgets(
      'ProfileEditScreen AppBar contains a leading IconButton with Icons.arrow_back',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileProvider.overrideWith(() => _FakeProfileNotifier()),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const ProfileEditScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the AppBar and check for a leading IconButton with back arrow
        final appBarFinder = find.byType(AppBar);
        expect(appBarFinder, findsOneWidget);

        // Look for an IconButton with Icons.arrow_back in the widget tree
        final backButtonFinder = find.descendant(
          of: appBarFinder,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is IconButton &&
                widget.icon is Icon &&
                (widget.icon as Icon).icon == Icons.arrow_back,
          ),
        );

        expect(
          backButtonFinder,
          findsOneWidget,
          reason:
              'ProfileEditScreen AppBar should contain a leading IconButton '
              'with Icons.arrow_back for explicit back navigation',
        );
      },
    );
  });
}

// ─── Fake notifiers for provider overrides ─────────────────────────────────────

/// Fake progress notifier that returns an empty but valid ProgressState.
class _FakeProgressNotifier extends ProgressNotifier {
  @override
  Future<ProgressState> build() async => const ProgressState(
        totalWorkouts: 5,
        currentStreak: 2,
        longestStreak: 7,
        currentWeightKg: 75.0,
        weightHistory: [],
        bmiHistory: [],
        weeklyStats: [],
        recentSessions: [],
      );
}

/// Fake community notifier that returns a state with a few posts.
class _FakeCommunityNotifier extends CommunityNotifier {
  @override
  Future<CommunityState> build() async => CommunityState(
        posts: [
          Post(
            id: 'post-1',
            authorName: 'Test User',
            content: 'Hello community!',
            timestamp: DateTime.now(),
            likeCount: 3,
            isLikedByCurrentUser: false,
            comments: [],
          ),
          Post(
            id: 'post-2',
            authorName: 'Another User',
            content: 'Great workout today!',
            timestamp: DateTime.now(),
            likeCount: 5,
            isLikedByCurrentUser: true,
            comments: [],
          ),
        ],
      );
}

/// Fake profile notifier that returns a valid UserProfile.
class _FakeProfileNotifier extends ProfileNotifier {
  @override
  Future<UserProfile?> build() async => const UserProfile(
        userId: 'user-001',
        firstName: 'Test',
        lastName: 'User',
        age: 30,
        heightCm: 175.0,
        weightKg: 75.0,
        gender: Gender.male,
        fitnessGoal: FitnessGoal.buildMuscle,
        fitnessLevel: FitnessLevel.intermediate,
        workoutPreference: WorkoutPreference.gym,
        workoutAvailability: [
          DayOfWeek.monday,
          DayOfWeek.wednesday,
          DayOfWeek.friday
        ],
      );
}
