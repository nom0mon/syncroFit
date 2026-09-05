import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/core/theme/app_colors.dart';
import 'package:synchrofit/shared/widgets/floating_pill_nav_bar.dart';

void main() {
  group('FloatingPillNavBar', () {
    Widget buildSubject({
      int selectedIndex = 0,
      ValueChanged<int>? onDestinationSelected,
      Size size = const Size(320, 640),
      EdgeInsets viewPadding = EdgeInsets.zero,
      double textScale = 1,
    }) {
      return MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: size,
            padding: viewPadding,
            viewPadding: viewPadding,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: Scaffold(
          bottomNavigationBar: FloatingPillNavBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected ?? (_) {},
          ),
        ),
      );
    }

    testWidgets('renders exactly four icon-only destinations', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(Icon), findsNWidgets(4));
      expect(
        find.descendant(
          of: find.byType(FloatingPillNavBar),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
    });

    testWidgets('uses active and inactive destination colors', (tester) async {
      const activeIndex = 2;
      await tester.pumpWidget(buildSubject(selectedIndex: activeIndex));

      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons[activeIndex].color, AppColors.textPrimary);
      for (var index = 0; index < icons.length; index++) {
        if (index == activeIndex) continue;
        expect(icons[index].color, AppColors.iconInactive);
      }
    });

    testWidgets('tapping a destination reports its index', (tester) async {
      int? tappedIndex;
      await tester.pumpWidget(
        buildSubject(onDestinationSelected: (index) => tappedIndex = index),
      );

      await tester.tap(find.bySemanticsLabel('Community'));
      await tester.pump();

      expect(tappedIndex, 3);
    });

    testWidgets('exposes labels, selection, and 48dp targets', (tester) async {
      await tester.pumpWidget(buildSubject(selectedIndex: 1, textScale: 2));

      for (final label in [
        'Dashboard',
        'Exercises',
        'Progress',
        'Community',
      ]) {
        final target = find.bySemanticsLabel(label);
        expect(target, findsOneWidget);
        final size = tester.getSize(target);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }

      final exercises = tester.widget<Semantics>(
        find.bySemanticsLabel('Exercises'),
      );
      expect(exercises.properties.selected, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('stays above Android gesture navigation inset', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        buildSubject(
          viewPadding: const EdgeInsets.only(bottom: 32),
          textScale: 2,
        ),
      );

      final pill = find.descendant(
        of: find.byType(FloatingPillNavBar),
        matching: find.byType(Container),
      );
      expect(tester.getBottomRight(pill).dy, lessThanOrEqualTo(608));
      expect(tester.takeException(), isNull);
    });

    testWidgets('constrains the pill on tablets', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1280);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildSubject(size: const Size(800, 1280)));

      final pill = find.descendant(
        of: find.byType(FloatingPillNavBar),
        matching: find.byType(Container),
      );
      expect(tester.getSize(pill).width, lessThanOrEqualTo(400));
      expect(tester.getSize(pill).height, 56);
      expect(tester.takeException(), isNull);
    });
  });
}
