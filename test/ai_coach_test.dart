import 'package:fit_routine/engine/stats.dart';
import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/services/ai_coach.dart';
import 'package:flutter_test/flutter_test.dart';

AiContext _ctx({Set<InjuryArea>? injuries, int minutes = 90}) => AiContext(
      profile: UserProfile(id: 'u', name: '테스트', weightKg: 75, injuries: injuries)..sessionMinutes = minutes,
      date: DateTime(2026, 10, 21),
      focus: [MuscleGroup.chest, MuscleGroup.arms],
      available: {EquipmentType.barbell, EquipmentType.dumbbell, EquipmentType.flatBench, EquipmentType.cableMachine, EquipmentType.bodyweight},
      progress: {'bb_bench': ExerciseProgress(exerciseId: 'bb_bench', workingWeight: 60, targetReps: 8)},
      recent: const [],
      stats: Stats.summarize(const [], days: 28, now: DateTime(2026, 10, 21)),
    );

void main() {
  test('prompt lists only doable candidates and the user context', () {
    final p = AiCoach.buildPrompt(_ctx(injuries: {InjuryArea.shoulder}));
    expect(p, contains('db_bench |')); // 덤벨 벤치는 가능
    expect(p, isNot(contains('bb_bench |'))); // 바벨 벤치는 어깨 부상 제외 목록
    expect(p, contains('time_budget_min: 90'));
    expect(p, contains('candidates'));
    expect(p, isNot(contains('leg_press |'))); // 레그프레스 기구 없음
    expect(p, isNot(contains('\nohp |'))); // 어깨 부상 → OHP 제외
    expect(p, contains('부상/주의: 어깨'));
  });

  test('validate maps ids to a plan with baseline-scaled weights and drops unknown ids', () {
    final ctx = _ctx();
    final ai = AiCoach.validate({
      'title': '가슴·삼두',
      'focus': ['chest', 'arms'],
      'rationale': '테스트',
      'exercises': [
        {'id': 'bb_bench', 'sets': 4, 'reps': 8, 'weightFactor': 0.95, 'note': '메인'},
        {'id': 'does_not_exist', 'sets': 3, 'reps': 10, 'weightFactor': 1.0},
        {'id': 'leg_press', 'sets': 3, 'reps': 10, 'weightFactor': 1.0}, // 기구 없음
        {'id': 'tri_pushdown', 'sets': 9, 'reps': 100, 'weightFactor': 5.0},
        {'id': 'pushup', 'sets': 3, 'reps': 15, 'weightFactor': 1.0},
      ],
    }, ctx);
    expect(ai.title, '가슴·삼두');
    expect(ai.exercises.map((e) => e.exerciseId), ['bb_bench', 'tri_pushdown', 'pushup']);
    final bench = ai.exercises.first;
    expect(bench.sets.length, 4);
    expect(bench.sets.first.targetWeight, 57.5); // 60 × 0.95 → 2.5 단위
    expect(bench.note, contains('메인'));
    final tri = ai.exercises[1];
    expect(tri.sets.length, 6); // clamp
    expect(tri.sets.first.targetReps, lessThanOrEqualTo(15 + 6));
    expect(ai.warnings.length, greaterThanOrEqualTo(3)); // unknown, leg_press, factor
    expect(ai.exercises.last.sets.first.targetWeight, 0); // 맨몸
  });

  test('validate trims sets to fit the time budget', () {
    final ctx = _ctx(minutes: 30);
    final ai = AiCoach.validate({
      'title': 't',
      'focus': ['chest'],
      'rationale': '',
      'exercises': [
        for (final id in ['bb_bench', 'db_bench', 'cable_fly', 'db_fly', 'pushup', 'tri_pushdown'])
          {'id': id, 'sets': 5, 'reps': 12, 'weightFactor': 1.0},
      ],
    }, ctx);
    expect(ai.warnings.any((w) => w.contains('시간')), isTrue);
    expect(ai.exercises.fold<int>(0, (a, e) => a + e.sets.length), lessThan(30));
  });

  test('validate throws when nothing usable', () {
    expect(
      () => AiCoach.validate({'title': 'x', 'focus': [], 'rationale': '', 'exercises': [{'id': 'nope', 'sets': 3, 'reps': 10, 'weightFactor': 1}]}, _ctx()),
      throwsA(isA<AiCoachException>()),
    );
  });
}
