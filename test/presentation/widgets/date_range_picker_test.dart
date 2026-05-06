import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/reports_widgets.dart';

void main() {
  group('DateRangePicker', () {
    testWidgets('shows the selected preset and exposes the others on tap',
        (tester) async {
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

      // Selected preset shows in the closed dropdown.
      expect(find.text('Today'), findsOneWidget);

      // Open the dropdown — the other presets become reachable.
      await tester
          .tap(find.byType(DropdownButtonFormField<DateRangePreset>));
      await tester.pumpAndSettle();

      expect(find.text('Yesterday'), findsWidgets);
      expect(find.text('This Week'), findsWidgets);
      expect(find.text('This Month'), findsWidgets);
    });

    testWidgets('calls onPresetChanged when a preset is selected',
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

      await tester
          .tap(find.byType(DropdownButtonFormField<DateRangePreset>));
      await tester.pumpAndSettle();

      // Multiple matches can exist (closed-state label + menu item) — pick
      // the menu entry, which is the last one in the tree.
      await tester.tap(find.text('Yesterday').last);
      await tester.pumpAndSettle();

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
