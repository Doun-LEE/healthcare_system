import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/engine/session_generator.dart';
import 'package:fit_routine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

PlannedExercise _pe(String id, EquipmentType eq) => PlannedExercise(
      exerciseId: id,
      equipmentType: eq,
      restSeconds: 60,
      sets: [SetEntry(targetReps: 10, targetWeight: 20)],
    );

void main() {
  final picked = [
    _pe('lateral_raise', EquipmentType.dumbbell), // 어깨 고립
    _pe('bb_bench', EquipmentType.barbell), // 가슴 복합
    _pe('crunch', EquipmentType.bodyweight), // 복근
    _pe('treadmill_run', EquipmentType.treadmill), // 유산소
    _pe('ohp', EquipmentType.barbell), // 어깨 복합
    _pe('bb_squat', EquipmentType.barbell), // 하체 복합
  ];

  test('default order: upper compound first, then isolation, lower, abs, cardio', () {
    final p = UserProfile(id: 'u', name: 'x');
    final out = SessionGenerator.orderForSession(picked, p).map((e) => e.exerciseId).toList();
    expect(out, ['bb_bench', 'ohp', 'lateral_raise', 'bb_squat', 'crunch', 'treadmill_run']);
  });

  test('section order preference moves cardio first', () {
    final p = UserProfile(id: 'u', name: 'x', sectionOrder: ['cardio', 'abs', 'upper', 'lower']);
    final out = SessionGenerator.orderForSession(picked, p).map((e) => e.exerciseId).toList();
    expect(out.first, 'treadmill_run');
    expect(out[1], 'crunch');
  });

  test('learned group/exercise rank overrides default within weights', () {
    final p = UserProfile(
      id: 'u',
      name: 'x',
      groupRank: {'shoulder': 0.0, 'chest': 1.0},
      exerciseRank: {'lateral_raise': 0.0, 'ohp': 1.0},
    );
    final out = SessionGenerator.orderForSession(picked, p).map((e) => e.exerciseId).toList();
    expect(out.take(3).toList(), ['lateral_raise', 'ohp', 'bb_bench']);
  });

  test('profile JSON keeps section order and learned ranks', () {
    final p = UserProfile(id: 'u', name: 'x', sectionOrder: ['abs', 'upper', 'lower', 'cardio'], exerciseRank: {'ohp': 0.5});
    final j = UserProfile.fromJson(p.toJson());
    expect(j.sectionOrder, ['abs', 'upper', 'lower', 'cardio']);
    expect(j.exerciseRank['ohp'], 0.5);
    // 예전 startWith 값은 구역 순서로 옮겨진다.
    final old = UserProfile.fromJson({...p.toJson()}..remove('sectionOrder')..['startWith'] = 'cardio');
    expect(old.sectionOrder.first, 'cardio');
  });

  test('planExercise prescribes exactly the requested exercise (add/swap bug)', () {
    final p = UserProfile(id: 'u', name: 'x');
    final gen = SessionGenerator(SessionRequest(
      groups: [MuscleGroup.back],
      available: {EquipmentType.barbell, EquipmentType.squatRack, EquipmentType.highRow, EquipmentType.cableMachine},
      progress: {},
      profile: p,
      minutesBudget: 60,
    ));
    for (final id in ['rack_pull', 'face_pull', 'bb_row']) {
      final planned = gen.planExercise(exerciseById(id)!);
      expect(planned.exerciseId, id);
      expect(planned.sets, isNotEmpty);
    }
  });
}
