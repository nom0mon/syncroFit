import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/core/theme/app_colors.dart';
import 'package:synchrofit/shared/widgets/floating_pill_nav_bar.dart';

void main() {
  group('FloatingPillNavBar', () {
    Widget buildSubject({
      int selectedIndex = 0,
      ValueChanged<int>? onDestinationSelected,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: FloatingPillNavBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected ?? (_) {},
          ),
        ),
      );
    }

    testWidgets('renders exactly 4 icon widgets', (tester) async {
      await tester.pumpWidget(buildSubject());

      final iconFinder = find.byType(Icon);
      expect(iconFinder, findsNWidgets(4));
    });

    testWidgets('active icon at selectedIndex has white color',
        (tester) async {
      const activeIndex = 2;
      await tester.pumpWidget(buildSubject(selectedIndex: activeIndex));

      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons[activeIndex].color, AppColors.textPrimary);
    });

    testWidgets('inactive icons have grey color (AppColors.iconInactive)',
        (tester) async {
      const activeIndex = 0;
      await tester.pumpWidget(buildSubject(selectedIndex: activeIndex));

      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      for (var i = 0; i < icons.length; i++) {
        if (i == activeIndex) continue;
        expect(
          icons[i].color,
          AppColors.iconInactive,
          reason: 'Icon at index $i should be inactive grey',
        );
      }
    });

    testWidgets('tapping an icon calls onDestinationSelected with correct index',
        (tester) async {
      int? tappedIndex;
      await tester.pumpWidget(
        buildSubject(onDestinationSelected: (index) => tappedIndex = index),
      );

      // Tap the 4th icon (index 3)
      final icons = find.byType(Icon);
      await tester.tap(icons.at(3));
      await tester.pump();

      expect(tappedIndex, 3);
    });

    testWidgets('no Text widgets are rendered (no labels)', (tester) async {
      await tester.pumpWidget(buildSubject());

      // No Text widgets should exist within the nav bar
      final textInNavBar = find.descendant(
        of: find.byType(FloatingPillNavBar),
        matching: find.byType(Text),
      );
      expect(textInNavBar, findsNothing);
    });

    testWidgets('container has height 56 and border radius 28',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      // The FloatingPillNavBar root is a Container with BoxDecoration
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(FloatingPillNavBar),
          matching: find.byType(Container),
        ).first,
      );

      // Verify height
      expect(container.constraints?.maxHeight ?? 0, 56);

      // Verify border radius
      final decoration = container.decoration as BoxDecoration;
      expect(
        decoration.borderRadius,
        BorderRadius.circular(28),
      );
    });
  });
}
