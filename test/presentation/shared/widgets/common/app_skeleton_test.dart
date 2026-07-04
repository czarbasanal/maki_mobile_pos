import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_skeleton.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/dashboard/summary_card.dart';

void main() {
  testWidgets('FieldSkeleton renders a single field-height SkeletonBox',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FieldSkeleton()),
    ));
    final box = tester.widget<SkeletonBox>(find.byType(SkeletonBox));
    expect(box.height, 56);
  });

  testWidgets('FormSkeleton renders N fields plus a button bar',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FormSkeleton(fields: 4)),
    ));
    expect(find.byType(FieldSkeleton), findsNWidgets(5)); // 4 fields + button
  });

  testWidgets('SummaryCard loading shows a SkeletonBox instead of the value',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SummaryCard(
          title: 'Today',
          value: '₱100.00',
          icon: LucideIcons.sun,
          compact: true,
          loading: true,
        ),
      ),
    ));
    expect(find.byType(SkeletonBox), findsOneWidget);
    expect(find.text('₱100.00'), findsNothing);
    expect(find.text('Today'), findsOneWidget);
  });
}
