import 'package:fit_routine/core/store.dart';
import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('지난 날 루틴을 그대로 가져온다: 한 세트는 그때 한 값, 안 한 추가 세트는 빼고, 완료 표시는 지운다', () async {
    final store = MemoryStore();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final src = today.subtract(const Duration(days: 3));
    final target = today.add(const Duration(days: 1));
    await store.save(AppData(
      currentUserId: 'u',
      profiles: [UserProfile(id: 'u', name: '도운', onboarded: true)],
      plans: [
        DayPlan(
          id: 'src', userId: 'u', date: src, kind: DayKind.workout, focus: const [MuscleGroup.legs],
          title: '하체', finishedAt: src.add(const Duration(hours: 20)),
          exercises: [
            PlannedExercise(exerciseId: 'leg_press', equipmentType: EquipmentType.legPress, restSeconds: 120, sets: [
              SetEntry(targetReps: 12, targetWeight: 200, doneReps: 15, doneWeight: 220, completed: true),
              SetEntry(targetReps: 12, targetWeight: 200),
              SetEntry(targetReps: 10, targetWeight: 240, extra: true),
            ]),
          ],
        ),
      ],
    ));
    final s = AppState(store);
    await s.load();
    expect(s.pastRoutines().map((p) => p.id), ['src']);

    final copied = await s.copyRoutineFrom(s.planOn(src)!, target);
    expect(copied, isNotNull);
    final sets = copied!.exercises.single.sets;
    expect(sets.length, 2, reason: '안 한 추가 세트는 빠진다');
    expect(sets.first.targetReps, 15);
    expect(sets.first.targetWeight, 220);
    expect(sets.last.targetWeight, 200);
    expect(sets.every((x) => !x.completed && x.doneReps == null), isTrue);
    expect(copied.isFinished, isFalse);
    expect(copied.focus, [MuscleGroup.legs]);
    expect(s.planOn(target)?.id, copied.id);
    expect(s.planOn(src)!.isFinished, isTrue, reason: '원래 날은 그대로');
  });
}
