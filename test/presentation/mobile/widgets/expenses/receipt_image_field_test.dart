import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/expenses/receipt_image_field.dart';

// 1x1 transparent PNG — enough for Image.memory to decode in tests.
final kTinyPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  Future<void> pump(
    WidgetTester tester, {
    String? existingUrl,
    Uint8List? pendingBytes,
    void Function(Uint8List?, {required bool removed})? onChanged,
  }) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReceiptImageField(
          existingUrl: existingUrl,
          pendingBytes: pendingBytes,
          onChanged: onChanged ?? (_, {required removed}) {},
        ),
      ),
    ));
  }

  testWidgets('empty state shows the add-photo tile', (tester) async {
    await pump(tester);
    expect(find.text('Add receipt photo'), findsOneWidget);
    expect(find.byIcon(LucideIcons.camera), findsOneWidget);
    expect(find.text('Remove'), findsNothing);
  });

  testWidgets('pending bytes show a local preview with Replace/Remove',
      (tester) async {
    await pump(tester, pendingBytes: kTinyPng);
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Replace'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
  });

  testWidgets('remove fires onChanged(null, removed: true)', (tester) async {
    Uint8List? gotBytes = kTinyPng;
    bool? gotRemoved;
    await pump(tester, pendingBytes: kTinyPng,
        onChanged: (bytes, {required removed}) {
      gotBytes = bytes;
      gotRemoved = removed;
    });
    await tester.tap(find.text('Remove'));
    expect(gotBytes, isNull);
    expect(gotRemoved, isTrue);
  });

  testWidgets('tapping the preview opens the full-screen viewer',
      (tester) async {
    await pump(tester, pendingBytes: kTinyPng);
    await tester.tap(find.byType(Image));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('viewer has a save/download action', (tester) async {
    await pump(tester, pendingBytes: kTinyPng);
    await tester.tap(find.byType(Image));
    await tester.pumpAndSettle();
    expect(find.byIcon(LucideIcons.download), findsOneWidget);
  });
}
