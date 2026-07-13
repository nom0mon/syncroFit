/// Named route path constants for all screens in the application.
///
/// Use these constants instead of hardcoding path strings throughout the app.
abstract final class RouteNames {
  // Auth routes (no bottom nav)
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // Onboarding routes (no bottom nav)
  static const String profileSetup = '/profile-setup';
  static const String assessment = '/assessment/:step';

  // Full-screen overlays
  static const String notifications = '/notifications';

  // Tab 1 — Dashboard
  static const String dashboard = '/dashboard';
  static const String workoutDetail = '/dashboard/workout/:id';
  static const String workoutActive = '/dashboard/workout/:id/active';
  static const String workoutRest = '/dashboard/workout/:id/rest';
  static const String workoutSummary = '/dashboard/workout/:id/summary';

  // Tab 2 — Exercise Library
  static const String exercises = '/exercises';
  static const String exerciseDetail = '/exercises/:id';

  // Tab 3 — Progress
  static const String progress = '/progress';
  static const String sessionDetail = '/progress/session/:id';

  // Tab 4 — Community
  static const String community = '/community';
  static const String postDetail = '/community/post/:id';

  // Tab 5 — Settings
  static const String settings = '/settings';
  static const String notificationSettings = '/settings/notifications';
  static const String changePassword = '/settings/change-password';
  static const String editProfile = '/settings/edit-profile';
  static const String trainers = '/settings/trainers';
  static const String trainerDetail = '/settings/trainers/:id';
  static const String trainerBook = '/settings/trainers/:id/book';
}
