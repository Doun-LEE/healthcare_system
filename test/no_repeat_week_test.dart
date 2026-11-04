import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/engine/planner.dart';
import 'package:fit_routine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('1분할 전신 일주일: 운동한 날끼리 같은 운동·같은 동작 계열이 연달아 나오지 않는다', () {
    final types = [
      EquipmentType.dumbbell, EquipmentType.barbell, EquipmentType.flatBench, EquipmentType.inclineBench, EquipmentType.squatRack,
      EquipmentType.legPress, EquipmentType.legCurl, EquipmentType.lyingLegCurl, EquipmentType.legExtension, EquipmentType.latPulldown,
      EquipmentType.seatedRow, EquipmentType.chestPress, EquipmentType.pecDeck, EquipmentType.shoulderPress, EquipmentType.cableMachine,
      EquipmentType.assistedPullUp, EquipmentType.smithMachine, EquipmentType.treadmill, EquipmentType.stairClimber, EquipmentType.chestSupportedRow,
      EquipmentType.chestPressPlateLoaded, EquipmentType.shoulderPressPlateLoaded, EquipmentType.lateralRaiseMachine, EquipmentType.hipThrust,
    ];
    final gym = Gym(id: 'g', name: 'g', equipment: [for (var i = 0; i < types.length; i++) GymEquipment(id: '$i', type: types[i])]);
    var n = 0;
    final plans = Planner(PlannerInput(
      profile: UserProfile(id: 'u', name: 'u', splitDays: 1, sessionMinutes: 95, includeCardio: true),
      from: DateTime(2026, 11, 2), to: DateTime(2026, 11, 8), restDays: {'2026-11-05'},
      available: gym.availableTypes, progress: {}, history: [], newId: () => 'p${n++}',
    )).build();
    List<String> prev = [];
    for (final p in plans.where((p) => !p.isRest)) {
      final ids = [for (final e in p.exercises) if (!e.warmup) e.exerciseId];
      final fams = ids.map(familyOf).toList();
      expect(fams.toSet().length, fams.length, reason: '${p.date.day}일 한 세션 안 중복: $ids');
      final prevFams = prev.map(familyOf).toSet();
      final repeated = [for (final id in ids) if (prevFams.contains(familyOf(id))) exerciseById(id)!.name];
      expect(repeated, isEmpty, reason: '${p.date.day}일이 직전 운동일과 겹침');
      prev = ids;
    }
  });
}
