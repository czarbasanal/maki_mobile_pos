import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/account_deactivation_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/account_deactivation_overlay.dart';

class _MockAuthNotifier extends Mock implements AuthNotifier {}

UserEntity _admin() => UserEntity(
      id: 'u1',
      email: 'a@x.com',
      displayName: 'Admin',
      role: UserRole.admin,
      isActive: true,
      createdAt: DateTime(2026, 7, 1),
    );

void main() {
  late _MockAuthNotifier auth;

  setUp(() {
    auth = _MockAuthNotifier();
    when(() => auth.signOut()).thenAnswer((_) async {});
  });

  Future<void> pumpOverlay(WidgetTester tester, AccountStatus status) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        accountStatusProvider.overrideWith((ref) => Stream.value(status)),
        currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
        authActionsProvider.overrideWithValue(auth),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const AccountDeactivationOverlay(
          child: Scaffold(body: Text('behind')),
        ),
      ),
    ));
    await tester.pump(); // deliver the stream event
    await tester.pump(); // rebuild with the new controller state
  }

  testWidgets('shows the blocking modal with the binding copy + countdown',
      (tester) async {
    await pumpOverlay(tester, AccountStatus.deactivated);

    expect(find.text('Account deactivated'), findsOneWidget);
    expect(
      find.text('Your account has been deactivated by an administrator. '
          'You will be signed out.'),
      findsOneWidget,
    );
    expect(find.text('Signing out in 10s…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Signing out in 9s…'), findsOneWidget);

    // Drain the countdown so no timer leaks out of the test.
    await tester.pump(const Duration(seconds: 9));
    verify(() => auth.signOut()).called(1);
  });

  testWidgets('doc-gone shows the modal without a countdown and signs out',
      (tester) async {
    await pumpOverlay(tester, AccountStatus.deleted);

    expect(find.text('Account deactivated'), findsOneWidget);
    expect(find.text('Signing out…'), findsOneWidget);
    expect(find.textContaining('Signing out in'), findsNothing);
    verify(() => auth.signOut()).called(1);
  });

  testWidgets('renders nothing extra while the account stays active',
      (tester) async {
    await pumpOverlay(tester, AccountStatus.active);

    expect(find.text('behind'), findsOneWidget);
    expect(find.text('Account deactivated'), findsNothing);
    verifyNever(() => auth.signOut());
  });
}
