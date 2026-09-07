import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:synchrofit/core/network/api_client.dart';
import 'package:synchrofit/core/network/token_storage.dart';
import 'package:synchrofit/features/auth/screens/login_screen.dart';
import 'package:synchrofit/features/auth/screens/register_screen.dart';
import 'package:synchrofit/shared/models/user.dart';
import 'package:synchrofit/shared/widgets/safe_layout.dart';

import '../../support/responsive_test_harness.dart';

class _EmptyTokenStorage extends TokenStorage {
  @override
  Future<String?> getToken() async => null;

  @override
  Future<User?> getUser() async => null;
}

ProviderScope _authTestScope(Widget child) => ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(_EmptyTokenStorage()),
      ],
      child: child,
    );

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('authentication responsive layout', () {
    const configurations = <ResponsiveTestConfiguration>[
      ResponsiveTestConfiguration.compactPhone,
      ResponsiveTestConfiguration.largeText,
    ];

    for (final configuration in configurations) {
      testWidgets(
        'login remains scrollable and exposes its primary action at $configuration',
        (tester) async {
          const action = Key('login-submit');

          await tester.pumpResponsiveWidget(
            _authTestScope(const LoginScreen()),
            configuration: configuration,
            settle: true,
          );

          expect(find.byType(SafeScrollableForm), findsOneWidget);
          await tester.scrollUntilVisible(
            find.byKey(action),
            180,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump();
          tester.expectFullyVisible(
            find.byKey(action),
            configuration: configuration,
          );
        },
      );

      testWidgets(
        'registration remains scrollable and exposes its primary action at $configuration',
        (tester) async {
          const action = Key('register-submit');

          await tester.pumpResponsiveWidget(
            _authTestScope(const RegisterScreen()),
            configuration: configuration,
            settle: true,
          );

          expect(find.byType(SafeScrollableForm), findsOneWidget);
          await tester.scrollUntilVisible(
            find.byKey(action),
            220,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump();
          tester.expectFullyVisible(
            find.byKey(action),
            configuration: configuration,
          );
        },
      );
    }

    testWidgets(
      'registration action remains above a compact-phone keyboard and cutout',
      (tester) async {
        const configuration = ResponsiveTestConfiguration(
          name: 'compact-phone-keyboard-cutout',
          size: Size(320, 640),
        );
        const keyboardInset = 260.0;
        const action = Key('register-submit');

        await tester.pumpResponsiveWidget(
          _authTestScope(
            Builder(
              builder: (context) {
                final mediaQuery = MediaQuery.of(context);
                return MediaQuery(
                  data: mediaQuery.copyWith(
                    padding: const EdgeInsets.only(top: 24, bottom: 16),
                    viewPadding: const EdgeInsets.only(top: 24, bottom: 16),
                    viewInsets: const EdgeInsets.only(bottom: keyboardInset),
                  ),
                  child: const RegisterScreen(),
                );
              },
            ),
          ),
          configuration: configuration,
          settle: true,
        );

        expect(
          tester.getTopLeft(find.byTooltip('Back to sign in')).dy,
          greaterThanOrEqualTo(24),
        );

        await tester.scrollUntilVisible(
          find.byKey(action),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();

        expect(
          tester.getRect(find.byKey(action)).bottom,
          lessThanOrEqualTo(configuration.size.height - keyboardInset),
        );
      },
    );
  });
}
