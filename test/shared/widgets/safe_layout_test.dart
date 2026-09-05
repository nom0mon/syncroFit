import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/shared/widgets/safe_layout.dart';

void main() {
  group('SafeScrollableForm', () {
    testWidgets('is safe, scrollable, and follows reading-order focus',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 480);
      addTearDown(tester.view.reset);

      final firstFocus = FocusNode();
      final secondFocus = FocusNode();
      addTearDown(firstFocus.dispose);
      addTearDown(secondFocus.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeScrollableForm(
              bottomAction: const ElevatedButton(
                onPressed: null,
                child: Text('Save changes'),
              ),
              child: Column(
                children: [
                  TextField(
                    key: const Key('first-field'),
                    focusNode: firstFocus,
                  ),
                  const SizedBox(height: 500),
                  TextField(
                    key: const Key('second-field'),
                    focusNode: secondFocus,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SafeArea), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(SafeScrollableForm),
          matching: find.byType(FocusTraversalGroup),
        ),
        findsWidgets,
      );
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      await tester.tap(find.byKey(const Key('first-field')));
      await tester.pump();
      expect(firstFocus.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(secondFocus.hasFocus, isTrue);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -700),
      );
      await tester.pumpAndSettle();
      expect(find.text('Save changes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('can reserve raw keyboard inset in a non-resizing overlay',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(360, 640),
              viewInsets: EdgeInsets.only(bottom: 240),
            ),
            child: SafeScrollableForm(
              includeKeyboardInset: true,
              child: Text('Form'),
            ),
          ),
        ),
      );

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect((scrollView.padding! as EdgeInsets).bottom, 256);
      expect(tester.takeException(), isNull);
    });
  });

  group('safe overlays', () {
    testWidgets('dialog stays constrained and scrollable above the keyboard',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              viewInsets: EdgeInsets.only(bottom: 240),
              textScaler: TextScaler.linear(2),
            ),
            child: SafeScrollableDialog(
              title: const Text(
                'Edit a very long translated profile heading',
              ),
              content: Column(
                children: [
                  for (var index = 0; index < 12; index++)
                    const TextField(
                      decoration: InputDecoration(labelText: 'Field'),
                    ),
                ],
              ),
              actions: const [
                ElevatedButton(onPressed: null, child: Text('Save')),
              ],
            ),
          ),
        ),
      );

      final scrollableSize = tester.getSize(
        find.descendant(
          of: find.byType(SafeScrollableDialog),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(scrollableSize.height, lessThanOrEqualTo(360));
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bottom sheet keeps its action above a visible keyboard',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 640);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              viewInsets: EdgeInsets.only(bottom: 240),
            ),
            child: Scaffold(
              body: SafeScrollableBottomSheet(
                bottomAction: const ElevatedButton(
                  onPressed: null,
                  child: Text('Apply filters'),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < 20; index++)
                      Text('Scrollable option $index'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final actionBottom = tester.getBottomRight(find.text('Apply filters')).dy;
      expect(actionBottom, lessThanOrEqualTo(400));
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('modal helper applies safe route and scrolling pattern',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showSafeModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const Text('Sheet content'),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(SafeScrollableBottomSheet), findsOneWidget);
      expect(find.text('Sheet content'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('accessible wrappers', () {
    testWidgets('minimum tap target is at least 48dp', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: MinimumTapTarget(
              child: Icon(Icons.add, size: 16),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(MinimumTapTarget));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('custom action exposes one label, button action, and 48dp hit',
        (tester) async {
      var taps = 0;
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AccessibleTapTarget(
                label: 'Add progress photo',
                onTap: () => taps++,
                child: const Icon(Icons.add, size: 16),
              ),
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Add progress photo'), findsOneWidget);

      final size = tester.getSize(find.byType(AccessibleTapTarget));
      expect(size, const Size(48, 48));

      await tester.tap(find.bySemanticsLabel('Add progress photo'));
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('accessible label replaces ambiguous child semantics',
        (tester) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: AccessibleLabel(
            label: 'Weekly workout completion chart',
            image: true,
            child: Text('42'),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('Weekly workout completion chart'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('42'), findsNothing);
      semantics.dispose();
    });
  });
}
