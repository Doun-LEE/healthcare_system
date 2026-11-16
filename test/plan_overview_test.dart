import 'package:fit_routine/core/store.dart';
import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/engine/plan_overview.dart';
import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

PlannedExercise pe(String id, EquipmentType t, int sets, {int reps = 10}) => PlannedExercise(
      exerciseId: id,
      equipmentType: t,
      restSeconds: 60,
      sets: [for (var i = 0; i < sets; i++) SetEntry(targetReps: reps, targetWeight: 0)],
    );

void main() {
  test('부위·세부 부위별로 센다(윗가슴·하복부·칼로리 소모/체력 증진)', () {
    final plan = DayPlan(id: 'p', userId: 'u', date: DateTime(2026, 11, 16), kind: DayKind.workout, focus: const [], title: '', exercises: [
      pe('incline_db', EquipmentType.dumbbell, 4),
      pe('hanging_leg_raise', EquipmentType.pullUpBar, 3),
      pe('treadmill_walk', EquipmentType.treadmill, 1, reps: 20),
      pe('jumping_jack', EquipmentType.bodyweight, 1, reps: 15),
    ]);
    final t = tallyPlan(plan);
    expect(t[MuscleGroup.chest]!.exercises, 1);
    expect(t[MuscleGroup.chest]!.sets, 4);
    expect(t[MuscleGroup.chest]!.subs.keys, contains('윗가슴'));
    expect(t[MuscleGroup.abs]!.subs.keys, contains('하복부'));
    expect(t[MuscleGroup.cardio]!.subs, {cardioBurn: 1, cardioFitness: 1});
    expect(subLabels(MuscleGroup.legs), containsAll(['둔근', '대퇴사두', '햄스트링', '종아리']));
  });

  test('부위 숫자 + 하면 그 세부 부위 운동을 골라 넣고, - 하면 안 한 운동부터 뺀다', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final store = MemoryStore();
    await store.save(AppData(
      currentUserId: 'u',
      profiles: [UserProfile(id: 'u', name: 'a', onboarded: true)],
      plans: [DayPlan(id: 'p', userId: 'u', date: today, kind: DayKind.workout, focus: const [], title: '', exercises: [])],
    ));
    final s = AppState(store);
    await s.load();
    final plan = s.planOn(today)!;
    final added = await s.addForGroup(plan, MuscleGroup.abs, sub: '하복부');
    expect(added, isNotNull);
    expect(subsOf(added!, MuscleGroup.abs), contains('하복부'));
    expect(tallyPlan(plan)[MuscleGroup.abs]!.exercises, 1);

    final second = await s.addForGroup(plan, MuscleGroup.abs);
    expect(second, isNotNull);
    expect(second!.id, isNot(added.id), reason: '이미 있는 운동은 다시 안 넣는다');

    plan.exercises.first.sets.first.completed = true;
    expect(await s.removeForGroup(plan, MuscleGroup.abs), isTrue);
    expect(plan.exercises.single.exerciseId, added.id, reason: '이미 한 운동은 남긴다');
    expect(await s.removeForGroup(plan, MuscleGroup.abs), isFalse);
    expect(exerciseById(added.id), isNotNull);
  });
}
