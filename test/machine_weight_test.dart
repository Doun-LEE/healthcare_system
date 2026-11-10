import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/engine/progression.dart';
import 'package:fit_routine/engine/session_generator.dart';
import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/services/partner.dart';
import 'package:fit_routine/state/app_state.dart';
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

  test('파트너 선호 합치기: 평균, 누군가 확실히 싫어하면 그 점수', () {
    final p = AppState.groupPref([
      {'a': 2, 'b': 3},
      {'a': 1, 'b': -3},
      {},
    ]);
    expect(p['a'], closeTo(1, 1e-9));
    expect(p['b'], -3);
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

  test('파트너 날 컨디션: 누가 입력하든 가장 안 좋은 컨디션으로 세트 수를 맞추고, 좋아지면 되돌림', () {
    List<SetEntry> sets(List<double> w) => [for (final x in w) SetEntry(targetReps: 8, targetWeight: x)];
    final plan = DayPlan(id: 'p', userId: 'u', date: DateTime(2026, 11, 10), kind: DayKind.workout, focus: [MuscleGroup.chest], exercises: [
      PlannedExercise(exerciseId: 'bb_bench', equipmentType: EquipmentType.barbell, restSeconds: 90, sets: sets([50, 55, 60, 60, 60])),
    ]);
    // 나는 8, 파트너가 3 → 0.8배: 5세트 → 4세트(가벼운 램프 세트부터 뺌)
    expect(AppState.groupIntensitySync(plan, [8, 3]), isTrue);
    expect(plan.exercises.first.sets.map((s) => s.targetWeight), [55, 60, 60, 60]);
    expect(plan.intensityFactor, 0.8);
    // 같은 컨디션이면 그대로
    expect(AppState.groupIntensitySync(plan, [3, 8]), isFalse);
    // 파트너가 7로 고치면 다시 5세트
    expect(AppState.groupIntensitySync(plan, [8, 7]), isTrue);
    expect(plan.exercises.first.sets.length, 5);
    // 시작한 날은 건드리지 않음
    plan.exercises.first.sets.first.completed = true;
    expect(AppState.groupIntensitySync(plan, [2]), isFalse);
  });

  test('같은 날 루틴이 둘이면 파트너 날을 남김', () {
    DayPlan mk(String? partner) => DayPlan(id: partner ?? 'solo', userId: 'u', date: DateTime(2026, 11, 10), kind: DayKind.workout, focus: [MuscleGroup.legs], partnerName: partner);
    expect(AppState.dayRank(mk('유주연')), greaterThan(AppState.dayRank(mk(null))));
  });
}
