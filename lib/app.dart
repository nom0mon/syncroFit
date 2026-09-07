import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/workout_reminder_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/workout/providers/workout_scheduler_provider.dart';

/// The root application widget.
///
/// Uses [MaterialApp.router] with GoRouter for declarative routing,
/// applies the theme system with dynamic light/dark switching via
/// [themeProvider], and is wrapped in a [ProviderScope] at the call site.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeProvider);
    final authState = ref.watch(authStateProvider);

    if (authState.isAuthenticated) {
      WorkoutReminderService.instance.setWorkoutNavigationHandler(
        (workoutId) => router.go('/dashboard/workout/$workoutId'),
      );
    }
    ref.listen(scheduledWorkoutsProvider, (_, next) {
      if (authState.isAuthenticated) {
        unawaited(WorkoutReminderService.instance.scheduleWeeklyPlan(next));
      }
    });
    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (!next.isAuthenticated) {
        unawaited(WorkoutReminderService.instance.cancelWeeklyPlan());
      } else if (previous?.isAuthenticated != true) {
        unawaited(
          WorkoutReminderService.instance.scheduleWeeklyPlan(
            ref.read(scheduledWorkoutsProvider),
          ),
        );
      }
    });

    return MaterialApp.router(
      title: 'SyncroFit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
