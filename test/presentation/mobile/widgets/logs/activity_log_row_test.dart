import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/logs/activity_log_row.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/logs/activity_log_style.dart';

ActivityLogEntity _log({
  ActivityType type = ActivityType.sale,
  String action = 'Completed sale',
  String? details = 'Receipt #1024',
  String userName = 'Maria Santos',
  String userRole = 'admin',
}) {
  return ActivityLogEntity(
    id: 'l1',
    type: type,
    action: action,
    details: details,
    userId: 'u1',
    userName: userName,
    userRole: userRole,
    createdAt: DateTime(2026, 6, 23, 14, 5),
  );
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('ActivityLogRow', () {
    testWidgets('renders action, time, details, actor name and role badge',
        (tester) async {
      await tester.pumpWidget(_wrap(ActivityLogRow(log: _log(), dark: false)));

      expect(find.text('Completed sale'), findsOneWidget);
      expect(find.text('2:05 PM'), findsOneWidget);
      expect(find.text('Receipt #1024'), findsOneWidget);
      expect(find.text('Maria Santos'), findsOneWidget);
      expect(find.text('admin'), findsOneWidget);
    });

    testWidgets('omits the details line when details is null', (tester) async {
      await tester.pumpWidget(
          _wrap(ActivityLogRow(log: _log(details: null), dark: false)));
      expect(find.text('Receipt #1024'), findsNothing);
    });

    testWidgets('financial and neutral rows use different leading icons',
        (tester) async {
      await tester.pumpWidget(_wrap(Column(children: [
        ActivityLogRow(log: _log(type: ActivityType.sale), dark: false),
        ActivityLogRow(
            log: _log(type: ActivityType.settings, details: null),
            dark: false),
      ])));

      expect(find.byIcon(ActivityLogStyle.iconFor(ActivityType.sale)),
          findsOneWidget);
      expect(find.byIcon(ActivityLogStyle.iconFor(ActivityType.settings)),
          findsOneWidget);
    });
  });
}
