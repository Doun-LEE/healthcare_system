import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/engine/progression.dart';
import 'package:fit_routine/engine/session_generator.dart';
import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/services/partner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('같은 종류 기구가 여러 대면 지난번 기구와 그 기구 무게로 처방', () {
    final ex = exerciseById('shoulder_press_pl') ?? exerciseById('shoulder_press_m')!;
    final eq = ex.equipment.first;
    final prog = ExerciseProgress(
      exerciseId: ex.id,
      workingWeight: 80,
      targetReps: 10,
      lastMachine: '레전더리 숄더 프레스',
      machineWeights: {'엠토쳐 숄더 프레스': 80, '레전더리 숄더 프레스': 30},
    );
    final gen = SessionGenerator(SessionRequest(
      groups: [MuscleGroup.shoulder],
      available: {eq},
      progress: {ex.id: prog},
      profile: UserProfile(id: 'u', name: 'a'),
      minutesBudget: 60,
      machines: {eq: ['엠토쳐 숄더 프레스', '레전더리 숄더 프레스']},
    ));
    final pe = gen.planExercise(ex);
    expect(pe.machine, '레전더리 숄더 프레스');
    expect(pe.topSet.targetWeight, lessThanOrEqualTo(30));

    // 마치면 그 기구 무게만 올라가고 다른 기구 기록은 그대로
    for (final s in pe.sets) {
      s.completed = true;
    }
    prog.workingWeight = 30;
    Progression.apply(pe, prog, DateTime(2026, 11, 9));
    expect(prog.machineWeights['레전더리 숄더 프레스'], greaterThan(30));
    expect(prog.machineWeights['엠토쳐 숄더 프레스'], 80);
    final back = ExerciseProgress.fromJson(prog.toJson());
    expect(back.machineWeights.length, 2);
    expect(back.lastMachine, '레전더리 숄더 프레스');
  });

  test('시티드 로우 머신과 체스트 서포티드 로우 머신이 따로 있고, 예전 브랜드 시티드 로우는 시티드 로우 머신으로', () {
    final old = GymEquipment.fromJson({'id': 'x', 'type': 'chestSupportedRow', 'customName': '렉스코 마스터프로 시티드 로우 (LPS-121)'});
    expect(old.type, EquipmentType.seatedRowMachine);
    final cs = GymEquipment.fromJson({'id': 'y', 'type': 'chestSupportedRow', 'customName': '아틀란티스 파워 실 로우 (Power D533 Seal Row)'});
    expect(cs.type, EquipmentType.chestSupportedRow);
    final plain = GymEquipment.fromJson({'id': 'z', 'type': 'chestSupportedRow'});
    expect(plain.type, EquipmentType.chestSupportedRow);
    expect(exerciseById('seated_row_m')!.canDoWith({EquipmentType.seatedRowMachine}), isTrue);
    expect(familyOf('seated_row_m'), familyOf('seated_row'));
  });

  test('덤벨 풀오버는 덤벨 1개 운동', () {
    expect(singleDumbbellIds.contains('db_pullover'), isTrue);
  });

  test('공개 프로필: 선호도·최근 수행일·기구별 무게를 주고받음', () {
    final me = UserProfile(id: 'u', name: '나', exercisePref: {'db_bench': 2});
    final j = PartnerProfile.build(
      uid: 'u1',
      me: me,
      available: {EquipmentType.dumbbell},
      progress: {
        'db_bench': ExerciseProgress(exerciseId: 'db_bench', workingWeight: 24, lastPerformed: DateTime.now(), machineWeights: {'A': 26}),
      },
      plans: const [],
    );
    final pp = PartnerProfile.fromJson(j);
    expect(pp.exercisePref['db_bench'], 2);
    expect(pp.lastDone.containsKey('db_bench'), isTrue);
    expect(pp.weightFor('db_bench', 'A'), 26);
    expect(pp.weightFor('db_bench', 'B'), 24);
  });
}
