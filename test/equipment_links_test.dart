import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _ids(EquipmentType t) => [for (final e in exercisesForTypes({t, ...?impliedEquipment[t]})) e.id];

void main() {
  test('every machine you can register shows at least one exercise', () {
    for (final t in EquipmentType.values) {
      expect(_ids(t), isNotEmpty, reason: '${t.label}로 하는 운동이 없음');
    }
  });

  test('combo machines and racks list what they really do', () {
    expect(_ids(EquipmentType.functionalTrainer), containsAll(['cable_fly', 'tri_pushdown', 'face_pull']));
    expect(_ids(EquipmentType.halfRack), containsAll(['bb_squat', 'ohp']));
    expect(_ids(EquipmentType.multiStation), containsAll(['lat_pulldown', 'leg_ext', 'chest_press_m']));
    expect(_ids(EquipmentType.assistedPullUp), containsAll(['assisted_pullup', 'assisted_dip', 'chinup']));
    expect(_ids(EquipmentType.multiHip), containsAll(['hip_abduction', 'hip_adduction', 'glute_kickback_m']));
    expect(_ids(EquipmentType.inclineBench), containsAll(['incline_db', 'incline_db_row', 'y_raise']));
    expect(_ids(EquipmentType.pool), contains('swim'));
  });

  test('dumbbell-on-bench moves need both, and use dumbbell weights', () {
    final incline = exerciseById('incline_db')!;
    expect(incline.canDoWith({EquipmentType.inclineBench}), isFalse);
    expect(incline.canDoWith({EquipmentType.dumbbell}), isFalse);
    expect(incline.canDoWith({EquipmentType.dumbbell, EquipmentType.inclineBench}), isTrue);
    expect(incline.pickEquipment({EquipmentType.dumbbell, EquipmentType.inclineBench}), EquipmentType.dumbbell);
    final g = Gym(id: 'g', name: 'x', equipment: [GymEquipment(id: 'a', type: EquipmentType.multiHip)]);
    expect(exerciseById('hip_abduction')!.canDoWith(g.availableTypes), isTrue);
  });
}
