import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import 'route_names.dart';

/// Auth routes that unauthenticated users are allowed to access.
///
/// Authenticated users visiting these are redirected to the dashboard.
const _authRoutes = <String>[
  RouteNames.login,
  RouteNames.register,
  RouteNames.forgotPassword,
];

/// Public routes accessible regardless of authentication state.
///
/// These neither force an unauthenticated user to sign in nor redirect an
/// authenticated user away. The privacy policy must be readable both before a
/// member consents at sign-up and from Settings after signing in.
const _publicRoutes = <String>[
  RouteNames.privacyPolicy,
];

/// Determines whether the current navigation should be redirected based on
/// authentication state.
///
/// Returns the redirect path, or `null` if no redirect is needed.
String? guardRedirect(AuthState authState, GoRouterState state) {
  // Do not redirect to sign-in while secure storage is restoring an existing
  // session. The router will reevaluate when restoration completes.
  if (authState.isLoading) return null;

  final isAuthenticated = authState.isAuthenticated;
  final currentLocation = state.uri.path;

  // Public routes are always allowed, for any auth state.
  if (_publicRoutes.contains(currentLocation)) {
    return null;
  }

  final isAuthRoute = _authRoutes.any(
    (route) => currentLocation == route,
  );

  // Unauthenticated user trying to access a protected route → login.
  if (!isAuthenticated && !isAuthRoute) {
    return RouteNames.login;
  }

  // Authenticated user trying to access an auth route → dashboard.
  if (isAuthenticated && isAuthRoute) {
    return RouteNames.dashboard;
  }

  // No redirect needed.
  return null;
}
