import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/receiving/bulk_receiving_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

/// A CurrentReceivingNotifier whose initNewReceiving always throws. Starts in
/// isLoading=true so the screen stays on the lightweight skeleton branch of
/// build() (no supplier/product providers to stub). Other notifier members are
/// unused in that branch and route through noSuchMethod.
class _ThrowingReceivingNotifier extends StateNotifier<CurrentReceivingState>
    implements CurrentReceivingNotifier {
  _ThrowingReceivingNotifier() : super(const CurrentReceivingState(isLoading: true));

  @override
  Future<void> initNewReceiving() async => throw Exception('boom');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('shows an error snackbar when initNewReceiving fails', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentReceivingProvider
              .overrideWith((ref) => _ThrowingReceivingNotifier()),
          currentUserProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(home: BulkReceivingScreen()),
      ),
    );
    // Can't pumpAndSettle: the isLoading skeleton shimmers forever. Pump a few
    // frames so the postFrame callback runs, the async initNewReceiving error
    // propagates to the catch, and the snackbar is inserted.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      find.textContaining('Could not start a new receiving'),
      findsOneWidget,
    );
  });
}
