import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/engine/session_generator.dart';
import 'package:fit_routine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final gym = {for (final t in EquipmentType.values) t};

  int barbellCount(UserProfile p) {
    var n = 0;
    for (var seed = 0; seed < 10; seed++) {
      final out = SessionGenerator(SessionRequest(
        groups: [MuscleGroup.legs, MuscleGroup.chest, MuscleGroup.back],
        available: gym,
        progress: const {},
        profile: p,
        minutesBudget: 60,
        seed: seed,
      )).generate();
      n += out.where((e) => !e.warmup && exerciseById(e.exerciseId)?.loadType == LoadType.barbell).length;
    }
    return n;
  }

  test('여성·다이어트는 바벨 운동이 근비대 목표보다 훨씬 적게, 세트는 3세트 이하', () {
    final diet = UserProfile(id: 'w', name: 'w', sex: Sex.female, heightCm: 162, weightKg: 58, goal: TrainingGoal.fatLoss);
    final hyper = UserProfile(id: 'w2', name: 'w2', sex: Sex.female, heightCm: 162, weightKg: 58);
    expect(barbellCount(diet), lessThan(barbellCount(hyper)));
    final out = SessionGenerator(SessionRequest(
      groups: [MuscleGroup.legs, MuscleGroup.back],
      available: gym,
      progress: const {},
      profile: diet,
      minutesBudget: 60,
      seed: 1,
    )).generate();
    for (final e in out.where((e) => !e.warmup)) {
      expect(e.sets.length, lessThanOrEqualTo(3), reason: e.exerciseId);
    }
  });

  test('시간이 적으면 활성화 워밍업 없이 본 세트 위주', () {
    expect(SessionGenerator.activationCap(40), 0);
    expect(SessionGenerator.activationCap(60), 1);
    expect(SessionGenerator.activationCap(150), 3);
    final out = SessionGenerator(SessionRequest(
      groups: [MuscleGroup.chest, MuscleGroup.arms],
      available: gym,
      progress: const {},
      profile: UserProfile(id: 'u', name: 'u'),
      minutesBudget: 40,
      seed: 1,
    )).generate();
    expect(out.where((e) => e.warmup && !stretchIds.contains(e.exerciseId)), isEmpty);
  });
}
