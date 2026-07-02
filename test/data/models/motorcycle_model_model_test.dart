import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/motorcycle_model_name.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  test('fromMap/toEntity round-trip', () {
    final m = MotorcycleModelModel.fromMap(
      {'name': 'Nmax', 'isActive': true},
      'id1',
    );
    expect(m.name, 'Nmax');
    expect(m.isActive, isTrue);
    expect(m.toEntity().name, 'Nmax');
  });

  test('toMap writes a normalizedName dedup key', () {
    final m = MotorcycleModelModel.fromEntity(
      MotorcycleModelEntity(
        id: 'x',
        name: 'Click 125i',
        isActive: true,
        createdAt: DateTime(2026, 7, 1),
      ),
    );
    expect(m.toMap()['normalizedName'], normalizedModelKey('Click 125i'));
    expect(m.toMap()['name'], 'Click 125i');
  });
}
