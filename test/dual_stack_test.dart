import 'package:fit_routine/core/store.dart';
import 'package:fit_routine/data/brands.dart';
import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/engine/session_generator.dart';
import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dual-stack machine: weights, step and max are per side; one-side doubles the time', () {
    final e = GymEquipment(id: 'x', type: EquipmentType.legExtension, dualStack: true, maxWeightKg: 50);
    expect(e.effectiveBasis, 'perSide');
    expect(e.displayFactor, 0.5);
    expect(e.independentSides, isTrue);
    final g = Gym(id: 'g', name: 'g', equipment: [e]);
    final st = AppState(MemoryStore());
    expect(st.stepForGym(g)[EquipmentType.legExtension], 10); // 한쪽 5kg × 2
    expect(st.maxForGym(g)[EquipmentType.legExtension], 100); // 한쪽 50kg × 2
    expect(GymEquipment.fromJson(e.toJson()).dualStack, isTrue);

    PlannedExercise pe({bool one = false}) => PlannedExercise(
        exerciseId: 'leg_ext', equipmentType: EquipmentType.legExtension, restSeconds: 60,
        sets: [SetEntry(targetReps: 12, targetWeight: 50)], oneSide: one);
    expect(SessionGenerator.estimateMinutes([pe(one: true)]), greaterThan(SessionGenerator.estimateMinutes([pe()])));
    expect(PlannedExercise.fromJson(pe(one: true).toJson()).oneSide, isTrue);
  });

  test('dumbbells default to 1kg steps', () {
    expect(GymEquipment(id: 'd', type: EquipmentType.dumbbell).effectiveStep, 1);
  });

  test('lying chest press machine exists and is used', () {
    expect(exerciseById('lying_chest_press_m')!.canDoWith({EquipmentType.lyingChestPress}), isTrue);
    expect(exercisesForTypes({EquipmentType.lyingChestPress}).map((e) => e.id), contains('lying_chest_press_m'));
  });

  test('researched brand line-ups are in, e.g. Hammer Strength hip thrust', () {
    final hammer = brandByKey('hammer')!;
    expect(hammer.models.any((m) => m.type == EquipmentType.hipThrust), isTrue);
    expect(hammer.badgeName, 'Hammer Strength');
    expect(equipmentBrands.length, greaterThanOrEqualTo(19));
    expect(equipmentBrands.fold<int>(0, (a, b) => a + b.models.length), greaterThan(1000));
    expect(brandByKey('lexco')!.models.any((m) => m.type == EquipmentType.lyingChestPress), isTrue);
  });
}

