import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/job_order_bill_out.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

DraftEntity _draft({String? model}) => DraftEntity(
      id: 'd',
      name: 'X',
      items: const [],
      motorcycleModel: model,
      createdBy: 'u',
      createdByName: 'C',
      createdAt: DateTime(2026, 7, 1),
    );

void main() {
  test('needs a non-blank motorcycle model', () {
    expect(jobOrderReadyToBillOut(_draft(model: null)), isFalse);
    expect(jobOrderReadyToBillOut(_draft(model: '  ')), isFalse);
    expect(jobOrderReadyToBillOut(_draft(model: 'Nmax')), isTrue);
  });
}
