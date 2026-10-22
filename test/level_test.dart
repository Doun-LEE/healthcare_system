import 'package:fit_routine/engine/level_assessor.dart';
import 'package:fit_routine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('strong male lifter with good body comp is advanced', () {
    final p = UserProfile(
      id: 'u', name: 'x', sex: Sex.male, heightCm: 179, weightKg: 84, age: 29,
      skeletalMuscleKg: 42, bodyFatPct: 15,
      squat1rm: 150, bench1rm: 120, deadlift1rm: 200, ohp1rm: 70,
    );
    final a = LevelAssessor.assess(p);
    expect(a.hasData, isTrue);
    expect(a.level, TrainingLevel.advanced);
    expect(a.items.firstWhere((i) => i.name == '벤치프레스').grade.index, greaterThanOrEqualTo(Grade.advanced.index));
    expect(a.items.firstWhere((i) => i.name == '골격근량').missing, isFalse);
  });

  test('no inputs keeps manual level and reports missing', () {
    final p = UserProfile(id: 'u', name: 'x', level: TrainingLevel.intermediate);
    final a = LevelAssessor.assess(p);
    expect(a.hasData, isFalse);
    expect(a.level, TrainingLevel.intermediate);
    expect(a.items.every((i) => i.missing), isTrue);
  });

  test('light lifts are beginner; female thresholds are lower', () {
    final m = LevelAssessor.assess(UserProfile(id: 'u', name: 'x', sex: Sex.male, weightKg: 80, squat1rm: 60, bench1rm: 40, deadlift1rm: 80));
    expect(m.level, TrainingLevel.beginner);
    final f = LevelAssessor.assess(UserProfile(id: 'u', name: 'y', sex: Sex.female, weightKg: 55, squat1rm: 70, bench1rm: 40, deadlift1rm: 90));
    expect(f.score!, greaterThan(m.score!));
  });
}
