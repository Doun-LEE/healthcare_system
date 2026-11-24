import 'package:fit_routine/core/store.dart';
import 'package:fit_routine/engine/plateau.dart';
import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

DayPlan done(DateTime d, String id, double w, int reps, {int? rpe}) => DayPlan(
      id: 'p${d.millisecondsSinceEpoch}$id',
      userId: 'u',
      date: d,
      kind: DayKind.workout,
      focus: const [MuscleGroup.chest],
      exercises: [
        PlannedExercise(exerciseId: id, equipmentType: EquipmentType.barbell, restSeconds: 120, sets: [
          for (var i = 0; i < 3; i++) SetEntry(targetReps: reps, targetWeight: w, completed: true),
        ]),
      ],
      estimatedMinutes: 40,
      finishedAt: d,
      rpe: rpe,
    );

void main() {
  final now = DateTime(2026, 11, 24);
  DateTime ago(int d) => now.subtract(Duration(days: d));

  test('정체기: 최고 기록 뒤 3주·3번 넘게 못 넘으면', () {
    final plans = [
      done(ago(50), 'bb_bench', 70, 8),
      done(ago(43), 'bb_bench', 75, 8),
      done(ago(36), 'bb_bench', 80, 8), // 최고
      done(ago(29), 'bb_bench', 80, 7),
      done(ago(22), 'bb_bench', 80, 8),
      done(ago(15), 'bb_bench', 77.5, 8),
      done(ago(8), 'bb_bench', 80, 6),
    ];
    final p = findPlateaus(plans, now);
    expect(p.length, 1);
    expect(p.first.exerciseId, 'bb_bench');
    expect(p.first.since, 4);
    // 계속 오르면 정체기 아님
    final up = [for (var i = 0; i < 6; i++) done(ago(42 - i * 7), 'bb_bench', 70.0 + i * 2.5, 8)];
    expect(findPlateaus(up, now), isEmpty);
    // 낮춰서 다시 쌓기 한 뒤 기록만 보면 아직 판단 안 함
    expect(findPlateaus(plans, now, resetAt: {'bb_bench': ago(10)}), isEmpty);
  });

  test('디로드 추천: 주 운동 둘이 정체', () {
    final plans = <DayPlan>[];
    for (final id in ['bb_bench', 'bb_squat']) {
      for (var i = 0; i < 7; i++) {
        plans.add(done(ago(50 - i * 7), id, i < 2 ? 70 : 80, 8));
      }
    }
    final a = deloadAdvice(plans, now);
    expect(a.recommended, isTrue);
    expect(deloadAdvice(plans, now, lastDeloadEnd: ago(10)).recommended, isFalse);
  });

  test('디로드 주: 세트·무게를 줄이고 그만하면 되돌린다', () async {
    final store = MemoryStore();
    final eq = [for (final t in EquipmentType.values) GymEquipment(id: t.name, type: t)];
    await store.save(AppData(
      currentUserId: 'u',
      profiles: [UserProfile(id: 'u', name: 'a', onboarded: true, splitDays: 3)],
      gyms: [Gym(id: 'g1', name: 'A', equipment: eq)],
    ));
    final s = AppState(store);
    await s.load();
    await s.generatePlans(from: s.today, to: s.today.add(const Duration(days: 6)), restDays: {});
    final p = [for (var i = 0; i < 7; i++) s.planOn(s.today.add(Duration(days: i)))].whereType<DayPlan>().firstWhere((p) => !p.isRest);
    final pe = p.exercises.firstWhere((e) => !e.warmup && e.cardio == null && e.sets.length >= 3 && e.topSet.targetWeight > 0);
    final n = pe.sets.length;
    final w = pe.topSet.targetWeight;
    await s.startDeload();
    expect(s.deloading, isTrue);
    final pe2 = p.exercises.firstWhere((e) => e.exerciseId == pe.exerciseId);
    expect(pe2.sets.length, lessThan(n));
    expect(pe2.topSet.targetWeight, lessThanOrEqualTo(w));
    expect(p.alcLoad, closeTo(deloadLoad, 0.001));
    // 저장·복원
    expect(UserProfile.fromJson(s.currentUser!.toJson()).deloadTo, isNotNull);
    await s.endDeload();
    expect(s.deloading, isFalse);
    final pe3 = p.exercises.firstWhere((e) => e.exerciseId == pe.exerciseId);
    expect(pe3.sets.length, n);
    expect(p.alcLoad, 1.0);
  });
}
