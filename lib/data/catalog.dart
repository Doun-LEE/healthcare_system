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
    this.altGroups = const [],
    this.warmupOnly = false,
    this.activity = false,
    this.needs = const {},
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

  /// 자세에 따라 타깃이 바뀌는 운동(덤벨 풀오버: 등 ↔ 가슴). 루틴에서 타깃을 바꿀 수 있다.
  final List<MuscleGroup> altGroups;

  /// 워밍업·스트레칭 전용(본 운동으로는 뽑지 않는다).
  final bool warmupOnly;

  /// 기구별로 같이 있어야 하는 것(예: 덤벨 → 인클라인 벤치). 그중 하나라도 있으면 된다.
  final Map<EquipmentType, List<EquipmentType>> needs;

  /// 축구·농구 같은 스포츠·활동. 기구 없이 언제든 직접 추가할 수 있고, 루틴 자동 생성엔 넣지 않는다.
  final bool activity;

  bool _usable(EquipmentType e, Set<EquipmentType> available) =>
      available.contains(e) && (needs[e]?.any(available.contains) ?? true);

  bool canDoWith(Set<EquipmentType> available) =>
      activity || equipment.any((e) => _usable(e, available));

  /// 주어진 기구 집합에서 실제로 쓸 기구 하나를 고른다(정의 순서 우선).
  EquipmentType pickEquipment(Set<EquipmentType> available) =>
      equipment.firstWhere((e) => _usable(e, available), orElse: () => equipment.first);

  /// 이 운동에 쓰이는 모든 기구(같이 필요한 벤치 등 포함).
  Set<EquipmentType> get allEquipment => {...equipment, for (final l in needs.values) ...l};
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
    type: EquipmentType.latPulldownPlateLoaded,
    summary: '원판을 끼우는 풀다운. 한쪽씩 당겨 좌우 균형을 맞추기 좋다.',
    strengths: ['광배(넓이)', '좌우 독립', '안전한 고중량'],
    groups: [MuscleGroup.back],
  ),
  EquipmentInfo(
    type: EquipmentType.standingLegCurl,
    summary: '서서 한 다리씩 하는 레그 컬. 햄스트링 고립.',
    strengths: ['햄스트링 고립', '좌우 독립'],
    groups: [MuscleGroup.legs],
  ),
  EquipmentInfo(
    type: EquipmentType.multiHip,
    summary: '킥백·어브덕션·어덕션·힙 플렉션을 한 기구에서. 둔근·중둔근.',
    strengths: ['대둔근 고립', '중둔근(힙 라인)', '좌우 독립'],
    groups: [MuscleGroup.legs],
  ),
  EquipmentInfo(
    type: EquipmentType.monsterGlute,
    summary: '서서 상체를 고정하고 고관절을 펴는 둔근 전용 머신. 힙 쓰러스트와 비슷하지만 세팅이 빠르다.',
    strengths: ['대둔근 고립', '허리 부담 ↓', '안전한 고중량'],
    groups: [MuscleGroup.legs],
  ),
  EquipmentInfo(
    type: EquipmentType.abCoaster,
    summary: '무릎을 당겨 올리는 복근 기구. 하복부에 집중.',
    strengths: ['하복부', '허리 부담 ↓'],
    groups: [MuscleGroup.abs],
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

  // ───── 프리웨이트 추가 ─────
  EquipmentInfo(
    type: EquipmentType.ezBar,
    summary: '손목 각도가 자연스러운 굽은 바. 컬·스컬크러셔에 손목 부담이 적다.',
    strengths: ['이두 컬(손목 편함)', '스컬 크러셔', '업라이트 로우'],
    groups: [MuscleGroup.arms],
  ),
  EquipmentInfo(
    type: EquipmentType.trapBar,
    summary: '안에 들어가서 드는 육각 바. 데드리프트가 허리 부담 적고 사두 개입이 크다.',
    strengths: ['데드리프트 입문', '허리 부담 ↓', '대퇴사두+후면 사슬'],
    groups: [MuscleGroup.legs, MuscleGroup.back],
  ),
  EquipmentInfo(
    type: EquipmentType.safetySquatBar,
    summary: '어깨에 패드가 있는 스쿼트 바. 어깨 가동성이 안 좋아도 스쿼트 가능, 상체가 세워진다.',
    strengths: ['상체 직립 스쿼트', '어깨·손목 부담 ↓', '대퇴사두·상부 등'],
    groups: [MuscleGroup.legs],
  ),
  EquipmentInfo(
    type: EquipmentType.fixedBarbell,
    summary: '무게가 고정된 짧은 바벨 세트. 원판 교체 없이 빠르게 컬/프레스.',
    strengths: ['빠른 무게 교체', '컬·오버헤드 익스텐션', '드롭세트'],
    groups: [MuscleGroup.arms, MuscleGroup.shoulder],
  ),
  EquipmentInfo(
    type: EquipmentType.medicineBall,
    summary: '던지고 내리치는 공. 코어 파워·컨디셔닝.',
    strengths: ['슬램(전신 파워)', '러시안 트위스트', '월볼'],
    groups: [MuscleGroup.abs, MuscleGroup.cardio],
  ),

  // ───── 벤치·랙 추가 ─────
  EquipmentInfo(
    type: EquipmentType.declineBench,
    summary: '머리가 아래로 가는 벤치. 아랫가슴과 디클라인 싯업.',
    strengths: ['아랫가슴', '디클라인 싯업(복근)'],
    groups: [MuscleGroup.chest, MuscleGroup.abs],
  ),
  EquipmentInfo(
    type: EquipmentType.halfRack,
    summary: '기둥 2개짜리 랙. 파워랙과 같은 운동을 적은 공간에서.',
    strengths: ['스쿼트·OHP·랙풀', '좁은 공간'],
    groups: [MuscleGroup.legs, MuscleGroup.back, MuscleGroup.shoulder],
  ),
  EquipmentInfo(
    type: EquipmentType.assistedPullUp,
    summary: '무릎 패드가 체중을 덜어주는 풀업/딥 머신. 풀업 못 하는 사람의 필수 코스.',
    strengths: ['풀업·딥스 입문', '보조 무게로 점진적 진행', '광배·삼두'],
    groups: [MuscleGroup.back, MuscleGroup.arms, MuscleGroup.chest],
  ),
  EquipmentInfo(
    type: EquipmentType.ghd,
    summary: '글루트 햄 디벨로퍼. 햄스트링·둔근·기립근 후면 사슬 전체, GHD 싯업.',
    strengths: ['햄스트링(GHR)', '둔근·기립근', 'GHD 싯업'],
    groups: [MuscleGroup.legs, MuscleGroup.back, MuscleGroup.abs],
  ),
  EquipmentInfo(
    type: EquipmentType.multiStation,
    summary: '랫풀·로우·체스트프레스·레그익스텐션이 하나에 붙은 홈짐.',
    strengths: ['한 대로 전신', '홈트', '케이블 운동 대부분'],
    groups: [MuscleGroup.chest, MuscleGroup.back, MuscleGroup.legs, MuscleGroup.arms],
  ),

  // ───── 가슴 추가 ─────
  EquipmentInfo(
    type: EquipmentType.inclineChestPress,
    summary: '윗가슴 각도로 고정된 프레스 머신. 안전하게 윗가슴 고중량.',
    strengths: ['윗가슴(쇄골부)', '안정적 고중량'],
    groups: [MuscleGroup.chest],
  ),
  EquipmentInfo(
    type: EquipmentType.declineChestPress,
    summary: '아랫가슴 각도 프레스 머신.',
    strengths: ['아랫가슴', '가슴 하부 라인'],
    groups: [MuscleGroup.chest],
  ),
  EquipmentInfo(
    type: EquipmentType.chestPressPlateLoaded,
    summary: '원판을 끼우는 해머스트렝스식 프레스. 좌우 독립(아이소 래터럴)으로 프리웨이트 느낌.',
    strengths: ['좌우 독립 프레스', '가슴 중앙·윗가슴(기울기에 따라)', '고중량'],
    groups: [MuscleGroup.chest],
  ),
  EquipmentInfo(
    type: EquipmentType.functionalTrainer,
    summary: '양쪽 도르래 높이를 자유롭게 바꾸는 듀얼 케이블. 케이블 운동 전부 가능.',
    strengths: ['전 부위 케이블 운동', '회전·기능성 동작', '피크 수축'],
    groups: [MuscleGroup.chest, MuscleGroup.back, MuscleGroup.shoulder, MuscleGroup.arms, MuscleGroup.abs],
  ),

  // ───── 등 추가 ─────
  EquipmentInfo(
    type: EquipmentType.chestSupportedRow,
    summary: '가슴을 패드에 대고 당기는 로우 머신. 허리 개입 없이 등만 고립.',
    strengths: ['등 두께(능형근·중부 승모)', '허리 부담 0', '리어 델트'],
    groups: [MuscleGroup.back],
  ),
  EquipmentInfo(
    type: EquipmentType.highRow,
    summary: '위에서 아래·뒤로 당기는 플레이트 로디드 머신. 랫풀다운과 로우의 중간.',
    strengths: ['광배 상부·넓이', '대원근', '좌우 독립'],
    groups: [MuscleGroup.back],
  ),
  EquipmentInfo(
    type: EquipmentType.lowRow,
    summary: '아래에서 몸쪽으로 당기는 플레이트 로디드 로우(해머 로우).',
    strengths: ['광배 하부·등 하부', '등 두께', '좌우 독립'],
    groups: [MuscleGroup.back],
  ),
  EquipmentInfo(
    type: EquipmentType.tBarRow,
    summary: '가슴 패드가 있는 티바 로우 머신.',
    strengths: ['등 중앙 두께', '승모 중·하부'],
    groups: [MuscleGroup.back],
  ),
  EquipmentInfo(
    type: EquipmentType.pulloverMachine,
    summary: '팔을 편 채 머리 위에서 내리는 머신. 광배 고립의 끝판왕.',
    strengths: ['광배 고립(팔 개입 ↓)', '가슴 확장'],
    groups: [MuscleGroup.back],
  ),
  EquipmentInfo(
    type: EquipmentType.shrugMachine,
    summary: '승모 상부 전용 머신.',
    strengths: ['승모 상부', '악력 부담 ↓'],
    groups: [MuscleGroup.back],
  ),
  EquipmentInfo(
    type: EquipmentType.backExtensionMachine,
    summary: '앉아서 등을 뒤로 펴는 머신. 척추기립근을 중량으로.',
    strengths: ['등 하부(기립근) 중량 훈련', '허리 강화'],
    groups: [MuscleGroup.back],
  ),
  EquipmentInfo(
    type: EquipmentType.reverseHyper,
    summary: '다리를 뒤로 올리는 머신. 둔근·햄과 함께 허리 감압 효과.',
    strengths: ['둔근·햄스트링', '등 하부 회복/감압'],
    groups: [MuscleGroup.legs, MuscleGroup.back],
  ),

  // ───── 어깨 추가 ─────
  EquipmentInfo(
    type: EquipmentType.shoulderPressPlateLoaded,
    summary: '플레이트 로디드 숄더 프레스. 좌우 독립, 궤도가 자연스럽다.',
    strengths: ['전면·측면 어깨 고중량', '좌우 독립'],
    groups: [MuscleGroup.shoulder],
  ),
  EquipmentInfo(
    type: EquipmentType.lateralRaiseMachine,
    summary: '측면 삼각근 전용 머신. 반동 없이 측면만 고립.',
    strengths: ['측면 어깨 고립(넓은 어깨)', '반동 차단', '드롭세트'],
    groups: [MuscleGroup.shoulder],
  ),
  EquipmentInfo(
    type: EquipmentType.rearDeltMachine,
    summary: '후면 삼각근 전용 머신.',
    strengths: ['후면 어깨', '자세 교정(라운드 숄더)'],
    groups: [MuscleGroup.shoulder, MuscleGroup.back],
  ),

  // ───── 팔 추가 ─────
  EquipmentInfo(
    type: EquipmentType.bicepCurlMachine,
    summary: '팔꿈치를 패드에 고정하는 이두 머신.',
    strengths: ['이두 고립', '피크 수축', '마무리 펌핑'],
    groups: [MuscleGroup.arms],
  ),
  EquipmentInfo(
    type: EquipmentType.preacherCurlMachine,
    summary: '프리처 각도의 이두 머신.',
    strengths: ['이두 단두', '반동 차단'],
    groups: [MuscleGroup.arms],
  ),
  EquipmentInfo(
    type: EquipmentType.tricepExtensionMachine,
    summary: '앉아서 팔꿈치를 펴는 삼두 머신.',
    strengths: ['삼두 고립', '팔꿈치 부담 ↓'],
    groups: [MuscleGroup.arms],
  ),
  EquipmentInfo(
    type: EquipmentType.dipMachine,
    summary: '앉아서 아래로 누르는 딥 머신. 삼두·아랫가슴.',
    strengths: ['삼두 고중량', '아랫가슴', '딥스 대체'],
    groups: [MuscleGroup.arms, MuscleGroup.chest],
  ),

  // ───── 하체 추가 ─────
  EquipmentInfo(
    type: EquipmentType.horizontalLegPress,
    summary: '앉아서 수평으로 미는 레그 프레스. 가동범위 짧고 안전.',
    strengths: ['대퇴사두', '입문자·재활', '허리 부담 ↓'],
    groups: [MuscleGroup.legs],
  ),
  EquipmentInfo(
    type: EquipmentType.pendulumSquat,
    summary: '호를 그리며 내려가는 스쿼트 머신. 사두 자극이 매우 크다.',
    strengths: ['대퇴사두 극대화', '깊은 가동범위', '허리 부담 ↓'],
    groups: [MuscleGroup.legs],
  ),
  EquipmentInfo(
    type: EquipmentType.vSquat,
    summary: '어깨 패드를 지고 비스듬히 서서 하는 스쿼트 머신.',
    strengths: ['대퇴사두·둔근', '안정적 고중량'],
    groups: [MuscleGroup.legs],
  ),
  EquipmentInfo(
    type: EquipmentType.beltSquat,
    summary: '허리 벨트에 하중을 거는 스쿼트. 척추에 부하가 0.',
    strengths: ['허리 부담 0 스쿼트', '대퇴사두·둔근', '고볼륨'],
    groups: [MuscleGroup.legs],
  ),
  EquipmentInfo(
    type: EquipmentType.lyingLegCurl,
    summary: '엎드려서 하는 레그 컬. 햄스트링 수축이 강하다.',
    strengths: ['햄스트링 피크 수축', '둔근 보조'],
    groups: [MuscleGroup.legs],
  ),
  EquipmentInfo(
    type: EquipmentType.hipAbductor,
    summary: '다리를 바깥으로 벌리는 머신. 중둔근(엉덩이 옆).',
    strengths: ['중둔근(힙 라인)', '무릎 안정'],
    groups: [MuscleGroup.legs],
  ),
  EquipmentInfo(
    type: EquipmentType.hipAdductor,
    summary: '다리를 안으로 모으는 머신. 내전근(허벅지 안쪽).',
    strengths: ['내전근', '스쿼트 안정성'],
    groups: [MuscleGroup.legs],
  ),
  EquipmentInfo(
    type: EquipmentType.gluteKickback,
    summary: '한 다리씩 뒤로 차는 글루트 머신.',
    strengths: ['대둔근 고립', '좌우 균형'],
    groups: [MuscleGroup.legs],
  ),
  EquipmentInfo(
    type: EquipmentType.seatedCalfRaise,
    summary: '앉아서 하는 카프 레이즈. 가자미근(종아리 아래 넓은 근육).',
    strengths: ['가자미근', '종아리 두께'],
    groups: [MuscleGroup.legs],
  ),
  EquipmentInfo(
    type: EquipmentType.sissySquat,
    summary: '발목을 고정하고 뒤로 눕듯 내려가는 사두 고립 기구.',
    strengths: ['대퇴사두(특히 대퇴직근)', '맨몸으로 고강도'],
    groups: [MuscleGroup.legs],
  ),
  EquipmentInfo(
    type: EquipmentType.nordicBench,
    summary: '발목을 걸고 상체를 앞으로 내리는 노르딕 컬 벤치.',
    strengths: ['햄스트링 신장성 수축', '부상 예방'],
    groups: [MuscleGroup.legs],
  ),

  // ───── 복근·코어 추가 ─────
  EquipmentInfo(
    type: EquipmentType.torsoRotation,
    summary: '앉아서 몸통을 회전하는 머신. 복사근.',
    strengths: ['복사근', '회전 코어'],
    groups: [MuscleGroup.abs],
  ),
  EquipmentInfo(
    type: EquipmentType.captainsChair,
    summary: '팔꿈치를 걸고 다리를 올리는 스테이션. 하복부.',
    strengths: ['하복부', '고관절 굴곡근'],
    groups: [MuscleGroup.abs],
  ),
  EquipmentInfo(
    type: EquipmentType.declineAbBench,
    summary: '발을 걸고 하는 싯업 벤치. 각도로 강도 조절.',
    strengths: ['상복부', '강도 조절 쉬움'],
    groups: [MuscleGroup.abs],
  ),
  EquipmentInfo(
    type: EquipmentType.abWheel,
    summary: '굴리는 복근 롤러. 코어 전체에 가장 강한 맨몸 운동 중 하나.',
    strengths: ['복직근·복횡근', '코어 안정', '광배 보조'],
    groups: [MuscleGroup.abs],
  ),

  // ───── 유산소 추가 ─────
  EquipmentInfo(
    type: EquipmentType.curvedTreadmill,
    summary: '무동력 곡선 트레드밀. 스프린트·인터벌에 최적.',
    strengths: ['스프린트 인터벌', '칼로리 소모 ↑', '햄스트링·둔근'],
    groups: [MuscleGroup.cardio],
  ),
  EquipmentInfo(
    type: EquipmentType.spinBike,
    summary: '무거운 플라이휠 자전거. 고강도 유산소.',
    strengths: ['고강도 인터벌', '하체 지구력'],
    groups: [MuscleGroup.cardio],
  ),
  EquipmentInfo(
    type: EquipmentType.recumbentBike,
    summary: '등받이 있는 좌식 자전거. 허리·무릎 부담 최소.',
    strengths: ['저충격', '재활·회복', '긴 시간 유산소'],
    groups: [MuscleGroup.cardio],
  ),
  EquipmentInfo(
    type: EquipmentType.assaultBike,
    summary: '팔다리를 같이 쓰는 에어 바이크. 가장 힘든 컨디셔닝 기구.',
    strengths: ['전신 HIIT', '최대 칼로리', '타바타'],
    groups: [MuscleGroup.cardio],
  ),
  EquipmentInfo(
    type: EquipmentType.skiErg,
    summary: '스키 폴 동작의 상체 유산소.',
    strengths: ['상체 유산소', '광배·삼두·코어', '하체 쉬는 날 유산소'],
    groups: [MuscleGroup.cardio, MuscleGroup.back],
  ),
  EquipmentInfo(
    type: EquipmentType.jacobsLadder,
    summary: '기울어진 사다리를 오르는 기구. 전신 유산소.',
    strengths: ['전신', '관절 부담 ↓', '코어'],
    groups: [MuscleGroup.cardio],
  ),
  EquipmentInfo(
    type: EquipmentType.versaClimber,
    summary: '수직으로 기어오르는 기구(마운틴 클라이머 머신). 팔다리를 번갈아 밀고 당긴다.',
    strengths: ['전신 고강도', '짧은 시간 최대 효과', '상체·코어 함께'],
    groups: [MuscleGroup.cardio],
  ),
  EquipmentInfo(
    type: EquipmentType.jumpRope,
    summary: '줄넘기. 워밍업과 인터벌.',
    strengths: ['워밍업', '종아리·협응', '어디서나'],
    groups: [MuscleGroup.cardio],
  ),
  EquipmentInfo(
    type: EquipmentType.outdoor,
    summary: '헬스장 밖에서 하는 유산소. 체크하면 러닝·산 뛰기·등산·자전거·계단이 루틴 유산소로 뽑힌다.',
    strengths: ['산 뛰기(트레일)', '러닝·걷기', '등산', '야외 자전거', '계단 오르기'],
    groups: [MuscleGroup.cardio, MuscleGroup.legs],
  ),
  EquipmentInfo(
    type: EquipmentType.pool,
    summary: '수영. 관절 부담 없는 전신 유산소.',
    strengths: ['전신 저충격', '회복', '어깨·등 지구력'],
    groups: [MuscleGroup.cardio],
  ),

  // ───── 기능성·기타 추가 ─────
  EquipmentInfo(
    type: EquipmentType.landmine,
    summary: '바벨 한쪽을 바닥에 고정하는 기구. 프레스·로우·로테이션.',
    strengths: ['랜드마인 프레스(어깨 안전)', '티바 로우', '코어 회전'],
    groups: [MuscleGroup.shoulder, MuscleGroup.back, MuscleGroup.abs],
  ),
  EquipmentInfo(
    type: EquipmentType.sled,
    summary: '밀고 끄는 썰매. 하체 컨디셔닝, 근육 손상 없이 고강도.',
    strengths: ['하체 컨디셔닝', '근육통 없는 고강도', '마무리'],
    groups: [MuscleGroup.cardio, MuscleGroup.legs],
  ),
  EquipmentInfo(
    type: EquipmentType.battleRope,
    summary: '굵은 로프를 흔드는 컨디셔닝.',
    strengths: ['상체 HIIT', '어깨·코어 지구력'],
    groups: [MuscleGroup.cardio, MuscleGroup.shoulder],
  ),
  EquipmentInfo(
    type: EquipmentType.plyoBox,
    summary: '점프 박스. 폭발력과 스텝업.',
    strengths: ['박스 점프(폭발력)', '스텝업(둔근)', '불가리안 받침'],
    groups: [MuscleGroup.legs, MuscleGroup.cardio],
  ),
  EquipmentInfo(
    type: EquipmentType.trx,
    summary: '천장에 매단 스트랩. 체중으로 로우·푸시업·코어.',
    strengths: ['TRX 로우(등)', '코어', '어디서나 맨몸 강도 조절'],
    groups: [MuscleGroup.back, MuscleGroup.abs, MuscleGroup.chest],
  ),
  EquipmentInfo(
    type: EquipmentType.resistanceBand,
    summary: '고무 밴드. 워밍업, 보조, 후면 어깨.',
    strengths: ['풀어파트(후면 어깨·회전근개)', '워밍업', '풀업 보조'],
    groups: [MuscleGroup.shoulder, MuscleGroup.back],
  ),
];

EquipmentInfo equipmentInfo(EquipmentType t) =>
    equipmentCatalog.firstWhere((e) => e.type == t);

const List<Exercise> exerciseCatalog = [
  // ── 워밍업·스트레칭(본 운동 전 준비용) ──
  Exercise(
    id: 'dyn_stretch', name: '동적 스트레칭(전신)', group: MuscleGroup.cardio,
    emphasis: ['워밍업', '가동범위 ↑'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [5, 5], priority: 1, warmupOnly: true,
    description: '팔·어깨 돌리기, 다리 스윙, 런지 트위스트 등 관절을 움직이며 체온을 올린다.',
  ),
  Exercise(
    id: 'arm_circles', name: '암 서클·어깨 돌리기', group: MuscleGroup.shoulder,
    emphasis: ['측면 어깨', '어깨 안전'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [15, 20], priority: 1, warmupOnly: true,
  ),
  Exercise(
    id: 'band_dislocate', name: '밴드 숄더 디스로케이트', group: MuscleGroup.shoulder,
    emphasis: ['후면 어깨', '회전근개'], equipment: [EquipmentType.resistanceBand],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [10, 15], priority: 1, warmupOnly: true,
  ),
  Exercise(
    id: 'scap_pushup', name: '스캐퓰러 푸시업', group: MuscleGroup.chest,
    emphasis: ['가슴 중앙부', '회전근개'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [10, 15], priority: 1, warmupOnly: true,
  ),
  Exercise(
    id: 'cat_cow', name: '캣카우', group: MuscleGroup.back,
    emphasis: ['등 하부', '부상 예방'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [10, 12], priority: 1, warmupOnly: true,
  ),
  Exercise(
    id: 'worlds_greatest', name: '월드 그레이티스트 스트레치', group: MuscleGroup.legs,
    emphasis: ['둔근', '햄스트링', '가동범위 ↑'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [6, 8], priority: 1, unilateral: true, warmupOnly: true,
  ),
  Exercise(
    id: 'hip_9090', name: '고관절 90/90 스트레칭', group: MuscleGroup.legs,
    emphasis: ['둔근', '내전근'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [8, 10], priority: 1, warmupOnly: true,
  ),
  Exercise(
    id: 'glute_bridge', name: '글루트 브릿지', group: MuscleGroup.legs,
    emphasis: ['둔근'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [12, 15], priority: 1, warmupOnly: true,
  ),

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
    emphasis: ['윗가슴'], equipment: [EquipmentType.dumbbell],
    loadType: LoadType.dumbbell, refLift: RefLift.bench, ratio: 0.3,
    compound: true, repRange: [8, 12], priority: 2,
    needs: {EquipmentType.dumbbell: [EquipmentType.inclineBench]},
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
    emphasis: ['아랫가슴', '삼두'], equipment: [EquipmentType.dipStation, EquipmentType.captainsChair],
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
    emphasis: ['광배(넓이)'], equipment: [EquipmentType.latPulldown, EquipmentType.latPulldownPlateLoaded, EquipmentType.cableMachine],
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
    emphasis: ['광배 하부', '등 두께'], equipment: [EquipmentType.dumbbell, EquipmentType.kettlebell],
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
    emphasis: ['후면 어깨', '등 상부', '회전근개'], equipment: [EquipmentType.cableMachine, EquipmentType.resistanceBand],
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
    emphasis: ['햄스트링', '둔근', '등 하부'], equipment: [EquipmentType.barbell, EquipmentType.dumbbell, EquipmentType.smithMachine, EquipmentType.kettlebell],
    loadType: LoadType.barbell, refLift: RefLift.deadlift, ratio: 0.7,
    compound: true, repRange: [8, 12], priority: 3,
  ),
  Exercise(
    id: 'bb_stiff_deadlift', name: '바벨 스티프 레그 데드리프트', group: MuscleGroup.legs,
    emphasis: ['햄스트링', '둔근', '등 하부'], equipment: [EquipmentType.barbell],
    loadType: LoadType.barbell, refLift: RefLift.deadlift, ratio: 0.6,
    compound: true, repRange: [8, 12], priority: 2,
    description: '루마니안보다 무릎을 더 펴고 햄스트링을 길게 늘린다. 무게는 가볍게.',
  ),
  Exercise(
    id: 'db_stiff_deadlift', name: '덤벨 스티프 레그 데드리프트', group: MuscleGroup.legs,
    emphasis: ['햄스트링', '둔근', '등 하부'], equipment: [EquipmentType.dumbbell],
    loadType: LoadType.dumbbell, refLift: RefLift.deadlift, ratio: 0.25,
    compound: true, repRange: [10, 12], priority: 2,
    description: '숫자는 한 손 덤벨 무게.',
  ),
  Exercise(
    id: 'bulgarian', name: '불가리안 스플릿 스쿼트', group: MuscleGroup.legs,
    emphasis: ['둔근', '대퇴사두', '좌우 균형'], equipment: [EquipmentType.dumbbell, EquipmentType.flatBench],
    loadType: LoadType.dumbbell, refLift: RefLift.squat, ratio: 0.18,
    compound: true, unilateral: true, repRange: [8, 12], priority: 2,
  ),
  Exercise(
    id: 'lunge', name: '워킹 런지', group: MuscleGroup.legs,
    emphasis: ['둔근', '대퇴사두'], equipment: [EquipmentType.dumbbell, EquipmentType.kettlebell, EquipmentType.smithMachine, EquipmentType.bodyweight],
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
    emphasis: ['햄스트링 고립'], equipment: [EquipmentType.legCurl, EquipmentType.standingLegCurl],
    loadType: LoadType.machine, refLift: RefLift.squat, ratio: 0.4,
    repRange: [12, 15], priority: 2,
  ),
  Exercise(
    id: 'hip_thrust', name: '힙 쓰러스트', group: MuscleGroup.legs,
    emphasis: ['대둔근'], equipment: [EquipmentType.hipThrust, EquipmentType.barbell, EquipmentType.smithMachine],
    loadType: LoadType.barbell, refLift: RefLift.squat, ratio: 1.0,
    compound: true, repRange: [8, 12], priority: 2,
  ),
  Exercise(
    id: 'calf_raise', name: '카프 레이즈', group: MuscleGroup.legs,
    emphasis: ['종아리'], equipment: [EquipmentType.calfRaise, EquipmentType.legPress, EquipmentType.hackSquat, EquipmentType.smithMachine, EquipmentType.bodyweight],
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
    emphasis: ['후면 어깨'], equipment: [EquipmentType.dumbbell, EquipmentType.cableMachine],
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
    emphasis: ['측면 어깨', '승모 상부'], equipment: [EquipmentType.barbell, EquipmentType.dumbbell, EquipmentType.cableMachine, EquipmentType.ezBar, EquipmentType.fixedBarbell],
    loadType: LoadType.barbell, refLift: RefLift.ohp, ratio: 0.6,
    repRange: [10, 12], priority: 1,
  ),

  // ───────────── 팔 ─────────────
  Exercise(
    id: 'bb_curl', name: '바벨 컬', group: MuscleGroup.arms,
    emphasis: ['이두 전체'], equipment: [EquipmentType.barbell, EquipmentType.ezBar, EquipmentType.fixedBarbell],
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
    emphasis: ['이두 장두(봉우리)'], equipment: [EquipmentType.dumbbell],
    loadType: LoadType.dumbbell, refLift: RefLift.row, ratio: 0.14,
    repRange: [10, 12], priority: 2,
    needs: {EquipmentType.dumbbell: [EquipmentType.inclineBench]},
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
    emphasis: ['삼두 장두'], equipment: [EquipmentType.barbell, EquipmentType.dumbbell, EquipmentType.fixedBarbell],
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
    id: 'monster_glute', name: '몬스터 글루트', group: MuscleGroup.legs,
    emphasis: ['대둔근', '허리 부담 ↓'], equipment: [EquipmentType.monsterGlute],
    loadType: LoadType.machine, refLift: RefLift.squat, ratio: 0.9,
    repRange: [10, 15], priority: 2,
  ),
  Exercise(
    id: 'ab_coaster', name: '앱 코스터', group: MuscleGroup.abs,
    emphasis: ['하복부', '허리 부담 ↓'], equipment: [EquipmentType.abCoaster],
    loadType: LoadType.machine, refLift: RefLift.row, ratio: 0.3,
    repRange: [12, 20], priority: 2,
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
    emphasis: ['복사근'], equipment: [EquipmentType.bodyweight, EquipmentType.kettlebell, EquipmentType.dumbbell, EquipmentType.medicineBall],
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
    id: 'stairs', name: '천국의 계단', group: MuscleGroup.cardio,
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

  // ═════════ 확장 기구용 운동 ═════════
  // ── 가슴 ──
  Exercise(
    id: 'decline_bb', name: '디클라인 바벨프레스', group: MuscleGroup.chest,
    emphasis: ['아랫가슴'], equipment: [EquipmentType.declineBench],
    loadType: LoadType.barbell, refLift: RefLift.bench, ratio: 1.05,
    compound: true, repRange: [6, 10], priority: 2,
  ),
  Exercise(
    id: 'incline_press_m', name: '인클라인 체스트프레스 머신', group: MuscleGroup.chest,
    emphasis: ['윗가슴', '안전한 고중량'], equipment: [EquipmentType.inclineChestPress],
    loadType: LoadType.machine, refLift: RefLift.bench, ratio: 0.75,
    compound: true, repRange: [8, 12], priority: 2,
  ),
  Exercise(
    id: 'decline_press_m', name: '디클라인 체스트프레스 머신', group: MuscleGroup.chest,
    emphasis: ['아랫가슴'], equipment: [EquipmentType.declineChestPress],
    loadType: LoadType.machine, refLift: RefLift.bench, ratio: 0.95,
    compound: true, repRange: [8, 12], priority: 1,
  ),
  Exercise(
    id: 'hammer_chest', name: '플레이트 로디드 체스트프레스', group: MuscleGroup.chest,
    emphasis: ['가슴 중앙부', '좌우 독립'], equipment: [EquipmentType.chestPressPlateLoaded],
    loadType: LoadType.machine, refLift: RefLift.bench, ratio: 0.8,
    compound: true, repRange: [8, 12], priority: 3,
    description: '한쪽씩 밀어도 되고, 양쪽을 함께 밀어도 된다. 원판 무게 기준.',
  ),
  Exercise(
    id: 'assisted_dip', name: '어시스트 딥스', group: MuscleGroup.chest,
    emphasis: ['아랫가슴', '삼두', '딥스 입문'], equipment: [EquipmentType.assistedPullUp],
    loadType: LoadType.machine, refLift: RefLift.bodyweight, ratio: 0.4,
    compound: true, repRange: [8, 12], priority: 2,
    description: '머신 무게 = 덜어주는 무게. 숫자가 작아질수록 강해진 것.',
  ),
  Exercise(
    id: 'trx_pushup', name: 'TRX 푸시업', group: MuscleGroup.chest,
    emphasis: ['가슴 중앙부', '코어 안정'], equipment: [EquipmentType.trx],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    compound: true, repRange: [10, 15], priority: 1,
  ),

  // ── 등 ──
  Exercise(
    id: 'trap_deadlift', name: '트랩바 데드리프트', group: MuscleGroup.back,
    emphasis: ['등 하부', '대퇴사두', '후면 사슬'], equipment: [EquipmentType.trapBar],
    loadType: LoadType.barbell, refLift: RefLift.deadlift, ratio: 1.05,
    compound: true, repRange: [5, 8], priority: 3,
    description: '허리가 더 세워져 컨벤셔널보다 안전. 데드리프트 입문에 최적.',
  ),
  Exercise(
    id: 'assisted_pullup', name: '어시스트 풀업', group: MuscleGroup.back,
    emphasis: ['광배(넓이)', '풀업 입문'], equipment: [EquipmentType.assistedPullUp],
    loadType: LoadType.machine, refLift: RefLift.bodyweight, ratio: 0.45,
    compound: true, repRange: [8, 12], priority: 3,
    description: '머신 무게 = 덜어주는 무게. 체중의 절반에서 시작해 점점 줄인다.',
  ),
  Exercise(
    id: 'cs_row_m', name: '체스트 서포티드 로우 머신', group: MuscleGroup.back,
    emphasis: ['등 두께(능형근)', '허리 부담 0'], equipment: [EquipmentType.chestSupportedRow],
    loadType: LoadType.machine, refLift: RefLift.row, ratio: 0.9,
    compound: true, repRange: [8, 12], priority: 3,
  ),
  Exercise(
    id: 'high_row', name: '하이 로우(플레이트 로디드)', group: MuscleGroup.back,
    emphasis: ['광배(넓이)', '대원근', '좌우 독립'], equipment: [EquipmentType.highRow],
    loadType: LoadType.machine, refLift: RefLift.row, ratio: 0.8,
    compound: true, repRange: [8, 12], priority: 3,
  ),
  Exercise(
    id: 'low_row', name: '로우 로우(플레이트 로디드)', group: MuscleGroup.back,
    emphasis: ['광배 하부', '등 하부', '좌우 독립'], equipment: [EquipmentType.lowRow],
    loadType: LoadType.machine, refLift: RefLift.row, ratio: 0.85,
    compound: true, repRange: [8, 12], priority: 3,
  ),
  Exercise(
    id: 'tbar_row_m', name: '티바 로우 머신', group: MuscleGroup.back,
    emphasis: ['등 상부(두께)', '승모 중부'], equipment: [EquipmentType.tBarRow],
    loadType: LoadType.machine, refLift: RefLift.row, ratio: 0.9,
    compound: true, repRange: [8, 12], priority: 2,
  ),
  Exercise(
    id: 'pullover_m', name: '풀오버 머신', group: MuscleGroup.back,
    emphasis: ['광배 고립', '가슴 확장'], equipment: [EquipmentType.pulloverMachine], altGroups: [MuscleGroup.chest],
    loadType: LoadType.machine, refLift: RefLift.row, ratio: 0.6,
    repRange: [10, 15], priority: 2,
  ),
  Exercise(
    id: 'db_pullover', name: '덤벨 풀오버', group: MuscleGroup.back,
    emphasis: ['광배 고립', '가슴 확장'], equipment: [EquipmentType.dumbbell],
    loadType: LoadType.dumbbell, refLift: RefLift.row, ratio: 0.35,
    repRange: [10, 15], priority: 1, altGroups: [MuscleGroup.chest],
    description: '벤치에 누워 덤벨을 머리 뒤로 내렸다 올린다. 팔꿈치를 굽히고 가슴을 늘리면 가슴, 팔을 펴고 광배로 당기면 등 운동이 된다.',
  ),
  Exercise(
    id: 'shrug', name: '슈러그', group: MuscleGroup.back,
    emphasis: ['승모 상부'], equipment: [EquipmentType.shrugMachine, EquipmentType.dumbbell, EquipmentType.barbell, EquipmentType.trapBar, EquipmentType.smithMachine, EquipmentType.kettlebell],
    loadType: LoadType.machine, refLift: RefLift.deadlift, ratio: 0.7,
    repRange: [10, 15], priority: 1,
  ),
  Exercise(
    id: 'back_ext_m', name: '백 익스텐션 머신', group: MuscleGroup.back,
    emphasis: ['등 하부(척추기립근)'], equipment: [EquipmentType.backExtensionMachine],
    loadType: LoadType.machine, refLift: RefLift.deadlift, ratio: 0.4,
    repRange: [12, 15], priority: 1,
  ),
  Exercise(
    id: 'reverse_hyper', name: '리버스 하이퍼', group: MuscleGroup.back,
    emphasis: ['둔근', '등 하부 회복'], equipment: [EquipmentType.reverseHyper],
    loadType: LoadType.machine, refLift: RefLift.deadlift, ratio: 0.3,
    repRange: [12, 20], priority: 1,
  ),
  Exercise(
    id: 'landmine_row', name: '랜드마인 로우', group: MuscleGroup.back,
    emphasis: ['등 상부(두께)', '광배 하부'], equipment: [EquipmentType.landmine],
    loadType: LoadType.barbell, refLift: RefLift.row, ratio: 0.8,
    compound: true, repRange: [8, 12], priority: 2,
  ),
  Exercise(
    id: 'trx_row', name: 'TRX 로우', group: MuscleGroup.back,
    emphasis: ['등 상부(두께)', '맨몸'], equipment: [EquipmentType.trx],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    compound: true, repRange: [10, 15], priority: 2,
    description: '몸을 눕힐수록 어렵다.',
  ),
  Exercise(
    id: 'band_pull_apart', name: '밴드 풀어파트', group: MuscleGroup.back,
    emphasis: ['후면 어깨', '회전근개', '자세 교정'], equipment: [EquipmentType.resistanceBand],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [15, 25], priority: 1,
  ),

  // ── 하체 ──
  Exercise(
    id: 'ssb_squat', name: '세이프티바 스쿼트', group: MuscleGroup.legs,
    emphasis: ['대퇴사두', '상부 등', '상체 직립'], equipment: [EquipmentType.safetySquatBar],
    loadType: LoadType.barbell, refLift: RefLift.squat, ratio: 0.9,
    compound: true, repRange: [5, 8], priority: 2,
  ),
  Exercise(
    id: 'h_leg_press', name: '수평 레그 프레스', group: MuscleGroup.legs,
    emphasis: ['대퇴사두', '입문·재활'], equipment: [EquipmentType.horizontalLegPress],
    loadType: LoadType.machine, refLift: RefLift.squat, ratio: 1.3,
    compound: true, repRange: [10, 15], priority: 2,
  ),
  Exercise(
    id: 'pendulum_squat', name: '펜듈럼 스쿼트', group: MuscleGroup.legs,
    emphasis: ['대퇴사두 극대화', '깊은 가동범위'], equipment: [EquipmentType.pendulumSquat],
    loadType: LoadType.machine, refLift: RefLift.squat, ratio: 0.9,
    compound: true, repRange: [8, 12], priority: 3,
  ),
  Exercise(
    id: 'v_squat', name: 'V 스쿼트', group: MuscleGroup.legs,
    emphasis: ['대퇴사두', '둔근'], equipment: [EquipmentType.vSquat],
    loadType: LoadType.machine, refLift: RefLift.squat, ratio: 1.0,
    compound: true, repRange: [8, 12], priority: 2,
  ),
  Exercise(
    id: 'belt_squat', name: '벨트 스쿼트', group: MuscleGroup.legs,
    emphasis: ['대퇴사두', '둔근', '허리 부담 0'], equipment: [EquipmentType.beltSquat],
    loadType: LoadType.machine, refLift: RefLift.squat, ratio: 0.9,
    compound: true, repRange: [10, 15], priority: 2,
  ),
  Exercise(
    id: 'lying_leg_curl', name: '라잉 레그 컬', group: MuscleGroup.legs,
    emphasis: ['햄스트링 피크 수축'], equipment: [EquipmentType.lyingLegCurl],
    loadType: LoadType.machine, refLift: RefLift.squat, ratio: 0.4,
    repRange: [10, 15], priority: 2,
  ),
  Exercise(
    id: 'hip_abduction', name: '힙 어브덕션', group: MuscleGroup.legs,
    emphasis: ['중둔근(힙 라인)'], equipment: [EquipmentType.hipAbductor, EquipmentType.multiHip],
    loadType: LoadType.machine, refLift: RefLift.squat, ratio: 0.5,
    repRange: [15, 20], priority: 1,
  ),
  Exercise(
    id: 'hip_adduction', name: '힙 어덕션', group: MuscleGroup.legs,
    emphasis: ['내전근'], equipment: [EquipmentType.hipAdductor, EquipmentType.multiHip],
    loadType: LoadType.machine, refLift: RefLift.squat, ratio: 0.5,
    repRange: [15, 20], priority: 1,
  ),
  Exercise(
    id: 'glute_kickback_m', name: '글루트 킥백 머신', group: MuscleGroup.legs,
    emphasis: ['대둔근 고립', '좌우 균형'], equipment: [EquipmentType.gluteKickback, EquipmentType.multiHip],
    loadType: LoadType.machine, refLift: RefLift.squat, ratio: 0.35,
    unilateral: true, repRange: [12, 15], priority: 1,
  ),
  Exercise(
    id: 'seated_calf', name: '시티드 카프 레이즈', group: MuscleGroup.legs,
    emphasis: ['가자미근', '종아리 두께'], equipment: [EquipmentType.seatedCalfRaise],
    loadType: LoadType.machine, refLift: RefLift.squat, ratio: 0.5,
    repRange: [12, 20], priority: 1,
  ),
  Exercise(
    id: 'sissy_squat', name: '시시 스쿼트', group: MuscleGroup.legs,
    emphasis: ['대퇴직근(사두 중앙)'], equipment: [EquipmentType.sissySquat],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [10, 15], priority: 1,
  ),
  Exercise(
    id: 'nordic_curl', name: '노르딕 컬', group: MuscleGroup.legs,
    emphasis: ['햄스트링 신장성', '부상 예방'], equipment: [EquipmentType.nordicBench, EquipmentType.ghd],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [5, 8], priority: 1,
    description: '천천히 내려가는 데 집중. 올라올 땐 손으로 밀어도 된다.',
  ),
  Exercise(
    id: 'ghr', name: '글루트 햄 레이즈(GHD)', group: MuscleGroup.legs,
    emphasis: ['햄스트링', '둔근', '등 하부'], equipment: [EquipmentType.ghd],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    compound: true, repRange: [8, 12], priority: 2,
  ),
  Exercise(
    id: 'step_up', name: '박스 스텝업', group: MuscleGroup.legs,
    emphasis: ['둔근', '대퇴사두', '좌우 균형'], equipment: [EquipmentType.plyoBox, EquipmentType.flatBench, EquipmentType.dumbbell],
    loadType: LoadType.dumbbell, refLift: RefLift.squat, ratio: 0.15,
    compound: true, unilateral: true, repRange: [10, 12], priority: 1,
  ),
  Exercise(
    id: 'sled_push', name: '슬레드 푸시', group: MuscleGroup.legs,
    emphasis: ['하체 컨디셔닝', '근육통 없는 고강도'], equipment: [EquipmentType.sled],
    loadType: LoadType.machine, refLift: RefLift.squat, ratio: 0.8,
    compound: true, repRange: [20, 30], priority: 1,
    description: '횟수 = 미터(m). 20~30m 왕복.',
  ),

  // ── 어깨 ──
  Exercise(
    id: 'shoulder_press_pl', name: '플레이트 로디드 숄더프레스', group: MuscleGroup.shoulder,
    emphasis: ['전면 어깨', '측면 어깨', '좌우 독립'], equipment: [EquipmentType.shoulderPressPlateLoaded],
    loadType: LoadType.machine, refLift: RefLift.ohp, ratio: 0.8,
    compound: true, repRange: [8, 12], priority: 3,
  ),
  Exercise(
    id: 'lateral_raise_m', name: '레터럴 레이즈 머신', group: MuscleGroup.shoulder,
    emphasis: ['측면 어깨 고립', '반동 차단'], equipment: [EquipmentType.lateralRaiseMachine],
    loadType: LoadType.machine, refLift: RefLift.ohp, ratio: 0.5,
    repRange: [12, 20], priority: 3,
  ),
  Exercise(
    id: 'reverse_pec_deck', name: '리버스 펙덱 플라이', group: MuscleGroup.shoulder,
    emphasis: ['후면 어깨', '중부 승모·능형근'], equipment: [EquipmentType.pecDeck, EquipmentType.rearDeltMachine],
    loadType: LoadType.machine, refLift: RefLift.ohp, ratio: 0.45,
    repRange: [12, 20], priority: 2,
    description: '펙덱에 거꾸로(가슴을 패드에 대고) 앉아 팔을 뒤로 벌린다.',
  ),
  Exercise(
    id: 'rear_delt_m', name: '리어 델트 머신', group: MuscleGroup.shoulder,
    emphasis: ['후면 어깨'], equipment: [EquipmentType.rearDeltMachine],
    loadType: LoadType.machine, refLift: RefLift.ohp, ratio: 0.45,
    repRange: [12, 20], priority: 2,
  ),
  Exercise(
    id: 'landmine_press', name: '랜드마인 프레스', group: MuscleGroup.shoulder,
    emphasis: ['전면 어깨', '윗가슴', '어깨 안전'], equipment: [EquipmentType.landmine],
    loadType: LoadType.barbell, refLift: RefLift.ohp, ratio: 0.6,
    compound: true, unilateral: true, repRange: [8, 12], priority: 2,
    description: '어깨가 불편한 사람의 오버헤드 대체. 바 무게 포함.',
  ),
  Exercise(
    id: 'fixed_bb_press', name: '고정바벨 숄더프레스', group: MuscleGroup.shoulder,
    emphasis: ['전면 어깨', '빠른 무게 교체'], equipment: [EquipmentType.fixedBarbell],
    loadType: LoadType.barbell, refLift: RefLift.ohp, ratio: 0.85,
    compound: true, repRange: [8, 12], priority: 1,
  ),

  // ── 팔 ──
  Exercise(
    id: 'ez_curl', name: 'EZ바 컬', group: MuscleGroup.arms,
    emphasis: ['이두 전체', '손목 편함'], equipment: [EquipmentType.ezBar, EquipmentType.fixedBarbell],
    loadType: LoadType.barbell, refLift: RefLift.row, ratio: 0.38,
    repRange: [8, 12], priority: 3,
  ),
  Exercise(
    id: 'ez_skull', name: 'EZ바 스컬 크러셔', group: MuscleGroup.arms,
    emphasis: ['삼두 장두'], equipment: [EquipmentType.ezBar],
    loadType: LoadType.barbell, refLift: RefLift.bench, ratio: 0.33,
    repRange: [8, 12], priority: 2,
  ),
  Exercise(
    id: 'bicep_curl_m', name: '바이셉 컬 머신', group: MuscleGroup.arms,
    emphasis: ['이두 고립', '피크 수축'], equipment: [EquipmentType.bicepCurlMachine],
    loadType: LoadType.machine, refLift: RefLift.row, ratio: 0.4,
    repRange: [10, 15], priority: 2,
  ),
  Exercise(
    id: 'preacher_curl_m', name: '프리처 컬 머신', group: MuscleGroup.arms,
    emphasis: ['이두 단두(안쪽)', '반동 차단'], equipment: [EquipmentType.preacherCurlMachine],
    loadType: LoadType.machine, refLift: RefLift.row, ratio: 0.38,
    repRange: [10, 12], priority: 2,
  ),
  Exercise(
    id: 'tri_ext_m', name: '트라이셉 익스텐션 머신', group: MuscleGroup.arms,
    emphasis: ['삼두 고립'], equipment: [EquipmentType.tricepExtensionMachine],
    loadType: LoadType.machine, refLift: RefLift.bench, ratio: 0.4,
    repRange: [10, 15], priority: 2,
  ),
  Exercise(
    id: 'dip_m', name: '시티드 딥 머신', group: MuscleGroup.arms,
    emphasis: ['삼두 고중량', '아랫가슴'], equipment: [EquipmentType.dipMachine],
    loadType: LoadType.machine, refLift: RefLift.bench, ratio: 0.9,
    compound: true, repRange: [8, 12], priority: 3,
  ),
  Exercise(
    id: 'band_curl', name: '밴드 컬', group: MuscleGroup.arms,
    emphasis: ['이두', '피크 수축'], equipment: [EquipmentType.resistanceBand],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [15, 20], priority: 1,
  ),

  // ── 복근 ──
  Exercise(
    id: 'torso_rotation', name: '토르소 로테이션', group: MuscleGroup.abs,
    emphasis: ['복사근'], equipment: [EquipmentType.torsoRotation],
    loadType: LoadType.machine, refLift: RefLift.row, ratio: 0.5,
    unilateral: true, repRange: [12, 15], priority: 2,
  ),
  Exercise(
    id: 'captains_chair', name: '캡틴스 체어 레그레이즈', group: MuscleGroup.abs,
    emphasis: ['하복부'], equipment: [EquipmentType.captainsChair],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [10, 15], priority: 3,
  ),
  Exercise(
    id: 'decline_situp', name: '디클라인 싯업', group: MuscleGroup.abs,
    emphasis: ['상복부'], equipment: [EquipmentType.declineAbBench, EquipmentType.declineBench],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [12, 20], priority: 2,
  ),
  Exercise(
    id: 'ab_wheel', name: 'AB 휠 롤아웃', group: MuscleGroup.abs,
    emphasis: ['복직근·복횡근', '코어 안정'], equipment: [EquipmentType.abWheel],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [8, 12], priority: 3,
    description: '무릎 대고 시작. 허리가 꺾이지 않는 범위까지만.',
  ),
  Exercise(
    id: 'ghd_situp', name: 'GHD 싯업', group: MuscleGroup.abs,
    emphasis: ['복직근 전체', '고관절 굴곡근'], equipment: [EquipmentType.ghd],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [10, 15], priority: 2,
  ),
  Exercise(
    id: 'med_ball_slam', name: '메디신볼 슬램', group: MuscleGroup.abs,
    emphasis: ['코어 파워', '전신'], equipment: [EquipmentType.medicineBall],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [10, 15], priority: 1,
  ),
  Exercise(
    id: 'landmine_rotation', name: '랜드마인 로테이션', group: MuscleGroup.abs,
    emphasis: ['복사근', '회전 코어'], equipment: [EquipmentType.landmine],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [10, 12], priority: 1,
  ),
  Exercise(
    id: 'trx_pike', name: 'TRX 파이크/니턱', group: MuscleGroup.abs,
    emphasis: ['하복부', '코어 안정'], equipment: [EquipmentType.trx],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [10, 15], priority: 1,
  ),

  // ── 유산소 (분) ──
  Exercise(
    id: 'curved_sprint', name: '커브드 트레드밀 인터벌', group: MuscleGroup.cardio,
    emphasis: ['스프린트 인터벌', '칼로리 ↑'], equipment: [EquipmentType.curvedTreadmill],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [10, 15], priority: 2,
    description: '20초 전력 / 40초 걷기 반복.',
  ),
  Exercise(
    id: 'spin', name: '스핀 바이크', group: MuscleGroup.cardio,
    emphasis: ['고강도 인터벌', '하체 지구력'], equipment: [EquipmentType.spinBike],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [15, 25], priority: 2,
  ),
  Exercise(
    id: 'recumbent', name: '리컴번트 바이크', group: MuscleGroup.cardio,
    emphasis: ['저충격', '회복'], equipment: [EquipmentType.recumbentBike],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [20, 30], priority: 1,
  ),
  Exercise(
    id: 'assault', name: '에어 바이크 인터벌', group: MuscleGroup.cardio,
    emphasis: ['전신 HIIT', '최대 칼로리'], equipment: [EquipmentType.assaultBike],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [8, 15], priority: 2,
    description: '30초 전력 / 60초 천천히. 짧아도 충분하다.',
  ),
  Exercise(
    id: 'ski_erg', name: '스키 에르그', group: MuscleGroup.cardio,
    emphasis: ['상체 유산소', '하체 쉬는 날'], equipment: [EquipmentType.skiErg],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [10, 20], priority: 2,
  ),
  Exercise(
    id: 'jacobs', name: '제이콥스 래더', group: MuscleGroup.cardio,
    emphasis: ['전신', '관절 부담 ↓'], equipment: [EquipmentType.jacobsLadder],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [10, 20], priority: 1,
  ),
  Exercise(
    id: 'versa', name: '마운틴 클라이머 머신', group: MuscleGroup.cardio,
    emphasis: ['전신 고강도'], equipment: [EquipmentType.versaClimber],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [8, 15], priority: 1,
  ),
  Exercise(
    id: 'jump_rope', name: '줄넘기', group: MuscleGroup.cardio,
    emphasis: ['워밍업', '종아리·협응'], equipment: [EquipmentType.jumpRope],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [10, 15], priority: 1,
  ),
  Exercise(
    id: 'battle_rope', name: '배틀 로프', group: MuscleGroup.cardio,
    emphasis: ['상체 HIIT', '어깨·코어 지구력'], equipment: [EquipmentType.battleRope],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [8, 12], priority: 1,
    description: '30초 흔들기 / 30초 휴식.',
  ),
  Exercise(
    id: 'box_jump', name: '박스 점프', group: MuscleGroup.cardio,
    emphasis: ['폭발력', '하체'], equipment: [EquipmentType.plyoBox],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [8, 12], priority: 1,
    description: '숫자는 분. 5회씩 여러 세트로 나눠서.',
  ),
  // ── 야외 / 맨몸 유산소 (분) ──
  Exercise(
    id: 'outdoor_run', name: '야외 러닝', group: MuscleGroup.cardio,
    emphasis: ['심폐 지구력', '야외'], equipment: [EquipmentType.outdoor],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [20, 40], priority: 3,
    description: '대화 가능한 속도로. 숫자는 분.',
  ),
  Exercise(
    id: 'trail_run', name: '산 뛰기 (트레일 러닝)', group: MuscleGroup.cardio,
    emphasis: ['심폐 지구력', '둔근·종아리', '야외'], equipment: [EquipmentType.outdoor],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [20, 40], priority: 3,
    description: '오르막은 걷고 평지·내리막은 뛰기. 하체 날 다음엔 피하기.',
  ),
  Exercise(
    id: 'hiking', name: '등산', group: MuscleGroup.cardio,
    emphasis: ['둔근·대퇴사두', '장시간 유산소', '야외'], equipment: [EquipmentType.outdoor],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [40, 90], priority: 2,
  ),
  Exercise(
    id: 'outdoor_walk', name: '빠르게 걷기', group: MuscleGroup.cardio,
    emphasis: ['지방 연소', '회복', '야외'], equipment: [EquipmentType.outdoor],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [20, 40], priority: 1,
  ),
  Exercise(
    id: 'outdoor_bike', name: '야외 자전거', group: MuscleGroup.cardio,
    emphasis: ['하체 지구력', '무릎 부담 ↓', '야외'], equipment: [EquipmentType.outdoor],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [30, 60], priority: 2,
  ),
  Exercise(
    id: 'stair_run', name: '계단 오르기 (아파트·육교)', group: MuscleGroup.cardio,
    emphasis: ['둔근·대퇴사두', '고강도'], equipment: [EquipmentType.outdoor, EquipmentType.bodyweight],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [10, 20], priority: 2,
  ),
  Exercise(
    id: 'swim', name: '수영', group: MuscleGroup.cardio,
    emphasis: ['전신 저충격', '회복'], equipment: [EquipmentType.pool],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [20, 40], priority: 2, activity: true,
  ),
  // ── 기구 연결 보강 (2026-10) ──
  Exercise(
    id: 'incline_db_fly', name: '인클라인 덤벨 플라이', group: MuscleGroup.chest,
    emphasis: ['윗가슴', '가슴 스트레칭'], equipment: [EquipmentType.dumbbell],
    loadType: LoadType.dumbbell, refLift: RefLift.bench, ratio: 0.12,
    repRange: [10, 15], priority: 1,
    needs: {EquipmentType.dumbbell: [EquipmentType.inclineBench]},
  ),
  Exercise(
    id: 'decline_db', name: '디클라인 덤벨프레스', group: MuscleGroup.chest,
    emphasis: ['아랫가슴'], equipment: [EquipmentType.dumbbell],
    loadType: LoadType.dumbbell, refLift: RefLift.bench, ratio: 0.3,
    compound: true, repRange: [8, 12], priority: 1,
    needs: {EquipmentType.dumbbell: [EquipmentType.declineBench]},
  ),
  Exercise(
    id: 'low_cable_fly', name: '로우 투 하이 케이블 플라이', group: MuscleGroup.chest,
    emphasis: ['윗가슴', '가슴 안쪽'], equipment: [EquipmentType.cableMachine],
    loadType: LoadType.cable, refLift: RefLift.bench, ratio: 0.15,
    repRange: [12, 15], priority: 1,
  ),
  Exercise(
    id: 'decline_pushup', name: '디클라인 푸시업', group: MuscleGroup.chest,
    emphasis: ['윗가슴', '코어'], equipment: [EquipmentType.bodyweight, EquipmentType.flatBench],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    compound: true, repRange: [10, 20], priority: 1,
    description: '발을 벤치·의자에 올리고 하는 푸시업.',
  ),
  Exercise(
    id: 'close_grip_pulldown', name: '클로즈그립 랫풀다운', group: MuscleGroup.back,
    emphasis: ['광배 하부', '등 두께(능형근)'], equipment: [EquipmentType.latPulldown, EquipmentType.cableMachine, EquipmentType.latPulldownPlateLoaded],
    loadType: LoadType.machine, refLift: RefLift.row, ratio: 0.9,
    compound: true, repRange: [8, 12], priority: 2,
    description: 'V바(좁은 손잡이)로 당긴다.',
  ),
  Exercise(
    id: 'underhand_pulldown', name: '언더그립 랫풀다운', group: MuscleGroup.back,
    emphasis: ['광배 하부', '이두'], equipment: [EquipmentType.latPulldown, EquipmentType.cableMachine, EquipmentType.latPulldownPlateLoaded],
    loadType: LoadType.machine, refLift: RefLift.row, ratio: 0.85,
    compound: true, repRange: [8, 12], priority: 1,
  ),
  Exercise(
    id: 'single_arm_pulldown', name: '원암 랫풀다운', group: MuscleGroup.back,
    emphasis: ['광배(넓이)', '좌우 균형'], equipment: [EquipmentType.cableMachine, EquipmentType.latPulldown],
    loadType: LoadType.cable, refLift: RefLift.row, ratio: 0.4,
    unilateral: true, repRange: [10, 12], priority: 1,
  ),
  Exercise(
    id: 'chinup', name: '친업', group: MuscleGroup.back,
    emphasis: ['광배 하부', '이두'], equipment: [EquipmentType.pullUpBar, EquipmentType.assistedPullUp],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    compound: true, repRange: [5, 10], priority: 2,
    description: '손바닥이 나를 보게 잡는 턱걸이.',
  ),
  Exercise(
    id: 'wide_seated_row', name: '와이드그립 시티드 로우', group: MuscleGroup.back,
    emphasis: ['등 상부(두께)', '후면 어깨'], equipment: [EquipmentType.seatedRow, EquipmentType.cableMachine],
    loadType: LoadType.machine, refLift: RefLift.row, ratio: 0.8,
    compound: true, repRange: [10, 12], priority: 1,
  ),
  Exercise(
    id: 'single_arm_cable_row', name: '원암 케이블 로우', group: MuscleGroup.back,
    emphasis: ['광배 하부', '좌우 균형'], equipment: [EquipmentType.cableMachine, EquipmentType.seatedRow],
    loadType: LoadType.cable, refLift: RefLift.row, ratio: 0.45,
    compound: true, unilateral: true, repRange: [10, 12], priority: 1,
  ),
  Exercise(
    id: 'incline_db_row', name: '인클라인 벤치 덤벨 로우', group: MuscleGroup.back,
    emphasis: ['등 두께(능형근)', '허리 부담 0'], equipment: [EquipmentType.dumbbell],
    loadType: LoadType.dumbbell, refLift: RefLift.row, ratio: 0.35,
    compound: true, repRange: [10, 12], priority: 2,
    needs: {EquipmentType.dumbbell: [EquipmentType.inclineBench]},
    description: '벤치에 엎드려 하는 체스트 서포티드 로우.',
  ),
  Exercise(
    id: 'meadows_row', name: '메도우 로우', group: MuscleGroup.back,
    emphasis: ['광배 하부', '좌우 균형'], equipment: [EquipmentType.landmine],
    loadType: LoadType.barbell, refLift: RefLift.row, ratio: 0.4,
    compound: true, unilateral: true, repRange: [8, 12], priority: 1,
  ),
  Exercise(
    id: 'inverted_row', name: '인버티드 로우', group: MuscleGroup.back,
    emphasis: ['등 상부(두께)', '맨몸'], equipment: [EquipmentType.smithMachine, EquipmentType.squatRack, EquipmentType.trx],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    compound: true, repRange: [8, 15], priority: 1,
    description: '스미스·랙 바를 허리 높이에 걸고 매달려 당긴다.',
  ),
  Exercise(
    id: 'good_morning', name: '굿모닝', group: MuscleGroup.legs,
    emphasis: ['햄스트링', '등 하부'], equipment: [EquipmentType.barbell, EquipmentType.smithMachine, EquipmentType.squatRack],
    loadType: LoadType.barbell, refLift: RefLift.deadlift, ratio: 0.35,
    compound: true, repRange: [8, 12], priority: 1,
  ),
  Exercise(
    id: 'sumo_deadlift', name: '스모 데드리프트', group: MuscleGroup.legs,
    emphasis: ['둔근', '내전근', '햄스트링'], equipment: [EquipmentType.barbell],
    loadType: LoadType.barbell, refLift: RefLift.deadlift, ratio: 0.9,
    compound: true, repRange: [5, 8], priority: 2,
  ),
  Exercise(
    id: 'sumo_squat', name: '스모 스쿼트(덤벨·케틀벨)', group: MuscleGroup.legs,
    emphasis: ['내전근', '둔근'], equipment: [EquipmentType.dumbbell, EquipmentType.kettlebell],
    loadType: LoadType.dumbbell, refLift: RefLift.squat, ratio: 0.25,
    compound: true, repRange: [10, 15], priority: 1,
  ),
  Exercise(
    id: 'reverse_lunge', name: '리버스 런지', group: MuscleGroup.legs,
    emphasis: ['둔근', '대퇴사두', '무릎 부담 ↓'], equipment: [EquipmentType.dumbbell, EquipmentType.kettlebell, EquipmentType.smithMachine, EquipmentType.bodyweight],
    loadType: LoadType.dumbbell, refLift: RefLift.squat, ratio: 0.15,
    compound: true, unilateral: true, repRange: [8, 12], priority: 2,
  ),
  Exercise(
    id: 'split_squat', name: '스플릿 스쿼트', group: MuscleGroup.legs,
    emphasis: ['대퇴사두', '둔근'], equipment: [EquipmentType.dumbbell, EquipmentType.smithMachine, EquipmentType.bodyweight],
    loadType: LoadType.dumbbell, refLift: RefLift.squat, ratio: 0.15,
    compound: true, unilateral: true, repRange: [8, 12], priority: 1,
  ),
  Exercise(
    id: 'single_leg_press', name: '싱글 레그 프레스', group: MuscleGroup.legs,
    emphasis: ['대퇴사두', '좌우 균형'], equipment: [EquipmentType.legPress, EquipmentType.horizontalLegPress],
    loadType: LoadType.machine, refLift: RefLift.squat, ratio: 0.7,
    compound: true, unilateral: true, repRange: [10, 12], priority: 1,
  ),
  Exercise(
    id: 'reverse_hack', name: '리버스 핵 스쿼트', group: MuscleGroup.legs,
    emphasis: ['둔근', '햄스트링'], equipment: [EquipmentType.hackSquat],
    loadType: LoadType.machine, refLift: RefLift.squat, ratio: 0.8,
    compound: true, repRange: [10, 12], priority: 1,
    description: '핵 스쿼트에 거꾸로(가슴을 패드에) 서서 한다.',
  ),
  Exercise(
    id: 'cable_kickback', name: '케이블 글루트 킥백', group: MuscleGroup.legs,
    emphasis: ['대둔근 고립'], equipment: [EquipmentType.cableMachine],
    loadType: LoadType.cable, refLift: RefLift.squat, ratio: 0.12,
    unilateral: true, repRange: [12, 15], priority: 1,
    description: '발목 스트랩을 끼고 한다.',
  ),
  Exercise(
    id: 'cable_pull_through', name: '케이블 풀스루', group: MuscleGroup.legs,
    emphasis: ['둔근', '햄스트링', '허리 부담 ↓'], equipment: [EquipmentType.cableMachine],
    loadType: LoadType.cable, refLift: RefLift.deadlift, ratio: 0.25,
    compound: true, repRange: [12, 15], priority: 1,
  ),
  Exercise(
    id: 'cable_abduction', name: '케이블 힙 어브덕션', group: MuscleGroup.legs,
    emphasis: ['중둔근(힙 라인)'], equipment: [EquipmentType.cableMachine],
    loadType: LoadType.cable, refLift: RefLift.squat, ratio: 0.08,
    unilateral: true, repRange: [12, 20], priority: 1,
  ),
  Exercise(
    id: 'landmine_squat', name: '랜드마인 스쿼트', group: MuscleGroup.legs,
    emphasis: ['대퇴사두', '둔근'], equipment: [EquipmentType.landmine],
    loadType: LoadType.barbell, refLift: RefLift.squat, ratio: 0.45,
    compound: true, repRange: [8, 12], priority: 1,
  ),
  Exercise(
    id: 'hyper_glute', name: '45° 힙 익스텐션(둔근)', group: MuscleGroup.legs,
    emphasis: ['둔근', '햄스트링'], equipment: [EquipmentType.romanChair, EquipmentType.ghd],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [12, 20], priority: 1,
    description: '로만체어에서 등을 살짝 말고 둔근으로 올라온다.',
  ),
  Exercise(
    id: 'arnold_press', name: '아놀드 프레스', group: MuscleGroup.shoulder,
    emphasis: ['전면 어깨', '측면 어깨'], equipment: [EquipmentType.dumbbell],
    loadType: LoadType.dumbbell, refLift: RefLift.ohp, ratio: 0.33,
    compound: true, repRange: [8, 12], priority: 1,
  ),
  Exercise(
    id: 'y_raise', name: '인클라인 Y 레이즈', group: MuscleGroup.shoulder,
    emphasis: ['하부 승모', '후면 어깨'], equipment: [EquipmentType.dumbbell],
    loadType: LoadType.dumbbell, refLift: RefLift.ohp, ratio: 0.06,
    repRange: [12, 15], priority: 1,
    needs: {EquipmentType.dumbbell: [EquipmentType.inclineBench]},
  ),
  Exercise(
    id: 'kb_press', name: '케틀벨 프레스', group: MuscleGroup.shoulder,
    emphasis: ['전면 어깨', '코어 안정'], equipment: [EquipmentType.kettlebell],
    loadType: LoadType.dumbbell, refLift: RefLift.ohp, ratio: 0.3,
    compound: true, unilateral: true, repRange: [8, 12], priority: 1,
  ),
  Exercise(
    id: 'concentration_curl', name: '컨센트레이션 컬', group: MuscleGroup.arms,
    emphasis: ['이두 단두', '피크 수축'], equipment: [EquipmentType.dumbbell],
    loadType: LoadType.dumbbell, refLift: RefLift.row, ratio: 0.15,
    unilateral: true, repRange: [10, 12], priority: 1,
  ),
  Exercise(
    id: 'reverse_curl', name: '리버스 컬', group: MuscleGroup.arms,
    emphasis: ['상완요골근', '전완'], equipment: [EquipmentType.ezBar, EquipmentType.barbell, EquipmentType.fixedBarbell],
    loadType: LoadType.barbell, refLift: RefLift.row, ratio: 0.2,
    repRange: [10, 15], priority: 1,
  ),
  Exercise(
    id: 'rope_hammer_curl', name: '로프 해머 컬', group: MuscleGroup.arms,
    emphasis: ['상완근', '전완'], equipment: [EquipmentType.cableMachine],
    loadType: LoadType.cable, refLift: RefLift.row, ratio: 0.3,
    repRange: [10, 15], priority: 1,
  ),
  Exercise(
    id: 'bayesian_curl', name: '베이지안 케이블 컬', group: MuscleGroup.arms,
    emphasis: ['이두 장두', '스트레칭'], equipment: [EquipmentType.cableMachine],
    loadType: LoadType.cable, refLift: RefLift.row, ratio: 0.15,
    unilateral: true, repRange: [10, 15], priority: 1,
  ),
  Exercise(
    id: 'wrist_curl', name: '리스트 컬', group: MuscleGroup.arms,
    emphasis: ['전완'], equipment: [EquipmentType.dumbbell, EquipmentType.barbell],
    loadType: LoadType.dumbbell, refLift: RefLift.row, ratio: 0.1,
    repRange: [15, 20], priority: 1,
  ),
  Exercise(
    id: 'farmers_walk', name: '파머스 워크', group: MuscleGroup.arms,
    emphasis: ['악력', '전완', '승모'], equipment: [EquipmentType.dumbbell, EquipmentType.kettlebell, EquipmentType.trapBar],
    loadType: LoadType.dumbbell, refLift: RefLift.deadlift, ratio: 0.3,
    compound: true, repRange: [20, 40], priority: 1,
    description: '숫자는 걸음 수(20m ≈ 30걸음).',
  ),
  Exercise(
    id: 'hanging_knee_raise', name: '행잉 니 레이즈', group: MuscleGroup.abs,
    emphasis: ['하복부', '입문'], equipment: [EquipmentType.pullUpBar, EquipmentType.captainsChair, EquipmentType.dipStation],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [10, 15], priority: 1,
  ),
  Exercise(
    id: 'pallof_press', name: '팔로프 프레스', group: MuscleGroup.abs,
    emphasis: ['코어 안정', '복사근(회전 저항)'], equipment: [EquipmentType.cableMachine, EquipmentType.resistanceBand],
    loadType: LoadType.cable, refLift: RefLift.bodyweight, ratio: 0,
    unilateral: true, repRange: [10, 12], priority: 1,
  ),
  Exercise(
    id: 'woodchop', name: '케이블 우드찹', group: MuscleGroup.abs,
    emphasis: ['복사근', '회전 코어'], equipment: [EquipmentType.cableMachine],
    loadType: LoadType.cable, refLift: RefLift.bodyweight, ratio: 0,
    unilateral: true, repRange: [10, 12], priority: 1,
  ),
  Exercise(
    id: 'dead_bug', name: '데드버그', group: MuscleGroup.abs,
    emphasis: ['복횡근', '허리 안정'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [10, 16], priority: 1,
  ),
  Exercise(
    id: 'side_plank', name: '사이드 플랭크', group: MuscleGroup.abs,
    emphasis: ['복사근', '코어 안정'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    unilateral: true, repRange: [30, 60], priority: 1,
    description: '숫자는 초.',
  ),
  Exercise(
    id: 'bicycle_crunch', name: '바이시클 크런치', group: MuscleGroup.abs,
    emphasis: ['복사근', '상복부'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.bodyweight, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [16, 30], priority: 1,
  ),
  Exercise(
    id: 'wall_ball', name: '월볼', group: MuscleGroup.cardio,
    emphasis: ['전신', '하체 파워'], equipment: [EquipmentType.medicineBall],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [5, 10], priority: 1,
    description: '숫자는 분.',
  ),
  // ── 스포츠·활동 (직접 추가용, 숫자는 분) ──
  Exercise(
    id: 'soccer', name: '축구', group: MuscleGroup.cardio,
    emphasis: ['스포츠', '인터벌 달리기', '하체'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [60, 120], priority: 1, activity: true,
  ),
  Exercise(
    id: 'futsal', name: '풋살', group: MuscleGroup.cardio,
    emphasis: ['스포츠', '인터벌 달리기', '하체'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [60, 120], priority: 1, activity: true,
  ),
  Exercise(
    id: 'basketball', name: '농구', group: MuscleGroup.cardio,
    emphasis: ['스포츠', '점프·방향 전환', '하체'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [60, 120], priority: 1, activity: true,
  ),
  Exercise(
    id: 'badminton', name: '배드민턴', group: MuscleGroup.cardio,
    emphasis: ['스포츠', '순발력', '어깨'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [60, 120], priority: 1, activity: true,
  ),
  Exercise(
    id: 'tennis', name: '테니스', group: MuscleGroup.cardio,
    emphasis: ['스포츠', '순발력', '어깨·코어 회전'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [60, 120], priority: 1, activity: true,
  ),
  Exercise(
    id: 'table_tennis', name: '탁구', group: MuscleGroup.cardio,
    emphasis: ['스포츠', '순발력'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [60, 120], priority: 1, activity: true,
  ),
  Exercise(
    id: 'volleyball', name: '배구', group: MuscleGroup.cardio,
    emphasis: ['스포츠', '점프', '어깨'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [60, 120], priority: 1, activity: true,
  ),
  Exercise(
    id: 'baseball', name: '야구', group: MuscleGroup.cardio,
    emphasis: ['스포츠', '순발력', '코어 회전'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [60, 180], priority: 1, activity: true,
  ),
  Exercise(
    id: 'squash', name: '스쿼시', group: MuscleGroup.cardio,
    emphasis: ['스포츠', '고강도 인터벌'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [30, 60], priority: 1, activity: true,
  ),
  Exercise(
    id: 'climbing', name: '클라이밍 (실내 암벽)', group: MuscleGroup.cardio,
    emphasis: ['스포츠', '등·전완 지구력', '악력'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [60, 120], priority: 1, activity: true,
  ),
  Exercise(
    id: 'boxing', name: '복싱', group: MuscleGroup.cardio,
    emphasis: ['스포츠', '고강도 인터벌', '어깨·코어'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [45, 90], priority: 1, activity: true,
  ),
  Exercise(
    id: 'jiujitsu', name: '주짓수·레슬링', group: MuscleGroup.cardio,
    emphasis: ['스포츠', '전신 근지구력'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [60, 120], priority: 1, activity: true,
  ),
  Exercise(
    id: 'golf', name: '골프 (라운딩)', group: MuscleGroup.cardio,
    emphasis: ['스포츠', '걷기', '코어 회전'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [120, 300], priority: 1, activity: true,
  ),
  Exercise(
    id: 'ski', name: '스키·스노보드', group: MuscleGroup.cardio,
    emphasis: ['스포츠', '하체 지구력'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [120, 300], priority: 1, activity: true,
  ),
  Exercise(
    id: 'dance', name: '댄스', group: MuscleGroup.cardio,
    emphasis: ['스포츠', '심폐 지구력'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [45, 90], priority: 1, activity: true,
  ),

  Exercise(
    id: 'mountain_climber', name: '마운틴 클라이머', group: MuscleGroup.cardio,
    emphasis: ['고강도 인터벌', '코어', '어디서나'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [6, 12], priority: 1,
    description: '30초 전력 / 30초 휴식 반복. 숫자는 분.',
  ),
  Exercise(
    id: 'jumping_jack', name: '점핑잭·하이니 인터벌', group: MuscleGroup.cardio,
    emphasis: ['워밍업', '고강도 인터벌', '어디서나'], equipment: [EquipmentType.bodyweight],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [6, 12], priority: 1,
  ),
  Exercise(
    id: 'sled_drag', name: '슬레드 드래그(끌기)', group: MuscleGroup.cardio,
    emphasis: ['하체 컨디셔닝', '햄스트링·둔근'], equipment: [EquipmentType.sled],
    loadType: LoadType.cardio, refLift: RefLift.bodyweight, ratio: 0,
    repRange: [8, 12], priority: 1,
  ),
];

/// 유산소 기구의 강도 단계 정의: 라벨, 범위, 숙련도별 시작 레벨.
class CardioLevelSpec {
  const CardioLevelSpec({required this.label, required this.unit, required this.min, required this.max, required this.start});
  final String label; // 예: '레벨', '경사'
  final String unit; // 예: '', '%'
  final int min;
  final int max;

  /// [초급, 중급, 고급] 시작값.
  final List<int> start;

  int startFor(TrainingLevel l, TrainingGoal g) {
    var v = start[l.index];
    if (g == TrainingGoal.fatLoss) v += 1;
    return v.clamp(min, max);
  }

  String format(int v) => '$label $v$unit';
}

/// exerciseId → 강도 단계 정의. 없는 유산소는 "편한 속도"로만 처방한다.
const Map<String, CardioLevelSpec> cardioLevels = {
  'stairs': CardioLevelSpec(label: '레벨', unit: '', min: 3, max: 20, start: [5, 8, 11]),
  'treadmill_walk': CardioLevelSpec(label: '경사', unit: '%', min: 2, max: 15, start: [6, 9, 12]),
  'treadmill_run': CardioLevelSpec(label: '속도', unit: 'km/h', min: 6, max: 16, start: [8, 10, 12]),
  'curved_sprint': CardioLevelSpec(label: '인터벌', unit: '회', min: 4, max: 12, start: [5, 7, 9]),
  'bike': CardioLevelSpec(label: '저항', unit: '', min: 1, max: 20, start: [5, 8, 11]),
  'spin': CardioLevelSpec(label: '저항', unit: '', min: 1, max: 20, start: [6, 9, 12]),
  'recumbent': CardioLevelSpec(label: '저항', unit: '', min: 1, max: 20, start: [4, 7, 10]),
  'assault': CardioLevelSpec(label: '인터벌', unit: '회', min: 4, max: 12, start: [5, 7, 9]),
  'rowing': CardioLevelSpec(label: '댐퍼', unit: '', min: 1, max: 10, start: [4, 5, 6]),
  'ski_erg': CardioLevelSpec(label: '댐퍼', unit: '', min: 1, max: 10, start: [4, 5, 6]),
  'elliptical': CardioLevelSpec(label: '저항', unit: '', min: 1, max: 20, start: [5, 8, 11]),
  'jacobs': CardioLevelSpec(label: '속도', unit: '', min: 1, max: 10, start: [3, 5, 7]),
  'versa': CardioLevelSpec(label: '인클라인', unit: '%', min: 0, max: 50, start: [10, 20, 30]),
  'stair_run': CardioLevelSpec(label: '층', unit: '층', min: 5, max: 40, start: [8, 14, 20]),
};

/// 부상 부위별로 루틴에서 제외할 운동. 해당 부위에 큰 부하가 걸리는 것들.
const Map<InjuryArea, Set<String>> injuryExclusions = {
  InjuryArea.lowerBack: {
    'deadlift', 'trap_deadlift', 'rack_pull', 'bb_row', 'tbar_row', 'landmine_row', 'rdl',
    'bb_stiff_deadlift', 'db_stiff_deadlift',
    'bb_squat', 'front_squat', 'ssb_squat', 'back_ext', 'back_ext_m', 'ghr', 'reverse_hyper',
    'kb_swing', 'sled_drag', 'decline_situp', 'ghd_situp', 'russian_twist',
  },
  InjuryArea.knee: {
    'bb_squat', 'front_squat', 'ssb_squat', 'hack_squat', 'pendulum_squat', 'v_squat', 'belt_squat',
    'lunge', 'bulgarian', 'step_up', 'sissy_squat', 'leg_ext', 'box_jump', 'burpee', 'jump_rope',
    'stairs', 'curved_sprint', 'treadmill_run', 'sled_push',
  },
  InjuryArea.shoulder: {
    'ohp', 'db_shoulder_press', 'shoulder_press_m', 'shoulder_press_pl', 'fixed_bb_press',
    'upright_row', 'dips', 'tri_dips', 'assisted_dip', 'dip_m', 'bb_bench', 'decline_bb',
    'behind_neck', 'pullup', 'lat_pulldown', 'overhead_tri', 'ski_erg', 'battle_rope', 'versa',
  },
  InjuryArea.wrist: {
    'pushup', 'trx_pushup', 'front_squat', 'bb_curl', 'skull_crusher', 'ab_wheel', 'burpee',
    'kickback', 'upright_row', 'cgbp',
  },
  InjuryArea.elbow: {
    'skull_crusher', 'ez_skull', 'overhead_tri', 'tri_pushdown', 'tri_ext_m', 'kickback',
    'dips', 'tri_dips', 'dip_m', 'cgbp', 'preacher_curl', 'preacher_curl_m', 'pullup',
  },
};

/// 프로필의 부상 체크에 걸리는 운동인지.
bool excludedByInjury(Exercise ex, Set<InjuryArea> injuries) =>
    injuries.any((i) => injuryExclusions[i]?.contains(ex.id) ?? false);

/// 이 운동이 부담을 주는 주의 부위들.
Set<InjuryArea> cautionHits(Exercise ex, Set<InjuryArea> cautions) =>
    {for (final i in cautions) if (injuryExclusions[i]?.contains(ex.id) ?? false) i};

final Map<String, Exercise> _byId = {
  for (final e in exerciseCatalog) e.id: e,
};

Exercise? exerciseById(String id) => _byId[id];

List<Exercise> exercisesOf(MuscleGroup g) =>
    exerciseCatalog.where((e) => e.group == g).toList();

/// 기록·구역·밸런스 계산에 쓰는 실제 타깃 부위(사용자가 바꿨으면 그것).
extension PlannedExerciseTarget on PlannedExercise {
  MuscleGroup get effectiveGroup => groupOverride ?? exerciseById(exerciseId)?.group ?? MuscleGroup.chest;
}


/// 부위별 워밍업 후보(앞에 있는 것부터). 본 운동 기구를 미리 가볍게 쓰는 활성화 운동 포함.
const warmupByGroup = <MuscleGroup, List<String>>{
  MuscleGroup.chest: ['scap_pushup', 'band_pull_apart', 'pushup', 'arm_circles'],
  MuscleGroup.back: ['straight_arm_pd', 'db_pullover', 'assisted_pullup', 'pullup', 'cat_cow'],
  MuscleGroup.shoulder: ['band_dislocate', 'face_pull', 'arm_circles', 'band_pull_apart'],
  MuscleGroup.legs: ['worlds_greatest', 'glute_bridge', 'hip_9090', 'bw_squat'],
  MuscleGroup.arms: ['arm_circles', 'band_pull_apart'],
  MuscleGroup.abs: ['cat_cow'],
};

/// 직접 고를 수 있는 워밍업 운동 목록.
List<Exercise> get warmupChoices {
  final ids = <String>{'dyn_stretch', for (final l in warmupByGroup.values) ...l};
  return [for (final id in ids) if (exerciseById(id) != null) exerciseById(id)!];
}


/// 운동 검색에서 자주 쓰는 다른 이름(줄임말·영어).
const Map<String, List<String>> exerciseAliases = {
  'bulgarian': ['불가리안 스쿼트', '스플릿 스쿼트', 'BSS', 'bulgarian'],
  'lunge': ['런지', 'lunge'],
  'rdl': ['RDL', '루마니안', 'romanian'],
  'bb_stiff_deadlift': ['스티프', '스티프 데드', 'SLDL', 'stiff'],
  'db_stiff_deadlift': ['스티프', '스티프 데드', 'SLDL', 'stiff'],
  'deadlift': ['데드', '컨벤', 'deadlift'],
  'reverse_pec_deck': ['리버스 플라이', '리어 델트', '후면 어깨'],
  'rear_delt_fly': ['리버스 플라이', '후면 어깨'],
};

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), '');

/// 검색어가 운동에 맞는지: 띄어쓰기 무시, 여러 단어면 단어마다 이름·다른 이름·타깃·부위 중 하나에 있으면 된다.
/// 예) '불가리안 스쿼트' → 불가리안 스플릿 스쿼트, '덤벨 스티프' → 덤벨 스티프 레그 데드리프트.
bool exerciseMatches(Exercise e, String query) {
  final q = query.trim();
  if (q.isEmpty) return true;
  final hay = [e.name, ...?exerciseAliases[e.id], ...e.emphasis, e.group.label].map(_norm).toList();
  final whole = _norm(q);
  if (hay.any((h) => h.contains(whole))) return true;
  final tokens = q.split(RegExp(r'\s+')).map(_norm).where((t) => t.isNotEmpty);
  return tokens.every((t) => hay.any((h) => h.contains(t)));
}


/// 이 기구(와 같이 있다고 보는 기구)로 할 수 있는 운동. 기구 상세·검색에 쓴다.
/// 맨몸 운동은 맨몸 기구일 때만 보여 준다.
List<Exercise> exercisesForTypes(Set<EquipmentType> types) {
  final t = {...types}..remove(EquipmentType.bodyweight);
  final onlyBody = types.contains(EquipmentType.bodyweight) && t.isEmpty;
  return [
    for (final e in exerciseCatalog)
      if (!e.warmupOnly &&
          (onlyBody
              ? !e.activity && e.equipment.contains(EquipmentType.bodyweight)
              : e.allEquipment.any(t.contains)))
        e,
  ];
}
