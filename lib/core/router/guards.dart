import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import 'route_names.dart';

/// Auth routes that unauthenticated users are allowed to access.
const _authRoutes = <String>[
  RouteNames.login,
  RouteNames.register,
  RouteNames.forgotPassword,
];

/// Determines whether the current navigation should be redirected based on
/// authentication state.
///
/// Returns the redirect path, or `null` if no redirect is needed.
String? guardRedirect(AuthState authState, GoRouterState state) {
  final isAuthenticated = authState.isAuthenticated;
  final currentLocation = state.uri.path;

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
