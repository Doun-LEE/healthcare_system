/// 운동/기구 지식 베이스.
///
/// 요구사항 9번: 사용자가 기구 특징을 직접 입력하지 않아도 "어떤 기구가 어느
/// 부위(등 하부, 윗가슴 등)에 잘 먹는지"를 앱이 이미 알고 있어야 한다.
/// 그래서 운동마다 [Exercise.emphasis](세부 타깃)와 기구마다
/// [EquipmentInfo]를 미리 정의한다.
library;

import '../models/models.dart';

/// 무게 추정의 기준이 되는 대표 리프트.
enum RefLift { squat, bench, deadlift, ohp, row, bodyweight }

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.group,
    required this.emphasis,
    required this.equipment,
    required this.loadType,
    required this.refLift,
    required this.ratio,
    this.compound = false,
    this.unilateral = false,
    this.repRange = const [8, 12],
    this.priority = 1,
    this.description = '',
  });

  final String id;
  final String name;
  final MuscleGroup group;

  /// 세부 타깃 태그. 같은 부위 안에서 다양성을 확보할 때 사용.
  /// 예: 등 → '광배(넓이)', '등 상부(두께)', '등 하부', '승모'.
  final List<String> emphasis;

  /// 이 운동을 할 수 있는 기구들(하나라도 있으면 가능).
  final List<EquipmentType> equipment;
  final LoadType loadType;
  final RefLift refLift;

  /// 대표 리프트 1RM 대비 비율. 덤벨은 한 손 기준.
  final double ratio;
  final bool compound;

  /// 한쪽씩 하는 운동(런지 등). 시간 계산 시 2배.
  final bool unilateral;
  final List<int> repRange;

  /// 1=보조, 2=주요, 3=핵심(세션에서 먼저 뽑힘).
  final int priority;
  final String description;

  bool canDoWith(Set<EquipmentType> available) =>
      equipment.any(available.contains);

  /// 주어진 기구 집합에서 실제로 쓸 기구 하나를 고른다(정의 순서 우선).
  EquipmentType pickEquipment(Set<EquipmentType> available) =>
      equipment.firstWhere(available.contains, orElse: () => equipment.first);
}

/// 기구 카탈로그 정보: 특징 설명과 세부 타깃.
class EquipmentInfo {
  const EquipmentInfo({
    required this.type,
    required this.summary,
    required this.strengths,
    this.groups = const [],
  });

  final EquipmentType type;
  final String summary;

  /// 이 기구가 특히 잘 먹는 포인트들.
  final List<String> strengths;
  final List<MuscleGroup> groups;
}

/// 부위별 대중적인 세트 간 휴식(초)과 부위 회복 기간(시간).
class RestRule {
  const RestRule({
    required this.group,
    required this.compoundRestSec,
    required this.isolationRestSec,
    required this.recoveryHours,
    required this.weeklyTargetSessions,
  });

  final MuscleGroup group;
  final int compoundRestSec;
  final int isolationRestSec;

  /// 같은 부위를 다시 훈련하기까지 권장 회복 시간.
  final int recoveryHours;

  /// 주당 권장 자극 횟수(상한은 회복 시간이 정한다).
  final int weeklyTargetSessions;
}

const Map<MuscleGroup, RestRule> restRules = {
  MuscleGroup.legs: RestRule(
      group: MuscleGroup.legs,
      compoundRestSec: 150,
      isolationRestSec: 75,
      recoveryHours: 72,
      weeklyTargetSessions: 2),
  MuscleGroup.chest: RestRule(
      group: MuscleGroup.chest,
      compoundRestSec: 120,
      isolationRestSec: 60,
      recoveryHours: 48,
      weeklyTargetSessions: 2),
  MuscleGroup.back: RestRule(
      group: MuscleGroup.back,
      compoundRestSec: 120,
      isolationRestSec: 75,
      recoveryHours: 48,
      weeklyTargetSessions: 2),
  MuscleGroup.shoulder: RestRule(
      group: MuscleGroup.shoulder,
      compoundRestSec: 90,
      isolationRestSec: 60,
      recoveryHours: 48,
      weeklyTargetSessions: 2),
  MuscleGroup.arms: RestRule(
      group: MuscleGroup.arms,
      compoundRestSec: 75,
      isolationRestSec: 60,
      recoveryHours: 48,
      weeklyTargetSessions: 2),
  MuscleGroup.abs: RestRule(
      group: MuscleGroup.abs,
      compoundRestSec: 60,
      isolationRestSec: 40,
      recoveryHours: 24,
      weeklyTargetSessions: 3),
  MuscleGroup.cardio: RestRule(
      group: MuscleGroup.cardio,
      compoundRestSec: 0,
      isolationRestSec: 0,
      recoveryHours: 24,
      weeklyTargetSessions: 3),
};

const List<EquipmentInfo> equipmentCatalog = [
  EquipmentInfo(
    type: EquipmentType.barbell,
    summary: '가장 무거운 중량을 다룰 수 있는 프리웨이트. 복합운동의 기본.',
    strengths: ['전신 복합운동', '최대 근력 향상', '점진적 과부하가 쉬움'],
    groups: [MuscleGroup.chest, MuscleGroup.back, MuscleGroup.legs, MuscleGroup.shoulder, MuscleGroup.arms],
  ),
  EquipmentInfo(
    type: EquipmentType.dumbbell,
    summary: '좌우 독립 가동. 가동범위가 넓고 좌우 불균형 교정에 유리.',
    strengths: ['가동범위 ↑', '안정근 동원', '좌우 불균형 교정'],
    groups: [MuscleGroup.chest, MuscleGroup.back, MuscleGroup.legs, MuscleGroup.shoulder, MuscleGroup.arms],
  ),
  EquipmentInfo(
    type: EquipmentType.flatBench,
    summary: '플랫 프레스/로우/덤벨 운동의 베이스.',
    strengths: ['가슴 중앙부', '서포티드 로우'],
    groups: [MuscleGroup.chest, MuscleGroup.back],
  ),
  EquipmentInfo(
    type: EquipmentType.inclineBench,
    summary: '각도 조절 벤치. 30~45도에서 윗가슴(쇄골부)이 잘 먹는다.',
    strengths: ['윗가슴(쇄골부)', '전면 어깨', '인클라인 컬(이두 장두)'],
    groups: [MuscleGroup.chest, MuscleGroup.shoulder, MuscleGroup.arms],
  ),
  EquipmentInfo(
    type: EquipmentType.squatRack,
    summary: '바벨 스쿼트/오버헤드프레스/랙풀을 안전하게.',
    strengths: ['대퇴사두·둔근', '전신 근력', '등 하부(랙풀)'],
    groups: [MuscleGroup.legs, MuscleGroup.back, MuscleGroup.shoulder],
  ),
  EquipmentInfo(
    type: EquipmentType.smithMachine,
    summary: '궤도가 고정된 바벨. 안정성이 높아 고립과 고중량 마무리에 좋다.',
    strengths: ['안정적 고중량', '타깃 근육 고립', '혼자서도 안전'],
    groups: [MuscleGroup.chest, MuscleGroup.legs, MuscleGroup.shoulder, MuscleGroup.back],
  ),
  EquipmentInfo(
    type: EquipmentType.cableMachine,
    summary: '전 가동범위에서 일정한 장력. 각도에 따라 다양한 부위 공략.',
    strengths: ['일정 장력(피크 수축)', '가슴 안쪽·아랫가슴', '후면 어깨', '삼두 외측두', '복근'],
    groups: [MuscleGroup.chest, MuscleGroup.back, MuscleGroup.shoulder, MuscleGroup.arms, MuscleGroup.abs],
  ),
  EquipmentInfo(
    type: EquipmentType.latPulldown,
    summary: '수직 당기기 머신. 광배근 넓이(상부 광배)에 특화.',
    strengths: ['광배근(넓이)', '대원근', '풀업 대체'],
    groups: [MuscleGroup.back],
  ),
  EquipmentInfo(
    type: EquipmentType.seatedRow,
    summary: '수평 당기기 머신. 등 중앙 두께와 등 하부(광배 하부)가 잘 먹는다.',
    strengths: ['등 두께(능형근·중부 승모)', '등 하부·광배 하부', '허리 부담 적음'],
    groups: [MuscleGroup.back],
  ),
  EquipmentInfo(
    type: EquipmentType.chestPress,
    summary: '궤도 고정 프레스 머신. 가슴 중앙에 안전하게 고중량.',
    strengths: ['가슴 중앙부', '안전한 고중량', '초보자 입문'],
    groups: [MuscleGroup.chest],
  ),
  EquipmentInfo(
    type: EquipmentType.pecDeck,
    summary: '가슴 안쪽 수축에 특화된 고립 머신. 리버스로 후면 어깨도 가능.',
    strengths: ['가슴 안쪽(피크 수축)', '후면 어깨(리버스 플라이)'],
    groups: [MuscleGroup.chest, MuscleGroup.shoulder],
  ),
  EquipmentInfo(
    type: EquipmentType.shoulderPress,
    summary: '어깨 전면·측면에 안정적인 고중량.',
    strengths: ['전면·측면 삼각근', '안정적 고중량'],
    groups: [MuscleGroup.shoulder],
  ),
  EquipmentInfo(
    type: EquipmentType.legPress,
    summary: '허리 부담 없이 하체 고중량. 발 위치로 사두/둔근 비중 조절.',
    strengths: ['대퇴사두(발 낮게)', '둔근·햄스트링(발 높게)', '허리 부담 적음'],
    groups: [MuscleGroup.legs],
  ),
  EquipmentInfo(
    type: EquipmentType.legExtension,
    summary: '대퇴사두 고립. 특히 내측광근(무릎 위 눈물근육).',
    strengths: ['대퇴사두 고립', '내측광근'],
    groups: [MuscleGroup.legs],
  ),
  EquipmentInfo(
    type: EquipmentType.legCurl,
    summary: '햄스트링 고립 머신.',
    strengths: ['햄스트링 고립', '무릎 안정'],
    groups: [MuscleGroup.legs],
  ),
  EquipmentInfo(
    type: EquipmentType.hipThrust,
    summary: '둔근(대둔근) 특화.',
    strengths: ['대둔근 피크 수축', '힙 힌지 보강'],
    groups: [MuscleGroup.legs],
  ),
  EquipmentInfo(
    type: EquipmentType.calfRaise,
    summary: '종아리(비복근·가자미근).',
    strengths: ['비복근(서서)', '가자미근(앉아서)'],
    groups: [MuscleGroup.legs],
  ),
  EquipmentInfo(
    type: EquipmentType.hackSquat,
    summary: '허리 부담을 줄인 스쿼트 머신. 대퇴사두 외측에 잘 먹는다.',
    strengths: ['대퇴사두 외측', '허리 부담 적은 고중량'],
    groups: [MuscleGroup.legs],
  ),
  EquipmentInfo(
    type: EquipmentType.pullUpBar,
    summary: '맨몸 수직 당기기. 광배근과 상체 전반.',
    strengths: ['광배근 넓이', '악력·코어'],
    groups: [MuscleGroup.back, MuscleGroup.abs],
  ),
  EquipmentInfo(
    type: EquipmentType.dipStation,
    summary: '딥스: 아랫가슴과 삼두. 레그레이즈로 하복부.',
    strengths: ['아랫가슴', '삼두 전체', '하복부(레그레이즈)'],
    groups: [MuscleGroup.chest, MuscleGroup.arms, MuscleGroup.abs],
  ),
  EquipmentInfo(
    type: EquipmentType.preacherBench,
    summary: '이두 고립. 반동을 없애 이두 단두에 집중.',
    strengths: ['이두 단두(안쪽)', '반동 차단'],
    groups: [MuscleGroup.arms],
  ),
  EquipmentInfo(
    type: EquipmentType.abCrunchMachine,
    summary: '상복부 고립 머신. 중량 조절이 쉬움.',
    strengths: ['상복부', '점진적 과부하'],
    groups: [MuscleGroup.abs],
  ),
  EquipmentInfo(
    type: EquipmentType.romanChair,
    summary: '백 익스텐션으로 척추기립근(등 하부)·둔근, 사이드로 복사근.',
    strengths: ['등 하부(척추기립근)', '둔근·햄스트링', '복사근'],
    groups: [MuscleGroup.back, MuscleGroup.abs, MuscleGroup.legs],
  ),
  EquipmentInfo(
    type: EquipmentType.kettlebell,
    summary: '스윙·고블릿 등 전신 파워/컨디셔닝.',
    strengths: ['후면 사슬(둔근·햄·기립근)', '심폐 지구력'],
    groups: [MuscleGroup.legs, MuscleGroup.back, MuscleGroup.cardio],
  ),
  EquipmentInfo(
    type: EquipmentType.treadmill,
    summary: '걷기/러닝/인클라인 워킹.',
    strengths: ['지방 연소', '인클라인 → 둔근·종아리'],
    groups: [MuscleGroup.cardio],
  ),
  EquipmentInfo(
    type: EquipmentType.bike,
    summary: '관절 부담이 적은 유산소.',
    strengths: ['무릎 부담 ↓', '하체 회복 촉진'],
    groups: [MuscleGroup.cardio],
  ),
  EquipmentInfo(
    type: EquipmentType.rower,
    summary: '전신 유산소. 등·하체 동시 사용.',
    strengths: ['전신 유산소', '등 상부 보조'],
    groups: [MuscleGroup.cardio, MuscleGroup.back],
  ),
  EquipmentInfo(
    type: EquipmentType.stairClimber,
    summary: '고강도 하체 유산소. 둔근 자극 큼.',
    strengths: ['둔근·사두', '높은 칼로리 소모'],
    groups: [MuscleGroup.cardio, MuscleGroup.legs],
  ),
  EquipmentInfo(
    type: EquipmentType.elliptical,
    summary: '저충격 전신 유산소.',
    strengths: ['저충격', '전신'],
    groups: [MuscleGroup.cardio],
  ),
  EquipmentInfo(
    type: EquipmentType.bodyweight,
    summary: '기구 없이 하는 운동.',
    strengths: ['어디서나', '코어·복근'],
    groups: [MuscleGroup.abs, MuscleGroup.chest, MuscleGroup.legs],
  ),
];

EquipmentInfo equipmentInfo(EquipmentType t) =>
    equipmentCatalog.firstWhere((e) => e.type == t);

const List<Exercise> exerciseCatalog = [
  // ───────────── 가슴 ─────────────
  Exercise(
    id: 'bb_bench', name: '바벨 벤치프레스', group: MuscleGroup.chest,
    emphasis: ['가슴 중앙부', '삼두'], equipment: [EquipmentType.barbell, EquipmentType.smithMachine],
    loadType: LoadType.barbell, refLift: RefLift.bench, ratio: 1.0,
    compound: true, repRange: [6, 10], priority: 3,
    description: '가슴 운동의 기준. 어깨 날개를 벤치에 고정하고 중간 가슴에 내린다.',
  ),
  Exercise(
    id: 'db_bench', name: '덤벨 벤치프레스', group: MuscleGroup.chest,
    emphasis: ['가슴 중앙부', '가동범위 ↑'], equipment: [EquipmentType.dumbbell],
    loadType: LoadType.dumbbell, refLift: RefLift.bench, ratio: 0.36,
    compound: true, repRange: [8, 12], priority: 3,
    description: '바벨보다 깊게 내려가 가슴 스트레칭이 크다.',
  ),
  Exercise(
    id: 'incline_bb', name: '인클라인 바벨프레스', group: MuscleGroup.chest,
    emphasis: ['윗가슴', '전면 어깨'], equipment: [EquipmentType.inclineBench, EquipmentType.smithMachine],
    loadType: LoadType.barbell, refLift: RefLift.bench, ratio: 0.8,
    compound: true, repRange: [6, 10], priority: 2,
    description: '벤치 각도 30~45도. 쇄골 아래 윗가슴이 타깃.',
  ),
  Exercise(
    id: 'incline_db', name: '인클라인 덤벨프레스', group: MuscleGroup.chest,
    emphasis: ['윗가슴'], equipment: [EquipmentType.inclineBench],
    loadType: LoadType.dumbbell, refLift: RefLift.bench, ratio: 0.3,
    compound: true, repRange: [8, 12], priority: 2,
    description: '윗가슴 발달에 가장 대중적인 선택.',
  ),
  Exercise(
    id: 'chest_press_m', name: '체스트프레스 머신', group: MuscleGroup.chest,
    emphasis: ['가슴 중앙부', '안전한 고중량'], equipment: [EquipmentType.chestPress],
    loadType: LoadType.machine, refLift: RefLift.bench, ratio: 0.9,
    compound: true, repRange: [8, 12], priority: 2,
  ),
  Exercise(
    id: 'pec_deck', name: '펙덱 플라이', group: MuscleGroup.chest,
    emphasis: ['가슴 안쪽', '피크 수축'], equipment: [EquipmentType.pecDeck],
    loadType: LoadType.machine, refLift: RefLift.bench, ratio: 0.55,
    repRange: [12, 15], priority: 1,
  ),
  Exercise(
    id: 'cable_fly', name: '케이블 크로스오버', group: MuscleGroup.chest,
    emphasis: ['가슴 안쪽', '아랫가슴'], equipment: [EquipmentType.cableMachine],
    loadType: LoadType.cable, refLift: RefLift.bench, ratio: 0.18,
    repRange: [12, 15], priority: 1,
    description: '높은 위치에서 아래로 모으면 아랫가슴, 낮은 위치에서 위로 모으면 윗가슴.',
  ),
  Exercise(
    id: 'db_fly', name: '덤벨 플라이', group: MuscleGroup.chest,
    emphasis: ['가슴 바깥쪽', '스트레칭'], equipment: [EquipmentType.dumbbell],
    loadType: LoadType.dumbbell, refLift: RefLift.bench, ratio: 0.18,
    repRange: [12, 15], priority: 1,
  ),
  Exercise(
    id: 'dips', name: '딥스', group: MuscleGroup.chest,
    emphasis: ['아랫가슴', '삼두'], equipment: [EquipmentType.dipStation],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    compound: true, repRange: [8, 12], priority: 2,
    description: '몸을 앞으로 기울이면 가슴, 세우면 삼두 비중이 커진다.',
  ),
  Exercise(
    id: 'pushup', name: '푸시업', group: MuscleGroup.chest,
    emphasis: ['가슴 중앙부', '코어'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    compound: true, repRange: [12, 20], priority: 1,
  ),

  // ───────────── 등 ─────────────
  Exercise(
    id: 'deadlift', name: '컨벤셔널 데드리프트', group: MuscleGroup.back,
    emphasis: ['등 하부', '후면 사슬', '승모'], equipment: [EquipmentType.barbell],
    loadType: LoadType.barbell, refLift: RefLift.deadlift, ratio: 1.0,
    compound: true, repRange: [4, 8], priority: 3,
    description: '전신 근력의 핵심. 허리 중립을 끝까지 유지.',
  ),
  Exercise(
    id: 'bb_row', name: '바벨 로우', group: MuscleGroup.back,
    emphasis: ['등 상부(두께)', '광배 하부'], equipment: [EquipmentType.barbell, EquipmentType.smithMachine],
    loadType: LoadType.barbell, refLift: RefLift.row, ratio: 1.0,
    compound: true, repRange: [6, 10], priority: 3,
    description: '상체 45도 고정. 배꼽 쪽으로 당기면 광배 하부, 가슴 쪽으로 당기면 등 상부.',
  ),
  Exercise(
    id: 'pullup', name: '풀업', group: MuscleGroup.back,
    emphasis: ['광배(넓이)', '대원근'], equipment: [EquipmentType.pullUpBar],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    compound: true, repRange: [5, 10], priority: 3,
  ),
  Exercise(
    id: 'lat_pulldown', name: '랫풀다운', group: MuscleGroup.back,
    emphasis: ['광배(넓이)'], equipment: [EquipmentType.latPulldown, EquipmentType.cableMachine],
    loadType: LoadType.machine, refLift: RefLift.row, ratio: 0.9,
    compound: true, repRange: [8, 12], priority: 3,
    description: '가슴을 열고 팔꿈치를 옆구리로. 넓은 등의 기본.',
  ),
  Exercise(
    id: 'seated_row', name: '시티드 케이블 로우', group: MuscleGroup.back,
    emphasis: ['등 하부', '등 두께(능형근)'], equipment: [EquipmentType.seatedRow, EquipmentType.cableMachine],
    loadType: LoadType.machine, refLift: RefLift.row, ratio: 0.95,
    compound: true, repRange: [8, 12], priority: 2,
    description: '시티드 로우 머신은 등 하부·광배 하부가 특히 잘 먹는다.',
  ),
  Exercise(
    id: 'db_row', name: '원암 덤벨 로우', group: MuscleGroup.back,
    emphasis: ['광배 하부', '등 두께'], equipment: [EquipmentType.dumbbell],
    loadType: LoadType.dumbbell, refLift: RefLift.row, ratio: 0.42,
    compound: true, unilateral: true, repRange: [8, 12], priority: 2,
  ),
  Exercise(
    id: 'tbar_row', name: '티바 로우(랜드마인)', group: MuscleGroup.back,
    emphasis: ['등 상부(두께)', '승모 중부'], equipment: [EquipmentType.barbell],
    loadType: LoadType.barbell, refLift: RefLift.row, ratio: 0.9,
    compound: true, repRange: [8, 12], priority: 2,
  ),
  Exercise(
    id: 'straight_arm_pd', name: '스트레이트암 풀다운', group: MuscleGroup.back,
    emphasis: ['광배 고립', '광배 하부'], equipment: [EquipmentType.cableMachine],
    loadType: LoadType.cable, refLift: RefLift.row, ratio: 0.3,
    repRange: [12, 15], priority: 1,
  ),
  Exercise(
    id: 'back_ext', name: '백 익스텐션', group: MuscleGroup.back,
    emphasis: ['등 하부(척추기립근)', '둔근'], equipment: [EquipmentType.romanChair],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [12, 15], priority: 1,
  ),
  Exercise(
    id: 'rack_pull', name: '랙풀', group: MuscleGroup.back,
    emphasis: ['등 하부', '승모', '악력'], equipment: [EquipmentType.squatRack],
    loadType: LoadType.barbell, refLift: RefLift.deadlift, ratio: 1.1,
    compound: true, repRange: [5, 8], priority: 2,
  ),
  Exercise(
    id: 'face_pull', name: '페이스 풀', group: MuscleGroup.back,
    emphasis: ['후면 어깨', '등 상부', '회전근개'], equipment: [EquipmentType.cableMachine],
    loadType: LoadType.cable, refLift: RefLift.row, ratio: 0.25,
    repRange: [12, 20], priority: 1,
  ),

  // ───────────── 하체 ─────────────
  Exercise(
    id: 'bb_squat', name: '바벨 백스쿼트', group: MuscleGroup.legs,
    emphasis: ['대퇴사두', '둔근', '코어'], equipment: [EquipmentType.squatRack, EquipmentType.smithMachine],
    loadType: LoadType.barbell, refLift: RefLift.squat, ratio: 1.0,
    compound: true, repRange: [5, 8], priority: 3,
    description: '하체의 왕. 무릎이 발끝 방향으로 나가도록.',
  ),
  Exercise(
    id: 'front_squat', name: '프론트 스쿼트', group: MuscleGroup.legs,
    emphasis: ['대퇴사두', '상체 직립'], equipment: [EquipmentType.squatRack],
    loadType: LoadType.barbell, refLift: RefLift.squat, ratio: 0.8,
    compound: true, repRange: [5, 8], priority: 2,
  ),
  Exercise(
    id: 'leg_press', name: '레그 프레스', group: MuscleGroup.legs,
    emphasis: ['대퇴사두', '둔근', '허리 부담 ↓'], equipment: [EquipmentType.legPress],
    loadType: LoadType.machine, refLift: RefLift.squat, ratio: 1.6,
    compound: true, repRange: [8, 12], priority: 3,
    description: '발을 높게 두면 둔근·햄, 낮게 두면 사두 비중.',
  ),
  Exercise(
    id: 'hack_squat', name: '핵 스쿼트', group: MuscleGroup.legs,
    emphasis: ['대퇴사두 외측'], equipment: [EquipmentType.hackSquat],
    loadType: LoadType.machine, refLift: RefLift.squat, ratio: 1.1,
    compound: true, repRange: [8, 12], priority: 2,
  ),
  Exercise(
    id: 'rdl', name: '루마니안 데드리프트', group: MuscleGroup.legs,
    emphasis: ['햄스트링', '둔근', '등 하부'], equipment: [EquipmentType.barbell, EquipmentType.dumbbell],
    loadType: LoadType.barbell, refLift: RefLift.deadlift, ratio: 0.7,
    compound: true, repRange: [8, 12], priority: 3,
  ),
  Exercise(
    id: 'bulgarian', name: '불가리안 스플릿 스쿼트', group: MuscleGroup.legs,
    emphasis: ['둔근', '대퇴사두', '좌우 균형'], equipment: [EquipmentType.dumbbell, EquipmentType.flatBench],
    loadType: LoadType.dumbbell, refLift: RefLift.squat, ratio: 0.18,
    compound: true, unilateral: true, repRange: [8, 12], priority: 2,
  ),
  Exercise(
    id: 'lunge', name: '워킹 런지', group: MuscleGroup.legs,
    emphasis: ['둔근', '대퇴사두'], equipment: [EquipmentType.dumbbell, EquipmentType.bodyweight],
    loadType: LoadType.dumbbell, refLift: RefLift.squat, ratio: 0.15,
    compound: true, unilateral: true, repRange: [10, 12], priority: 1,
  ),
  Exercise(
    id: 'leg_ext', name: '레그 익스텐션', group: MuscleGroup.legs,
    emphasis: ['대퇴사두 고립', '내측광근'], equipment: [EquipmentType.legExtension],
    loadType: LoadType.machine, refLift: RefLift.squat, ratio: 0.5,
    repRange: [12, 15], priority: 1,
  ),
  Exercise(
    id: 'leg_curl', name: '레그 컬', group: MuscleGroup.legs,
    emphasis: ['햄스트링 고립'], equipment: [EquipmentType.legCurl],
    loadType: LoadType.machine, refLift: RefLift.squat, ratio: 0.4,
    repRange: [12, 15], priority: 2,
  ),
  Exercise(
    id: 'hip_thrust', name: '힙 쓰러스트', group: MuscleGroup.legs,
    emphasis: ['대둔근'], equipment: [EquipmentType.hipThrust, EquipmentType.barbell],
    loadType: LoadType.barbell, refLift: RefLift.squat, ratio: 1.0,
    compound: true, repRange: [8, 12], priority: 2,
  ),
  Exercise(
    id: 'calf_raise', name: '카프 레이즈', group: MuscleGroup.legs,
    emphasis: ['종아리'], equipment: [EquipmentType.calfRaise, EquipmentType.legPress, EquipmentType.smithMachine, EquipmentType.bodyweight],
    loadType: LoadType.machine, refLift: RefLift.squat, ratio: 0.9,
    repRange: [12, 20], priority: 1,
  ),
  Exercise(
    id: 'goblet_squat', name: '고블릿 스쿼트', group: MuscleGroup.legs,
    emphasis: ['대퇴사두', '코어'], equipment: [EquipmentType.kettlebell, EquipmentType.dumbbell],
    loadType: LoadType.dumbbell, refLift: RefLift.squat, ratio: 0.3,
    compound: true, repRange: [10, 15], priority: 1,
  ),
  Exercise(
    id: 'bw_squat', name: '맨몸 스쿼트', group: MuscleGroup.legs,
    emphasis: ['대퇴사두', '둔근'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    compound: true, repRange: [15, 25], priority: 1,
  ),

  // ───────────── 어깨 ─────────────
  Exercise(
    id: 'ohp', name: '오버헤드 프레스', group: MuscleGroup.shoulder,
    emphasis: ['전면 어깨', '측면 어깨', '삼두'], equipment: [EquipmentType.barbell, EquipmentType.squatRack, EquipmentType.smithMachine],
    loadType: LoadType.barbell, refLift: RefLift.ohp, ratio: 1.0,
    compound: true, repRange: [6, 10], priority: 3,
  ),
  Exercise(
    id: 'db_shoulder_press', name: '덤벨 숄더프레스', group: MuscleGroup.shoulder,
    emphasis: ['전면 어깨', '측면 어깨'], equipment: [EquipmentType.dumbbell],
    loadType: LoadType.dumbbell, refLift: RefLift.ohp, ratio: 0.38,
    compound: true, repRange: [8, 12], priority: 3,
  ),
  Exercise(
    id: 'shoulder_press_m', name: '숄더프레스 머신', group: MuscleGroup.shoulder,
    emphasis: ['전면 어깨', '안전한 고중량'], equipment: [EquipmentType.shoulderPress],
    loadType: LoadType.machine, refLift: RefLift.ohp, ratio: 0.95,
    compound: true, repRange: [8, 12], priority: 2,
  ),
  Exercise(
    id: 'lateral_raise', name: '덤벨 사이드 레터럴 레이즈', group: MuscleGroup.shoulder,
    emphasis: ['측면 어깨(넓은 어깨)'], equipment: [EquipmentType.dumbbell],
    loadType: LoadType.dumbbell, refLift: RefLift.ohp, ratio: 0.16,
    repRange: [12, 20], priority: 3,
    description: '어깨 넓이의 핵심. 가볍게, 많이, 깔끔하게.',
  ),
  Exercise(
    id: 'cable_lateral', name: '케이블 레터럴 레이즈', group: MuscleGroup.shoulder,
    emphasis: ['측면 어깨', '일정 장력'], equipment: [EquipmentType.cableMachine],
    loadType: LoadType.cable, refLift: RefLift.ohp, ratio: 0.12,
    unilateral: true, repRange: [12, 20], priority: 2,
  ),
  Exercise(
    id: 'rear_delt_fly', name: '리어 델트 플라이', group: MuscleGroup.shoulder,
    emphasis: ['후면 어깨'], equipment: [EquipmentType.pecDeck, EquipmentType.dumbbell, EquipmentType.cableMachine],
    loadType: LoadType.machine, refLift: RefLift.ohp, ratio: 0.4,
    repRange: [12, 20], priority: 2,
    description: '후면 어깨는 대부분 부족하다. 어깨 라운드와 자세 교정에 중요.',
  ),
  Exercise(
    id: 'front_raise', name: '프론트 레이즈', group: MuscleGroup.shoulder,
    emphasis: ['전면 어깨'], equipment: [EquipmentType.dumbbell, EquipmentType.cableMachine],
    loadType: LoadType.dumbbell, refLift: RefLift.ohp, ratio: 0.16,
    repRange: [12, 15], priority: 1,
  ),
  Exercise(
    id: 'upright_row', name: '업라이트 로우', group: MuscleGroup.shoulder,
    emphasis: ['측면 어깨', '승모 상부'], equipment: [EquipmentType.barbell, EquipmentType.dumbbell, EquipmentType.cableMachine],
    loadType: LoadType.barbell, refLift: RefLift.ohp, ratio: 0.6,
    repRange: [10, 12], priority: 1,
  ),

  // ───────────── 팔 ─────────────
  Exercise(
    id: 'bb_curl', name: '바벨 컬', group: MuscleGroup.arms,
    emphasis: ['이두 전체'], equipment: [EquipmentType.barbell],
    loadType: LoadType.barbell, refLift: RefLift.row, ratio: 0.4,
    repRange: [8, 12], priority: 3,
  ),
  Exercise(
    id: 'db_curl', name: '덤벨 컬', group: MuscleGroup.arms,
    emphasis: ['이두', '회외(수피네이션)'], equipment: [EquipmentType.dumbbell],
    loadType: LoadType.dumbbell, refLift: RefLift.row, ratio: 0.18,
    repRange: [10, 12], priority: 2,
  ),
  Exercise(
    id: 'incline_curl', name: '인클라인 덤벨 컬', group: MuscleGroup.arms,
    emphasis: ['이두 장두(봉우리)'], equipment: [EquipmentType.inclineBench],
    loadType: LoadType.dumbbell, refLift: RefLift.row, ratio: 0.14,
    repRange: [10, 12], priority: 2,
  ),
  Exercise(
    id: 'preacher_curl', name: '프리처 컬', group: MuscleGroup.arms,
    emphasis: ['이두 단두(안쪽)'], equipment: [EquipmentType.preacherBench],
    loadType: LoadType.barbell, refLift: RefLift.row, ratio: 0.32,
    repRange: [10, 12], priority: 2,
  ),
  Exercise(
    id: 'hammer_curl', name: '해머 컬', group: MuscleGroup.arms,
    emphasis: ['상완근', '전완'], equipment: [EquipmentType.dumbbell],
    loadType: LoadType.dumbbell, refLift: RefLift.row, ratio: 0.2,
    repRange: [10, 12], priority: 2,
    description: '팔 두께(상완근)에 좋다.',
  ),
  Exercise(
    id: 'cable_curl', name: '케이블 컬', group: MuscleGroup.arms,
    emphasis: ['이두', '피크 수축'], equipment: [EquipmentType.cableMachine],
    loadType: LoadType.cable, refLift: RefLift.row, ratio: 0.35,
    repRange: [12, 15], priority: 1,
  ),
  Exercise(
    id: 'cgbp', name: '클로즈그립 벤치프레스', group: MuscleGroup.arms,
    emphasis: ['삼두 전체', '고중량'], equipment: [EquipmentType.barbell, EquipmentType.smithMachine],
    loadType: LoadType.barbell, refLift: RefLift.bench, ratio: 0.8,
    compound: true, repRange: [6, 10], priority: 3,
  ),
  Exercise(
    id: 'tri_pushdown', name: '케이블 트라이셉스 푸시다운', group: MuscleGroup.arms,
    emphasis: ['삼두 외측두'], equipment: [EquipmentType.cableMachine],
    loadType: LoadType.cable, refLift: RefLift.bench, ratio: 0.3,
    repRange: [10, 15], priority: 3,
  ),
  Exercise(
    id: 'overhead_tri', name: '오버헤드 트라이셉스 익스텐션', group: MuscleGroup.arms,
    emphasis: ['삼두 장두'], equipment: [EquipmentType.cableMachine, EquipmentType.dumbbell],
    loadType: LoadType.cable, refLift: RefLift.bench, ratio: 0.25,
    repRange: [10, 15], priority: 2,
    description: '팔을 머리 위로 올리면 삼두 장두가 늘어나 가장 잘 먹는다.',
  ),
  Exercise(
    id: 'skull_crusher', name: '스컬 크러셔', group: MuscleGroup.arms,
    emphasis: ['삼두 장두'], equipment: [EquipmentType.barbell, EquipmentType.dumbbell],
    loadType: LoadType.barbell, refLift: RefLift.bench, ratio: 0.35,
    repRange: [8, 12], priority: 2,
  ),
  Exercise(
    id: 'tri_dips', name: '트라이셉스 딥스', group: MuscleGroup.arms,
    emphasis: ['삼두 전체'], equipment: [EquipmentType.dipStation, EquipmentType.flatBench],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    compound: true, repRange: [8, 15], priority: 2,
  ),
  Exercise(
    id: 'kickback', name: '덤벨 킥백', group: MuscleGroup.arms,
    emphasis: ['삼두 외측두', '피크 수축'], equipment: [EquipmentType.dumbbell],
    loadType: LoadType.dumbbell, refLift: RefLift.bench, ratio: 0.1,
    unilateral: true, repRange: [12, 15], priority: 1,
  ),

  // ───────────── 복근 ─────────────
  Exercise(
    id: 'hanging_leg_raise', name: '행잉 레그 레이즈', group: MuscleGroup.abs,
    emphasis: ['하복부'], equipment: [EquipmentType.pullUpBar, EquipmentType.dipStation],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [10, 15], priority: 3,
  ),
  Exercise(
    id: 'cable_crunch', name: '케이블 크런치', group: MuscleGroup.abs,
    emphasis: ['상복부', '점진적 과부하'], equipment: [EquipmentType.cableMachine],
    loadType: LoadType.cable, refLift: RefLift.row, ratio: 0.5,
    repRange: [12, 15], priority: 2,
  ),
  Exercise(
    id: 'ab_machine', name: '복근 머신 크런치', group: MuscleGroup.abs,
    emphasis: ['상복부'], equipment: [EquipmentType.abCrunchMachine],
    loadType: LoadType.machine, refLift: RefLift.row, ratio: 0.6,
    repRange: [12, 15], priority: 2,
  ),
  Exercise(
    id: 'plank', name: '플랭크', group: MuscleGroup.abs,
    emphasis: ['코어 안정', '복횡근'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [45, 60], priority: 2,
    description: '횟수 대신 초(sec)로 수행한다.',
  ),
  Exercise(
    id: 'crunch', name: '크런치', group: MuscleGroup.abs,
    emphasis: ['상복부'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [15, 25], priority: 1,
  ),
  Exercise(
    id: 'leg_raise', name: '라잉 레그 레이즈', group: MuscleGroup.abs,
    emphasis: ['하복부'], equipment: [EquipmentType.bodyweight, EquipmentType.flatBench],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [12, 20], priority: 2,
  ),
  Exercise(
    id: 'russian_twist', name: '러시안 트위스트', group: MuscleGroup.abs,
    emphasis: ['복사근'], equipment: [EquipmentType.bodyweight, EquipmentType.kettlebell, EquipmentType.dumbbell],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [20, 30], priority: 1,
  ),
  Exercise(
    id: 'side_bend', name: '로만체어 사이드 벤드', group: MuscleGroup.abs,
    emphasis: ['복사근'], equipment: [EquipmentType.romanChair],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    unilateral: true, repRange: [12, 15], priority: 1,
  ),

  // ───────────── 유산소 (repRange = 분) ─────────────
  Exercise(
    id: 'treadmill_walk', name: '트레드밀 인클라인 워킹', group: MuscleGroup.cardio,
    emphasis: ['지방 연소', '둔근·종아리'], equipment: [EquipmentType.treadmill],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [15, 25], priority: 3,
    description: '경사 8~12%, 속도 5~6km/h. 숫자는 분(min).',
  ),
  Exercise(
    id: 'treadmill_run', name: '트레드밀 러닝', group: MuscleGroup.cardio,
    emphasis: ['심폐 지구력'], equipment: [EquipmentType.treadmill],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [15, 25], priority: 2,
  ),
  Exercise(
    id: 'bike', name: '사이클', group: MuscleGroup.cardio,
    emphasis: ['무릎 부담 ↓', '하체 회복'], equipment: [EquipmentType.bike],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [15, 25], priority: 2,
  ),
  Exercise(
    id: 'rowing', name: '로잉 머신', group: MuscleGroup.cardio,
    emphasis: ['전신', '등 보조'], equipment: [EquipmentType.rower],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [12, 20], priority: 2,
  ),
  Exercise(
    id: 'stairs', name: '스텝밀', group: MuscleGroup.cardio,
    emphasis: ['둔근', '고강도'], equipment: [EquipmentType.stairClimber],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [10, 20], priority: 2,
  ),
  Exercise(
    id: 'elliptical', name: '일립티컬', group: MuscleGroup.cardio,
    emphasis: ['저충격', '전신'], equipment: [EquipmentType.elliptical],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [15, 25], priority: 1,
  ),
  Exercise(
    id: 'kb_swing', name: '케틀벨 스윙', group: MuscleGroup.cardio,
    emphasis: ['후면 사슬', '컨디셔닝'], equipment: [EquipmentType.kettlebell],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [8, 12], priority: 1,
  ),
  Exercise(
    id: 'burpee', name: '버피', group: MuscleGroup.cardio,
    emphasis: ['전신', '고강도 인터벌'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [8, 12], priority: 1,
  ),
];

final Map<String, Exercise> _byId = {
  for (final e in exerciseCatalog) e.id: e,
};

Exercise? exerciseById(String id) => _byId[id];

List<Exercise> exercisesOf(MuscleGroup g) =>
    exerciseCatalog.where((e) => e.group == g).toList();
