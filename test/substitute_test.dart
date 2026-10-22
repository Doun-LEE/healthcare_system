import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/engine/substitute.dart';
import 'package:fit_routine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('barbell bench becomes a chest press machine when no barbell/bench', () {
    final bench = exerciseById('bb_bench')!;
    final alt = substituteFor(bench, {EquipmentType.bodyweight, EquipmentType.chestPress, EquipmentType.cableMachine});
    expect(alt, isNotNull);
    expect(alt!.group, MuscleGroup.chest);
    expect(alt.id, 'chest_press_m');
  });

  test('exercise that is still doable is returned unchanged', () {
    final squat = exerciseById('bb_squat')!;
    expect(substituteFor(squat, {EquipmentType.barbell, EquipmentType.squatRack})!.id, 'bb_squat');
  });

  test('returns null when the group has nothing doable', () {
    final pulldown = exerciseById('lat_pulldown')!;
    expect(substituteFor(pulldown, {EquipmentType.treadmill}), isNull);
  });
}
