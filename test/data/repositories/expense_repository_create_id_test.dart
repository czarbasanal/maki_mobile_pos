import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/repositories/expense_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  ExpenseEntity expense({String id = ''}) => ExpenseEntity(
        id: id,
        description: 'Diesel',
        amount: 500,
        category: 'Fuel',
        date: DateTime(2026, 7, 4),
        createdAt: DateTime(2026, 7, 4),
        createdBy: 'u-1',
        createdByName: 'U',
        receiptImageUrl: id.isEmpty ? null : 'https://x/r.jpg',
      );

  test('newExpenseId returns a non-empty unique id', () {
    final repo = ExpenseRepositoryImpl(firestore: FakeFirebaseFirestore());
    final a = repo.newExpenseId();
    final b = repo.newExpenseId();
    expect(a, isNotEmpty);
    expect(a, isNot(b));
  });

  test('createExpense honors a preset id (set, not add)', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = ExpenseRepositoryImpl(firestore: firestore);
    final id = repo.newExpenseId();

    final created = await repo.createExpense(expense(id: id));

    expect(created.id, id);
    final doc = await firestore.collection('expenses').doc(id).get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['receiptImageUrl'], 'https://x/r.jpg');
  });

  test('createExpense without id still auto-generates (add path)', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = ExpenseRepositoryImpl(firestore: firestore);

    final created = await repo.createExpense(expense());

    expect(created.id, isNotEmpty);
  });
}
