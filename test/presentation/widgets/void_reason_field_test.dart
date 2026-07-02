import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/category_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/void_reason_field.dart';
import 'package:maki_mobile_pos/presentation/providers/category_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dropdown.dart';

CategoryEntity _reason(String name) => CategoryEntity(
      id: 'r-$name',
      name: name,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

class _Host extends StatefulWidget {
  const _Host({required this.formKey});
  final GlobalKey<FormState> formKey;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final _detail = TextEditingController();
  String? _selected;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: VoidReasonField(
        selectedReason: _selected,
        detailController: _detail,
        onChanged: (v) => setState(() => _selected = v),
      ),
    );
  }
}

Widget _app(GlobalKey<FormState> formKey, List<CategoryEntity> reasons) {
  return ProviderScope(
    overrides: [
      activeCategoriesProvider(CategoryKind.voidReason)
          .overrideWith((ref) => Stream.value(reasons)),
    ],
    child: MaterialApp(
      home: Scaffold(body: _Host(formKey: formKey)),
    ),
  );
}

void main() {
  testWidgets('renders the admin-managed reasons as a dropdown',
      (tester) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
        _app(formKey, [_reason('Wrong item'), _reason('Other')]));
    await tester.pumpAndSettle();

    expect(find.byType(AppDropdown<String>), findsOneWidget);
    await tester.tap(find.byType(AppDropdown<String>));
    await tester.pumpAndSettle();
    expect(find.text('Wrong item'), findsWidgets);
    expect(find.text('Other'), findsWidgets);
  });

  testWidgets('validates that a reason is picked', (tester) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(_app(formKey, [_reason('Wrong item')]));
    await tester.pumpAndSettle();

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Please pick a reason'), findsOneWidget);
  });

  testWidgets('"Other" reveals the detail field and enforces min length',
      (tester) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
        _app(formKey, [_reason('Wrong item'), _reason('Other')]));
    await tester.pumpAndSettle();

    // No detail field until "Other" is picked.
    expect(find.text('Reason details'), findsNothing);

    await tester.tap(find.byType(AppDropdown<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();

    expect(find.text('Reason details'), findsOneWidget);

    // Too-short detail fails validation.
    await tester.enterText(find.byType(TextFormField).last, 'abc');
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Reason must be at least 5 characters'), findsOneWidget);

    // Long enough passes.
    await tester.enterText(
        find.byType(TextFormField).last, 'Customer returned the part');
    expect(formKey.currentState!.validate(), isTrue);
  });

  testWidgets(
      'falls back to free text (with seeding hint) when no reasons configured',
      (tester) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(_app(formKey, const []));
    await tester.pumpAndSettle();

    // The request must never be blocked on the admin list: hint + free text.
    expect(find.textContaining('No void reasons configured'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);

    // The fallback field enforces required + min length.
    expect(formKey.currentState!.validate(), isFalse);
    await tester.enterText(
        find.byType(TextFormField), 'Customer returned the part');
    expect(formKey.currentState!.validate(), isTrue);
  });

  test('resolveReason returns picked name, or detail text for Other/none', () {
    expect(VoidReasonField.resolveReason('Wrong item', 'ignored'),
        'Wrong item');
    expect(VoidReasonField.resolveReason('Other', '  scratched casing  '),
        'scratched casing');
    // Null selection = free-text fallback mode: the typed text is the reason.
    expect(VoidReasonField.resolveReason(null, ' typed reason '),
        'typed reason');
  });
}
