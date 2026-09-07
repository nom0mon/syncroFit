import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/features/dashboard/widgets/calendar_grid_widget.dart';

void main() {
  testWidgets('tapping a calendar day changes the selected date',
      (tester) async {
    DateTime selected = DateTime(2026, 9, 6);
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 350,
                    child: CalendarGridWidget(
                      year: 2026,
                      month: 9,
                      completedDates: {DateTime(2026, 9, 5)},
                      scheduledWeekdays: const {DateTime.saturday},
                      selectedDate: selected,
                      onDateSelected: (date) => setState(() => selected = date),
                    ),
                  ),
                ),
              )),
    ));

    await tester.tap(find.text('12'));
    await tester.pump();

    expect(selected, DateTime(2026, 9, 12));
    expect(find.byKey(const ValueKey('calendar-indicator-12')), findsOneWidget);
  });
}
