import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/shop_timezone_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/shop_timezone_repository.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/shop_timezone_settings_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/shop_time_provider.dart';

class _FakeRepo implements ShopTimezoneRepository {
  ShopTimezoneEntity current;
  ShopTimezoneEntity? saved;
  String? savedBy;
  Object? failWith;
  _FakeRepo(this.current);

  @override
  Stream<ShopTimezoneEntity> watch() => Stream.value(current);

  @override
  Future<ShopTimezoneEntity> get() async => current;

  @override
  Future<void> save(ShopTimezoneEntity settings,
      {required String updatedBy}) async {
    if (failWith != null) throw failWith!;
    saved = settings;
    savedBy = updatedBy;
  }
}

UserEntity _user(UserRole role) => UserEntity(
      id: 'u-1',
      email: 'u@x.com',
      displayName: 'U',
      role: role,
      isActive: true,
      createdAt: DateTime(2026, 5, 30),
    );

void main() {
  Future<void> pump(
    WidgetTester tester,
    _FakeRepo repo, {
    UserRole role = UserRole.admin,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shopTimezoneRepositoryProvider.overrideWithValue(repo),
          currentUserProvider.overrideWith((ref) => Stream.value(_user(role))),
          nowProvider.overrideWithValue(() => DateTime.utc(2026, 8, 26, 5, 0)),
        ],
        child: const MaterialApp(home: ShopTimezoneSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the current shop timezone', (tester) async {
    await pump(tester, _FakeRepo(ShopTimezoneEntity.defaults));
    expect(find.text('Philippines (Manila)'), findsWidgets);
  });

  testWidgets('shows the current shop time, not the device time',
      (tester) async {
    await pump(tester, _FakeRepo(ShopTimezoneEntity.defaults));
    // 2026-08-26 05:00 UTC is 13:00 in Manila.
    expect(find.textContaining('1:00 PM'), findsOneWidget);
  });

  testWidgets('lists the curated timezones', (tester) async {
    await pump(tester, _FakeRepo(ShopTimezoneEntity.defaults));
    expect(find.text('Japan (Tokyo)'), findsOneWidget);
  });

  testWidgets('Save stays disabled until the selection changes',
      (tester) async {
    await pump(tester, _FakeRepo(ShopTimezoneEntity.defaults));
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('selecting a zone and saving writes both fields', (tester) async {
    final repo = _FakeRepo(ShopTimezoneEntity.defaults);
    await pump(tester, repo);

    await tester.tap(find.text('Japan (Tokyo)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.saved?.timezoneId, 'Asia/Tokyo');
    expect(repo.saved?.offsetMinutes, 540);
    expect(repo.savedBy, 'u-1');
  });

  testWidgets('a failed save surfaces the error and keeps the selection',
      (tester) async {
    final repo = _FakeRepo(ShopTimezoneEntity.defaults)
      ..failWith = Exception('permission denied');
    await pump(tester, repo);

    await tester.tap(find.text('Japan (Tokyo)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.saved, isNull);
    expect(find.textContaining('permission denied'), findsOneWidget);
  });

  testWidgets('a non-admin sees the list read-only — no Save', (tester) async {
    await pump(tester, _FakeRepo(ShopTimezoneEntity.defaults),
        role: UserRole.cashier);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('warns that all devices must be updated', (tester) async {
    await pump(tester, _FakeRepo(ShopTimezoneEntity.defaults));
    expect(find.textContaining('every device'), findsOneWidget);
  });
}
