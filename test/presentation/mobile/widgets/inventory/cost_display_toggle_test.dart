// Revealing costs is the sensitive action the cost-code cipher exists for,
// yet the `cost_viewed` ActivityType had never been written by anyone: the
// toggle verified the password against the repository directly — bypassing the
// logging use-case — and logCostViewed had zero callers.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/auth_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/inventory/cost_display_toggle.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockActivityLogRepository extends Mock
    implements ActivityLogRepository {}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

UserEntity _staff() => UserEntity(
      id: 'staff-1',
      email: 's@test',
      displayName: 'Staff User',
      role: UserRole.staff,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivityLog());
  });

  late _MockAuthRepository authRepo;
  late _MockActivityLogRepository logRepo;
  late bool toggledTo;

  Future<void> pumpToggle(WidgetTester tester) async {
    authRepo = _MockAuthRepository();
    logRepo = _MockActivityLogRepository();
    toggledTo = false;
    when(() => logRepo.logActivity(any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as ActivityLogEntity);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(_staff())),
          authRepositoryProvider.overrideWithValue(authRepo),
          activityLoggerProvider.overrideWithValue(ActivityLogger(logRepo)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CostDisplayToggle(
              showCost: false,
              onToggle: (v) => toggledTo = v,
            ),
          ),
        ),
      ),
    );
    // Warm the auth stream — the toggle reads currentUserProvider only after
    // the password round-trip, and an unwatched StreamProvider is still
    // loading at that point. The real app shell watches it from startup.
    final container = ProviderScope.containerOf(
        tester.element(find.byType(CostDisplayToggle)));
    container.listen(currentUserProvider, (_, __) {});
    await tester.pumpAndSettle();
  }

  Future<void> revealCosts(WidgetTester tester, {required bool verified}) async {
    when(() => authRepo.verifyPassword(any()))
        .thenAnswer((_) async => verified);
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'pw');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();
  }

  List<ActivityLogEntity> loggedOf(ActivityType type) =>
      verify(() => logRepo.logActivity(captureAny()))
          .captured
          .cast<ActivityLogEntity>()
          .where((e) => e.type == type)
          .toList();

  testWidgets('revealing costs writes a cost_viewed entry', (tester) async {
    await pumpToggle(tester);

    await revealCosts(tester, verified: true);

    expect(toggledTo, isTrue);
    expect(loggedOf(ActivityType.costViewed), hasLength(1));

    // Flush the toggle's 5-minute auto-hide timer so the test harness's
    // no-pending-timers invariant holds.
    await tester.pump(const Duration(minutes: 5));
  });

  testWidgets('the password check itself is logged too', (tester) async {
    await pumpToggle(tester);

    await revealCosts(tester, verified: true);

    final verifiedEntries = loggedOf(ActivityType.passwordVerified);
    expect(verifiedEntries, hasLength(1));
    expect(verifiedEntries.single.action, contains('view costs'));

    await tester.pump(const Duration(minutes: 5));
  });

  testWidgets('a failed attempt logs password_failed and never cost_viewed',
      (tester) async {
    await pumpToggle(tester);

    await revealCosts(tester, verified: false);

    expect(toggledTo, isFalse);
    final captured = verify(() => logRepo.logActivity(captureAny()))
        .captured
        .cast<ActivityLogEntity>();
    expect(
        captured.where((e) => e.type == ActivityType.passwordFailed).length,
        greaterThanOrEqualTo(1));
    expect(captured.where((e) => e.type == ActivityType.costViewed), isEmpty);
  });
}
