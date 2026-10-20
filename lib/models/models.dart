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

/// 운동기구 종류(카탈로그 수준). 헬스장은 이 종류들 중 보유한 것을 체크한다.
enum EquipmentType {
  barbell('바벨/플레이트'),
  dumbbell('덤벨'),
  flatBench('플랫 벤치'),
  inclineBench('인클라인 벤치'),
  squatRack('스쿼트 랙/파워랙'),
  smithMachine('스미스 머신'),
  cableMachine('케이블 머신'),
  latPulldown('랫풀다운'),
  seatedRow('시티드 로우 머신'),
  chestPress('체스트 프레스 머신'),
  pecDeck('펙덱 플라이'),
  shoulderPress('숄더 프레스 머신'),
  legPress('레그 프레스'),
  legExtension('레그 익스텐션'),
  legCurl('레그 컬'),
  hipThrust('힙 쓰러스트/글루트 머신'),
  calfRaise('카프 레이즈 머신'),
  hackSquat('핵 스쿼트'),
  pullUpBar('풀업 바'),
  dipStation('딥스 스테이션'),
  preacherBench('프리처 컬 벤치'),
  abCrunchMachine('복근 머신'),
  romanChair('로만 체어/백 익스텐션'),
  kettlebell('케틀벨'),
  treadmill('트레드밀'),
  bike('사이클'),
  rower('로잉 머신'),
  stairClimber('스텝밀'),
  elliptical('일립티컬'),
  bodyweight('맨몸(기구 불필요)');

  const EquipmentType(this.label);
  final String label;

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

  Set<EquipmentType> get availableTypes =>
      {EquipmentType.bodyweight, ...equipment.map((e) => e.type)};

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
}

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

  /// 1.0 기본. 연속 운동일이 길면 0.85 등으로 볼륨을 낮춘다.
  final double intensityFactor;
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
