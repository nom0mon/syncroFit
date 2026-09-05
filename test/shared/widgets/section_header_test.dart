import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:synchrofit/shared/widgets/section_header.dart';

void main() {
  setUpAll(() {
    // Prevent google_fonts from making HTTP requests in tests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('SectionHeader', () {
    testWidgets('renders title in uppercase', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionHeader(title: 'weekly load'),
          ),
        ),
      );

      expect(find.text('WEEKLY LOAD'), findsOneWidget);
      expect(find.text('weekly load'), findsNothing);
    });

    testWidgets('renders trailing label in uppercase when provided',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionHeader(
              title: 'calendar grid',
              trailingLabel: 'tap a day',
            ),
          ),
        ),
      );

      expect(find.text('CALENDAR GRID'), findsOneWidget);
      expect(find.text('TAP A DAY'), findsOneWidget);
      expect(find.text('tap a day'), findsNothing);
    });

    testWidgets('does not render trailing text when trailingLabel is null',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionHeader(title: 'test section'),
          ),
        ),
      );

      // Only the title text widget should exist, no Opacity wrapper
      expect(find.text('TEST SECTION'), findsOneWidget);
      expect(find.byType(Opacity), findsNothing);
    });

    testWidgets('wraps trailing label in Opacity widget at 0.5',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionHeader(
              title: 'completed sessions',
              trailingLabel: '3 on day',
            ),
          ),
        ),
      );

      final opacityWidget = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacityWidget.opacity, 0.5);
    });

    testWidgets('uses Wrap with WrapAlignment.spaceBetween',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionHeader(
              title: 'test',
              trailingLabel: 'label',
            ),
          ),
        ),
      );

      // Find the Wrap that is a descendant of SectionHeader
      final wrapFinder = find.descendant(
        of: find.byType(SectionHeader),
        matching: find.byType(Wrap),
      );
      final wrap = tester.widget<Wrap>(wrapFinder.first);
      expect(wrap.alignment, WrapAlignment.spaceBetween);
    });
  });
}
