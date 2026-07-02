import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  test('copyWith + props + empty', () {
    final m = MotorcycleModelEntity(
      id: '1',
      name: 'Nmax',
      isActive: true,
      createdAt: DateTime(2026, 7, 1),
    );
    expect(m.copyWith(name: 'Aerox').name, 'Aerox');
    expect(m.copyWith(isActive: false).isActive, isFalse);
    expect(m == m.copyWith(), isTrue);
    expect(MotorcycleModelEntity.empty().name, '');
  });
}
