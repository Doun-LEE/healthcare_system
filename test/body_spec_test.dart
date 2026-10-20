import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/engine/load_estimator.dart';
import 'package:fit_routine/engine/session_generator.dart';
import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/services/partner.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _user() => UserProfile(id: 'u', name: '테스트', weightKg: 75, heightCm: 175, age: 28);

const _gym = {
  EquipmentType.barbell,
  EquipmentType.dumbbell,
  EquipmentType.flatBench,
  EquipmentType.squatRack,
  EquipmentType.cableMachine,
  EquipmentType.latPulldown,
  EquipmentType.legPress,
  EquipmentType.legCurl,
  EquipmentType.legExtension,
  EquipmentType.bodyweight,
};

void main() {
  test('real 1RM overrides the estimate', () {
    final u = _user()..bench1rm = 100;
    final est = LoadEstimator(u);
    expect(est.oneRepMax(RefLift.bench), 100);
    expect(est.oneRepMax(RefLift.row), 90); // 벤치에서 유도
    final w = est.initialWeight(exerciseById('bb_bench')!, 10);
    expect(w, greaterThan(60)); // 100/(1+10/30)*0.9 ≈ 67.5
  });

  test('goal shifts reps and rest', () {
    final squat = exerciseById('bb_squat')!; // 5~8
    expect(LoadEstimator.targetReps(squat, TrainingLevel.beginner, TrainingGoal.strength), 5);
    expect(LoadEstimator.targetReps(squat, TrainingLevel.advanced, TrainingGoal.fatLoss), 8);
    expect(LoadEstimator.restFactor(TrainingGoal.strength), greaterThan(1));
    expect(LoadEstimator.restFactor(TrainingGoal.fatLoss), lessThan(1));

    final plan = SessionGenerator(SessionRequest(
      groups: [MuscleGroup.legs],
      available: _gym,
      progress: {},
      profile: _user()..goal = TrainingGoal.strength,
      minutesBudget: 90,
      seed: 1,
    )).generate();
    final compound = plan.firstWhere((p) => exerciseById(p.exerciseId)!.compound);
    expect(compound.restSeconds, greaterThan(restRules[MuscleGroup.legs]!.compoundRestSec));
  });

  test('injury flags exclude risky exercises', () {
    final plan = SessionGenerator(SessionRequest(
      groups: [MuscleGroup.back, MuscleGroup.legs],
      available: _gym,
      progress: {},
      profile: _user()..injuries.addAll({InjuryArea.lowerBack, InjuryArea.knee}),
      minutesBudget: 120,
      seed: 2,
    )).generate();
    final ids = plan.map((p) => p.exerciseId).toSet();
    for (final banned in ['deadlift', 'bb_row', 'bb_squat', 'lunge', 'leg_ext']) {
      expect(ids, isNot(contains(banned)), reason: '$banned 가 부상 체크에도 포함됨');
    }
    expect(plan, isNotEmpty);
  });

  test('profile JSON keeps the new fields', () {
    final u = _user()
      ..squat1rm = 120
      ..goal = TrainingGoal.fatLoss
      ..injuries.add(InjuryArea.shoulder);
    final back = UserProfile.fromJson(u.toJson());
    expect(back.squat1rm, 120);
    expect(back.goal, TrainingGoal.fatLoss);
    expect(back.injuries, {InjuryArea.shoulder});
  });

  test('partner public profile round-trips and exposes plan focus and weights', () {
    final me = _user()..bench1rm = 80;
    final plan = DayPlan(
      id: 'p',
      userId: 'u',
      date: DateTime.now(),
      kind: DayKind.workout,
      focus: [MuscleGroup.chest, MuscleGroup.arms],
      title: '밀기',
    );
    final json = PartnerProfile.build(
      uid: 'uid1',
      me: me,
      available: _gym,
      progress: {'bb_bench': ExerciseProgress(exerciseId: 'bb_bench', workingWeight: 60)},
      plans: [plan],
      email: 'a@b.c',
    );
    final pp = PartnerProfile.fromJson(json);
    expect(pp.name, '테스트');
    expect(pp.profile.bench1rm, 80);
    expect(pp.available, contains(EquipmentType.legPress));
    expect(pp.workingWeights['bb_bench'], 60);
    expect(pp.planFocus[dateKey(plan.date)], [MuscleGroup.chest, MuscleGroup.arms]);
  });
}
