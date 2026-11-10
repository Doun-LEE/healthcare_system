import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/engine/progression.dart';
import 'package:fit_routine/engine/session_generator.dart';
import 'package:fit_routine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bench = exerciseById('bb_bench')!;

  test('기록 없으면 복합운동은 램프업: 가볍게 시작해 본 세트로', () {
    final s = SessionGenerator.setScheme(bench, null, 4, 8, 60, 2.5);
    expect(s.map((e) => e.targetWeight), [47.5, 55, 60, 60]);
    expect(s.map((e) => e.targetReps), [10, 9, 8, 8]);
  });

  test('지난번 세트 배치를 따라가고, 못 채운 앞 세트는 올리지 않음', () {
    final prog = ExerciseProgress(exerciseId: 'bb_bench', workingWeight: 62.5, lastSets: const [
      SetRecord(reps: 12, weight: 40, target: 12),
      SetRecord(reps: 8, weight: 50, target: 10), // 못 채움
      SetRecord(reps: 8, weight: 60, target: 8),
      SetRecord(reps: 8, weight: 60, target: 8),
    ]);
    final s = SessionGenerator.setScheme(bench, prog, 4, 8, 62.5, 2.5);
    expect(s.map((e) => e.targetWeight), [42.5, 50, 62.5, 62.5]);
    expect(s.map((e) => e.targetReps), [12, 10, 8, 8]);
  });

  test('지난번 같은 무게로 했으면 계속 같은 무게', () {
    final prog = ExerciseProgress(exerciseId: 'bb_bench', workingWeight: 60, lastSets: const [
      SetRecord(reps: 8, weight: 60, target: 8),
      SetRecord(reps: 8, weight: 60, target: 8),
      SetRecord(reps: 8, weight: 60, target: 8),
    ]);
    final s = SessionGenerator.setScheme(bench, prog, 3, 8, 62.5, 2.5);
    expect(s.every((e) => e.targetWeight == 62.5), isTrue);
  });

  test('램프업 세트도 각자 목표로 판정하고 지난 세트를 기록', () {
    final pe = PlannedExercise(
      exerciseId: 'bb_bench',
      equipmentType: EquipmentType.barbell,
      restSeconds: 120,
      sets: SessionGenerator.setScheme(bench, null, 4, 8, 60, 2.5),
    );
    for (final s in pe.sets) {
      s.completed = true;
    }
    final cur = ExerciseProgress(exerciseId: 'bb_bench', workingWeight: 60, targetReps: 8);
    Progression.apply(pe, cur, DateTime(2026, 11, 6));
    expect(cur.workingWeight, 62.5);
    expect(cur.lastSets.map((s) => s.weight), [47.5, 55, 60, 60]);
    final back = ExerciseProgress.fromJson(cur.toJson());
    expect(back.lastSets.length, 4);
    expect(back.lastSets.first.target, 10);
  });

  test('선호도 JSON 저장', () {
    final u = UserProfile(id: 'u', name: 'a', exercisePref: {'shrug': -1, 'db_bench': 2});
    final back = UserProfile.fromJson(u.toJson());
    expect(back.exercisePref, {'shrug': -1.0, 'db_bench': 2.0});
    expect(exerciseById('shrug')!.niche, isTrue);
  });

  test('구역 순서만 다시 정렬: 하체 먼저면 팔보다 스쿼트가 앞, 구역 안 순서는 그대로', () {
    PlannedExercise pe(String id, EquipmentType t) => PlannedExercise(exerciseId: id, equipmentType: t, restSeconds: 60, sets: [SetEntry(targetReps: 10, targetWeight: 20)]);
    final list = [pe('ez_skull', EquipmentType.ezBar), pe('crunch', EquipmentType.bodyweight), pe('bb_squat', EquipmentType.barbell), pe('skull_crusher', EquipmentType.barbell)];
    final out = SessionGenerator.sortSections(list, ['lower', 'upper', 'abs', 'cardio']);
    expect(out.map((e) => e.exerciseId), ['bb_squat', 'ez_skull', 'skull_crusher', 'crunch']);
  });
}
