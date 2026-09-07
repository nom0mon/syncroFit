import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/core/theme/app_theme.dart';
import 'package:synchrofit/shared/widgets/edge_fade_gradient.dart';

void main() {
  group('EdgeFadeGradient', () {
    testWidgets('wraps content in IgnorePointer in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: EdgeFadeGradient(isTop: true),
          ),
        ),
      );

      // The EdgeFadeGradient's root widget should be an IgnorePointer
      final ignorePointerFinder = find.descendant(
        of: find.byType(EdgeFadeGradient),
        matching: find.byWidgetPredicate(
          (widget) => widget is IgnorePointer && widget.ignoring == true,
        ),
      );
      expect(ignorePointerFinder, findsOneWidget);
    });

    testWidgets('renders nothing in light mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: EdgeFadeGradient(isTop: true),
          ),
        ),
      );

      final containerFinder = find.descendant(
        of: find.byType(EdgeFadeGradient),
        matching: find.byType(Container),
      );
      expect(containerFinder, findsNothing);
    });

    testWidgets('uses default height of 32 when not specified', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: EdgeFadeGradient(isTop: true),
          ),
        ),
      );

      final containerFinder = find.descendant(
        of: find.byType(EdgeFadeGradient),
        matching: find.byType(Container),
      );
      final container = tester.widget<Container>(containerFinder);
      expect(container.constraints?.maxHeight, 32);
    });

    testWidgets('uses custom height when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: EdgeFadeGradient(isTop: true, height: 48),
          ),
        ),
      );

      final containerFinder = find.descendant(
        of: find.byType(EdgeFadeGradient),
        matching: find.byType(Container),
      );
      final container = tester.widget<Container>(containerFinder);
      expect(container.constraints?.maxHeight, 48);
    });

    testWidgets('top gradient goes from scaffoldBackgroundColor to transparent',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: EdgeFadeGradient(isTop: true),
          ),
        ),
      );

      final containerFinder = find.descendant(
        of: find.byType(EdgeFadeGradient),
        matching: find.byType(Container),
      );
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      final gradient = decoration.gradient as LinearGradient;

      expect(gradient.colors[0], AppTheme.darkTheme.scaffoldBackgroundColor);
      expect(gradient.colors[1], Colors.transparent);
      expect(gradient.begin, Alignment.topCenter);
      expect(gradient.end, Alignment.bottomCenter);
    });

    testWidgets(
        'bottom gradient goes from transparent to scaffoldBackgroundColor',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: EdgeFadeGradient(isTop: false),
          ),
        ),
      );

      final containerFinder = find.descendant(
        of: find.byType(EdgeFadeGradient),
        matching: find.byType(Container),
      );
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      final gradient = decoration.gradient as LinearGradient;

      expect(gradient.colors[0], Colors.transparent);
      expect(gradient.colors[1], AppTheme.darkTheme.scaffoldBackgroundColor);
      expect(gradient.begin, Alignment.topCenter);
      expect(gradient.end, Alignment.bottomCenter);
    });
  });
}
