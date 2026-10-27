import 'package:flutter_test/flutter_test.dart';

import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/engine/session_generator.dart';
import 'package:fit_routine/models/models.dart';

void main() {
  test('워밍업: 본 운동과 같은 계열은 빠지고, 활성화 개수는 운동 시간에 비례(95분 → 2개)', () {
    final profile = UserProfile(
      id: 'u',
      name: 't',
      level: TrainingLevel.intermediate,
      warmupMode: 'custom',
      sessionMinutes: 95,
      warmupByGroupIds: {
        'back': ['db_pullover', 'pullup', 'straight_arm_pulldown', 'pullover_machine'],
        'legs': ['hip_abduction', 'hip_adduction'],
        'chest': ['pec_deck', 'db_pullover'],
      },
    );
    final out = SessionGenerator(SessionRequest(
      groups: [MuscleGroup.back, MuscleGroup.legs, MuscleGroup.chest, MuscleGroup.shoulder],
      available: {EquipmentType.barbell, EquipmentType.dumbbell, EquipmentType.pullUpBar, EquipmentType.assistedPullUp, EquipmentType.cableMachine, EquipmentType.hipAbductor, EquipmentType.hipAdductor, EquipmentType.pecDeck, EquipmentType.flatBench, EquipmentType.pulloverMachine},
      progress: const {},
      profile: profile,
      minutesBudget: 95,
      seed: 3,
    )).generate();
    final warm = out.where((e) => e.warmup).map((e) => e.exerciseId).toList();
    final mainIds = out.where((e) => !e.warmup).map((e) => e.exerciseId).toSet();
    expect(warm.length, lessThanOrEqualTo(2), reason: '95분이면 활성화 워밍업 2개까지: $warm');
    for (final w in warm) {
      final name = exerciseById(w)!.name;
      for (final m in mainIds) {
        final mn = exerciseById(m)!.name;
        expect(m.contains(w) || w.contains(m) || mn.contains(name) || name.contains(mn), isFalse, reason: '$w 는 본 운동 $m 와 같은 계열');
      }
    }
  });
}
