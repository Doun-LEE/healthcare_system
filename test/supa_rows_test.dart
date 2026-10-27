import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fit_routine/core/store.dart';
import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/services/partner.dart';
import 'package:fit_routine/services/supa_rows.dart';

void main() {
  PlannedExercise pe(String id, EquipmentType t, List<(double, int, bool)> sets, {CardioStats? cardio, bool warmup = false}) => PlannedExercise(
        exerciseId: id,
        equipmentType: t,
        restSeconds: 120,
        note: '메모',
        warmup: warmup,
        pinned: !warmup,
        oneSide: id == 'leg_ext',
        cardio: cardio,
        sets: [
          for (final (w, r, done) in sets)
            SetEntry(targetReps: r, targetWeight: w)
              ..completed = done
              ..doneReps = done ? r + 1 : null
              ..doneWeight = done ? w : null,
        ],
      );

  final plan = DayPlan(
    id: 'plan1',
    userId: 'local-u',
    date: DateTime(2026, 10, 25),
    kind: DayKind.workout,
    focus: [MuscleGroup.legs, MuscleGroup.cardio],
    title: '하체·유산소 · 유주연와 함께',
    partnerName: '유주연',
    members: [GroupMember('uidB', '유주연')],
    memberWeights: {'uidB': {'bb_squat': 80}},
    venueOwner: 'uidB',
    venueGymId: 'g9',
    venueName: '보스턴 피트니스',
    venueTypes: [EquipmentType.squatRack, EquipmentType.treadmill],
    custom: true,
    condition: 7,
    rpe: 6,
    estimatedMinutes: 70,
    startedAt: DateTime(2026, 10, 25, 18),
    endedAt: DateTime(2026, 10, 25, 19, 10),
    finishedAt: DateTime(2026, 10, 25, 19, 10),
    exercises: [
      pe('dyn_stretch', EquipmentType.bodyweight, [(0, 10, true)], warmup: true),
      pe('bb_squat', EquipmentType.squatRack, [(60, 10, true), (100, 6, true), (120, 3, false)]),
      pe('leg_ext', EquipmentType.legExtension, [(40, 12, true), (40, 12, true)]),
      pe('treadmill_run', EquipmentType.treadmill, [(0, 20, true)],
          cardio: CardioStats(durationSec: 1230, distanceKm: 3.4, avgHr: 150, maxHr: 172, activeKcal: 210, splits: [CardioSplit(distanceKm: 1, sec: 360, paceSec: 360, hr: 148)], source: '사진 인식')),
    ],
  );

  test('계획 → 행(계획·운동·세트·워치) → 계획 왕복이 손실 없다', () {
    final planR = planRow(plan, 'uidA');
    final peR = planExerciseRows(plan);
    final setR = setRows(plan, 'uidA');
    final carR = cardioRows(plan, 'uidA');

    expect(planR['id'], 'plan1');
    expect(planR['user_id'], 'uidA');
    expect(planR['date'], '2026-10-25');
    expect(planR['focus'], ['legs', 'cardio']);
    expect(peR.length, 4);
    expect(peR[1]['id'], 'plan1:1');
    expect(peR[1]['exercise_id'], 'bb_squat');
    expect(setR.length, 1 + 3 + 2 + 1);
    expect(setR.where((s) => s['completed'] == true).length, 6);
    expect(carR.single['plan_exercise_id'], 'plan1:3');
    expect(carR.single['avg_hr'], 150);

    // JSON 왕복(Postgres 에서 돌아오는 모양 흉내: 숫자는 num)
    Map<String, dynamic> j(Map<String, dynamic> m) => jsonDecode(jsonEncode(m)) as Map<String, dynamic>;
    final back = planFromRows(j(planR), peR.map(j).toList(), setR.map(j).toList(), carR.map(j).toList(), localUserId: 'local-u');
    expect(jsonEncode(back.toJson()), jsonEncode(plan.toJson()));
    expect(back.displayTitle, plan.displayTitle);
    expect(back.exercises[3].cardio!.splits.single.hr, 148);
    expect(back.exercises[2].oneSide, isTrue);
  });

  test('세트 순서가 섞여 와도 position 으로 정렬되고, 운동 수가 줄면 id 가 바뀌어 옛 행과 겹치지 않는다', () {
    final setR = setRows(plan, 'uidA').reversed.toList();
    final back = planFromRows(planRow(plan, 'uidA'), planExerciseRows(plan).reversed.toList(), setR, const [], localUserId: 'local-u');
    expect(back.exercises.map((e) => e.exerciseId).toList(), plan.exercises.map((e) => e.exerciseId).toList());
    expect(back.exercises[1].sets.map((s) => s.targetWeight).toList(), [60, 100, 120]);
    expect(planExerciseId('plan1', 0), 'plan1:0');
  });

  test('프로필·헬스장·진행·파트너 행 왕복', () {
    final p = UserProfile(id: 'local-u', name: '도운', splitDays: 1, theme: 'marine', cardioOnLegDays: true, injuries: {InjuryArea.values.first});
    final row = userRow(p, 'uidA');
    expect(row['id'], 'uidA');
    expect(row['theme'], 'marine');
    final back = profileFromRow(jsonDecode(jsonEncode(row)) as Map<String, dynamic>, localId: 'local-u');
    expect(jsonEncode(back.toJson()), jsonEncode(p.toJson()));

    final gym = Gym(id: 'g1', name: '보스턴', equipment: [
      GymEquipment(id: 'e1', type: EquipmentType.legPress, brand: 'lexco', plateBasis: 'full', emptyKg: 40, weightBasis: 'perSide'),
      GymEquipment(id: 'e2', type: EquipmentType.dumbbell),
    ]);
    final gBack = gymFromRows(jsonDecode(jsonEncode(gymRow(gym, 'uidA'))) as Map<String, dynamic>, equipmentRows(gym).map((e) => jsonDecode(jsonEncode(e)) as Map<String, dynamic>).toList());
    expect(jsonEncode(gBack.toJson()), jsonEncode(gym.toJson()));

    final prog = {'bb_squat': ExerciseProgress(exerciseId: 'bb_squat', workingWeight: 100, targetReps: 6, lastPerformed: DateTime(2026, 10, 20), timesPerformed: 3)};
    final pr = progressRows(prog, 'uidA').single;
    final pBack = progressFromRow(jsonDecode(jsonEncode(pr)) as Map<String, dynamic>);
    expect(pBack.workingWeight, 100);
    expect(pBack.targetReps, 6);
    expect(pBack.lastPerformed, DateTime(2026, 10, 20));
    expect(pBack.timesPerformed, 3);

    final link = PartnerLink(uid: 'uidB', name: '유주연', handle: '유주연#1111', readAt: DateTime(2026, 10, 25, 9));
    final lr = partnerRows([link], 'uidA').single;
    final lBack = partnerFromRow(jsonDecode(jsonEncode(lr)) as Map<String, dynamic>, name: '유주연', handle: '유주연#1111');
    expect(lBack.uid, 'uidB');
    expect(lBack.readAt, DateTime(2026, 10, 25, 9));
    expect(lBack.pending, isFalse);
  });

  test('RowBundle 은 현재 프로필의 계획만 모으고, 해시는 내용이 같을 때만 같다', () {
    final d = AppData(currentUserId: 'local-u', profiles: [UserProfile(id: 'local-u', name: '도운'), UserProfile(id: 'other', name: '남')], plans: [
      plan,
      DayPlan(id: 'p2', userId: 'other', date: DateTime(2026, 10, 26), kind: DayKind.workout, focus: [MuscleGroup.chest]),
    ]);
    final b = RowBundle.fromData(d, 'uidA');
    expect(b.plans.length, 1);
    expect(b.user!['name'], '도운');
    final h1 = contentHash(b.plans.first);
    plan.rpe = 9;
    final h2 = contentHash(planRow(plan, 'uidA'));
    expect(h1, isNot(h2));
    plan.rpe = 6;
    expect(contentHash(planRow(plan, 'uidA')), h1);
  });
}
