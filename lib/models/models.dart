/// 앱 전역 도메인 모델.
///
/// 모든 모델은 JSON(Map) 직렬화를 지원해 [LocalStore]에 그대로 저장된다.
library;

/// 운동 부위. 요구사항 6번의 7개 부위를 그대로 사용한다.
enum MuscleGroup {
  shoulder('어깨'),
  chest('가슴'),
  arms('팔'),
  abs('복근'),
  legs('하체'),
  back('등'),
  cardio('유산소');

  const MuscleGroup(this.label);
  final String label;

  static MuscleGroup parse(String v) =>
      MuscleGroup.values.firstWhere((e) => e.name == v);
}

/// 기구 분류. 기구 선택 화면의 탭/필터로 쓴다.
enum EquipmentCategory {
  freeWeight('프리웨이트'),
  bench('벤치·랙'),
  chest('가슴'),
  back('등'),
  shoulder('어깨'),
  arms('팔'),
  legs('하체'),
  core('복근·코어'),
  cardio('유산소'),
  functional('기능성·기타');

  const EquipmentCategory(this.label);
  final String label;
}

/// 운동기구 종류(카탈로그 수준). 헬스장은 이 종류들 중 보유한 것을 체크한다.
///
/// 기존 항목의 name은 저장 데이터 호환을 위해 바꾸지 않는다. 새 기구는 뒤에 추가.
/// [aliases]는 검색용 영문/별칭.
enum EquipmentType {
  // ── 프리웨이트 ──
  barbell('바벨/플레이트', EquipmentCategory.freeWeight, ['barbell', 'olympic bar', '올림픽 바', '원판']),
  dumbbell('덤벨', EquipmentCategory.freeWeight, ['dumbbell', 'db']),
  kettlebell('케틀벨', EquipmentCategory.freeWeight, ['kettlebell', 'kb']),
  ezBar('EZ 바(컬 바)', EquipmentCategory.freeWeight, ['ez bar', 'curl bar', '이지바']),
  trapBar('트랩 바(헥스 바)', EquipmentCategory.freeWeight, ['trap bar', 'hex bar', '헥스바']),
  safetySquatBar('세이프티 스쿼트 바', EquipmentCategory.freeWeight, ['ssb', 'safety squat bar']),
  fixedBarbell('고정 바벨', EquipmentCategory.freeWeight, ['fixed barbell', '고정바']),
  medicineBall('메디신볼/슬램볼', EquipmentCategory.freeWeight, ['medicine ball', 'slam ball', '월볼']),

  // ── 벤치·랙 ──
  flatBench('플랫 벤치', EquipmentCategory.bench, ['flat bench']),
  inclineBench('인클라인(각도조절) 벤치', EquipmentCategory.bench, ['incline bench', 'adjustable bench', '조절 벤치']),
  declineBench('디클라인 벤치', EquipmentCategory.bench, ['decline bench']),
  squatRack('스쿼트 랙/파워랙', EquipmentCategory.bench, ['power rack', 'squat rack', '파워 케이지']),
  halfRack('하프 랙', EquipmentCategory.bench, ['half rack']),
  smithMachine('스미스 머신', EquipmentCategory.bench, ['smith machine']),
  preacherBench('프리처 컬 벤치', EquipmentCategory.bench, ['preacher bench', '프리쳐']),
  pullUpBar('풀업 바(철봉)', EquipmentCategory.bench, ['pull up bar', 'chin up', '친업']),
  dipStation('딥스 스테이션', EquipmentCategory.bench, ['dip station', '패러렐 바']),
  assistedPullUp('어시스트 풀업/딥 머신', EquipmentCategory.bench, ['assisted pull up', 'assisted dip', '어시스티드']),
  ghd('GHD(글루트 햄 디벨로퍼)', EquipmentCategory.bench, ['ghd', 'glute ham developer']),
  multiStation('멀티 스테이션(홈짐)', EquipmentCategory.bench, ['multi station', 'home gym', '멀티짐']),

  // ── 가슴 ──
  chestPress('체스트 프레스 머신', EquipmentCategory.chest, ['chest press', '체스트프레스']),
  inclineChestPress('인클라인 체스트 프레스 머신', EquipmentCategory.chest, ['incline chest press', '인클라인 프레스']),
  declineChestPress('디클라인 체스트 프레스 머신', EquipmentCategory.chest, ['decline chest press']),
  chestPressPlateLoaded('해머 체스트 프레스(플레이트 로디드)', EquipmentCategory.chest, ['hammer strength', 'plate loaded', 'iso lateral', '해머스트렝스', '아이소', '해머 프레스', '해머프레스', '해머 체스트']),
  lyingChestPress('라잉 체스트 프레스 머신(누워서 미는)', EquipmentCategory.chest, ['lying chest press', 'horizontal bench press', 'iso-lateral bench press', 'bench press machine', '라잉', '라잉 체스트', '누워서', '벤치형', '플레이트 벤치']),
  pecDeck('펙덱 플라이/리어델트', EquipmentCategory.chest, ['pec deck', 'pec fly', 'rear delt', '펙 플라이']),
  cableMachine('케이블 크로스오버', EquipmentCategory.chest, ['cable crossover', 'cable machine', '케이블 머신', '케이블', '암풀다운', '케이블 크런치', '페이스풀']),
  functionalTrainer('펑셔널 트레이너(듀얼 케이블)', EquipmentCategory.chest, ['functional trainer', 'dual cable', 'ft']),

  // ── 등 ──
  latPulldown('랫풀다운', EquipmentCategory.back, ['lat pulldown', '랫풀', '암풀다운', 'arm pulldown', '풀다운']),
  latPulldownPlateLoaded('플레이트 로디드 랫풀다운(아이소 풀다운)', EquipmentCategory.back, ['iso lateral pulldown', 'hammer pulldown', '해머 풀다운', '아이소 풀다운', '아이소 래터럴 풀다운']),
  seatedRow('시티드 로우(케이블)', EquipmentCategory.back, ['seated row', 'cable row', '로우']),
  chestSupportedRow('체스트 서포티드 로우 머신', EquipmentCategory.back, ['chest supported row', 'seated row machine']),
  highRow('하이 로우(플레이트 로디드)', EquipmentCategory.back, ['high row', 'hammer high row', '해머 하이로우']),
  lowRow('로우 로우(플레이트 로디드·아이소 래터럴 로우)', EquipmentCategory.back, ['low row', 'hammer row', '해머 로우', 'iso row', 'iso lateral row', '아이소 래터럴 로우', '래터럴 로우', '레터럴 로우', '아이소 로우']),
  tBarRow('티바 로우 머신', EquipmentCategory.back, ['t bar row', '티바']),
  pulloverMachine('풀오버 머신', EquipmentCategory.back, ['pullover machine']),
  shrugMachine('슈러그 머신', EquipmentCategory.back, ['shrug machine', '승모']),
  backExtensionMachine('백 익스텐션 머신', EquipmentCategory.back, ['back extension machine', 'lower back']),
  romanChair('로만 체어/45° 백 익스텐션', EquipmentCategory.back, ['roman chair', 'hyperextension', '하이퍼익스텐션']),
  reverseHyper('리버스 하이퍼', EquipmentCategory.back, ['reverse hyper']),

  // ── 어깨 ──
  shoulderPress('숄더 프레스 머신', EquipmentCategory.shoulder, ['shoulder press', '숄더프레스']),
  shoulderPressPlateLoaded('해머 숄더 프레스(플레이트 로디드)', EquipmentCategory.shoulder, ['hammer shoulder press', 'iso shoulder', '해머 프레스', '해머프레스', '해머 숄더', '아이소 숄더']),
  lateralRaiseMachine('레터럴 레이즈 머신', EquipmentCategory.shoulder, ['lateral raise machine', '사레레 머신']),
  rearDeltMachine('리어 델트 머신', EquipmentCategory.shoulder, ['rear delt machine', 'reverse fly']),

  // ── 팔 ──
  bicepCurlMachine('바이셉 컬 머신', EquipmentCategory.arms, ['bicep curl machine', 'arm curl', '이두 머신']),
  preacherCurlMachine('프리처 컬 머신', EquipmentCategory.arms, ['preacher curl machine']),
  tricepExtensionMachine('트라이셉 익스텐션 머신', EquipmentCategory.arms, ['tricep extension machine', '삼두 머신']),
  dipMachine('시티드 딥 머신', EquipmentCategory.arms, ['dip machine', 'seated dip']),

  // ── 하체 ──
  legPress('레그 프레스(45°)', EquipmentCategory.legs, ['leg press', '레그프레스']),
  horizontalLegPress('수평 레그 프레스', EquipmentCategory.legs, ['horizontal leg press', 'seated leg press']),
  hackSquat('핵 스쿼트', EquipmentCategory.legs, ['hack squat', '핵스쿼트']),
  pendulumSquat('펜듈럼 스쿼트', EquipmentCategory.legs, ['pendulum squat']),
  vSquat('V 스쿼트', EquipmentCategory.legs, ['v squat', 'v-squat']),
  beltSquat('벨트 스쿼트', EquipmentCategory.legs, ['belt squat']),
  legExtension('레그 익스텐션', EquipmentCategory.legs, ['leg extension', '레그익스텐션']),
  legCurl('시티드 레그 컬', EquipmentCategory.legs, ['seated leg curl', 'leg curl', '레그컬']),
  lyingLegCurl('라잉 레그 컬', EquipmentCategory.legs, ['lying leg curl', 'prone leg curl']),
  standingLegCurl('스탠딩 레그 컬', EquipmentCategory.legs, ['standing leg curl', '스탠딩 컬']),
  hipAbductor('힙 어브덕터(바깥)', EquipmentCategory.legs, ['hip abductor', 'abduction', '어브덕션']),
  hipAdductor('힙 어덕터(안쪽)', EquipmentCategory.legs, ['hip adductor', 'adduction', '어덕션', '이너타이']),
  hipThrust('힙 쓰러스트 머신', EquipmentCategory.legs, ['hip thrust', '글루트 드라이브']),
  gluteKickback('글루트 킥백 머신', EquipmentCategory.legs, ['glute kickback', 'glute machine']),
  multiHip('멀티 힙 머신', EquipmentCategory.legs, ['multi hip', '멀티힙', 'hip machine']),
  monsterGlute('몬스터 글루트', EquipmentCategory.legs, ['monster glute', '몬스터글루트', '글루트 머신', '힙 익스텐션 머신']),
  calfRaise('스탠딩 카프 레이즈', EquipmentCategory.legs, ['standing calf', 'calf raise', '종아리']),
  seatedCalfRaise('시티드 카프 레이즈', EquipmentCategory.legs, ['seated calf']),
  sissySquat('시시 스쿼트 머신', EquipmentCategory.legs, ['sissy squat']),
  nordicBench('노르딕 컬 벤치', EquipmentCategory.legs, ['nordic curl', 'nordic hamstring']),

  // ── 복근·코어 ──
  abCrunchMachine('복근 크런치 머신', EquipmentCategory.core, ['ab crunch machine', 'ab machine']),
  torsoRotation('토르소 로테이션', EquipmentCategory.core, ['torso rotation', 'rotary torso', '복사근']),
  captainsChair('캡틴스 체어(레그레이즈 스테이션)', EquipmentCategory.core, ['captains chair', 'leg raise station', 'vkr']),
  declineAbBench('디클라인 싯업 벤치', EquipmentCategory.core, ['sit up bench', 'ab bench', '싯업']),
  abWheel('AB 휠(복근 롤러)', EquipmentCategory.core, ['ab wheel', 'ab roller']),
  abCoaster('앱 코스터', EquipmentCategory.core, ['ab coaster', '앱코스터', '복근 코스터']),

  // ── 유산소 ──
  treadmill('트레드밀(러닝머신)', EquipmentCategory.cardio, ['treadmill', '러닝머신']),
  curvedTreadmill('커브드 트레드밀', EquipmentCategory.cardio, ['curved treadmill', '무동력 러닝머신']),
  bike('실내 자전거(업라이트)', EquipmentCategory.cardio, ['bike', 'upright bike', '사이클']),
  spinBike('스핀 바이크', EquipmentCategory.cardio, ['spin bike', 'spinning', '스피닝']),
  recumbentBike('리컴번트 바이크', EquipmentCategory.cardio, ['recumbent bike', '좌식 자전거']),
  assaultBike('에어 바이크(어썰트)', EquipmentCategory.cardio, ['assault bike', 'air bike', 'echo bike']),
  rower('로잉 머신', EquipmentCategory.cardio, ['rower', 'rowing', 'concept2', '로잉']),
  skiErg('스키 에르그', EquipmentCategory.cardio, ['ski erg', 'skierg']),
  stairClimber('천국의 계단(스텝밀)', EquipmentCategory.cardio, ['stairmaster', 'stepmill', 'stair climber', '천국의 계단', '스텝밀', '계단']),
  elliptical('일립티컬', EquipmentCategory.cardio, ['elliptical', 'cross trainer']),
  jacobsLadder('제이콥스 래더', EquipmentCategory.cardio, ['jacobs ladder']),
  versaClimber('마운틴 클라이머 머신(버사클라이머)', EquipmentCategory.cardio, ['versaclimber', '버사 클라이머', '버사클라이머', '마운틴 클라이머', '마운틴', 'mountain climber', 'climber']),
  jumpRope('줄넘기', EquipmentCategory.cardio, ['jump rope', 'skipping']),
  outdoor('야외 활동 가능 (러닝·등산·자전거)', EquipmentCategory.cardio, ['outdoor', 'running', 'trail', 'hiking', '야외', '러닝', '등산', '산']),
  pool('수영장', EquipmentCategory.cardio, ['pool', 'swim', '수영']),

  // ── 기능성·기타 ──
  landmine('랜드마인', EquipmentCategory.functional, ['landmine', '랜드마인']),
  sled('슬레드(썰매)', EquipmentCategory.functional, ['sled', 'prowler', '프라울러']),
  battleRope('배틀 로프', EquipmentCategory.functional, ['battle rope', '배틀로프']),
  plyoBox('플라이오 박스', EquipmentCategory.functional, ['plyo box', 'jump box', '점프 박스']),
  trx('TRX(서스펜션)', EquipmentCategory.functional, ['trx', 'suspension trainer', '서스펜션']),
  resistanceBand('저항 밴드', EquipmentCategory.functional, ['resistance band', 'band', '밴드', '루프밴드']),
  bodyweight('맨몸(기구 불필요)', EquipmentCategory.functional, ['bodyweight', '맨몸', '매트']);

  const EquipmentType(this.label, this.category, [this.aliases = const []]);
  final String label;
  final EquipmentCategory category;
  final List<String> aliases;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return label.toLowerCase().contains(q) ||
        name.toLowerCase().contains(q) ||
        aliases.any((a) => a.toLowerCase().contains(q));
  }

  static EquipmentType parse(String v) =>
      EquipmentType.values.firstWhere((e) => e.name == v);
}

/// 중량 종류. 무게 증감 단위를 정할 때 사용한다.
enum LoadType {
  barbell(2.5),
  dumbbell(2.0),
  machine(5.0),
  cable(2.5),
  bodyweight(0),
  cardio(0);

  const LoadType(this.increment);

  /// 한 번에 올리거나 내리는 최소 단위(kg). 덤벨은 한 손 기준.
  final double increment;

  static LoadType parse(String v) =>
      LoadType.values.firstWhere((e) => e.name == v);
}

/// 운동 숙련도. 초기 무게 추정의 기준이 된다.
enum TrainingLevel {
  beginner('초급', 1.0),
  intermediate('중급', 1.35),
  advanced('고급', 1.7);

  const TrainingLevel(this.label, this.strengthFactor);
  final String label;
  final double strengthFactor;

  static TrainingLevel parse(String v) =>
      TrainingLevel.values.firstWhere((e) => e.name == v);
}

enum Sex {
  male('남'),
  female('여');

  const Sex(this.label);
  final String label;
  static Sex parse(String v) => Sex.values.firstWhere((e) => e.name == v);
}

/// 운동 목표. 횟수 범위·휴식·유산소 비중을 바꾼다.
enum TrainingGoal {
  hypertrophy('근비대', '8~12회, 보통 휴식'),
  strength('근력', '낮은 횟수·고중량, 긴 휴식'),
  fatLoss('다이어트', '높은 횟수, 짧은 휴식, 유산소 ↑');

  const TrainingGoal(this.label, this.description);
  final String label;
  final String description;
  static TrainingGoal parse(String v) =>
      TrainingGoal.values.firstWhere((e) => e.name == v, orElse: () => TrainingGoal.hypertrophy);
}

/// 부상·주의 부위. 체크하면 그 부위에 부담 가는 운동을 루틴에서 뺀다.
enum InjuryArea {
  lowerBack('허리'),
  knee('무릎'),
  shoulder('어깨'),
  wrist('손목'),
  elbow('팔꿈치');

  const InjuryArea(this.label);
  final String label;
  static InjuryArea? tryParse(String v) {
    for (final e in InjuryArea.values) {
      if (e.name == v) return e;
    }
    return null;
  }
}

/// 사용자 프로필. 로그인 시 선택되며 신체 스펙과 설정을 담는다.
class UserProfile {
  UserProfile({
    required this.id,
    required this.name,
    this.sex = Sex.male,
    this.heightCm = 172,
    this.weightKg = 70,
    this.age = 28,
    this.skeletalMuscleKg,
    this.bodyFatPct,
    this.level = TrainingLevel.beginner,
    this.levelAuto = true,
    this.onboarded = true,
    this.dayStartHour = 4,
    this.restMode = 'shift',
    this.warmupMode = 'auto',
    List<String>? warmupIds,
    Map<String, List<String>>? warmupByGroupIds,
    this.splitDays = 3,
    this.sessionMinutes = 120,
    this.includeCardio = true,
    this.startWith = 'auto',
    this.volumeBias = 1.0,
    List<String>? sectionOrder,
    Map<String, double>? exerciseRank,
    Map<String, double>? groupRank,
    this.activeGymId,
    this.inbodyScannedAt,
    this.squat1rm,
    this.bench1rm,
    this.deadlift1rm,
    this.ohp1rm,
    this.goal = TrainingGoal.hypertrophy,
    Set<InjuryArea>? injuries,
    Set<InjuryArea>? cautions,
    this.theme = 'basic',
  })  : injuries = injuries ?? {},
        cautions = cautions ?? {},
        sectionOrder = sectionOrder ?? List.of(defaultSectionOrder),
        exerciseRank = exerciseRank ?? {},
        groupRank = groupRank ?? {},
        warmupIds = warmupIds ?? [],
        warmupByGroupIds = warmupByGroupIds ?? {};

  final String id;
  String name;
  Sex sex;
  double heightCm;
  double weightKg;
  int age;
  double? skeletalMuscleKg;
  double? bodyFatPct;
  TrainingLevel level;

  /// 숙련도를 스펙·3대 기록으로 자동 판정할지. 끄면 직접 고른 값을 쓴다.
  bool levelAuto;

  /// 처음 만든 프로필이면 false: 홈 전에 초기 설정(신체 정보 등)을 보여준다.
  bool onboarded;

  /// 하루가 시작되는 시각(0~12시). 이 시각 전까지는 전날로 본다. 밤늦게·새벽에 운동하는 사람용.
  int dayStartHour;

  /// 갑자기 쉬게 된 날(또는 운동을 못 한 날) 처리: 'shift' 이후 루틴을 뒤로 밀어 다시 맞춤,
  /// 'keep' 정해진 날짜별 루틴을 그대로 유지(그 날만 '휴식' 표시).
  String restMode;

  /// 운동 전 워밍업: 'auto'(그 날 부위에 맞춰), 'custom'(직접 고른 것), 'off'.
  String warmupMode;

  /// 직접 정하기: 매번 하는 워밍업.
  List<String> warmupIds;

  /// 직접 정하기: 그 날 부위에 따라 하는 워밍업(부위 이름 → 운동 id). 예) 등 → 덤벨 풀오버·풀업.
  Map<String, List<String>> warmupByGroupIds;

  /// n분할. 1(무분할)~6.
  int splitDays;

  /// 하루 운동 시간 예산(분).
  int sessionMinutes;
  bool includeCardio;

  /// 운동 시작 순서: 'auto'(복합→고립→복근→유산소) | 'weights' | 'cardio' | 'abs'.
  String startWith;

  /// 볼륨 보정(0.8~1.3). 계획보다 더 하면 올라가고, 못 채우면 내려간다. 세션 시간 예산에 곱한다.
  double volumeBias;

  /// 구역 순서: 'upper'(웨이트 상체) · 'lower'(웨이트 하체) · 'abs' · 'cardio'.
  List<String> sectionOrder;

  /// 사용자가 직접 바꾼 순서에서 학습한 운동/부위 순위(0=앞, 1=뒤). 다음 루틴 정렬에 반영.
  Map<String, double> exerciseRank;
  Map<String, double> groupRank;

  static const defaultSectionOrder = ['upper', 'lower', 'abs', 'cardio'];
  String? activeGymId;
  DateTime? inbodyScannedAt;

  /// 실제 3대+OHP 기록(1RM 또는 최고 중량). 있으면 추정 대신 이 값을 쓴다.
  double? squat1rm;
  double? bench1rm;
  double? deadlift1rm;
  double? ohp1rm;
  TrainingGoal goal;
  final Set<InjuryArea> injuries;

  /// 주의 부위: 빼지 않고 무게를 낮추고 횟수를 늘려 재활 느낌으로 넣는다.
  final Set<InjuryArea> cautions;

  /// 앱 디자인: 'basic'(기본) · 'cute'(귀여운) · 'tough'(상남자). 프로필에 저장돼 기기 간 동기화.
  String theme;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sex': sex.name,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'age': age,
        'skeletalMuscleKg': skeletalMuscleKg,
        'bodyFatPct': bodyFatPct,
        'level': level.name,
        'levelAuto': levelAuto,
        'onboarded': onboarded,
        'dayStartHour': dayStartHour,
        'restMode': restMode,
        'warmupMode': warmupMode,
        'warmupIds': warmupIds,
        'warmupByGroupIds': warmupByGroupIds,
        'splitDays': splitDays,
        'sessionMinutes': sessionMinutes,
        'includeCardio': includeCardio,
        'startWith': startWith,
        'volumeBias': volumeBias,
        'sectionOrder': sectionOrder,
        'exerciseRank': exerciseRank,
        'groupRank': groupRank,
        'activeGymId': activeGymId,
        'inbodyScannedAt': inbodyScannedAt?.toIso8601String(),
        'squat1rm': squat1rm,
        'bench1rm': bench1rm,
        'deadlift1rm': deadlift1rm,
        'ohp1rm': ohp1rm,
        'goal': goal.name,
        'injuries': injuries.map((i) => i.name).toList(),
        if (cautions.isNotEmpty) 'cautions': cautions.map((i) => i.name).toList(),
        'theme': theme,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'] as String,
        name: j['name'] as String,
        sex: Sex.parse(j['sex'] as String),
        heightCm: (j['heightCm'] as num).toDouble(),
        weightKg: (j['weightKg'] as num).toDouble(),
        age: j['age'] as int,
        skeletalMuscleKg: (j['skeletalMuscleKg'] as num?)?.toDouble(),
        bodyFatPct: (j['bodyFatPct'] as num?)?.toDouble(),
        level: TrainingLevel.parse(j['level'] as String),
        levelAuto: (j['levelAuto'] as bool?) ?? true,
        onboarded: (j['onboarded'] as bool?) ?? true,
        dayStartHour: (j['dayStartHour'] as num?)?.toInt() ?? 4,
        restMode: (j['restMode'] as String?) ?? 'shift',
        warmupMode: (j['warmupMode'] as String?) ?? 'auto',
        warmupIds: (j['warmupIds'] as List?)?.cast<String>(),
        warmupByGroupIds: {
          for (final e in ((j['warmupByGroupIds'] as Map?) ?? const {}).entries)
            e.key as String: ((e.value as List?) ?? const []).cast<String>().toList(),
        },
        splitDays: j['splitDays'] as int,
        sessionMinutes: j['sessionMinutes'] as int,
        includeCardio: j['includeCardio'] as bool,
        startWith: (j['startWith'] as String?) ?? 'auto',
        volumeBias: (j['volumeBias'] as num?)?.toDouble() ?? 1.0,
        sectionOrder: (j['sectionOrder'] as List?)?.cast<String>() ??
            switch (j['startWith']) {
              'cardio' => ['cardio', 'upper', 'lower', 'abs'],
              'abs' => ['abs', 'upper', 'lower', 'cardio'],
              _ => null,
            },
        exerciseRank: {for (final e in ((j['exerciseRank'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toDouble()},
        groupRank: {for (final e in ((j['groupRank'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toDouble()},
        activeGymId: j['activeGymId'] as String?,
        inbodyScannedAt: j['inbodyScannedAt'] == null
            ? null
            : DateTime.parse(j['inbodyScannedAt'] as String),
        squat1rm: (j['squat1rm'] as num?)?.toDouble(),
        bench1rm: (j['bench1rm'] as num?)?.toDouble(),
        deadlift1rm: (j['deadlift1rm'] as num?)?.toDouble(),
        ohp1rm: (j['ohp1rm'] as num?)?.toDouble(),
        goal: TrainingGoal.parse((j['goal'] as String?) ?? 'hypertrophy'),
        injuries: ((j['injuries'] as List?) ?? const [])
            .map((v) => InjuryArea.tryParse(v as String))
            .whereType<InjuryArea>()
            .toSet(),
        cautions: ((j['cautions'] as List?) ?? const [])
            .map((v) => InjuryArea.tryParse(v as String))
            .whereType<InjuryArea>()
            .toSet(),
        theme: (j['theme'] as String?) ?? 'basic',
      );
}

/// 기구의 중량 방식. 같은 숄더프레스라도 핀 꽂는 머신과 원판 끼우는 머신은 무게 단위가 다르다.
enum LoadMechanism {
  pin('핀 (선택식)', 5.0),
  plate('원판 (플레이트)', 2.5),
  free('프리웨이트', 2.5),
  none('해당 없음', 0);

  const LoadMechanism(this.label, this.defaultStepKg);
  final String label;
  final double defaultStepKg;

  static LoadMechanism parse(String v) =>
      LoadMechanism.values.firstWhere((e) => e.name == v, orElse: () => LoadMechanism.none);

  /// 기구 종류별 기본 방식.
  static LoadMechanism defaultFor(EquipmentType t) {
    switch (t) {
      case EquipmentType.barbell:
      case EquipmentType.dumbbell:
      case EquipmentType.kettlebell:
      case EquipmentType.ezBar:
      case EquipmentType.trapBar:
      case EquipmentType.safetySquatBar:
      case EquipmentType.fixedBarbell:
      case EquipmentType.squatRack:
      case EquipmentType.halfRack:
      case EquipmentType.smithMachine:
      case EquipmentType.landmine:
      case EquipmentType.sled:
      case EquipmentType.hipThrust:
      case EquipmentType.beltSquat:
        return LoadMechanism.free;
      case EquipmentType.chestPressPlateLoaded:
      case EquipmentType.lyingChestPress:
      case EquipmentType.latPulldownPlateLoaded:
      case EquipmentType.monsterGlute:
      case EquipmentType.shoulderPressPlateLoaded:
      case EquipmentType.highRow:
      case EquipmentType.lowRow:
      case EquipmentType.tBarRow:
      case EquipmentType.legPress:
      case EquipmentType.hackSquat:
      case EquipmentType.pendulumSquat:
      case EquipmentType.vSquat:
      case EquipmentType.calfRaise:
      case EquipmentType.seatedCalfRaise:
      case EquipmentType.reverseHyper:
        return LoadMechanism.plate;
      case EquipmentType.cableMachine:
      case EquipmentType.functionalTrainer:
      case EquipmentType.latPulldown:
      case EquipmentType.seatedRow:
      case EquipmentType.chestSupportedRow:
      case EquipmentType.chestPress:
      case EquipmentType.inclineChestPress:
      case EquipmentType.declineChestPress:
      case EquipmentType.pecDeck:
      case EquipmentType.shoulderPress:
      case EquipmentType.lateralRaiseMachine:
      case EquipmentType.rearDeltMachine:
      case EquipmentType.bicepCurlMachine:
      case EquipmentType.preacherCurlMachine:
      case EquipmentType.tricepExtensionMachine:
      case EquipmentType.dipMachine:
      case EquipmentType.horizontalLegPress:
      case EquipmentType.legExtension:
      case EquipmentType.legCurl:
      case EquipmentType.lyingLegCurl:
      case EquipmentType.hipAbductor:
      case EquipmentType.hipAdductor:
      case EquipmentType.gluteKickback:
      case EquipmentType.abCrunchMachine:
      case EquipmentType.torsoRotation:
      case EquipmentType.pulloverMachine:
      case EquipmentType.shrugMachine:
      case EquipmentType.backExtensionMachine:
      case EquipmentType.assistedPullUp:
      case EquipmentType.multiStation:
        return LoadMechanism.pin;
      default:
        return LoadMechanism.none;
    }
  }
}

/// 헬스장이 보유한 기구 한 대(또는 한 종류).
class GymEquipment {
  GymEquipment({
    required this.id,
    required this.type,
    this.customName,
    this.note,
    this.maxWeightKg,
    LoadMechanism? mechanism,
    this.stepKg,
    List<EquipmentType>? extraTypes,
    this.brand,
    this.frameColor,
    this.padColor,
    this.shroud,
    this.hasPhoto = false,
    this.dualStack = false,
    this.weightBasis,
    this.plateBasis,
    this.emptyKg,
  })  : mechanism = mechanism ?? LoadMechanism.defaultFor(type),
        extraTypes = extraTypes ?? [];

  final String id;
  EquipmentType type;

  /// 사용자가 붙인 이름(예: "해머스트렝스 체스트프레스"). 비우면 카탈로그 이름.
  String? customName;
  String? note;

  /// 머신 최대 중량 등. 추정 무게의 상한으로 사용.
  double? maxWeightKg;

  /// 핀/원판/프리웨이트.
  LoadMechanism mechanism;

  /// 무게 한 칸(kg). 비우면 방식의 기본값(핀 5 / 원판 2.5).
  double? stepKg;

  /// 화면 기준 한 칸 무게(한쪽 기준 기구면 한쪽 무게). 덤벨은 보통 1kg 단위.
  double get effectiveStep =>
      stepKg ??
      switch (type) {
        EquipmentType.dumbbell => 1.0,
        EquipmentType.kettlebell => 2.0,
        _ => mechanism.defaultStepKg,
      };

  /// 복합(짬뽕) 머신: 한 기구로 여러 종류 운동이 될 때 추가로 해당하는 기구 종류.
  /// 예) 레그 익스텐션 + 레그 컬 겸용, 랫풀다운 + 시티드 로우 겸용.
  final List<EquipmentType> extraTypes;

  List<EquipmentType> get allTypes => [type, ...extraTypes];

  /// 브랜드 키(브랜드별 탭에서 추가한 경우). 3D 색상·프레임 스타일에 쓴다.
  String? brand;

  /// 사용자가 고른 3D 색상(ARGB). null이면 브랜드/기본 색.
  int? frameColor;
  int? padColor;

  /// 웨이트 스택 커버(슈라우드) 표시. null이면 브랜드 기본.
  bool? shroud;

  /// 이 기기에 실물 사진이 저장돼 있는지(사진 자체는 동기화하지 않는다).
  bool hasPhoto;

  /// 좌우가 따로 움직이고 웨이트 스택(핀)도 양쪽에 따로 있는 머신. 무게는 한쪽(스택 하나) 기준,
  /// 한쪽씩도 할 수 있다.
  bool dualStack;

  /// 좌우를 따로 쓰는 머신(스택 2개 또는 한쪽 기준 원판 머신) — '한쪽씩 하기'가 가능.
  bool get independentSides => dualStack || (effectiveBasis == 'perSide' && !perSideByDefault(type));

  /// 무게 표시 기준: 'total'(양쪽 합계) / 'perSide'(한쪽 기준). null이면 기구 기본
  /// (덤벨·케틀벨은 한 손 기준, 나머지는 합계).
  String? weightBasis;

  static bool perSideByDefault(EquipmentType t) => t == EquipmentType.dumbbell || t == EquipmentType.kettlebell;
  String get effectiveBasis => weightBasis ?? (perSideByDefault(type) || dualStack ? 'perSide' : 'total');

  /// 앱 내부 무게(덤벨은 한 손, 나머지는 합계) → 화면에 보일 무게로 바꾸는 배율.
  double get displayFactor {
    final def = perSideByDefault(type) ? 'perSide' : 'total';
    if (effectiveBasis == def) return 1;
    return def == 'perSide' ? 2 : 0.5;
  }

  /// 원판 머신의 무게 기준: 'plates'(끼운 원판만, 기본) / 'full'(빈 기구·슬레드 무게 포함).
  /// 내부 무게 값은 그대로 두고 표기와 안내에만 쓴다.
  String? plateBasis;

  /// 빈 기구(슬레드·캐리지·암) 무게. 모르면 null.
  double? emptyKg;

  /// 원판을 끼우는 머신(바벨·덤벨 제외)이라 빈 기구 무게가 따로 있는 기구.
  bool get sledMatters =>
      mechanism == LoadMechanism.plate &&
      !const {
        EquipmentType.barbell, EquipmentType.dumbbell, EquipmentType.kettlebell, EquipmentType.ezBar,
        EquipmentType.trapBar, EquipmentType.safetySquatBar, EquipmentType.fixedBarbell, EquipmentType.squatRack,
        EquipmentType.halfRack, EquipmentType.landmine, EquipmentType.sled,
      }.contains(type);

  String get effectivePlateBasis => plateBasis ?? 'plates';

  /// 원판 기준 무게 → 기구 포함 무게(빈 기구 무게를 알 때만). 한쪽 기준이면 빈 기구도 반으로 본다.
  double? withSled(double shown) =>
      emptyKg == null ? null : shown + (effectiveBasis == 'perSide' ? emptyKg! / 2 : emptyKg!);

  double? withoutSled(double shown) =>
      emptyKg == null ? null : (shown - (effectiveBasis == 'perSide' ? emptyKg! / 2 : emptyKg!)).clamp(0, double.infinity);

  String get basisLabel {
    final side = effectiveBasis == 'perSide'
        ? (perSideByDefault(type) ? '한 손' : '한쪽')
        : (perSideByDefault(type) ? '양손 합' : '');
    if (!sledMatters) return side;
    final plate = effectivePlateBasis == 'full' ? '기구 포함' : '원판';
    return side.isEmpty ? plate : '$side $plate';
  }

  String get displayName =>
      (customName == null || customName!.isEmpty) ? type.label : customName!;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'customName': customName,
        'note': note,
        'maxWeightKg': maxWeightKg,
        'mechanism': mechanism.name,
        'stepKg': stepKg,
        if (extraTypes.isNotEmpty) 'extraTypes': extraTypes.map((t) => t.name).toList(),
        if (brand != null) 'brand': brand,
        if (frameColor != null) 'frameColor': frameColor,
        if (padColor != null) 'padColor': padColor,
        if (shroud != null) 'shroud': shroud,
        if (hasPhoto) 'hasPhoto': true,
        if (weightBasis != null) 'weightBasis': weightBasis,
        if (dualStack) 'dualStack': true,
        if (plateBasis != null) 'plateBasis': plateBasis,
        if (emptyKg != null) 'emptyKg': emptyKg,
      };

  factory GymEquipment.fromJson(Map<String, dynamic> j) => GymEquipment(
        id: j['id'] as String,
        type: EquipmentType.parse(j['type'] as String),
        customName: j['customName'] as String?,
        note: j['note'] as String?,
        maxWeightKg: (j['maxWeightKg'] as num?)?.toDouble(),
        mechanism: j['mechanism'] == null ? null : LoadMechanism.parse(j['mechanism'] as String),
        stepKg: (j['stepKg'] as num?)?.toDouble(),
        extraTypes: [
          for (final n in ((j['extraTypes'] as List?) ?? const []))
            if (EquipmentType.values.any((t) => t.name == n)) EquipmentType.parse(n as String),
        ],
        brand: j['brand'] as String?,
        frameColor: (j['frameColor'] as num?)?.toInt(),
        padColor: (j['padColor'] as num?)?.toInt(),
        shroud: j['shroud'] as bool?,
        hasPhoto: (j['hasPhoto'] as bool?) ?? false,
        weightBasis: j['weightBasis'] as String?,
        dualStack: (j['dualStack'] as bool?) ?? false,
        plateBasis: j['plateBasis'] as String?,
        emptyKg: (j['emptyKg'] as num?)?.toDouble(),
      );
}

class Gym {
  Gym({required this.id, required this.name, List<GymEquipment>? equipment})
      : equipment = equipment ?? [];

  final String id;
  String name;
  final List<GymEquipment> equipment;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'equipment': equipment.map((e) => e.toJson()).toList(),
      };

  factory Gym.fromJson(Map<String, dynamic> j) => Gym(
        id: j['id'] as String,
        name: j['name'] as String,
        equipment: (j['equipment'] as List)
            .map((e) => GymEquipment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// 보유 기구 + 그 기구가 대신할 수 있는 기구(하프랙→스쿼트랙, 펑셔널 트레이너→케이블 등).
  Set<EquipmentType> get availableTypes {
    final s = {EquipmentType.bodyweight, for (final e in equipment) ...e.allTypes};
    for (final t in s.toList()) {
      s.addAll(impliedEquipment[t] ?? const []);
    }
    return s;
  }
}

/// 어떤 기구를 가지고 있으면 자동으로 "할 수 있는 것"으로 치는 기구들.
const Map<EquipmentType, List<EquipmentType>> impliedEquipment = {
  EquipmentType.halfRack: [EquipmentType.squatRack],
  // 어시스트 머신은 보조 0으로 두면 풀업·딥스 스테이션, 캡틴스 체어엔 딥스 손잡이가 있다.
  EquipmentType.assistedPullUp: [EquipmentType.pullUpBar, EquipmentType.dipStation],
  EquipmentType.captainsChair: [EquipmentType.dipStation],
  // 멀티 힙 머신은 바깥·안쪽·뒤로 차기를 다 한다.
  EquipmentType.multiHip: [EquipmentType.hipAbductor, EquipmentType.hipAdductor, EquipmentType.gluteKickback],
  // GHD에서 백 익스텐션도 된다.
  EquipmentType.ghd: [EquipmentType.romanChair],

  EquipmentType.inclineBench: [EquipmentType.flatBench],
  EquipmentType.declineBench: [EquipmentType.flatBench],
  EquipmentType.functionalTrainer: [EquipmentType.cableMachine],
  EquipmentType.multiStation: [
    EquipmentType.cableMachine,
    EquipmentType.latPulldown,
    EquipmentType.seatedRow,
    EquipmentType.chestPress,
    EquipmentType.pecDeck,
    EquipmentType.legExtension,
    EquipmentType.legCurl,
  ],
  EquipmentType.fixedBarbell: [EquipmentType.ezBar],
  EquipmentType.lyingLegCurl: [EquipmentType.legCurl],
  EquipmentType.curvedTreadmill: [EquipmentType.treadmill],
  EquipmentType.spinBike: [EquipmentType.bike],
  EquipmentType.recumbentBike: [EquipmentType.bike],
};


/// 한 세트의 처방과 실제 수행 결과.
class SetEntry {
  SetEntry({
    required this.targetReps,
    required this.targetWeight,
    this.doneReps,
    this.doneWeight,
    this.completed = false,
    this.level,
    this.doneLevel,
    this.extra = false,
  });

  final int targetReps;

  /// kg. 맨몸/유산소는 0. 유산소는 [targetReps]를 '분'으로 해석한다.
  final double targetWeight;
  int? doneReps;
  double? doneWeight;
  bool completed;

  /// 유산소 기구 강도 단계(스텝밀 레벨, 트레드밀 경사%, 바이크 저항 등). 근력 운동은 null.
  final int? level;
  int? doneLevel;

  /// 처방 외에 직접 추가한 세트. 완료하면 다음 루틴 볼륨을 올리는 근거가 된다.
  final bool extra;

  int get effectiveReps => doneReps ?? targetReps;
  double get effectiveWeight => doneWeight ?? targetWeight;
  int? get effectiveLevel => doneLevel ?? level;

  Map<String, dynamic> toJson() => {
        'targetReps': targetReps,
        'targetWeight': targetWeight,
        'doneReps': doneReps,
        'doneWeight': doneWeight,
        'completed': completed,
        'level': level,
        'doneLevel': doneLevel,
        if (extra) 'extra': true,
      };

  factory SetEntry.fromJson(Map<String, dynamic> j) => SetEntry(
        targetReps: j['targetReps'] as int,
        targetWeight: (j['targetWeight'] as num).toDouble(),
        doneReps: j['doneReps'] as int?,
        doneWeight: (j['doneWeight'] as num?)?.toDouble(),
        completed: j['completed'] as bool,
        level: j['level'] as int?,
        doneLevel: j['doneLevel'] as int?,
        extra: (j['extra'] as bool?) ?? false,
      );
}

/// 세션에 들어간 운동 하나.
class PlannedExercise {
  PlannedExercise({
    required this.exerciseId,
    required this.equipmentType,
    required this.restSeconds,
    required this.sets,
    this.note,
    this.personal = false,
    this.groupOverride,
    this.warmup = false,
    this.pinned = false,
    this.skipMine = false,
    this.oneSide = false,
    this.cardio,
  });

  final String exerciseId;
  final EquipmentType equipmentType;
  final int restSeconds;
  final List<SetEntry> sets;

  /// 생성 근거(예: "지난 루틴에서 미사용", "등 하부 보강").
  final String? note;

  /// 파트너 운동일에 나만 추가한 운동(팔·복근 등). 파트너에게 보내지 않고, 파트너가
  /// 루틴을 바꿔도 유지된다.
  final bool personal;

  /// 사용자가 바꾼 타깃 부위(덤벨 풀오버를 가슴으로 등). null이면 운동 기본 부위.
  MuscleGroup? groupOverride;

  /// 본 운동 전 워밍업·스트레칭. 기록(무게 진행·밸런스)에 넣지 않는다.
  final bool warmup;

  /// 루틴을 다시 짜도 바꾸지 않을 운동(📌 고정).
  bool pinned;

  /// 파트너 날에 나만 빼기로 한 운동(파트너는 그대로 한다). 내 화면에선 흐리게 표시.
  bool skipMine;

  /// 좌우 독립 머신에서 한쪽씩 하기(횟수는 좌우 각각).
  bool oneSide;

  /// 유산소 세부 기록(거리·페이스·심박·케이던스 등). 워치·앱 기록 사진에서 읽어 온다.
  CardioStats? cardio;

  bool get allCompleted => sets.every((s) => s.completed);
  bool get anyCompleted => sets.any((s) => s.completed);

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'equipmentType': equipmentType.name,
        'restSeconds': restSeconds,
        'sets': sets.map((s) => s.toJson()).toList(),
        'note': note,
        if (personal) 'personal': true,
        if (groupOverride != null) 'group': groupOverride!.name,
        if (warmup) 'warmup': true,
        if (pinned) 'pinned': true,
        if (skipMine) 'skipMine': true,
        if (oneSide) 'oneSide': true,
        if (cardio != null && !cardio!.isEmpty) 'cardio': cardio!.toJson(),
      };

  factory PlannedExercise.fromJson(Map<String, dynamic> j) => PlannedExercise(
        exerciseId: j['exerciseId'] as String,
        equipmentType: EquipmentType.parse(j['equipmentType'] as String),
        restSeconds: j['restSeconds'] as int,
        sets: (j['sets'] as List)
            .map((s) => SetEntry.fromJson(s as Map<String, dynamic>))
            .toList(),
        note: j['note'] as String?,
        personal: (j['personal'] as bool?) ?? false,
        groupOverride: j['group'] == null ? null : MuscleGroup.parse(j['group'] as String),
        warmup: (j['warmup'] as bool?) ?? false,
        pinned: (j['pinned'] as bool?) ?? false,
        skipMine: (j['skipMine'] as bool?) ?? false,
        oneSide: (j['oneSide'] as bool?) ?? false,
        cardio: j['cardio'] is Map ? CardioStats.fromJson((j['cardio'] as Map).cast<String, dynamic>()) : null,
      );
}

enum DayKind { workout, rest }

/// 특정 날짜의 계획. 휴식일이면 [exercises]가 비어 있다.
class DayPlan {
  DayPlan({
    required this.id,
    required this.userId,
    required this.date,
    required this.kind,
    required this.focus,
    List<PlannedExercise>? exercises,
    this.estimatedMinutes = 0,
    this.intensityFactor = 1.0,
    this.loadFactor = 1.0,
    this.condition,
    this.rpe,
    this.title,
    this.finishedAt,
    this.startedAt,
    this.endedAt,
    this.gymId,
    this.jointAt,
    this.custom = false,
    this.skipped = false,
    this.venueOwner,
    this.venueGymId,
    this.venueName,
    List<EquipmentType>? venueTypes,
    this.partnerName,
    Map<String, double>? partnerWeights,
    List<GroupMember>? members,
    Map<String, Map<String, double>>? memberWeights,
  })  : exercises = exercises ?? [],
        partnerWeights = partnerWeights ?? {},
        members = members ?? [],
        memberWeights = memberWeights ?? {},
        venueTypes = venueTypes ?? [];

  /// 파트너 운동이면 함께하는 사람 이름(여러 명이면 '·'로 이음)과 운동별 파트너 무게(kg, 첫 사람).
  String? partnerName;
  final Map<String, double> partnerWeights;

  /// 함께 운동하는 사람들(나 제외). 1:1이면 한 명, 그룹이면 여러 명.
  /// 비어 있는데 partnerName만 있으면 예전 버전에서 만든 1:1 파트너 날.
  final List<GroupMember> members;

  /// 사람(uid)별 운동별 무게(kg).
  final Map<String, Map<String, double>> memberWeights;

  final String id;
  final String userId;

  /// 날짜(시간 없음, 로컬).
  final DateTime date;
  final DayKind kind;
  final List<MuscleGroup> focus;
  final List<PlannedExercise> exercises;
  int estimatedMinutes;

  /// 1.0 기본. 연속 운동일이 길면 0.85 등으로 볼륨(세트 수)을 낮춘다.
  final double intensityFactor;

  /// 오늘 컨디션에 따른 무게 배율. 0.7이면 평소 무게의 70%로 처방.
  final double loadFactor;

  /// 운동 전 컨디션 1~10 (사용자 입력). null이면 미설정.
  int? condition;

  /// 운동 후 체감 강도 1~10 (애플워치식: 1~3 쉬움, 4~6 보통, 7~9 어려움, 10 전력투구).
  int? rpe;
  String? title;
  DateTime? finishedAt;

  bool get isRest => kind == DayKind.rest;
  bool get isFinished => finishedAt != null;

  /// '운동 시작'을 누른 시각(또는 첫 세트 체크 시각)과 끝낸 시각.
  DateTime? startedAt;
  DateTime? endedAt;
  bool get isStarted => startedAt != null;

  /// 이 날 가는 헬스장. null이면 프로필의 기본 헬스장.
  String? gymId;

  /// 파트너 운동 장소(누구의 어떤 헬스장인지). 내 헬스장이면 [gymId]와 같고,
  /// 파트너 헬스장이면 그 이름과 기구 목록([venueTypes])으로 운동을 짠다.
  String? venueOwner;
  String? venueGymId;
  String? venueName;
  List<EquipmentType> venueTypes;

  /// 사용자가 직접 손본 날(부위 변경·운동 교체/추가/삭제·AI 적용 등).
  /// 이후 날짜를 자동으로 다시 맞출 때 이 날은 그대로 두고 기준으로 삼는다.
  bool custom;

  /// 운동일이었지만 쉬기로 한 날(또는 안 하고 지나간 날). 계획한 부위는 남겨두고 '휴식'으로 표시한다.
  bool skipped;

  /// 파트너 루틴의 마지막 변경 시각(나든 파트너든). 서로 보낸 루틴이 엇갈리면 더 최근 것만 남긴다.
  DateTime? jointAt;

  /// 내 헬스장이 아닌 곳(파트너 헬스장)에서 하는 날.
  bool get atOtherGym => venueTypes.isNotEmpty && venueName != null;

  /// 실제 운동 시간(분). 시작하지 않았으면 null, 진행 중이면 지금까지.
  int? get actualMinutes {
    final s = startedAt;
    if (s == null) return null;
    return (endedAt ?? DateTime.now()).difference(s).inMinutes;
  }

  /// 처방 외 추가로 완료한 세트 수(직접 추가한 세트 + 직접 추가한 운동의 세트).
  int get extraSetsDone => exercises.fold(
      0, (a, e) => a + e.sets.where((s) => s.completed && (s.extra || e.note == '직접 추가')).length);

  double get completionRatio {
    final mine = exercises.where((e) => !e.skipMine);
    final total = mine.fold<int>(0, (a, e) => a + e.sets.length);
    if (total == 0) return 0;
    final done = mine.fold<int>(
        0, (a, e) => a + e.sets.where((s) => s.completed).length);
    return done / total;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'date': dateKey(date),
        'kind': kind.name,
        'focus': focus.map((f) => f.name).toList(),
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'estimatedMinutes': estimatedMinutes,
        'intensityFactor': intensityFactor,
        'loadFactor': loadFactor,
        'condition': condition,
        'rpe': rpe,
        'title': title,
        'finishedAt': finishedAt?.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'gymId': gymId,
        if (jointAt != null) 'jointAt': jointAt!.toUtc().toIso8601String(),
        if (custom) 'custom': true,
        if (skipped) 'skipped': true,
        if (venueOwner != null) 'venueOwner': venueOwner,
        if (venueGymId != null) 'venueGymId': venueGymId,
        if (venueName != null) 'venueName': venueName,
        if (venueTypes.isNotEmpty) 'venueTypes': venueTypes.map((t) => t.name).toList(),
        'partnerName': partnerName,
        'partnerWeights': partnerWeights,
        if (members.isNotEmpty) 'members': members.map((m) => m.toJson()).toList(),
        if (memberWeights.isNotEmpty) 'memberWeights': memberWeights,
      };

  factory DayPlan.fromJson(Map<String, dynamic> j) => DayPlan(
        id: j['id'] as String,
        userId: j['userId'] as String,
        date: parseDateKey(j['date'] as String),
        kind: DayKind.values.firstWhere((k) => k.name == j['kind']),
        focus: (j['focus'] as List)
            .map((f) => MuscleGroup.parse(f as String))
            .toList(),
        exercises: (j['exercises'] as List)
            .map((e) => PlannedExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
        estimatedMinutes: j['estimatedMinutes'] as int,
        intensityFactor: (j['intensityFactor'] as num).toDouble(),
        loadFactor: (j['loadFactor'] as num?)?.toDouble() ?? 1.0,
        condition: j['condition'] as int?,
        rpe: j['rpe'] as int?,
        partnerName: j['partnerName'] as String?,
        partnerWeights: {
          for (final e in ((j['partnerWeights'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toDouble(),
        },
        members: [for (final m in (j['members'] as List?) ?? const []) GroupMember.fromJson((m as Map).cast<String, dynamic>())],
        memberWeights: {
          for (final e in ((j['memberWeights'] as Map?) ?? const {}).entries)
            e.key as String: {
              for (final w in (e.value as Map).entries) w.key as String: (w.value as num).toDouble(),
            },
        },
        title: j['title'] as String?,
        finishedAt: j['finishedAt'] == null
            ? null
            : DateTime.parse(j['finishedAt'] as String),
        startedAt: j['startedAt'] == null ? null : DateTime.parse(j['startedAt'] as String),
        endedAt: j['endedAt'] == null ? null : DateTime.parse(j['endedAt'] as String),
        gymId: j['gymId'] as String?,
        jointAt: j['jointAt'] == null ? null : DateTime.tryParse(j['jointAt'] as String),
        custom: (j['custom'] as bool?) ?? false,
        skipped: (j['skipped'] as bool?) ?? false,
        venueOwner: j['venueOwner'] as String?,
        venueGymId: j['venueGymId'] as String?,
        venueName: j['venueName'] as String?,
        venueTypes: [
          for (final n in ((j['venueTypes'] as List?) ?? const []))
            if (EquipmentType.values.any((t) => t.name == n)) EquipmentType.parse(n as String),
        ],
      );
}

/// 운동별 현재 작업 중량 상태. 진행(progression) 엔진이 갱신한다.
class ExerciseProgress {
  ExerciseProgress({
    required this.exerciseId,
    required this.workingWeight,
    this.targetReps = 10,
    this.lastPerformed,
    this.timesPerformed = 0,
    this.consecutiveSuccess = 0,
    this.consecutiveFail = 0,
    this.level,
  });

  final String exerciseId;
  double workingWeight;
  int targetReps;

  /// 유산소 기구 강도 단계(현재 작업 레벨).
  int? level;
  DateTime? lastPerformed;
  int timesPerformed;
  int consecutiveSuccess;
  int consecutiveFail;

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'workingWeight': workingWeight,
        'targetReps': targetReps,
        'lastPerformed': lastPerformed?.toIso8601String(),
        'timesPerformed': timesPerformed,
        'consecutiveSuccess': consecutiveSuccess,
        'consecutiveFail': consecutiveFail,
        'level': level,
      };

  factory ExerciseProgress.fromJson(Map<String, dynamic> j) =>
      ExerciseProgress(
        exerciseId: j['exerciseId'] as String,
        workingWeight: (j['workingWeight'] as num).toDouble(),
        targetReps: j['targetReps'] as int,
        lastPerformed: j['lastPerformed'] == null
            ? null
            : DateTime.parse(j['lastPerformed'] as String),
        timesPerformed: j['timesPerformed'] as int,
        consecutiveSuccess: j['consecutiveSuccess'] as int,
        consecutiveFail: j['consecutiveFail'] as int,
        level: j['level'] as int?,
      );
}

/// 'yyyy-MM-dd' 키. 날짜 비교/저장에 통일해서 사용한다.
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDateKey(String k) {
  final p = k.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);


/// 함께 운동하는 사람 한 명(계정 uid와 이름).
class GroupMember {
  const GroupMember(this.uid, this.name);
  final String uid;
  final String name;

  Map<String, dynamic> toJson() => {'u': uid, 'n': name};

  factory GroupMember.fromJson(Map<String, dynamic> j) => GroupMember(j['u'] as String, (j['n'] as String?) ?? '');
}


/// 유산소 한 번의 세부 기록. 모든 값은 없을 수 있다.
class CardioStats {
  CardioStats({
    this.durationSec,
    this.distanceKm,
    this.activeKcal,
    this.totalKcal,
    this.avgHr,
    this.maxHr,
    this.paceSec,
    this.cadence,
    this.strideM,
    this.contactMs,
    this.powerW,
    this.elevationM,
    this.speedKmh,
    this.effort,
    List<CardioSplit>? splits,
    this.source,
  }) : splits = splits ?? [];

  int? durationSec;
  double? distanceKm;
  int? activeKcal;
  int? totalKcal;
  int? avgHr;
  int? maxHr;

  /// 평균 페이스(초/km).
  int? paceSec;

  /// 평균 케이던스(spm, 분당 걸음 / 자전거는 rpm).
  int? cadence;

  /// 평균 보폭(m).
  double? strideM;

  /// 평균 지면 접촉 시간(ms).
  int? contactMs;
  int? powerW;

  /// 오른 고도(m).
  int? elevationM;

  /// 평균 속도(km/h, 자전거 등).
  double? speedKmh;

  /// 운동 강도(1~10, 애플 워치 '운동 강도').
  int? effort;
  final List<CardioSplit> splits;

  /// 어디서 왔는지(예: '사진 인식').
  String? source;

  bool get isEmpty =>
      durationSec == null &&
      distanceKm == null &&
      activeKcal == null &&
      totalKcal == null &&
      avgHr == null &&
      maxHr == null &&
      paceSec == null &&
      cadence == null &&
      strideM == null &&
      contactMs == null &&
      powerW == null &&
      elevationM == null &&
      speedKmh == null &&
      effort == null &&
      splits.isEmpty;

  /// 페이스가 없으면 거리·시간으로 계산.
  int? get effectivePace {
    if (paceSec != null) return paceSec;
    final d = distanceKm, t = durationSec;
    if (d == null || t == null || d <= 0) return null;
    return (t / d).round();
  }

  Map<String, dynamic> toJson() => {
        if (durationSec != null) 't': durationSec,
        if (distanceKm != null) 'km': distanceKm,
        if (activeKcal != null) 'ak': activeKcal,
        if (totalKcal != null) 'tk': totalKcal,
        if (avgHr != null) 'hr': avgHr,
        if (maxHr != null) 'mhr': maxHr,
        if (paceSec != null) 'p': paceSec,
        if (cadence != null) 'c': cadence,
        if (strideM != null) 'st': strideM,
        if (contactMs != null) 'gc': contactMs,
        if (powerW != null) 'w': powerW,
        if (elevationM != null) 'el': elevationM,
        if (speedKmh != null) 'v': speedKmh,
        if (effort != null) 'ef': effort,
        if (splits.isNotEmpty) 'sp': splits.map((e) => e.toJson()).toList(),
        if (source != null) 'src': source,
      };

  static int? _i(Object? v) => v is num ? v.round() : null;
  static double? _d(Object? v) => v is num ? v.toDouble() : null;

  factory CardioStats.fromJson(Map<String, dynamic> j) => CardioStats(
        durationSec: _i(j['t']),
        distanceKm: _d(j['km']),
        activeKcal: _i(j['ak']),
        totalKcal: _i(j['tk']),
        avgHr: _i(j['hr']),
        maxHr: _i(j['mhr']),
        paceSec: _i(j['p']),
        cadence: _i(j['c']),
        strideM: _d(j['st']),
        contactMs: _i(j['gc']),
        powerW: _i(j['w']),
        elevationM: _i(j['el']),
        speedKmh: _d(j['v']),
        effort: _i(j['ef']),
        splits: [
          for (final e in (j['sp'] as List?) ?? const [])
            if (e is Map) CardioSplit.fromJson(e.cast<String, dynamic>()),
        ],
        source: j['src'] as String?,
      );
}

/// 구간(스플릿) 하나: 거리·시간·페이스·심박.
class CardioSplit {
  CardioSplit({this.distanceKm, this.sec, this.paceSec, this.hr});
  final double? distanceKm;
  final int? sec;
  final int? paceSec;
  final int? hr;

  Map<String, dynamic> toJson() => {
        if (distanceKm != null) 'km': distanceKm,
        if (sec != null) 't': sec,
        if (paceSec != null) 'p': paceSec,
        if (hr != null) 'hr': hr,
      };

  factory CardioSplit.fromJson(Map<String, dynamic> j) => CardioSplit(
        distanceKm: (j['km'] as num?)?.toDouble(),
        sec: (j['t'] as num?)?.round(),
        paceSec: (j['p'] as num?)?.round(),
        hr: (j['hr'] as num?)?.round(),
      );
}
