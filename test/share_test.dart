import 'package:fit_routine/data/quotes.dart';
import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/services/routine_share.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('routine share code round-trips exercises, sets and reps (no weights)', () {
    final plan = DayPlan(
      id: 'p',
      userId: 'u',
      date: DateTime(2026, 10, 20),
      kind: DayKind.workout,
      focus: [MuscleGroup.chest, MuscleGroup.arms],
      title: '밀기',
      exercises: [
        PlannedExercise(
          exerciseId: 'bb_bench',
          equipmentType: EquipmentType.barbell,
          restSeconds: 120,
          sets: List.generate(4, (_) => SetEntry(targetReps: 8, targetWeight: 60)),
        ),
        PlannedExercise(
          exerciseId: 'tri_pushdown',
          equipmentType: EquipmentType.cableMachine,
          restSeconds: 60,
          sets: List.generate(3, (_) => SetEntry(targetReps: 12, targetWeight: 20)),
        ),
      ],
    );
    final code = encodeRoutine(plan, from: '도운');
    expect(code, startsWith('FR1:'));
    expect(code, isNot(contains('60'))); // 무게는 코드에 들어가지 않는다

    // 카톡에서 문장과 함께 붙여넣은 경우도 코드만 뽑아낸다.
    final decoded = decodeRoutine('오늘 루틴이야\n$code\n같이 하자');
    expect(decoded, isNotNull);
    expect(decoded!.title, '밀기');
    expect(decoded.from, '도운');
    expect(decoded.focus, [MuscleGroup.chest, MuscleGroup.arms]);
    expect(decoded.items.length, 2);
    expect(decoded.items[0].exerciseId, 'bb_bench');
    expect(decoded.items[0].sets, 4);
    expect(decoded.items[0].reps, 8);
    expect(decoded.items[1].equipment, EquipmentType.cableMachine);
  });

  test('garbage codes decode to null', () {
    expect(decodeRoutine('hello'), isNull);
    expect(decodeRoutine('FR1:!!!'), isNull);
    expect(decodeRoutine(''), isNull);
  });

  test('quote of the day is stable within a day and non-empty', () {
    final a = quoteFor(DateTime(2026, 10, 20, 7));
    final b = quoteFor(DateTime(2026, 10, 20, 22));
    expect(a, b);
    expect(a, isNotEmpty);
  });
}
