import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/widgets/reports/reports_widgets.dart';

void main() {
  group('DateRangePicker', () {
    testWidgets('displays preset options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateRangePicker(
              startDate: DateTime(2025, 2, 5),
              endDate: DateTime(2025, 2, 5),
              selectedPreset: DateRangePreset.today,
              onPresetChanged: (_) {},
              onCustomRangeSelected: (_, __) {},
            ),
          ),
        ),
      );

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
    });

    testWidgets('calls onPresetChanged when preset is selected',
        (tester) async {
      DateRangePreset? selectedPreset;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateRangePicker(
              startDate: DateTime(2025, 2, 5),
              endDate: DateTime(2025, 2, 5),
              selectedPreset: DateRangePreset.today,
              onPresetChanged: (preset) => selectedPreset = preset,
              onCustomRangeSelected: (_, __) {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Yesterday'));
      await tester.pump();

      expect(selectedPreset, DateRangePreset.yesterday);
    });

    testWidgets('displays selected date range', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateRangePicker(
              startDate: DateTime(2025, 2, 1),
              endDate: DateTime(2025, 2, 5),
              selectedPreset: DateRangePreset.custom,
              onPresetChanged: (_) {},
              onCustomRangeSelected: (_, __) {},
            ),
          ),
        ),
      );

      expect(find.textContaining('Feb 1'), findsOneWidget);
      expect(find.textContaining('Feb 5'), findsOneWidget);
    });
  });
}
