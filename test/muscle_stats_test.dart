import 'package:flutter_test/flutter_test.dart';

import 'package:fit_routine/data/body_model.dart';
import 'package:fit_routine/engine/muscle_stats.dart';
import 'package:fit_routine/models/models.dart';

void main() {
  PlannedExercise pe(String id, EquipmentType t, int sets, double w, int reps, {CardioStats? cardio}) => PlannedExercise(
        exerciseId: id,
        equipmentType: t,
        restSeconds: 90,
        cardio: cardio,
        sets: List.generate(sets, (_) => SetEntry(targetReps: reps, targetWeight: w)..completed = true),
      );
  DayPlan day(String id, DateTime d, List<PlannedExercise> ex) => DayPlan(
        id: id,
        userId: 'u',
        date: d,
        kind: DayKind.workout,
        focus: [MuscleGroup.chest],
        exercises: ex,
        finishedAt: d.add(const Duration(hours: 20)),
      );

  test('주동근은 세트×1.0, 보조근은 ×0.4로 집계되고 열지도는 최대 1', () {
    final plans = [
      day('a', DateTime(2026, 10, 20), [pe('bb_bench', EquipmentType.barbell, 3, 60, 10)]),
    ];
    final st = MuscleStats.compute(plans, from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 27));
    final chest = st.scores[Muscle.chestMid]!;
    expect(chest.primarySets, 3);
    expect(chest.score, 3);
    // 벤치프레스 보조근: 삼두·전면 어깨
    expect(st.scores[Muscle.triceps]!.secondarySets, closeTo(1.2, 1e-9));
    expect(st.scores[Muscle.deltFront]!.secondarySets, closeTo(1.2, 1e-9));
    expect(st.heat[Muscle.chestMid], 1.0);
    expect(st.heat[Muscle.triceps]!, lessThan(0.5));
    expect(st.ranked.first.muscle, Muscle.chestMid);
    expect(chest.byExercise.keys.single, '바벨 벤치프레스');
    expect(st.sessions, 1);
    expect(st.statusOf(Muscle.chestMid), MuscleStatus.unknown); // 세션 2회 미만
  });

  test('유산소는 20분≈1세트, 워치 평균 심박으로 0.6~1.4배 보정하고 워치 합계를 모은다', () {
    final hard = CardioStats(durationSec: 40 * 60, avgHr: 168, maxHr: 185, activeKcal: 420, distanceKm: 6.2);
    final plans = [
      day('a', DateTime(2026, 10, 20), [pe('treadmill_run', EquipmentType.treadmill, 1, 0, 40, cardio: hard)]),
      day('b', DateTime(2026, 10, 22), [pe('treadmill_run', EquipmentType.treadmill, 1, 0, 40)]),
    ];
    final st = MuscleStats.compute(plans, from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 27));
    final quads = st.scores[Muscle.quads]!;
    // 40분/20 = 2세트: 첫날은 ×1.2(168/140), 둘째 날은 ×1.0 → 주동근이면 2.4 + 2.0
    expect(quads.cardioSets, closeTo(4.4, 1e-9));
    expect(quads.primarySets, 0);
    expect(st.watch.sessions, 1);
    expect(st.watch.avgHr, 168);
    expect(st.watch.maxHr, 185);
    expect(st.watch.activeKcal, 420);
    expect(st.watch.distanceKm, closeTo(6.2, 1e-9));
    expect(st.statusOf(Muscle.quads), isNot(MuscleStatus.unknown));
  });
}
