import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/user_repository.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/users/users_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/user_provider.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _MockActivityLogRepository extends Mock
    implements ActivityLogRepository {}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

UserEntity _user({
  required String id,
  required String name,
  UserRole role = UserRole.cashier,
  bool isActive = true,
}) =>
    UserEntity(
      id: id,
      email: '$id@test',
      displayName: name,
      role: role,
      isActive: isActive,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivityLog());
  });

  final admin = _user(id: 'u-admin', name: 'Admin', role: UserRole.admin);
  final activeCashier = _user(id: 'u-cash', name: 'Cashier');
  final inactiveStaff =
      _user(id: 'u-staff', name: 'Zstaff', role: UserRole.staff, isActive: false);

  late _MockUserRepository repo;
  late _MockActivityLogRepository logRepo;

  setUp(() {
    repo = _MockUserRepository();
    logRepo = _MockActivityLogRepository();
    when(() => repo.deleteUser(any())).thenAnswer((_) async {});
    when(() => repo.getUserById('u-staff'))
        .thenAnswer((_) async => inactiveStaff);
    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        allUsersProvider
            .overrideWith((ref) async => [admin, activeCashier, inactiveStaff]),
        currentUserProvider.overrideWith((ref) => Stream.value(admin)),
        userRepositoryProvider.overrideWithValue(repo),
        activityLogRepositoryProvider.overrideWithValue(logRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const UsersScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    // Reveal inactive users.
    await tester.tap(find.byIcon(LucideIcons.eyeOff));
    await tester.pumpAndSettle();
  }

  testWidgets('Delete appears only in the INACTIVE user row menu',
      (tester) async {
    await pumpScreen(tester);

    // Rows sort active-first: Admin (self, chevron), Cashier, then Zstaff.
    // Two overflow menus exist (self gets none).
    expect(find.byIcon(LucideIcons.moreVertical), findsNWidgets(2));

    // Active user: no Delete.
    await tester.tap(find.byIcon(LucideIcons.moreVertical).first);
    await tester.pumpAndSettle();
    expect(find.text('Deactivate'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
    await tester.tapAt(const Offset(5, 5)); // dismiss menu
    await tester.pumpAndSettle();

    // Inactive user: Reactivate + Delete.
    await tester.tap(find.byIcon(LucideIcons.moreVertical).last);
    await tester.pumpAndSettle();
    expect(find.text('Reactivate'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('confirming Delete runs the delete through the repo',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byIcon(LucideIcons.moreVertical).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Destructive confirm dialog names the user.
    expect(find.text('Delete user?'), findsOneWidget);
    expect(find.textContaining('Zstaff'), findsWidgets);

    await tester.tap(find.text('Delete')); // dialog primary action
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // waiting dialog min
    await tester.pumpAndSettle();

    verify(() => repo.deleteUser('u-staff')).called(1);
  });
}
