import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/draft_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/domain/usecases/draft/delete_draft_usecase.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/draft_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/drafts/drafts_list_screen.dart';

class _MockDeleteUseCase extends Mock implements DeleteDraftUseCase {}

class _MockDraftRepository extends Mock implements DraftRepository {}

class _FakeUser extends Fake implements UserEntity {}

const _errorMessage = "Couldn't remove the job order. Please try again.";

void main() {
  setUpAll(() => registerFallbackValue(_FakeUser()));

  UserEntity admin() => UserEntity(
        id: 'admin-1',
        email: 'a@x.com',
        displayName: 'Admin',
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime(2026, 6, 1),
      );

  DraftEntity draft() => DraftEntity(
        id: 'd-1',
        name: 'Table 9',
        items: const [
          SaleItemEntity(
            id: 'i-1',
            productId: 'p-1',
            sku: 'SKU-1',
            name: 'Widget',
            unitPrice: 100,
            unitCost: 60,
            quantity: 1,
          ),
        ],
        discountType: DiscountType.amount,
        createdBy: 'admin-1',
        createdByName: 'Admin',
        createdAt: DateTime(2026, 6, 1, 9),
      );

  /// Pumps the drafts screen wired to a GoRouter (so context.go works). The
  /// delete is gated on the returned [Completer] so the test controls exactly
  /// when it resolves — letting us pop/dispose the bottom sheet *before* the
  /// delete completes (the real-world race the fix guards against).
  Future<Completer<UseCaseResult<void>>> pumpControllableDelete(
    WidgetTester tester,
  ) async {
    final gate = Completer<UseCaseResult<void>>();
    final deleteUseCase = _MockDeleteUseCase();
    when(() => deleteUseCase.execute(
          actor: any(named: 'actor'),
          draftId: any(named: 'draftId'),
        )).thenAnswer((_) => gate.future);

    final router = GoRouter(
      initialLocation: '/drafts',
      routes: [
        GoRoute(path: '/drafts', builder: (_, __) => const DraftsListScreen()),
        GoRoute(
          path: '/pos',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('POS-STUB'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // The operations notifier builds the real repo (which touches
          // Firebase) at construction; stub it so the notifier is buildable.
          draftRepositoryProvider.overrideWithValue(_MockDraftRepository()),
          activeDraftsProvider.overrideWith((ref) => Stream.value([draft()])),
          currentUserProvider.overrideWith((ref) => Stream.value(admin())),
          deleteDraftUseCaseProvider.overrideWithValue(deleteUseCase),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return gate;
  }

  testWidgets(
      'a failed delete on TILE load surfaces an error and stays on the drafts '
      'screen instead of silently navigating away', (tester) async {
    final gate = await pumpControllableDelete(tester);

    await tester.tap(find.text('Load'));
    await tester.pump();
    gate.complete(const UseCaseResult.failure(message: 'denied'));
    await tester.pumpAndSettle();

    expect(find.text(_errorMessage), findsOneWidget);
    expect(find.text('POS-STUB'), findsNothing);
    expect(find.text('Job Orders'), findsOneWidget);
  });

  testWidgets(
      'a failed delete on SHEET load (Load into Cart) also surfaces the error '
      'and stays — the post-await handler must use the screen context, not the '
      'popped sheet context', (tester) async {
    final gate = await pumpControllableDelete(tester);

    // Open the detail sheet (the whole tile is tappable via AppCard.onTap).
    await tester.tap(find.text('Table 9'));
    await tester.pumpAndSettle();
    expect(find.text('Load into Cart'), findsOneWidget);

    // Trigger load; the sheet pops and is fully disposed here — its
    // BuildContext is now unmounted while the delete is still pending.
    await tester.tap(find.text('Load into Cart'));
    await tester.pumpAndSettle();

    // Now resolve the delete (failure) — the handler resumes after its await.
    gate.complete(const UseCaseResult.failure(message: 'denied'));
    await tester.pumpAndSettle();

    expect(find.text(_errorMessage), findsOneWidget);
    expect(find.text('POS-STUB'), findsNothing);
    expect(find.text('Job Orders'), findsOneWidget);
  });
}
