import 'package:flutter_test/flutter_test.dart';

import 'package:fit_routine/data/body_model.dart';
import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/engine/session_generator.dart';
import 'package:fit_routine/models/models.dart';

void main() {
  final profile = UserProfile(id: 'u', name: '테스트', level: TrainingLevel.intermediate);
  final bench = exerciseById('bb_bench')!;

  test('덜 회복된 주동근(60% 미만)은 세트 -1, 무게 90%, 메모에 표시', () {
    SessionRequest req(Map<Muscle, double> rec) => SessionRequest(
          groups: [MuscleGroup.chest],
          available: {EquipmentType.barbell, EquipmentType.flatBench},
          progress: {'bb_bench': ExerciseProgress(exerciseId: 'bb_bench', workingWeight: 80, targetReps: 8)},
          profile: profile,
          minutesBudget: 60,
          recovery: rec,
        );
    final fresh = SessionGenerator(req({})).planExercise(bench);
    final tired = SessionGenerator(req({Muscle.chestMid: 0.3})).planExercise(bench);
    expect(tired.sets.length, fresh.sets.length - 1);
    expect(tired.sets.first.targetWeight, lessThan(fresh.sets.first.targetWeight));
    expect(tired.note, contains('회복 중'));
    expect(fresh.note, isNot(contains('회복 중')));
  });

  test('부족한 근육(boost)을 주동근으로 쓰는 운동이 우선 뽑힌다', () {
    List<String> pick(Set<Muscle> boost) => SessionGenerator(SessionRequest(
          groups: [MuscleGroup.shoulder],
          available: {EquipmentType.dumbbell, EquipmentType.barbell, EquipmentType.cableMachine, EquipmentType.flatBench},
          progress: const {},
          profile: profile,
          minutesBudget: 40,
          seed: 1,
          boost: boost,
        )).generate().where((e) => !e.warmup).map((e) => e.exerciseId).toList();
    final plain = pick({});
    final boosted = pick({Muscle.deltRear});
    final rearFirst = boosted.indexWhere((id) => musclesFor(exerciseById(id)!).primary.contains(Muscle.deltRear));
    final rearPlain = plain.indexWhere((id) => musclesFor(exerciseById(id)!).primary.contains(Muscle.deltRear));
    expect(rearFirst, isNot(-1));
    expect(rearPlain == -1 || rearFirst <= rearPlain, isTrue);
  });
}
