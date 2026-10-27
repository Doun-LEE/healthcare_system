import 'package:fit_routine/core/store.dart';
import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/services/routine_share.dart';
import 'package:fit_routine/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

DayPlan _plan() => DayPlan(
      id: 'p', userId: 'u', date: DateTime(2026, 10, 30), kind: DayKind.workout,
      focus: const [MuscleGroup.legs], title: '하체 · 유주연·김철수와 함께',
      exercises: [
        PlannedExercise(exerciseId: 'bb_squat', equipmentType: EquipmentType.squatRack, restSeconds: 120,
            sets: [SetEntry(targetReps: 8, targetWeight: 100)]),
      ],
      partnerName: '유주연·김철수',
      members: const [GroupMember('a', '유주연'), GroupMember('b', '김철수')],
      memberWeights: {'a': {'bb_squat': 60}, 'b': {'bb_squat': 90}},
    );

void main() {
  test('group members and their weights survive saving', () {
    final back = DayPlan.fromJson(_plan().toJson());
    expect(back.members.map((m) => m.name), ['유주연', '김철수']);
    expect(back.memberWeights['b']!['bb_squat'], 90);
  });

  test('the shared routine carries everyone in the group', () {
    final code = encodeRoutine(_plan(), from: '도운', group: const [GroupMember('me', '도운'), GroupMember('a', '유주연'), GroupMember('b', '김철수')]);
    final r = decodeRoutine(code)!;
    expect(r.group.map((m) => m.uid), ['me', 'a', 'b']);
    // 예전 1:1 코드도 그대로 읽힌다
    expect(decodeRoutine(encodeRoutine(_plan(), from: '도운'))!.group, isEmpty);
  });

  test('old 1:1 partner days still resolve to that partner', () {
    final s = AppState(MemoryStore());
    expect(s.membersOf(_plan()).length, 2);
    final legacy = DayPlan(id: 'x', userId: 'u', date: DateTime(2026, 10, 30), kind: DayKind.workout, focus: const [], partnerName: '없는사람');
    expect(s.membersOf(legacy), isEmpty);
  });
}
