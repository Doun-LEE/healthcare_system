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
}
