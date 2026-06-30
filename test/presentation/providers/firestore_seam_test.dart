import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

void main() {
  test('productRepositoryProvider honors a firestoreProvider override', () async {
    final fake = FakeFirebaseFirestore();
    final container = ProviderContainer(
      overrides: [firestoreProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    // Before D1: the provider builds ProductRepositoryImpl() ->
    // FirebaseFirestore.instance, which throws in tests (no Firebase app).
    // After D1: it uses the injected fake and emits an empty list.
    final repo = container.read(productRepositoryProvider);
    final products = await repo.watchProducts().first;
    expect(products, isEmpty);
  });
}
