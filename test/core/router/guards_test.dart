import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:synchrofit/core/router/guards.dart';
import 'package:synchrofit/core/router/route_names.dart';
import 'package:synchrofit/features/auth/providers/auth_state.dart';

/// Regression tests for [guardRedirect].
///
/// The privacy policy is a PUBLIC route: it must be reachable both before
/// sign-up (unauthenticated) and from Settings after signing in
/// (authenticated). A previous implementation placed it in the auth-only
/// allowlist, which bounced authenticated users to the dashboard — so the
/// "Privacy Policy" item in Settings appeared to do nothing.
void main() {
  GoRouter buildRouter(AuthState authState) {
    return GoRouter(
      initialLocation: RouteNames.dashboard,
      redirect: (context, state) => guardRedirect(authState, state),
      routes: [
        GoRoute(
          path: RouteNames.login,
          builder: (context, state) => const Scaffold(body: Text('Login')),
        ),
        GoRoute(
          path: RouteNames.privacyPolicy,
          builder: (context, state) =>
              const Scaffold(body: Text('Privacy Policy')),
        ),
        GoRoute(
          path: RouteNames.dashboard,
          builder: (context, state) => const Scaffold(body: Text('Dashboard')),
        ),
      ],
    );
  }

  Future<void> pumpRouter(WidgetTester tester, GoRouter router) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'authenticated user can open the privacy policy from settings',
    (tester) async {
      final router = buildRouter(const AuthState(isAuthenticated: true));
      await pumpRouter(tester, router);

      router.push(RouteNames.privacyPolicy);
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Dashboard'), findsNothing);
    },
  );

  testWidgets(
    'unauthenticated user can open the privacy policy before sign-up',
    (tester) async {
      final router = buildRouter(const AuthState(isAuthenticated: false));
      await pumpRouter(tester, router);

      router.go(RouteNames.privacyPolicy);
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Login'), findsNothing);
    },
  );

  testWidgets(
    'unauthenticated user is still redirected to login for protected routes',
    (tester) async {
      final router = buildRouter(const AuthState(isAuthenticated: false));
      await pumpRouter(tester, router);

      // Starts at dashboard (protected) → should redirect to login.
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Dashboard'), findsNothing);
    },
  );
}
