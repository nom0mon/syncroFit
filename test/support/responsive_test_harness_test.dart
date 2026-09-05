import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/shared/widgets/responsive_layout.dart';

import 'responsive_test_harness.dart';

void main() {
  group('ResponsiveTestConfiguration', () {
    test('defines the complete PRD section 2 release matrix', () {
      expect(
        ResponsiveTestConfiguration.requiredConfigurations,
        hasLength(5),
      );
      expect(
        ResponsiveTestConfiguration.requiredConfigurations.map(
          (configuration) => configuration.name,
        ),
        containsAll(<String>[
          'compact-phone',
          'standard-phone',
          'tablet',
          'phone-landscape',
          'standard-phone-200-percent-text',
        ]),
      );
      expect(
        ResponsiveTestConfiguration.compactPhone.size.width,
        ResponsiveStandards.minSupportedWidth,
      );
      expect(
        ResponsiveTestConfiguration.largeText.textScaleFactor,
        2,
      );
      expect(
        ResponsiveTestConfiguration.landscape.orientation,
        Orientation.landscape,
      );
    });

    test('uses task 3.1 width classifications', () {
      expect(
        ResponsiveTestConfiguration.compactPhone.widthClass,
        AppWidthClass.compact,
      );
      expect(
        ResponsiveTestConfiguration.standardPhone.widthClass,
        AppWidthClass.standard,
      );
      expect(
        ResponsiveTestConfiguration.tablet.widthClass,
        AppWidthClass.tablet,
      );
      expect(
        ResponsiveTestConfiguration.landscape.widthClass,
        AppWidthClass.large,
      );
    });
  });

  group('ResponsiveWidgetTester', () {
    for (final configuration
        in ResponsiveTestConfiguration.requiredConfigurations) {
      testWidgets('applies ${configuration.name} size and text scale',
          (tester) async {
        Size? mediaSize;
        double? textScale;

        await tester.pumpResponsiveWidget(
          Builder(
            builder: (context) {
              mediaSize = MediaQuery.sizeOf(context);
              textScale = MediaQuery.textScalerOf(context).scale(10) / 10;
              return const Scaffold(body: Text('Responsive content'));
            },
          ),
          configuration: configuration,
        );

        expect(mediaSize, configuration.size);
        expect(textScale, configuration.textScaleFactor);
      });
    }

    testWidgets('uses deterministic Android theme and Ahem font',
        (tester) async {
      ThemeData? theme;
      TextStyle? textStyle;

      await tester.pumpResponsiveWidget(
        Builder(
          builder: (context) {
            theme = Theme.of(context);
            textStyle = Theme.of(context).textTheme.bodyMedium;
            return const Scaffold(body: Text('Golden content'));
          },
        ),
        configuration: ResponsiveTestConfiguration.standardPhone,
      );

      expect(theme!.platform, TargetPlatform.android);
      expect(theme!.splashFactory, NoSplash.splashFactory);
      expect(textStyle!.fontFamily, 'Ahem');
    });

    testWidgets('surfaces RenderFlex overflow as a harness failure',
        (tester) async {
      final failure = await _captureFailure(
        () => tester.pumpResponsiveWidget(
          const Scaffold(
            body: Row(
              children: <Widget>[SizedBox(width: 500, height: 20)],
            ),
          ),
          configuration: ResponsiveTestConfiguration.compactPhone,
        ),
      );

      expect(
        failure,
        isA<TestFailure>().having(
          (error) => error.message,
          'message',
          contains('RenderFlex overflow'),
        ),
      );
    });

    testWidgets('surfaces uncaught layout exceptions as a harness failure',
        (tester) async {
      final failure = await _captureFailure(
        () => tester.pumpResponsiveWidget(
          Scaffold(
            body: LayoutBuilder(
              builder: (context, constraints) {
                throw StateError('intentional layout failure');
              },
            ),
          ),
          configuration: ResponsiveTestConfiguration.standardPhone,
        ),
      );

      expect(
        failure,
        isA<TestFailure>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('uncaught layout/paint exception'),
            contains('intentional layout failure'),
          ),
        ),
      );
    });

    testWidgets('surfaces clipping of a release-critical widget',
        (tester) async {
      const actionKey = Key('primary-action');
      await tester.pumpResponsiveWidget(
        const Scaffold(
          body: Center(
            child: SizedBox(
              width: 100,
              height: 100,
              child: ClipRect(
                child: OverflowBox(
                  maxWidth: 200,
                  maxHeight: 200,
                  child: SizedBox(
                    key: actionKey,
                    width: 200,
                    height: 200,
                  ),
                ),
              ),
            ),
          ),
        ),
        configuration: ResponsiveTestConfiguration.standardPhone,
      );

      expect(
        () => tester.expectFullyVisible(
          find.byKey(actionKey),
          configuration: ResponsiveTestConfiguration.standardPhone,
        ),
        throwsA(
          isA<TestFailure>().having(
            (failure) => failure.message,
            'message',
            contains('clipped by RenderClipRect'),
          ),
        ),
      );
    });

    testWidgets('checks required visible widgets during pump', (tester) async {
      const actionKey = Key('visible-action');
      await tester.pumpResponsiveWidget(
        const Scaffold(
          body: Center(
            child: SizedBox(
              key: actionKey,
              width: 48,
              height: 48,
            ),
          ),
        ),
        configuration: ResponsiveTestConfiguration.largeText,
        mustRemainVisible: <Finder>[find.byKey(actionKey)],
      );
    });
  });

  group('golden image stubs', () {
    test('network environment restores the previous global override', () {
      final previous = HttpOverrides.current;
      final environment = ResponsiveGoldenNetworkEnvironment();

      environment.install();
      expect(HttpOverrides.current, isNot(same(previous)));

      environment.restore();
      expect(HttpOverrides.current, same(previous));
    });

    testWidgets('network images resolve to deterministic local PNG bytes',
        (tester) async {
      final environment = ResponsiveGoldenNetworkEnvironment()..install();
      addTearDown(environment.restore);

      await tester.pumpResponsiveWidget(
        const Scaffold(
          body: Image(
            image: NetworkImage('https://example.invalid/golden.png'),
            width: 24,
            height: 24,
          ),
        ),
        configuration: ResponsiveTestConfiguration.standardPhone,
        settle: true,
      );

      expect(find.byType(RawImage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('memory image stub is stable and non-empty', () {
      final first = ResponsiveGoldenImages.transparentProvider;
      final second = ResponsiveGoldenImages.transparentProvider;

      expect(first.bytes, isNotEmpty);
      expect(first.bytes, orderedEquals(second.bytes));
    });
  });
}

Future<Object?> _captureFailure(Future<void> Function() body) async {
  try {
    await body();
    return null;
  } catch (error) {
    return error;
  }
}
