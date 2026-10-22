import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/engine/planner.dart';
import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/services/partner.dart';
import 'package:fit_routine/services/routine_share.dart';
import 'package:flutter_test/flutter_test.dart';

var _n = 0;
String _id() => 'id${_n++}';

void main() {
  test('planner uses the day gym equipment and keeps its gym id', () {
    final u = UserProfile(id: 'u', name: 'x', splitDays: 3, includeCardio: false);
    final big = {
      EquipmentType.bodyweight, EquipmentType.barbell, EquipmentType.squatRack, EquipmentType.flatBench,
      EquipmentType.dumbbell, EquipmentType.cableMachine, EquipmentType.latPulldown, EquipmentType.legPress,
    };
    final small = {EquipmentType.bodyweight, EquipmentType.dumbbell};
    final plans = Planner(PlannerInput(
      profile: u,
      from: DateTime(2026, 10, 20),
      to: DateTime(2026, 10, 21),
      restDays: const {},
      available: big,
      progress: {},
      history: [],
      newId: _id,
      dayAvailable: {'2026-10-21': small},
      dayGym: {'2026-10-21': 'home-gym'},
    )).build();
    final day2 = plans.firstWhere((p) => p.date == DateTime(2026, 10, 21));
    expect(day2.gymId, 'home-gym');
    for (final pe in day2.exercises) {
      expect(small.contains(pe.equipmentType), isTrue, reason: '${pe.exerciseId} uses ${pe.equipmentType}');
    }
    expect(plans.firstWhere((p) => p.date == DateTime(2026, 10, 20)).gymId, isNull);
  });

  test('routine share code carries the workout venue', () {
    final plan = DayPlan(
      id: 'p', userId: 'u', date: DateTime(2026, 10, 22), kind: DayKind.workout, focus: [MuscleGroup.chest],
      exercises: [PlannedExercise(exerciseId: 'bb_bench', equipmentType: EquipmentType.barbell, restSeconds: 90, sets: [SetEntry(targetReps: 8, targetWeight: 60)])],
    );
    final code = encodeRoutine(plan, venue: const SharedVenue(owner: 'uidB', gymId: 'g1', name: '친구 헬스장', types: [EquipmentType.barbell, EquipmentType.flatBench]));
    final v = decodeRoutine(code)!.venue!;
    expect(v.owner, 'uidB');
    expect(v.name, '친구 헬스장');
    expect(v.types, containsAll([EquipmentType.barbell, EquipmentType.flatBench]));
    expect(decodeRoutine(encodeRoutine(plan))!.venue, isNull);
  });

  test('partner public profile lists gyms, and day plans keep venue through JSON', () {
    final gym = Gym(id: 'g1', name: '집앞짐', equipment: [GymEquipment(id: 'e', type: EquipmentType.legPress)]);
    final json = PartnerProfile.build(uid: 'u1', me: UserProfile(id: 'u1', name: 'x'), available: gym.availableTypes, progress: {}, plans: [], gyms: [gym]);
    final pp = PartnerProfile.fromJson(json);
    expect(pp.gyms.single.name, '집앞짐');
    expect(pp.gyms.single.types, contains(EquipmentType.legPress));

    final p = DayPlan(id: 'p', userId: 'u', date: DateTime(2026, 10, 22), kind: DayKind.workout, focus: const [],
        venueOwner: 'uidB', venueGymId: 'g9', venueName: '친구짐', venueTypes: [EquipmentType.smithMachine]);
    final back = DayPlan.fromJson(p.toJson());
    expect(back.atOtherGym, isTrue);
    expect(back.venueTypes, [EquipmentType.smithMachine]);
    expect(exerciseById('bb_bench'), isNotNull);
  });

  test('share code carries the last-change time so crossed shares keep the newest', () {
    final plan = DayPlan(id: 'p', userId: 'u', date: DateTime(2026, 10, 22), kind: DayKind.workout, focus: [MuscleGroup.chest],
        exercises: [PlannedExercise(exerciseId: 'bb_bench', equipmentType: EquipmentType.barbell, restSeconds: 90, sets: [SetEntry(targetReps: 8, targetWeight: 60)])]);
    final t1 = DateTime.utc(2026, 10, 22, 12, 0);
    final t2 = DateTime.utc(2026, 10, 22, 12, 5);
    expect(decodeRoutine(encodeRoutine(plan, at: t2))!.at, t2);
    expect(t2.isAfter(t1), isTrue);
    plan.jointAt = t1;
    expect(DayPlan.fromJson(plan.toJson()).jointAt, t1);
  });

  test('hand-edited days stay fixed when the plan is re-balanced', () {
    final u = UserProfile(id: 'u', name: 'x', splitDays: 3, includeCardio: false);
    final edited = DayPlan(id: 'e', userId: 'u', date: DateTime(2026, 10, 21), kind: DayKind.workout,
        focus: [MuscleGroup.shoulder], title: '어깨만', custom: true);
    final plans = Planner(PlannerInput(
      profile: u, from: DateTime(2026, 10, 20), to: DateTime(2026, 10, 22), restDays: const {},
      available: {EquipmentType.bodyweight, EquipmentType.dumbbell, EquipmentType.barbell, EquipmentType.flatBench},
      progress: {}, history: [], newId: _id, fixed: {'2026-10-21': edited},
    )).build();
    expect(identical(plans[1], edited), isTrue);
    expect(DayPlan.fromJson(edited.toJson()).custom, isTrue);
  });
}
