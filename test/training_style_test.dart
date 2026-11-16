import 'package:fit_routine/engine/training_style.dart';
import 'package:fit_routine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 16);

  DayPlan day(int ago, List<(String, EquipmentType, List<(double, int)>)> ex, {int? rpe}) => DayPlan(
        id: 'd$ago',
        userId: 'u',
        date: now.subtract(Duration(days: ago)),
        kind: DayKind.workout,
        focus: const [],
        title: '',
        finishedAt: now.subtract(Duration(days: ago)),
        exercises: [
          for (final (id, t, sets) in ex)
            PlannedExercise(exerciseId: id, equipmentType: t, restSeconds: 90, sets: [
              for (final (w, r) in sets) SetEntry(targetReps: r, targetWeight: w)..completed = true,
            ]),
        ],
      )..rpe = rpe;

  test('프로필만 있으면: 근력 남성은 웨이트·고강도, 다이어트는 유산소 쪽·가볍게', () {
    final lifter = UserProfile(id: 'a', name: 'a', goal: TrainingGoal.strength, level: TrainingLevel.advanced, levelAuto: false);
    final diet = UserProfile(id: 'b', name: 'b', sex: Sex.female, goal: TrainingGoal.fatLoss, level: TrainingLevel.beginner, levelAuto: false);
    final a = TrainingStyle.of(lifter, const []);
    final b = TrainingStyle.of(diet, const []);
    expect(a.x, greaterThan(b.x));
    expect(a.sessions, 0);
    expect(TrainingStyle.of(diet, const []).x, lessThan(50));
  });

  test('기록 8회면 기록만으로: 저반복 바벨 → 헤비 리프터, 유산소만 → 유산소 쪽', () {
    final p = UserProfile(id: 'c', name: 'c', goal: TrainingGoal.fatLoss);
    final heavy = [
      for (var i = 0; i < 8; i++) day(i * 3, [('bb_squat', EquipmentType.squatRack, [(140, 4), (140, 4), (140, 4)]), ('deadlift', EquipmentType.barbell, [(180, 3), (180, 3)])], rpe: 9),
    ];
    final s = TrainingStyle.of(p, heavy, now: now);
    expect(s.dataWeight, 1);
    expect(s.zone, StyleZone.heavyLifter);

    final cardio = [for (var i = 0; i < 8; i++) day(i * 3, [('treadmill_walk', EquipmentType.treadmill, [(0, 40)])], rpe: 3)];
    final c = TrainingStyle.of(p, cardio, now: now);
    expect(c.x, lessThan(35));
    expect(c.zone, StyleZone.healingWalker);
  });

  test('함께 성향은 평균, 차이가 크면 궁합 문구가 달라진다', () {
    const a = TrainingStyle(90, 80), b = TrainingStyle(20, 20);
    final t = TrainingStyle.combine([a, b]);
    expect(t.x, 55);
    expect(t.zone, StyleZone.allRounder);
    expect(TrainingStyle.chemistry([a, b]), contains('차이 큼'));
    expect(TrainingStyle.chemistry([a, const TrainingStyle(85, 78)]), contains('찰떡'));
    expect(TrainingStyle.fromJson(a.toJson())!.x, 90);
  });
}
