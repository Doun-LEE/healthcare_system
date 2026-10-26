import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/engine/session_generator.dart';
import 'package:fit_routine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final all = EquipmentType.values.toSet();
  SessionGenerator gen(UserProfile u) => SessionGenerator(SessionRequest(
        groups: [MuscleGroup.legs], available: all, progress: {}, profile: u, minutesBudget: 90));

  test('injury removes the exercise, caution keeps it lighter with more reps', () {
    final base = UserProfile(id: 'u', name: 'x', includeCardio: false, warmupMode: 'off');
    final hurt = UserProfile(id: 'u', name: 'x', includeCardio: false, warmupMode: 'off', injuries: {InjuryArea.knee});
    final careful = UserProfile(id: 'u', name: 'x', includeCardio: false, warmupMode: 'off', cautions: {InjuryArea.knee});
    final squat = exerciseById('bb_squat')!;

    final normal = gen(base).planExercise(squat);
    final light = gen(careful).planExercise(squat);
    expect(light.sets.first.targetWeight, lessThan(normal.sets.first.targetWeight));
    expect(light.sets.first.targetReps, greaterThan(normal.sets.first.targetReps));
    expect(light.note, contains('무릎 주의'));

    final hurtOut = gen(hurt).generate();
    expect(hurtOut.any((e) => injuryExclusions[InjuryArea.knee]!.contains(e.exerciseId)), isFalse);
    expect(gen(careful).generate(), isNotEmpty);
    expect(UserProfile.fromJson(careful.toJson()).cautions, {InjuryArea.knee});
  });
}
