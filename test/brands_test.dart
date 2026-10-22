import 'package:fit_routine/data/brands.dart';
import 'package:fit_routine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every brand has models and brand search works', () {
    expect(equipmentBrands, isNotEmpty);
    for (final b in equipmentBrands) {
      expect(b.models, isNotEmpty, reason: b.name);
    }
    expect(equipmentBrands.where((b) => b.matches('디렉스')), isNotEmpty);
    expect(equipmentBrands.where((b) => b.matches('hammer')), isNotEmpty);
  });

  test('combo machine contributes all its types to the gym and survives JSON', () {
    final eq = GymEquipment(id: 'e', type: EquipmentType.legExtension, customName: '레그 익스텐션/컬', extraTypes: [EquipmentType.legCurl]);
    final gym = Gym(id: 'g', name: 'x', equipment: [eq]);
    expect(gym.availableTypes, containsAll([EquipmentType.legExtension, EquipmentType.legCurl]));
    final back = GymEquipment.fromJson(eq.toJson());
    expect(back.extraTypes, [EquipmentType.legCurl]);
    expect(back.customName, '레그 익스텐션/컬');
  });
}
