import 'package:fit_routine/core/store.dart';
import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

DayPlan _day(DateTime d, {bool finished = false, bool skipped = false}) => DayPlan(
      id: 'p${d.day}${finished ? 'f' : ''}',
      userId: 'u',
      date: d,
      kind: DayKind.workout,
      focus: const [MuscleGroup.legs],
      exercises: [
        PlannedExercise(
          exerciseId: 'back_squat',
          equipmentType: EquipmentType.barbell,
          restSeconds: 90,
          sets: [SetEntry(targetReps: 10, targetWeight: 60, completed: finished)],
        ),
      ],
      finishedAt: finished ? d.add(const Duration(hours: 21)) : null,
    )..skipped = skipped;

void main() {
  final d = DateTime(2026, 10, 25);
  final state = AppState(MemoryStore());

  test('a stale copy that marked the day as rest cannot erase a finished workout', () {
    final good = AppData(plans: [_day(d, finished: true)]);
    final stale = AppData(plans: [_day(d, skipped: true)], updatedAt: DateTime(2026, 10, 26));
    state.mergeForTest(good, stale);
    expect(stale.plans.single.isFinished, isTrue);
  });

  test('a deliberately deleted record is not brought back', () {
    final old = AppData(plans: [_day(d, finished: true)]);
    final now = AppData(deleted: {'u|${dateKey(d)}': DateTime(2026, 10, 27)});
    state.mergeForTest(old, now);
    expect(now.plans, isEmpty);
  });

  test('the more recently edited gym wins, per gym', () {
    final newer = AppData(
      gyms: [Gym(id: 'g1', name: '보스턴 피트니스', equipment: [GymEquipment(id: 'e1', type: EquipmentType.legPress)])],
      editedAt: {'gym:g1': DateTime(2026, 10, 26)},
    );
    final stale = AppData(
      gyms: [Gym(id: 'g1', name: '보스턴 피트니스'), Gym(id: 'g2', name: '부티크짐')],
      editedAt: {'gym:g1': DateTime(2026, 10, 20)},
      updatedAt: DateTime(2026, 10, 27),
    );
    state.mergeForTest(newer, stale);
    expect(stale.gyms.firstWhere((g) => g.id == 'g1').equipment.length, 1);
    expect(stale.gyms.length, 2);
  });

  test('backup bookkeeping fields survive JSON', () {
    final a = AppData(deleted: {'gym:x': DateTime(2026, 1, 1)}, editedAt: {'gym:y': DateTime(2026, 1, 2)});
    final b = AppData.fromJson(a.toJson());
    expect(b.deleted['gym:x'], DateTime(2026, 1, 1));
    expect(b.editedAt['gym:y'], DateTime(2026, 1, 2));
  });
}
