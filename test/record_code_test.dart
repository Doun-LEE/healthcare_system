import 'package:fit_routine/services/record_code.dart';
import 'package:flutter_test/flutter_test.dart';

RecordExercise _x(String id, List<List<num>> sets) =>
    RecordExercise(id, [for (final s in sets) RecordSet(s[0].toInt(), s[1].toDouble(), s.length > 2 ? s[2].toInt() : null)]);

void main() {
  test('record code round-trips and rejects junk', () {
    final rc = RecordCode(date: DateTime(2026, 10, 25), rpe: 6, exercises: [
      _x('stairs', [[20, 0, 6]]),
      _x('hanging_leg_raise', [[30, 0], [25, 0], [20, 0], [15, 0]]),
      _x('db_pullover', [[15, 20], [15, 20], [15, 20]]),
      _x('bb_squat', [[10, 60], [6, 110], [1, 140], [3, 120]]),
      _x('deadlift', [[6, 100], [4, 120], [8, 100]]),
      _x('tbar_row', [[12, 30], [10, 40], [10, 35]]),
      _x('db_bench', [[10, 32], [10, 36], [8, 40]]),
      _x('chest_press_m', [[10, 50], [10, 70], [10, 90]]),
      _x('shoulder_press_pl', [[12, 30], [10, 40], [12, 35]]),
      _x('monster_glute', [[20, 5], [20, 5], [15, 10]]),
      _x('overhead_tri', [[12, 50], [12, 50], [12, 50]]),
    ]);
    final code = rc.encode();
    final back = RecordCode.decode('  $code \n')!;
    expect(back.date, DateTime(2026, 10, 25));
    expect(back.exercises.length, 11);
    expect(back.setCount, 33);
    expect(back.exercises[3].sets[2].weight, 140);
    expect(back.exercises.first.sets.first.level, 6);
    expect(RecordCode.decode('hello'), isNull);
    expect(RecordCode.decode('FRREC1.abc'), isNull);
  });
}
