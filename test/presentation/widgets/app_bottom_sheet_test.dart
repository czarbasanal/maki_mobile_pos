import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_bottom_sheet.dart';

void main() {
  testWidgets('action sheet renders rows and returns the tapped value',
      (tester) async {
    String? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () {
                showAppActionSheet<String>(
                  context,
                  icon: LucideIcons.image,
                  title: 'Add product photo',
                  actions: const [
                    AppSheetAction(
                        icon: LucideIcons.camera,
                        label: 'Take photo',
                        value: 'camera'),
                    AppSheetAction(
                        icon: LucideIcons.image,
                        label: 'Choose from gallery',
                        value: 'gallery'),
                  ],
                ).then((v) => picked = v);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Add product photo'), findsOneWidget);
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);

    await tester.tap(find.text('Choose from gallery'));
    await tester.pumpAndSettle();
    expect(picked, 'gallery');
  });
}
