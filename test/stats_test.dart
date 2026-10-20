import 'package:fit_routine/engine/stats.dart';
import 'package:fit_routine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

DayPlan _session(DateTime date, Map<String, List<(double, int)>> sets, {int? rpe}) {
  final exercises = <PlannedExercise>[];
  sets.forEach((id, list) {
    exercises.add(PlannedExercise(
      exerciseId: id,
      equipmentType: EquipmentType.barbell,
      restSeconds: 90,
      sets: [for (final (w, r) in list) SetEntry(targetReps: r, targetWeight: w, completed: true)],
    ));
  });
  return DayPlan(
    id: 'p${date.day}',
    userId: 'u',
    date: date,
    kind: DayKind.workout,
    focus: const [],
    exercises: exercises,
    rpe: rpe,
    finishedAt: date.add(const Duration(hours: 20)),
  );
}

void main() {
  test('summary aggregates sets, tonnage, rpe and finds under-trained groups', () {
    final now = DateTime(2026, 10, 21);
    final plans = [
      _session(DateTime(2026, 10, 14), {'bb_bench': [(60, 10), (60, 10), (60, 10)], 'tri_pushdown': [(20, 12)]}, rpe: 6),
      _session(DateTime(2026, 10, 16), {'bb_bench': [(62.5, 10), (62.5, 10)], 'lat_pulldown': [(50, 10), (50, 10), (50, 10)]}, rpe: 8),
      _session(DateTime(2026, 10, 19), {'bb_bench': [(65, 8), (65, 8), (65, 8)], 'treadmill_walk': [(0, 20)]}),
      // 기간 밖
      _session(DateTime(2026, 8, 1), {'bb_squat': [(100, 5)]}),
      // 미완료
      DayPlan(id: 'x', userId: 'u', date: DateTime(2026, 10, 20), kind: DayKind.workout, focus: const []),
    ];
    final s = Stats.summarize(plans, days: 28, now: now);
    expect(s.sessions, 3);
    expect(s.totalSets, 3 + 1 + 2 + 3 + 3); // 유산소 제외
    expect(s.totalTonnage, 60 * 30 + 20 * 12 + 62.5 * 20 + 50 * 30 + 65 * 24);
    expect(s.avgRpe, 7);
    expect(s.cardioMinutes, 20);
    expect(s.groups.firstWhere((g) => g.group == MuscleGroup.chest).sets, 8);
    expect(s.underTrained, contains(MuscleGroup.legs));
    expect(s.underTrained, isNot(contains(MuscleGroup.chest)));
    expect(s.mostTrained, MuscleGroup.chest);
    final bench = s.trends.firstWhere((t) => t.exercise.id == 'bb_bench');
    expect(bench.points.map((p) => p.weight), [60, 62.5, 65]);
    expect(bench.delta, 5);
    expect(s.weeks.length, greaterThanOrEqualTo(4));
    expect(s.weeks.fold<int>(0, (a, w) => a + w.sessions), 3);
  });

  test('empty history gives zero summary without errors', () {
    final s = Stats.summarize(const [], days: 14);
    expect(s.sessions, 0);
    expect(s.underTrained, isEmpty);
    expect(s.trends, isEmpty);
  });
}
