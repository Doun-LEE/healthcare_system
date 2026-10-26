import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/engine/planner.dart';
import 'package:fit_routine/engine/session_generator.dart';
import 'package:fit_routine/engine/splits.dart';
import 'package:fit_routine/engine/substitute.dart';
import 'package:fit_routine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

const _gym = {
  EquipmentType.bodyweight, EquipmentType.barbell, EquipmentType.dumbbell, EquipmentType.flatBench,
  EquipmentType.squatRack, EquipmentType.cableMachine, EquipmentType.latPulldown, EquipmentType.seatedRow,
  EquipmentType.legPress, EquipmentType.legExtension, EquipmentType.legCurl, EquipmentType.pecDeck,
  EquipmentType.shoulderPress,
};

var _n = 0;
String _id() => 'c${_n++}';

DayPlan _h(DateTime d, String title, List<MuscleGroup> focus) => DayPlan(
      id: _id(), userId: 'u', date: d, kind: DayKind.workout, focus: focus, title: title,
      exercises: const [], finishedAt: d,
    );

void main() {
  test('a cardio-only day does not reset a 4-day split back to chest', () {
    final u = UserProfile(id: 'u', name: 'x', splitDays: 4, includeCardio: false, warmupMode: 'off');
    final history = [
      _h(DateTime(2026, 10, 21), '하체', [MuscleGroup.legs]),
      _h(DateTime(2026, 10, 22), '가슴·삼두', [MuscleGroup.chest, MuscleGroup.arms]),
      _h(DateTime(2026, 10, 23), '등·이두', [MuscleGroup.back, MuscleGroup.arms]),
      _h(DateTime(2026, 10, 24), '어깨·복근', [MuscleGroup.shoulder, MuscleGroup.abs]),
      _h(DateTime(2026, 10, 25), '유산소', [MuscleGroup.cardio]),
    ];
    final plans = Planner(PlannerInput(
      profile: u, from: DateTime(2026, 10, 27), to: DateTime(2026, 10, 30), restDays: const {},
      available: _gym, progress: {}, history: history, newId: _id,
    )).build();
    final titles = plans.where((p) => !p.isRest).map((p) => p.title).toList();
    expect(titles.first, '하체');
    expect(titles.where((t) => t!.startsWith('가슴')).length, lessThanOrEqualTo(1));
  });

  test('titles with an added part or a partner suffix still map to the split day', () {
    final cycle = splitCycles[4]!;
    expect(Planner.cycleIndexOf(_h(DateTime(2026), '등·이두 + 하체', [MuscleGroup.back, MuscleGroup.arms, MuscleGroup.legs]), cycle), 1);
    expect(Planner.cycleIndexOf(_h(DateTime(2026), '가슴·삼두 · 유주연와 함께', [MuscleGroup.chest, MuscleGroup.arms]), cycle), 0);
    expect(Planner.cycleIndexOf(_h(DateTime(2026), '유산소', [MuscleGroup.cardio]), cycle), isNull);
  });

  test('sports can always be added but are never picked automatically', () {
    expect(exerciseById('soccer')!.canDoWith({EquipmentType.barbell}), isTrue);
    expect(exerciseById('reverse_pec_deck')!.name, '리버스 펙덱 플라이');
    final out = SessionGenerator(SessionRequest(
      groups: [MuscleGroup.cardio], available: {..._gym, EquipmentType.outdoor}, progress: {},
      profile: UserProfile(id: 'u', name: 'x', includeCardio: true, warmupMode: 'off'), minutesBudget: 60,
    )).generate();
    expect(out.any((e) => exerciseById(e.exerciseId)!.activity), isFalse);
    expect(cardioLevels['versa']!.max, 50);
  });

  test('swap recommendations skip what is already in the day', () {
    PlannedExercise pe(String id) => PlannedExercise(
        exerciseId: id, equipmentType: exerciseById(id)!.pickEquipment(_gym), restSeconds: 60,
        sets: [SetEntry(targetReps: 10, targetWeight: 20)]);
    final day = [pe('bb_bench'), pe('pec_deck'), pe('cable_fly')];
    final picks = recommendSwaps(day, 2, _gym);
    expect(picks, isNotEmpty);
    expect(picks.map((p) => p.exercise.id), isNot(contains('pec_deck')));
    expect(picks.every((p) => p.exercise.group == MuscleGroup.chest), isTrue);
  });
}
