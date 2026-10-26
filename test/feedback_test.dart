import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/engine/planner.dart';
import 'package:fit_routine/engine/session_generator.dart';
import 'package:fit_routine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

const _gym = {
  EquipmentType.bodyweight, EquipmentType.barbell, EquipmentType.dumbbell, EquipmentType.flatBench,
  EquipmentType.inclineBench, EquipmentType.squatRack, EquipmentType.cableMachine, EquipmentType.latPulldown,
  EquipmentType.seatedRow, EquipmentType.legPress, EquipmentType.legExtension, EquipmentType.legCurl,
  EquipmentType.chestPress, EquipmentType.shoulderPress, EquipmentType.pullUpBar,
};

var _n = 0;
String _id() => 'id${_n++}';

void main() {
  test('short session on a full-body day still covers every planned body part', () {
    final groups = [MuscleGroup.legs, MuscleGroup.chest, MuscleGroup.back, MuscleGroup.shoulder, MuscleGroup.arms, MuscleGroup.abs];
    final out = SessionGenerator(SessionRequest(
      groups: groups,
      available: _gym,
      progress: {},
      profile: UserProfile(id: 'u', name: 'x', includeCardio: false, warmupMode: 'off'),
      minutesBudget: 30,
    )).generate();
    final covered = out.map((e) => e.effectiveGroup).toSet();
    expect(covered, containsAll(groups));
  });

  test('the same exercise is avoided on back-to-back days', () {
    final u = UserProfile(id: 'u', name: 'x', splitDays: 1, includeCardio: false, warmupMode: 'off');
    final plans = Planner(PlannerInput(
      profile: u, from: DateTime(2026, 10, 26), to: DateTime(2026, 10, 27), restDays: const {},
      available: _gym, progress: {}, history: [], newId: _id,
    )).build();
    final a = plans[0].exercises.map((e) => e.exerciseId).toSet();
    final b = plans[1].exercises.map((e) => e.exerciseId).toSet();
    expect(a.intersection(b).length, lessThan(a.length ~/ 2 + 1));
  });

  test('pinned exercises survive a rebuild', () {
    final pin = PlannedExercise(exerciseId: 'hip_thrust', equipmentType: EquipmentType.barbell, restSeconds: 90,
        sets: [SetEntry(targetReps: 10, targetWeight: 80)], pinned: true);
    final out = SessionGenerator(SessionRequest(
      groups: [MuscleGroup.legs], available: _gym, progress: {},
      profile: UserProfile(id: 'u', name: 'x', includeCardio: false, warmupMode: 'off'),
      minutesBudget: 60, pinned: [pin],
    )).generate();
    expect(out.any((e) => e.exerciseId == 'hip_thrust' && e.pinned), isTrue);
  });

  test('custom warm-ups follow the day body part', () {
    final u = UserProfile(id: 'u', name: 'x', includeCardio: false, warmupMode: 'custom',
        warmupIds: ['dyn_stretch'], warmupByGroupIds: {'back': ['db_pullover'], 'legs': ['hip_abduction']});
    List<String> warm(List<MuscleGroup> g) => SessionGenerator(SessionRequest(
          groups: g, available: {..._gym, EquipmentType.hipAbductor}, progress: {}, profile: u, minutesBudget: 60,
        )).generate().where((e) => e.warmup).map((e) => e.exerciseId).toList();
    expect(warm([MuscleGroup.back]), containsAll(['dyn_stretch', 'db_pullover']));
    expect(warm([MuscleGroup.back]), isNot(contains('hip_abduction')));
    expect(warm([MuscleGroup.legs]), contains('hip_abduction'));
    expect(UserProfile.fromJson(u.toJson()).warmupByGroupIds['back'], ['db_pullover']);
  });

  test('weight basis converts between per-side and total display', () {
    expect(GymEquipment(id: 'a', type: EquipmentType.dumbbell).displayFactor, 1);
    expect(GymEquipment(id: 'a', type: EquipmentType.dumbbell, weightBasis: 'total').displayFactor, 2);
    expect(GymEquipment(id: 'b', type: EquipmentType.chestPressPlateLoaded, weightBasis: 'perSide').displayFactor, 0.5);
    expect(GymEquipment(id: 'b', type: EquipmentType.chestPressPlateLoaded).displayFactor, 1);
    expect(GymEquipment.fromJson(GymEquipment(id: 'c', type: EquipmentType.legPress, weightBasis: 'perSide').toJson()).weightBasis, 'perSide');
    expect(exerciseById('hip_thrust'), isNotNull);
  });
}
