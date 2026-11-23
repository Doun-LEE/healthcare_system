import 'package:fit_routine/core/store.dart';
import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<AppState> make() async {
    final store = MemoryStore();
    final eq = [for (final t in EquipmentType.values) GymEquipment(id: t.name, type: t)];
    await store.save(AppData(
      currentUserId: 'u',
      profiles: [UserProfile(id: 'u', name: 'a', onboarded: true, splitDays: 3)],
      gyms: [Gym(id: 'g1', name: 'A', equipment: eq)],
    ));
    final s = AppState(store);
    await s.load();
    return s;
  }

  test('각성모드: 세트·운동 못 빼고, 쉬면 남은 휴식일로 옮긴다', () async {
    final s = await make();
    await s.startAwakening(7);
    expect(s.awakening, isTrue);
    final days = [for (var i = 0; i < 7; i++) s.today.add(Duration(days: i))];
    final work = days.map(s.planOn).whereType<DayPlan>().where((p) => !p.isRest).toList();
    final rests = days.where((d) => s.planOn(d) == null || s.planOn(d)!.isRest).length;
    expect(work, isNotEmpty);
    final p = work.first;
    final pe = p.exercises.firstWhere((e) => !e.warmup);
    final n = pe.sets.length;
    await s.removeSet(p, pe);
    expect(pe.sets.length, n);
    final count = p.exercises.length;
    await s.removeExercise(p, pe);
    expect(p.exercises.length, count);

    final before = work.length;
    await s.toggleRestDay(p.date);
    final after = days.map(s.planOn).whereType<DayPlan>().where((x) => !x.isRest && !x.skipped).length;
    if (rests > 0) {
      expect(s.planOn(p.date)!.skipped, isTrue);
      expect(after, before); // 운동일 수는 그대로(휴식일로 옮김)
    }
    // 저장·복원
    final j = UserProfile.fromJson(s.currentUser!.toJson());
    expect(j.awakenTo, isNotNull);
    final end = s.currentUser!.awakenTo!;
    await s.extendAwakening(7);
    expect(s.currentUser!.awakenTo, end.add(const Duration(days: 7)));
  });

  test('각성모드: 지난 못 한 운동일은 남은 휴식일로 밀린다', () async {
    final s = await make();
    final u = s.currentUser!;
    final y = s.today.subtract(const Duration(days: 1));
    await s.generatePlans(from: y, to: s.today.add(const Duration(days: 5)), restDays: {});
    var missed = s.planOn(y);
    if (missed == null || missed.isRest) {
      await s.changeDayFocus(y, [MuscleGroup.chest], shiftFollowing: false);
      missed = s.planOn(y)!;
    }
    u.awakenFrom = y;
    u.awakenTo = s.today.add(const Duration(days: 5));
    await s.setWorkoutHour(19); // 저장 → 밀어 넣기 실행
    expect(s.planOn(y)!.skipped, isTrue);
  });

  test('각성모드: 무게만 다시 맞추기(운동·세트 수·순서 그대로)', () async {
    final s = await make();
    await s.startAwakening(7);
    final p = [for (var i = 0; i < 7; i++) s.planOn(s.today.add(Duration(days: i)))].whereType<DayPlan>().firstWhere((p) => !p.isRest);
    final ids = [for (final e in p.exercises) e.exerciseId];
    final counts = [for (final e in p.exercises) e.sets.length];
    final reps = [for (final e in p.exercises) [for (final x in e.sets) x.targetReps]];
    // 예전 기준으로 짠 것처럼 무게를 어긋나게
    final i = p.exercises.indexWhere((e) => !e.warmup && e.sets.isNotEmpty && e.topSet.targetWeight > 0);
    expect(i, greaterThanOrEqualTo(0));
    final pe = p.exercises[i];
    final good = pe.topSet.targetWeight;
    p.exercises[i] = pe.copyWith(sets: [for (final x in pe.sets) SetEntry(targetReps: x.targetReps, targetWeight: x.targetWeight + 7.5)]);
    final n = await s.rebalanceWeights(p);
    expect(n, greaterThanOrEqualTo(1));
    expect(p.exercises[i].topSet.targetWeight, good);
    expect([for (final e in p.exercises) e.exerciseId], ids);
    expect([for (final e in p.exercises) e.sets.length], counts);
    expect([for (final e in p.exercises) [for (final x in e.sets) x.targetReps]], reps);
    expect(await s.rebalanceAwakenWeights(), 0); // 방금 짠 루틴은 그대로
  });
}
