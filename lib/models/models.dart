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
  chestPressPlateLoaded('플레이트 로디드 체스트 프레스(해머)', EquipmentCategory.chest, ['hammer strength', 'plate loaded', 'iso lateral', '해머스트렝스', '아이소']),
  pecDeck('펙덱 플라이/리어델트', EquipmentCategory.chest, ['pec deck', 'pec fly', 'rear delt', '펙 플라이']),
  cableMachine('케이블 크로스오버', EquipmentCategory.chest, ['cable crossover', 'cable machine', '케이블 머신']),
  functionalTrainer('펑셔널 트레이너(듀얼 케이블)', EquipmentCategory.chest, ['functional trainer', 'dual cable', 'ft']),

  // ── 등 ──
  latPulldown('랫풀다운', EquipmentCategory.back, ['lat pulldown', '랫풀']),
  seatedRow('시티드 로우(케이블)', EquipmentCategory.back, ['seated row', 'cable row', '로우']),
  chestSupportedRow('체스트 서포티드 로우 머신', EquipmentCategory.back, ['chest supported row', 'seated row machine']),
  highRow('하이 로우(플레이트 로디드)', EquipmentCategory.back, ['high row', 'hammer high row', '해머 하이로우']),
  lowRow('로우 로우(플레이트 로디드)', EquipmentCategory.back, ['low row', 'hammer row', '해머 로우', 'iso row']),
  tBarRow('티바 로우 머신', EquipmentCategory.back, ['t bar row', '티바']),
  pulloverMachine('풀오버 머신', EquipmentCategory.back, ['pullover machine']),
  shrugMachine('슈러그 머신', EquipmentCategory.back, ['shrug machine', '승모']),
  backExtensionMachine('백 익스텐션 머신', EquipmentCategory.back, ['back extension machine', 'lower back']),
  romanChair('로만 체어/45° 백 익스텐션', EquipmentCategory.back, ['roman chair', 'hyperextension', '하이퍼익스텐션']),
  reverseHyper('리버스 하이퍼', EquipmentCategory.back, ['reverse hyper']),

  // ── 어깨 ──
  shoulderPress('숄더 프레스 머신', EquipmentCategory.shoulder, ['shoulder press', '숄더프레스']),
  shoulderPressPlateLoaded('플레이트 로디드 숄더 프레스', EquipmentCategory.shoulder, ['hammer shoulder press', 'iso shoulder']),
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
  hipAbductor('힙 어브덕터(바깥)', EquipmentCategory.legs, ['hip abductor', 'abduction', '어브덕션']),
  hipAdductor('힙 어덕터(안쪽)', EquipmentCategory.legs, ['hip adductor', 'adduction', '어덕션', '이너타이']),
  hipThrust('힙 쓰러스트 머신', EquipmentCategory.legs, ['hip thrust', '글루트 드라이브']),
  gluteKickback('글루트 킥백 머신', EquipmentCategory.legs, ['glute kickback', 'glute machine']),
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

  // ── 유산소 ──
  treadmill('트레드밀(러닝머신)', EquipmentCategory.cardio, ['treadmill', '러닝머신']),
  curvedTreadmill('커브드 트레드밀', EquipmentCategory.cardio, ['curved treadmill', '무동력 러닝머신']),
  bike('실내 자전거(업라이트)', EquipmentCategory.cardio, ['bike', 'upright bike', '사이클']),
  spinBike('스핀 바이크', EquipmentCategory.cardio, ['spin bike', 'spinning', '스피닝']),
  recumbentBike('리컴번트 바이크', EquipmentCategory.cardio, ['recumbent bike', '좌식 자전거']),
  assaultBike('에어 바이크(어썰트)', EquipmentCategory.cardio, ['assault bike', 'air bike', 'echo bike']),
  rower('로잉 머신', EquipmentCategory.cardio, ['rower', 'rowing', 'concept2', '로잉']),
  skiErg('스키 에르그', EquipmentCategory.cardio, ['ski erg', 'skierg']),
  stairClimber('스텝밀(천국의 계단)', EquipmentCategory.cardio, ['stairmaster', 'stepmill', 'stair climber', '천국의 계단']),
  elliptical('일립티컬', EquipmentCategory.cardio, ['elliptical', 'cross trainer']),
  jacobsLadder('제이콥스 래더', EquipmentCategory.cardio, ['jacobs ladder']),
  versaClimber('버사클라이머', EquipmentCategory.cardio, ['versaclimber', '버사 클라이머']),
  jumpRope('줄넘기', EquipmentCategory.cardio, ['jump rope', 'skipping']),

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
    this.splitDays = 3,
    this.sessionMinutes = 120,
    this.includeCardio = true,
    this.activeGymId,
    this.inbodyScannedAt,
  });

  final String id;
  String name;
  Sex sex;
  double heightCm;
  double weightKg;
  int age;
  double? skeletalMuscleKg;
  double? bodyFatPct;
  TrainingLevel level;

  /// n분할. 1(무분할)~6.
  int splitDays;

  /// 하루 운동 시간 예산(분).
  int sessionMinutes;
  bool includeCardio;
  String? activeGymId;
  DateTime? inbodyScannedAt;

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
        'splitDays': splitDays,
        'sessionMinutes': sessionMinutes,
        'includeCardio': includeCardio,
        'activeGymId': activeGymId,
        'inbodyScannedAt': inbodyScannedAt?.toIso8601String(),
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
        splitDays: j['splitDays'] as int,
        sessionMinutes: j['sessionMinutes'] as int,
        includeCardio: j['includeCardio'] as bool,
        activeGymId: j['activeGymId'] as String?,
        inbodyScannedAt: j['inbodyScannedAt'] == null
            ? null
            : DateTime.parse(j['inbodyScannedAt'] as String),
      );
}

/// 헬스장이 보유한 기구 한 대(또는 한 종류).
class GymEquipment {
  GymEquipment({
    required this.id,
    required this.type,
    this.customName,
    this.note,
    this.maxWeightKg,
  });

  final String id;
  EquipmentType type;

  /// 사용자가 붙인 이름(예: "해머스트렝스 체스트프레스"). 비우면 카탈로그 이름.
  String? customName;
  String? note;

  /// 머신 최대 중량 등. 추정 무게의 상한으로 사용.
  double? maxWeightKg;

  String get displayName =>
      (customName == null || customName!.isEmpty) ? type.label : customName!;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'customName': customName,
        'note': note,
        'maxWeightKg': maxWeightKg,
      };

  factory GymEquipment.fromJson(Map<String, dynamic> j) => GymEquipment(
        id: j['id'] as String,
        type: EquipmentType.parse(j['type'] as String),
        customName: j['customName'] as String?,
        note: j['note'] as String?,
        maxWeightKg: (j['maxWeightKg'] as num?)?.toDouble(),
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
    final s = {EquipmentType.bodyweight, ...equipment.map((e) => e.type)};
    for (final t in s.toList()) {
      s.addAll(impliedEquipment[t] ?? const []);
    }
    return s;
  }
}

/// 어떤 기구를 가지고 있으면 자동으로 "할 수 있는 것"으로 치는 기구들.
const Map<EquipmentType, List<EquipmentType>> impliedEquipment = {
  EquipmentType.halfRack: [EquipmentType.squatRack],
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
  });

  final int targetReps;

  /// kg. 맨몸/유산소는 0. 유산소는 [targetReps]를 '분'으로 해석한다.
  final double targetWeight;
  int? doneReps;
  double? doneWeight;
  bool completed;

  int get effectiveReps => doneReps ?? targetReps;
  double get effectiveWeight => doneWeight ?? targetWeight;

  Map<String, dynamic> toJson() => {
        'targetReps': targetReps,
        'targetWeight': targetWeight,
        'doneReps': doneReps,
        'doneWeight': doneWeight,
        'completed': completed,
      };

  factory SetEntry.fromJson(Map<String, dynamic> j) => SetEntry(
        targetReps: j['targetReps'] as int,
        targetWeight: (j['targetWeight'] as num).toDouble(),
        doneReps: j['doneReps'] as int?,
        doneWeight: (j['doneWeight'] as num?)?.toDouble(),
        completed: j['completed'] as bool,
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
  });

  final String exerciseId;
  final EquipmentType equipmentType;
  final int restSeconds;
  final List<SetEntry> sets;

  /// 생성 근거(예: "지난 루틴에서 미사용", "등 하부 보강").
  final String? note;

  bool get allCompleted => sets.every((s) => s.completed);
  bool get anyCompleted => sets.any((s) => s.completed);

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'equipmentType': equipmentType.name,
        'restSeconds': restSeconds,
        'sets': sets.map((s) => s.toJson()).toList(),
        'note': note,
      };

  factory PlannedExercise.fromJson(Map<String, dynamic> j) => PlannedExercise(
        exerciseId: j['exerciseId'] as String,
        equipmentType: EquipmentType.parse(j['equipmentType'] as String),
        restSeconds: j['restSeconds'] as int,
        sets: (j['sets'] as List)
            .map((s) => SetEntry.fromJson(s as Map<String, dynamic>))
            .toList(),
        note: j['note'] as String?,
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
  }) : exercises = exercises ?? [];

  final String id;
  final String userId;

  /// 날짜(시간 없음, 로컬).
  final DateTime date;
  final DayKind kind;
  final List<MuscleGroup> focus;
  final List<PlannedExercise> exercises;
  final int estimatedMinutes;

  /// 1.0 기본. 연속 운동일이 길면 0.85 등으로 볼륨(세트 수)을 낮춘다.
  final double intensityFactor;

  /// 오늘 컨디션에 따른 무게 배율. 0.7이면 평소 무게의 70%로 처방.
  final double loadFactor;

  /// 운동 전 컨디션 1~10 (사용자 입력). null이면 미설정.
  int? condition;

  /// 운동 후 체감 강도 1~10 (애플워치식: 1~3 쉬움, 4~6 보통, 7~9 어려움, 10 전력투구).
  int? rpe;
  final String? title;
  DateTime? finishedAt;

  bool get isRest => kind == DayKind.rest;
  bool get isFinished => finishedAt != null;

  double get completionRatio {
    final total = exercises.fold<int>(0, (a, e) => a + e.sets.length);
    if (total == 0) return 0;
    final done = exercises.fold<int>(
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
        title: j['title'] as String?,
        finishedAt: j['finishedAt'] == null
            ? null
            : DateTime.parse(j['finishedAt'] as String),
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
  });

  final String exerciseId;
  double workingWeight;
  int targetReps;
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
