import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/shared/widgets/responsive_layout.dart';

void main() {
  group('ResponsiveStandards', () {
    test('classifies breakpoint boundaries', () {
      expect(
        ResponsiveStandards.widthClassFor(320),
        AppWidthClass.compact,
      );
      expect(
        ResponsiveStandards.widthClassFor(359.9),
        AppWidthClass.compact,
      );
      expect(
        ResponsiveStandards.widthClassFor(360),
        AppWidthClass.standard,
      );
      expect(
        ResponsiveStandards.widthClassFor(599.9),
        AppWidthClass.standard,
      );
      expect(
        ResponsiveStandards.widthClassFor(600),
        AppWidthClass.tablet,
      );
      expect(
        ResponsiveStandards.widthClassFor(839.9),
        AppWidthClass.tablet,
      );
      expect(
        ResponsiveStandards.widthClassFor(840),
        AppWidthClass.large,
      );
      expect(
        ResponsiveStandards.widthClassFor(1280),
        AppWidthClass.large,
      );
    });

    test('covers every supported integer width', () {
      for (var width = 320; width <= 1280; width++) {
        expect(
          AppWidthClass.values,
          contains(ResponsiveStandards.widthClassFor(width.toDouble())),
          reason: '$width dp must belong to exactly one width class',
        );
      }
    });

    test('uses shared page padding and 48dp tap target', () {
      expect(ResponsiveStandards.horizontalPaddingFor(320), 16);
      expect(ResponsiveStandards.horizontalPaddingFor(360), 20);
      expect(ResponsiveStandards.horizontalPaddingFor(600), 24);
      expect(ResponsiveStandards.horizontalPaddingFor(840), 32);
      expect(ResponsiveStandards.minTapTarget, 48);
    });

    test('adaptive columns preserve minimum card width or use one column', () {
      for (var width = 320; width <= 1280; width++) {
        final columns = ResponsiveStandards.adaptiveColumnCount(
          width.toDouble(),
        );
        final itemWidth = (width - (16 * (columns - 1))) / columns;

        expect(columns, inInclusiveRange(1, 3));
        expect(
          columns == 1 || itemWidth >= ResponsiveStandards.minCardWidth,
          isTrue,
          reason: '$width dp produced $columns columns at $itemWidth dp',
        );
      }
    });

    test('simplifies chart labels at narrow widths', () {
      expect(
        ResponsiveStandards.chartLabelDensityFor(320),
        ChartLabelDensity.sparse,
      );
      expect(ResponsiveStandards.chartLabelStrideFor(320, 12), 3);
      expect(
        ResponsiveStandards.chartLabelDensityFor(360),
        ChartLabelDensity.abbreviated,
      );
      expect(ResponsiveStandards.chartLabelStrideFor(360, 12), 2);
      expect(
        ResponsiveStandards.chartLabelDensityFor(600),
        ChartLabelDensity.full,
      );
      expect(ResponsiveStandards.chartLabelStrideFor(840, 12), 1);
    });
  });

  group('responsive widgets', () {
    testWidgets('constrained page centers content within readable width',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveConstrainedPage(
              child: ColoredBox(
                key: Key('content'),
                color: Colors.blue,
                child: SizedBox(height: 20),
              ),
            ),
          ),
        ),
      );

      final contentSize = tester.getSize(find.byKey(const Key('content')));
      final contentTopLeft =
          tester.getTopLeft(find.byKey(const Key('content')));

      expect(contentSize.width, 776); // 840 max width - 32dp on each side.
      expect(contentTopLeft.dx, 252); // Centered 840dp page + 32dp inset.
    });

    testWidgets('adaptive grid falls back to one column on narrow widths',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: AdaptiveGridList(
                children: List.generate(
                  3,
                  (index) => SizedBox(
                    key: Key('item-$index'),
                    height: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(AdaptiveGridList),
          matching: find.byType(Column),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AdaptiveGridList),
          matching: find.byType(Wrap),
        ),
        findsNothing,
      );
      expect(tester.getSize(find.byKey(const Key('item-0'))).width, 320);
    });

    testWidgets('adaptive grid uses equal-width columns when cards fit',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              child: AdaptiveGridList(
                children: List.generate(
                  3,
                  (index) => SizedBox(
                    key: Key('item-$index'),
                    height: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(AdaptiveGridList),
          matching: find.byType(Wrap),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(find.byKey(const Key('item-0'))).width, 292);
    });

    testWidgets('responsive card uses compact and tablet padding',
        (tester) async {
      Future<double> pumpCardAt(double width) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(width, 800)),
              child: const Scaffold(
                body: ResponsiveCard(child: Text('Card content')),
              ),
            ),
          ),
        );
        final padding = tester.widget<Padding>(
          find
              .descendant(
                of: find.byType(ResponsiveCard),
                matching: find.byType(Padding),
              )
              .last,
        );
        return (padding.padding as EdgeInsets).left;
      }

      expect(await pumpCardAt(320), 16);
      expect(await pumpCardAt(600), 24);
    });
  });
}
