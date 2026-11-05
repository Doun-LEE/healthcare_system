import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

DayPlan _plan(String userId, List<PlannedExercise> ex) => DayPlan(
      id: 'p1',
      userId: userId,
      date: DateTime(2026, 11, 5),
      kind: DayKind.workout,
      focus: const [],
      exercises: ex,
    );

PlannedExercise _ex(String id, List<(double, int, bool)> sets) => PlannedExercise(
      exerciseId: id,
      equipmentType: EquipmentType.barbell,
      restSeconds: 120,
      sets: [for (final (w, r, done) in sets) SetEntry(targetReps: r, targetWeight: w, completed: done)],
    );

void main() {
  test('나이는 출생 연도로 저장돼 해마다 저절로 바뀐다', () {
    final p = UserProfile(id: 'u', name: 'a', age: 29);
    expect(p.birthYear, DateTime.now().year - 29);
    expect(p.age, 29);
    p.age = 30;
    expect(p.birthYear, DateTime.now().year - 30);
    final back = UserProfile.fromJson(p.toJson());
    expect(back.birthYear, p.birthYear);
  });

  test('예전 저장본(나이만 있음)도 불러오고, 측정·리프트 기록은 왕복 저장된다', () {
    final j = UserProfile(id: 'u', name: 'a').toJson()
      ..remove('birthYear')
      ..['age'] = 25;
    expect(UserProfile.fromJson(j).age, 25);

    final p = UserProfile(id: 'u', name: 'a');
    p.bodyLog.add(BodyEntry(date: DateTime(2026, 1, 1), weightKg: 80, bodyFatPct: 18));
    p.liftLog.add(LiftEntry(date: DateTime(2026, 1, 2), lift: 'bench', kg: 100, auto: true, note: '90kg×3'));
    final back = UserProfile.fromJson(p.toJson());
    expect(back.bodyLog.single.weightKg, 80);
    expect(back.bodyLog.single.skeletalMuscleKg, isNull);
    expect(back.liftLog.single.note, '90kg×3');
    expect(back.liftLog.single.auto, isTrue);
  });

  test('운동 기록의 추정 1RM이 기존보다 높을 때만 3대 기록을 자동 갱신한다', () {
    final u = UserProfile(id: 'u', name: 'a')
      ..bench1rm = 100
      ..squat1rm = 200;
    final plan = _plan('u', [
      _ex('bb_bench', [(90, 5, true), (95, 3, true), (120, 1, false)]), // 90×5=105, 95×3=104.5, 안 한 세트는 무시
      _ex('bb_squat', [(150, 5, true)]), // 175 < 200 → 유지
      _ex('deadlift', [(100, 15, true)]), // 10회 넘으면 무시
      _ex('ohp', [(60, 1, true)]), // 기록 없음 → 등록
    ]);
    final msgs = AppState.applyLiftPrs(u, plan, DateTime(2026, 11, 5));
    expect(u.bench1rm, 105);
    expect(u.squat1rm, 200);
    expect(u.deadlift1rm, isNull);
    expect(u.ohp1rm, 60);
    expect(msgs.length, 2);
    expect(msgs.first, contains('100 → 105'));
    expect(u.liftLog.map((e) => e.lift), ['bench', 'ohp']);
    expect(u.liftLog.first.note, '90kg×5');
  });
}
