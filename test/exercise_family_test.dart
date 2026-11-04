import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/engine/progression.dart';
import 'package:fit_routine/engine/session_generator.dart';
import 'package:fit_routine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

List<PlannedExercise> _gen(Gym gym, List<MuscleGroup> groups, {Set<String> avoid = const {}, int seed = 0}) =>
    SessionGenerator(SessionRequest(
      groups: groups,
      available: gym.availableTypes,
      progress: {},
      profile: UserProfile(id: 'u', name: 'u', includeCardio: false, warmupMode: 'off'),
      minutesBudget: 90,
      seed: seed,
      now: DateTime(2026, 11, 4),
      avoidIds: avoid,
    )).generate();

Gym _gym(List<EquipmentType> types) =>
    Gym(id: 'g', name: 'g', equipment: [for (var i = 0; i < types.length; i++) GymEquipment(id: '$i', type: types[i])]);

void main() {
  final multi = _gym([EquipmentType.multiStation, EquipmentType.dumbbell, EquipmentType.flatBench, EquipmentType.dipStation]);
  final machines = _gym([
    EquipmentType.multiStation, EquipmentType.dumbbell, EquipmentType.flatBench, EquipmentType.dipStation,
    EquipmentType.pecDeck, EquipmentType.bicepCurlMachine, EquipmentType.tricepExtensionMachine,
  ]);

  test('같은 계열(딥스·플라이·레그 컬)은 한 세션에 하나만', () {
    for (final gym in [multi, machines]) {
      for (var seed = 0; seed < 5; seed++) {
        for (final groups in [
          [MuscleGroup.chest, MuscleGroup.arms],
          [MuscleGroup.chest, MuscleGroup.back, MuscleGroup.legs, MuscleGroup.shoulder, MuscleGroup.arms],
          [MuscleGroup.legs],
        ]) {
          final fams = [for (final e in _gen(gym, groups, seed: seed)) familyOf(e.exerciseId)];
          expect(fams.toSet().length, fams.length, reason: '$groups seed $seed: $fams');
        }
      }
    }
  });

  test('전용 머신이 있으면 머신, 멀티스테이션만 있으면 케이블로 대체', () {
    final withMachine = _gen(machines, [MuscleGroup.chest, MuscleGroup.arms]).map((e) => e.exerciseId).toList();
    expect(withMachine, isNot(contains('cable_fly')));
    expect(withMachine, isNot(contains('tri_pushdown')));
    expect(withMachine, contains('tri_ext_m'));

    final onlyMulti = _gen(multi, [MuscleGroup.back, MuscleGroup.arms]).map((e) => e.exerciseId).toList();
    expect(onlyMulti.any((id) => exerciseById(id)!.equipment.contains(EquipmentType.cableMachine)), isTrue);
  });

  test('멀티스테이션만 있어도 케이블 팔 운동(오버헤드 익스텐션 등)이 뽑힌다', () {
    final ids = _gen(multi, [MuscleGroup.arms]).map((e) => e.exerciseId).toList();
    expect(ids, contains('overhead_tri'));
  });

  test('직전 운동일에 레그 컬을 했으면 라잉 레그 컬도 피한다', () {
    final legs = _gym([EquipmentType.legCurl, EquipmentType.lyingLegCurl, EquipmentType.legPress, EquipmentType.legExtension, EquipmentType.dumbbell, EquipmentType.barbell, EquipmentType.squatRack]);
    for (var seed = 0; seed < 5; seed++) {
      final ids = _gen(legs, [MuscleGroup.legs], avoid: {'leg_curl'}, seed: seed).map((e) => e.exerciseId);
      expect(ids, isNot(contains('lying_leg_curl')), reason: 'seed $seed: $ids');
    }
  });

  test('라잉 인클라인 체스트 프레스 기구·운동이 있다', () {
    final ex = exerciseById('lying_incline_press_m')!;
    expect(ex.canDoWith(_gym([EquipmentType.lyingInclinePress]).availableTypes), isTrue);
    expect(exerciseById('cs_row_m')!.name, '시티드 로우 머신');
  });

  test('유산소 구간별 레벨: 시간 가중 평균 레벨, 총 시간으로 완주 판단', () {
    final pe = PlannedExercise(exerciseId: 'stairs', equipmentType: EquipmentType.stairClimber, restSeconds: 0, sets: [
      SetEntry(targetReps: 20, targetWeight: 0, level: 8, doneReps: 10, completed: true),
      SetEntry(targetReps: 5, targetWeight: 0, level: 8, doneReps: 10, doneLevel: 12, completed: true, extra: true),
    ]);
    final prog = ExerciseProgress(exerciseId: 'stairs', workingWeight: 0, targetReps: 20, level: 8);
    final r = Progression.apply(pe, prog, DateTime(2026, 11, 4));
    expect(r.progress.consecutiveSuccess, 1, reason: '10분+10분 = 목표 20분 완주');
    expect(r.progress.level, anyOf(10, 11), reason: '8(10분)·12(10분) 평균 10 → 완주로 다음 단계일 수 있음');
  });
}
