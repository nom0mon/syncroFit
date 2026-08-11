import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/assessment/screens/bmi_step_screen.dart';
import '../../features/assessment/screens/goals_step_screen.dart';
import '../../features/assessment/screens/physical_info_step_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/community/screens/feed_screen.dart';
import '../../features/consultation/screens/booking_form_screen.dart';
import '../../features/consultation/screens/trainer_list_screen.dart';
import '../../features/consultation/screens/trainer_profile_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/profile/screens/profile_edit_screen.dart';
import '../../features/profile/screens/profile_setup_screen.dart';
import '../../features/profile/screens/profile_view_screen.dart';

import '../../features/settings/screens/change_password_screen.dart';
import '../../features/settings/screens/notification_settings_screen.dart';
import '../../features/settings/screens/settings_main_screen.dart';
import '../../features/community/screens/post_detail_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/exercise_library/screens/exercise_detail_screen.dart';
import '../../features/exercise_library/screens/exercise_and_recommendations_screen.dart';
import '../../features/progress/screens/progress_summary_screen.dart';
import '../../features/progress/screens/session_detail_screen.dart';
import '../../features/workout/screens/rest_timer_screen.dart';
import '../../features/workout/screens/workout_active_screen.dart';
import '../../features/workout/screens/workout_detail_screen.dart';
import '../../features/workout/screens/workout_summary_screen.dart';
import '../../shared/widgets/floating_pill_nav_bar.dart';
import '../../shared/widgets/offline_indicator.dart';
import '../../shared/widgets/page_not_found_screen.dart';
import '../../shared/widgets/sync_pending_badge.dart';
import 'guards.dart';
import 'route_names.dart';

/// Global navigator keys for the shell and each tab branch.
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _dashboardNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'dashboard');
final _exercisesNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'exercises');
final _progressNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'progress');
final _communityNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'community');

/// Provides the configured [GoRouter] instance.
///
/// Watches [authStateProvider] to reactively redirect based on auth changes.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation:
        authState.isAuthenticated ? RouteNames.dashboard : RouteNames.login,
    redirect: (context, state) => guardRedirect(authState, state),
    routes: [
      // ─── Auth routes (no bottom nav) ───────────────────────────────────
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // ─── Onboarding routes (no bottom nav) ─────────────────────────────
      GoRoute(
        path: RouteNames.profileSetup,
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: RouteNames.assessment,
        builder: (context, state) {
          final step = state.pathParameters['step'] ?? '1';
          return switch (step) {
            '2' => const PhysicalInfoStepScreen(),
            '3' => const GoalsStepScreen(),
            _ => const BmiStepScreen(),
          };
        },
      ),

      // ─── Full-screen overlays ──────────────────────────────────────────
      GoRoute(
        path: RouteNames.notifications,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: RouteNames.settings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsMainScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/change-password',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/settings/edit-profile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: '/settings/profile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProfileViewScreen(),
      ),
      GoRoute(
        path: '/settings/trainers',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TrainerListScreen(),
      ),
      GoRoute(
        path: '/settings/trainers/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return TrainerProfileScreen(trainerId: id);
        },
      ),
      GoRoute(
        path: '/settings/trainers/:id/book',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return BookingFormScreen(trainerId: id);
        },
      ),

      // ─── Main tabbed shell ─────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _MainShellScreen(navigationShell: navigationShell);
        },
        branches: [
          // Tab 1 — Dashboard
          StatefulShellBranch(
            navigatorKey: _dashboardNavigatorKey,
            routes: [
              GoRoute(
                path: RouteNames.dashboard,
                builder: (context, state) => const DashboardScreen(),
                routes: [
                  GoRoute(
                    path: 'workout/:id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return WorkoutDetailScreen(workoutId: id);
                    },
                    routes: [
                      GoRoute(
                        path: 'active',
                        builder: (context, state) {
                          final id = state.pathParameters['id'] ?? '';
                          return WorkoutActiveScreen(workoutId: id);
                        },
                      ),
                      GoRoute(
                        path: 'rest',
                        builder: (context, state) {
                          final id = state.pathParameters['id'] ?? '';
                          return RestTimerScreen(workoutId: id);
                        },
                      ),
                      GoRoute(
                        path: 'summary',
                        builder: (context, state) {
                          final id = state.pathParameters['id'] ?? '';
                          return WorkoutSummaryScreen(workoutId: id);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Tab 2 — Exercise Library
          StatefulShellBranch(
            navigatorKey: _exercisesNavigatorKey,
            routes: [
              GoRoute(
                path: RouteNames.exercises,
                builder: (context, state) =>
                    const ExerciseAndRecommendationsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return ExerciseDetailScreen(exerciseId: id);
                    },
                  ),
                ],
              ),
            ],
          ),

          // Tab 3 — Progress
          StatefulShellBranch(
            navigatorKey: _progressNavigatorKey,
            routes: [
              GoRoute(
                path: RouteNames.progress,
                builder: (context, state) => const ProgressSummaryScreen(),
                routes: [
                  GoRoute(
                    path: 'session/:id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return SessionDetailScreen(sessionId: id);
                    },
                  ),
                ],
              ),
            ],
          ),

          // Tab 4 — Community
          StatefulShellBranch(
            navigatorKey: _communityNavigatorKey,
            routes: [
              GoRoute(
                path: RouteNames.community,
                builder: (context, state) => const FeedScreen(),
                routes: [
                  GoRoute(
                    path: 'post/:id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return PostDetailScreen(postId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => PageNotFoundScreen(
      onGoToDashboard: () => GoRouter.of(context).go(RouteNames.dashboard),
    ),
  );
});

// ─── Shell scaffold with bottom navigation ─────────────────────────────────

/// The main shell screen that wraps tabbed content with a [FloatingPillNavBar].
///
/// Integrates offline-aware UI indicators:
/// - [OfflineIndicator] banner at the top when the device is offline.
/// - [SyncPendingBadge] in the app bar showing pending sync count.
/// - [SyncStatusListener] for toast/snackbar notifications on sync events.
class _MainShellScreen extends ConsumerWidget {
  const _MainShellScreen({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SyncStatusListener(
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(
          title: const Text('SyncroFit'),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: SyncPendingBadge(),
            ),
          ],
        ),
        body: Column(
          children: [
            const OfflineIndicator(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 72),
                child: navigationShell,
              ),
            ),
          ],
        ),
        bottomNavigationBar: FloatingPillNavBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) {
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
        ),
      ),
    );
  }
}

// End of file
