/// 하루 세션 생성기 (요구사항 7, 8, 9, 12).
///
/// 입력: 오늘 다룰 부위들, 헬스장 보유 기구, 운동별 진행 상태(이력), 시간 예산.
/// 출력: 시간 예산 안에 들어가는 [PlannedExercise] 목록.
///
/// 선택 로직:
/// 1. 부위별 예산 배분 — 부위 수가 많으면(무분할) 부위당 1~2개, 적으면 3~5개.
/// 2. 각 부위 안에서 점수 = 우선도 + 복합운동 보너스
///    + "오래 안 한 운동" 보너스(요구사항 8)
///    + "이번 세션에 아직 안 들어온 세부 타깃" 보너스(요구사항 9: 등 하부/윗가슴 등 분산)
///    - 같은 기구 연속 사용 페널티.
/// 3. 운동마다 세트·횟수·무게·휴식을 정하고 예상 시간을 누적. 예산 초과 시 중단.
library;

import 'dart:math';

import '../data/body_model.dart';
import '../data/catalog.dart';
import '../models/models.dart';
import 'load_estimator.dart';
import 'splits.dart';

class SessionRequest {
  SessionRequest({
    required this.groups,
    required this.available,
    required this.progress,
    required this.profile,
    required this.minutesBudget,
    this.intensityFactor = 1.0,
    this.loadFactor = 1.0,
    this.now,
    this.equipmentMax = const {},
    this.equipmentStep = const {},
    this.seed,
    this.extraInjuries = const {},
    this.cardioOverride,
    this.avoidIds = const {},
    this.pinned = const [],
    this.recovery = const {},
    this.boost = const {},
    this.yesterdayGroups = const {},
  });

  /// 전날 한 부위(워밍업 부위를 고를 때 전날 안 한 부위를 우선).
  final Set<MuscleGroup> yesterdayGroups;

  /// 데이터 기반 첨삭: 근육별 회복 정도(0 = 방금 자극, 1 = 완전 회복). 비어 있으면 반영 안 함.
  final Map<Muscle, double> recovery;

  /// 최근 몇 주 자극이 부족한 근육. 이 근육을 주동근으로 쓰는 운동에 보너스.
  final Set<Muscle> boost;

  /// 전날·전전날 한 운동(같은 자세·무게가 연일 겹치지 않게 피한다).
  final Set<String> avoidIds;

  /// 사용자가 고정한 운동(다시 짜도 그대로 남긴다).
  final List<PlannedExercise> pinned;

  /// 파트너 운동 시 파트너의 부상 부위(양쪽 모두 제외).
  final Set<InjuryArea> extraInjuries;

  /// 유산소 포함 여부를 프로필 대신 강제할 때(파트너 운동: 둘 다 원할 때만).
  final bool? cardioOverride;

  bool get includeCardio => cardioOverride ?? profile.includeCardio;
  Set<InjuryArea> get injuries => {...profile.injuries, ...extraInjuries};

  /// 주의 부위(부상으로 뺀 부위는 제외): 운동은 넣되 가볍게.
  Set<InjuryArea> get cautions => profile.cautions.difference(injuries);

  final List<MuscleGroup> groups;
  final Set<EquipmentType> available;

  /// exerciseId → 진행 상태. 없는 운동은 처음 하는 것으로 본다.
  final Map<String, ExerciseProgress> progress;
  final UserProfile profile;
  final int minutesBudget;

  /// 연속 운동일 피로 등으로 볼륨(세트 수)을 줄일 때 <1.0.
  final double intensityFactor;

  /// 오늘 컨디션에 따른 무게 배율(0.5~1.1). 1.0이면 평소 작업 중량.
  final double loadFactor;
  final DateTime? now;

  /// 기구 종류별 최대 중량(사용자가 입력한 경우).
  final Map<EquipmentType, double> equipmentMax;

  /// 기구 종류별 무게 한 칸(kg). 핀 머신 5, 원판 2.5 등. 없으면 운동의 기본 단위.
  final Map<EquipmentType, double> equipmentStep;
  final int? seed;

  /// 이 운동/기구에 맞는 무게 단위.
  double stepFor(Exercise ex, EquipmentType eq) {
    final s = equipmentStep[eq];
    if (s != null && s > 0) return s;
    return ex.loadType.increment;
  }
}

class SessionGenerator {
  SessionGenerator(this.req)
      : _rng = Random(req.seed),
        _estimator = LoadEstimator(req.profile);

  final SessionRequest req;
  final Random _rng;
  final LoadEstimator _estimator;

  /// 세트 1회 수행 시간(초) 추정. 횟수×4초 + 준비 20초.
  static int _workSeconds(int reps, bool unilateral) =>
      (reps * 4 + 20) * (unilateral ? 2 : 1);

  /// 운동 간 전환/세팅 시간(초). 기구 이동·무게 세팅·대기 포함.
  static const int _transitionSec = 120;

  /// 한 세션의 근력 운동 개수 상한. 부위 수에 비례하되 9개를 넘기지 않는다.
  static int _maxExercises(int groupCount) => min(9, 2 + groupCount * 2);

  /// 워밍업·마무리 스트레칭에 고정으로 빼두는 시간(분).
  static const int _overheadMin = 8;

  Set<String> _reserved = const {};

  List<PlannedExercise> generate() {
    final groups = req.groups
        .where((g) => g != MuscleGroup.cardio || req.includeCardio)
        .toList();
    if (groups.isEmpty) return [];

    final budgetSec = max(20, req.minutesBudget - _overheadMin) * 60;
    final fatLoss = req.profile.goal == TrainingGoal.fatLoss;
    final cardioSec = (groups.contains(MuscleGroup.cardio) ||
            req.includeCardio && (fatLoss || _shouldAppendCardio(groups)))
        ? (fatLoss ? min(30 * 60, budgetSec ~/ 4) : min(20 * 60, budgetSec ~/ 6))
        : 0;
    final strengthBudget = budgetSec - cardioSec;

    final strengthGroups =
        groups.where((g) => g != MuscleGroup.cardio).toList();
    // 직접 정한 워밍업 운동은 본 운동으로 뽑지 않는다(워밍업 자리에 넣는다).
    final pf = req.profile;
    _reserved = pf.warmupMode == 'custom'
        ? {...pf.warmupIds, for (final g in strengthGroups) ...?pf.warmupByGroupIds[g.name]}
        : <String>{};
    final perGroup = _exercisesPerGroup(strengthGroups.length);

    // 고정한 운동은 먼저 넣는다(시간·개수에 포함).
    final picked = <PlannedExercise>[
      for (final p in req.pinned)
        if (exerciseById(p.exerciseId) != null && !p.warmup) p,
    ];
    final usedEmphasis = <String>{for (final p in picked) ...exerciseById(p.exerciseId)!.emphasis};
    var usedSec = picked.fold<int>(0, (a, p) => a + _costSec(p, exerciseById(p.exerciseId)!));
    EquipmentType? lastEquipment;

    final maxExercises = max(_maxExercises(strengthGroups.length), picked.length);
    int countOf(MuscleGroup g) => picked.where((p) => p.effectiveGroup == g).length;

    // 0차: 시간이 모자라도 그 날 부위는 하나씩은 꼭 넣는다(세트를 2개까지 줄여서라도).
    // 1차: 부위별 할당 수까지. 2차: 남는 시간이 있으면 보조 운동으로 채운다.
    for (var round = 0; round < 3; round++) {
      for (final g in strengthGroups) {
        final already = countOf(g);
        final want = switch (round) { 0 => already == 0 ? 1 : 0, 1 => perGroup - already, _ => already >= perGroup + 1 ? 0 : 1 };
        var added = 0;
        while (added < want && picked.length < maxExercises) {
          final candidate = _best(g, picked, usedEmphasis, lastEquipment, strengthGroups);
          if (candidate == null) break;
          final planned = _plan(candidate);
          final cost = _costSec(planned, candidate);
          if (usedSec + cost > strengthBudget) {
            // 시간이 없으면 세트 수를 줄여서라도 한 번 시도. 첫 운동은 최소 2세트로라도 넣는다.
            final trimmed = _trim(planned, strengthBudget - usedSec, candidate) ?? (round == 0 ? _minSets(planned) : null);
            if (trimmed == null) break;
            picked.add(trimmed);
            usedSec += _costSec(trimmed, candidate);
            usedEmphasis.addAll(candidate.emphasis);
            lastEquipment = trimmed.equipmentType;
            added++;
            break;
          }
          picked.add(planned);
          usedSec += cost;
          usedEmphasis.addAll(candidate.emphasis);
          lastEquipment = planned.equipmentType;
          added++;
        }
      }
      if (round > 0 && (usedSec > strengthBudget * 0.85 || picked.length >= maxExercises)) break;
    }

    if (cardioSec > 0) {
      final cardio = _best(MuscleGroup.cardio, picked, usedEmphasis, null, strengthGroups);
      final cardioFirst = req.profile.sectionOrder.isNotEmpty && req.profile.sectionOrder.first == 'cardio';
      if (cardio != null) {
        final minutes = (cardioSec / 60).round().clamp(10, 30);
        final level = cardioLevelFor(cardio, req.profile, req.progress[cardio.id]);
        final spec = cardioLevels[cardio.id];
        picked.add(PlannedExercise(
          exerciseId: cardio.id,
          equipmentType: cardio.pickEquipment(req.available),
          restSeconds: 0,
          sets: [SetEntry(targetReps: minutes, targetWeight: 0, level: level)],
          note: '${cardioFirst ? '워밍업' : '마무리'} 유산소 $minutes분${level != null && spec != null ? ' · ${spec.format(level)}' : ''}',
        ));
      }
    }
    return [..._warmups(strengthGroups, picked), ...orderForSession(picked, req.profile)];
  }

  /// 본 운동 전 워밍업: 동적 스트레칭 + 그 날 주요 부위 활성화 운동(가볍게 2세트).
  /// 직접 고른 목록이 있으면 그것, 끄면 없음. 본 루틴과 겹치는 운동은 뺀다.
  List<PlannedExercise> _warmups(List<MuscleGroup> groups, List<PlannedExercise> main) {
    final p = req.profile;
    if (p.warmupMode == 'off' || groups.isEmpty) return const [];
    final mainIds = main.map((e) => e.exerciseId).toSet();
    final ids = <String>[];
    // 부위별 워밍업은 그 날 부위를 다 하지 않는다. 총 운동 시간에 비례해 몇 부위만(30분당 1부위, 1~4개)
    // 랜덤으로 고르되 전날 안 한 부위를 먼저. 고른 부위에서 그 헬스장에서 할 수 있는 것만 1~2개 뽑는다.
    final rnd = Random(req.seed ?? (req.now ?? DateTime.now()).millisecondsSinceEpoch ~/ 86400000);
    final slots = (req.minutesBudget / 30).round().clamp(1, 4);
    final major = groups.where((g) => g != MuscleGroup.cardio).toList()..shuffle(rnd);
    major.sort((a, b) => (req.yesterdayGroups.contains(a) ? 1 : 0) - (req.yesterdayGroups.contains(b) ? 1 : 0));
    final chosenGroups = major.take(slots).toList();
    final perGroup = <String>[];
    for (final g in chosenGroups) {
      final cand = [
        for (final id in p.warmupByGroupIds[g.name] ?? const <String>[])
          if (exerciseById(id) case final ex?)
            if (ex.canDoWith(req.available) && !mainIds.contains(id) && !excludedByInjury(ex, req.injuries)) id,
      ]..shuffle(rnd);
      perGroup.addAll(cand.take(cand.length >= 2 ? 2 : cand.length));
    }
    if (p.warmupMode == 'custom' && (p.warmupIds.isNotEmpty || perGroup.isNotEmpty)) {
      for (final id in [...p.warmupIds, ...perGroup]) {
        if (!ids.contains(id)) ids.add(id);
      }
    } else {
      ids.add('dyn_stretch');
      for (final g in chosenGroups.take(2)) {
        var n = 0;
        for (final id in warmupByGroup[g] ?? const <String>[]) {
          if (n >= 2 || ids.length >= 5) break;
          final ex = exerciseById(id);
          if (ex == null || ids.contains(id) || mainIds.contains(id) || !ex.canDoWith(req.available)) continue;
          if (excludedByInjury(ex, req.injuries)) continue;
          ids.add(id);
          n++;
        }
      }
    }
    final out = <PlannedExercise>[];
    for (final id in ids) {
      final ex = exerciseById(id);
      if (ex == null || !ex.canDoWith(req.available) || mainIds.contains(id)) continue;
      out.add(planWarmup(ex));
    }
    return out;
  }

  /// 운동 하나를 워밍업으로 처방: 유산소는 짧게 1세트, 나머지는 작업 중량의 절반으로 2세트.
  /// 워밍업 칸의 교체·추가에도 쓴다.
  PlannedExercise planWarmup(Exercise ex) {
    final eq = ex.pickEquipment(req.available);
    if (ex.loadType == LoadType.cardio) {
      return PlannedExercise(
        exerciseId: ex.id,
        equipmentType: eq,
        restSeconds: 0,
        sets: [SetEntry(targetReps: ex.repRange[0], targetWeight: 0)],
        note: '워밍업',
        warmup: true,
      );
    }
    final base = _plan(ex);
    final w = base.sets.first.targetWeight;
    final step = req.stepFor(ex, eq);
    final light = w > 0 ? max(step, LoadEstimator.roundTo(w * 0.5, step)) : 0.0;
    return PlannedExercise(
      exerciseId: ex.id,
      equipmentType: eq,
      restSeconds: 30,
      sets: List.generate(2, (_) => SetEntry(targetReps: ex.repRange[1], targetWeight: light)),
      note: '워밍업 · 가볍게',
      warmup: true,
    );
  }

  /// 운동 구역: 'upper'(웨이트 상체) · 'lower'(웨이트 하체) · 'abs' · 'cardio'.
  static String sectionOf(PlannedExercise p) {
    if (p.warmup) return 'warmup';
    final ex = exerciseById(p.exerciseId);
    if (ex == null) return 'upper';
    if (ex.loadType == LoadType.cardio) return 'cardio';
    final g = p.effectiveGroup;
    if (g == MuscleGroup.abs) return 'abs';
    if (g == MuscleGroup.legs) return 'lower';
    return 'upper';
  }

  static const sectionKeys = ['upper', 'lower', 'abs', 'cardio'];
  static const sectionLabels = {'warmup': '워밍업 · 스트레칭', 'upper': '웨이트 · 상체', 'lower': '웨이트 · 하체', 'abs': '복근', 'cardio': '유산소'};
  static String sectionLabel(String key) => sectionLabels[key] ?? key;

  /// 세션 정렬. 구역은 프로필의 [UserProfile.sectionOrder] 순서, 웨이트 구역 안은
  /// 기본적으로 복합(고중량) → 고립 순서(덜 힘든 순서)이되, 사용자가 직접 바꾼 적이 있으면
  /// 그때 학습한 부위/운동 순위([UserProfile.groupRank], [UserProfile.exerciseRank])를 우선한다.
  static List<PlannedExercise> orderForSession(List<PlannedExercise> picked, UserProfile p) {
    final bySec = <String, List<PlannedExercise>>{};
    for (final e in picked) {
      (bySec[sectionOf(e)] ??= []).add(e);
    }
    final order = ['warmup', ...p.sectionOrder, for (final k in sectionKeys) if (!p.sectionOrder.contains(k)) k];
    final out = <PlannedExercise>[];
    for (final k in order) {
      final list = bySec[k] ?? const [];
      out.addAll(k == 'upper' || k == 'lower' ? orderWeights(list, p) : list);
    }
    return out;
  }

  static List<PlannedExercise> orderWeights(List<PlannedExercise> list, UserProfile p) {
    if (list.length < 2) return list;
    bool isCompound(PlannedExercise e) => exerciseById(e.exerciseId)?.compound ?? false;
    MuscleGroup groupOf(PlannedExercise e) => e.effectiveGroup;
    // 기본 효율 순서: 복합 → 큰 근육(하체·등·가슴 > 어깨 > 팔) → 프리웨이트(바벨·덤벨) 먼저.
    const sizeRank = {
      MuscleGroup.legs: 0, MuscleGroup.back: 1, MuscleGroup.chest: 2,
      MuscleGroup.shoulder: 3, MuscleGroup.arms: 4, MuscleGroup.abs: 5, MuscleGroup.cardio: 6,
    };
    bool isFree(PlannedExercise e) => const {
          EquipmentType.barbell, EquipmentType.dumbbell, EquipmentType.ezBar, EquipmentType.trapBar,
          EquipmentType.kettlebell, EquipmentType.safetySquatBar, EquipmentType.squatRack, EquipmentType.flatBench,
          EquipmentType.inclineBench, EquipmentType.declineBench,
        }.contains(e.equipmentType);
    final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
    indexed.sort((a, b) {
      final ca = isCompound(a.$2) ? 0 : 1, cb = isCompound(b.$2) ? 0 : 1;
      if (ca != cb) return ca - cb;
      final ga = sizeRank[groupOf(a.$2)] ?? 9, gb = sizeRank[groupOf(b.$2)] ?? 9;
      if (ga != gb) return ga - gb;
      final fa = isFree(a.$2) ? 0 : 1, fb = isFree(b.$2) ? 0 : 1;
      if (fa != fb) return fa - fb;
      return a.$1 - b.$1;
    });
    final base = [for (final e in indexed) e.$2];
    // 학습한 순위가 하나도 없으면 기본 효율 순서(복합 → 고립) 그대로.
    final learned = list.any((e) => p.exerciseRank.containsKey(e.exerciseId) || p.groupRank.containsKey(groupOf(e).name));
    if (!learned) return base;
    final groups = <MuscleGroup>[];
    for (final e in base) {
      if (!groups.contains(groupOf(e))) groups.add(groupOf(e));
    }
    double gRank(MuscleGroup g) => p.groupRank[g.name] ?? (groups.indexOf(g) / max(1, groups.length - 1));
    double eRank(int i, PlannedExercise e) => p.exerciseRank[e.exerciseId] ?? (i / max(1, base.length - 1));
    final keyed = <(double, int, PlannedExercise)>[
      for (var i = 0; i < base.length; i++) (gRank(groupOf(base[i])) * 10 + eRank(i, base[i]), i, base[i]),
    ];
    keyed.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
    return [for (final k in keyed) k.$3];
  }

  bool _shouldAppendCardio(List<MuscleGroup> groups) =>
      // 하체 날엔 기본적으로 유산소를 붙이지 않는다(회복 우선). 프로필에서 켜면 하체 날에도 붙인다.
      !groups.contains(MuscleGroup.legs) || req.profile.cardioOnLegDays;

  static int _exercisesPerGroup(int groupCount) => switch (groupCount) {
        <= 1 => 5,
        2 => 4,
        3 => 3,
        4 => 2,
        _ => 1,
      };

  int _costSec(PlannedExercise p, Exercise ex) {
    var total = _transitionSec;
    for (final s in p.sets) {
      total += _workSeconds(s.targetReps, ex.unilateral || p.oneSide) + p.restSeconds;
    }
    return total - p.restSeconds; // 마지막 세트 뒤 휴식은 전환 시간에 포함
  }

  PlannedExercise _minSets(PlannedExercise p) => PlannedExercise(
        exerciseId: p.exerciseId,
        equipmentType: p.equipmentType,
        restSeconds: p.restSeconds,
        sets: p.sets.take(2).toList(),
        note: '${p.note ?? ''} · 시간이 짧아 2세트'.trim(),
      );

  PlannedExercise? _trim(PlannedExercise p, int remainingSec, Exercise ex) {
    var sets = List<SetEntry>.from(p.sets);
    while (sets.length > 2) {
      sets.removeLast();
      final t = PlannedExercise(
        exerciseId: p.exerciseId,
        equipmentType: p.equipmentType,
        restSeconds: p.restSeconds,
        sets: sets,
        note: '${p.note ?? ''} · 시간 맞춰 세트 축소'.trim(),
      );
      if (_costSec(t, ex) <= remainingSec) return t;
    }
    return null;
  }

  Exercise? _best(
    MuscleGroup g,
    List<PlannedExercise> picked,
    Set<String> usedEmphasis,
    EquipmentType? lastEquipment,
    List<MuscleGroup> dayGroups,
  ) {
    final pickedIds = picked.map((p) => p.exerciseId).toSet();
    final now = req.now ?? DateTime.now();
    final armsHint = g == MuscleGroup.arms ? armsEmphasisFor(dayGroups) : const <String>[];
    final compoundCount = picked.where((p) {
      final e = exerciseById(p.exerciseId);
      return e != null && e.group == g && e.compound;
    }).length;
    final hasPrimaryCompound = compoundCount > 0;

    Exercise? best;
    var bestScore = double.negativeInfinity;
    for (final ex in exercisesOf(g)) {
      if (ex.warmupOnly || ex.activity || _reserved.contains(ex.id)) continue;
      if (pickedIds.contains(ex.id)) continue;
      // 전날·전전날 한 운동은 웬만하면 피한다(같은 자세·무게가 연일 겹치지 않게).
      final repeatPenalty = req.avoidIds.contains(ex.id) ? 6.0 : 0.0;
      if (!ex.canDoWith(req.available)) continue;
      if (excludedByInjury(ex, req.injuries)) continue;

      var score = ex.priority * 2.0;
      // 주의 부위에 부담 가는 운동은 넣을 수는 있지만 덜 부담되는 운동을 먼저.
      if (cautionHits(ex, req.cautions).isNotEmpty) score -= 2.5;
      // 부위마다 첫 운동은 복합운동, 이후엔 고립을 섞는다. 같은 부위 복합운동은 최대 2개.
      if (ex.compound && compoundCount >= 2) continue;
      // 두 번째 복합운동은 첫 번째와 주 타깃이 달라야 한다(덤벨 벤치 + 바벨 벤치 같은 중복 방지).
      if (ex.compound && hasPrimaryCompound && ex.emphasis.isNotEmpty && usedEmphasis.contains(ex.emphasis.first)) {
        continue;
      }
      score += ex.compound ? (hasPrimaryCompound ? -1.0 : 3.0) : (hasPrimaryCompound ? 1.0 : -1.0);

      // 요구사항 8: 오래 안 한 운동 우선.
      final prog = req.progress[ex.id];
      if (prog == null || prog.lastPerformed == null) {
        score += 2.5; // 처음 하는 운동
      } else {
        final days = now.difference(prog.lastPerformed!).inDays;
        score += min(3.0, days / 7.0); // 1주마다 +1, 최대 +3
        if (days <= 2) score -= 2.0;
      }

      // 요구사항 9: 아직 안 다룬 세부 타깃(등 하부·윗가슴 등)에 보너스.
      final fresh = ex.emphasis.where((e) => !usedEmphasis.contains(e)).length;
      score += fresh * 1.0;
      if (fresh == 0 && ex.emphasis.isNotEmpty) score -= 3.0; // 같은 포인트만 때리는 중복 운동 회피

      // 팔: 밀기 날엔 삼두, 당기기 날엔 이두를 우선.
      if (armsHint.isNotEmpty) {
        final match = ex.emphasis.any((e) => armsHint.any(e.contains));
        score += match ? 2.0 : -2.0;
      }

      // 같은 기구 연속 사용은 동선/점유 측면에서 약한 페널티.
      final eq = ex.pickEquipment(req.available);
      if (lastEquipment != null && eq == lastEquipment && eq != EquipmentType.dumbbell) {
        score -= 0.7;
      }
      // 초급자는 머신/덤벨 비중을 높인다.
      if (req.profile.level == TrainingLevel.beginner &&
          (ex.loadType == LoadType.machine || ex.loadType == LoadType.cable)) {
        score += 0.5;
      }
      score -= repeatPenalty;
      // 데이터 기반 첨삭: 아직 회복 안 된 근육(70% 미만)을 주동근으로 쓰면 감점, 부족한 근육이면 가점.
      if (req.recovery.isNotEmpty || req.boost.isNotEmpty) {
        final mm = musclesFor(ex);
        for (final m in mm.primary) {
          final r = req.recovery[m];
          if (r != null && r < 0.7) score -= (0.7 - r) * 8;
          if (req.boost.contains(m)) score += 1.5;
        }
      }
      score += _rng.nextDouble() * 0.6; // 동점 깨기 + 약간의 변화

      if (score > bestScore) {
        bestScore = score;
        best = ex;
      }
    }
    return best;
  }

  /// 특정 운동 하나를 현재 프로필·기록 기준으로 처방(세트·횟수·무게). 추가/교체에 쓴다.
  PlannedExercise planExercise(Exercise ex) => _plan(ex);

  PlannedExercise _plan(Exercise ex) {
    final level = req.profile.level;
    final prog = req.progress[ex.id];
    final equipment = ex.pickEquipment(req.available);
    final rule = restRules[ex.group]!;

    var reps = prog?.targetReps ?? LoadEstimator.targetReps(ex, level, req.profile.goal);
    var sets = LoadEstimator.setsFor(ex, level);
    if (req.intensityFactor < 0.95) {
      sets = max(2, (sets * req.intensityFactor).round());
    }
    // 데이터 기반 첨삭: 주동근이 60% 미만 회복이면 한 세트 줄이고 무게도 살짝 낮춘다.
    var tired = false;
    if (req.recovery.isNotEmpty) {
      final mm = musclesFor(ex);
      tired = mm.primary.any((m) => (req.recovery[m] ?? 1) < 0.6);
      if (tired) sets = max(2, sets - 1);
    }

    final step = req.stepFor(ex, equipment);
    double weight;
    if (prog != null && prog.workingWeight > 0) {
      weight = prog.workingWeight;
    } else {
      weight = _estimator.initialWeight(ex, reps,
          maxWeightKg: req.equipmentMax[equipment]);
    }
    if (req.intensityFactor < 0.95 && weight > 0) {
      weight = LoadEstimator.roundTo(weight * 0.95, step);
    }
    if (req.loadFactor != 1.0 && weight > 0) {
      weight = max(step, LoadEstimator.roundTo(weight * req.loadFactor, step));
    }
    // 기구 단위(핀 5kg 등)에 맞춰 마지막으로 한 번 더 정렬.
    if (weight > 0 && step > 0) weight = max(step, LoadEstimator.roundTo(weight, step));
    // 컨디션이 안 좋은 날(무게 ↓)은 횟수를 2회 늘려 볼륨을 일부 보전하고, 좋은 날은 그대로.
    if (req.loadFactor < 0.85 && ex.loadType != LoadType.cardio && ex.loadType != LoadType.bodyweight) {
      reps = min(ex.repRange[1] + 2, reps + 2);
    }

    // 주의 부위: 무게 60%, 횟수 ↑, 세트 -1 — 통증 없는 범위에서 재활 느낌으로.
    final careful = cautionHits(ex, req.cautions);
    if (careful.isNotEmpty && ex.loadType != LoadType.cardio) {
      if (weight > 0) weight = max(step > 0 ? step : 0.0, LoadEstimator.roundTo(weight * 0.6, step));
      if (ex.loadType != LoadType.bodyweight) reps = min(20, max(reps, ex.repRange[1]) + 3);
      sets = max(2, sets - 1);
    }

    final rest = ((ex.compound ? rule.compoundRestSec : rule.isolationRestSec) *
            LoadEstimator.restFactor(req.profile.goal))
        .round();
    final baseNote = prog == null
        ? '처음 하는 운동 · ${ex.emphasis.join(', ')}'
        : prog.lastPerformed == null
            ? ex.emphasis.join(', ')
            : '마지막 수행 ${(req.now ?? DateTime.now()).difference(prog.lastPerformed!).inDays}일 전 · ${ex.emphasis.join(', ')}';
    if (tired && weight > 0 && careful.isEmpty) weight = max(step > 0 ? step : 0.0, LoadEstimator.roundTo(weight * 0.9, step));
    final note = careful.isEmpty
        ? (tired ? '회복 중인 근육 · 세트 -1, 무게 90% · $baseNote' : baseNote)
        : '⚠ ${careful.map((i) => i.label).join('·')} 주의 · 가볍게, 3초 천천히 내리기, 아프면 바로 중단 · $baseNote';

    return PlannedExercise(
      exerciseId: ex.id,
      equipmentType: equipment,
      restSeconds: rest,
      sets: List.generate(
          sets, (_) => SetEntry(targetReps: reps, targetWeight: weight)),
      note: note,
    );
  }

  /// 유산소 기구 강도: 진행 기록이 있으면 그 레벨, 없으면 숙련도·목표별 시작값.
  static int? cardioLevelFor(Exercise ex, UserProfile p, ExerciseProgress? prog) {
    final spec = cardioLevels[ex.id];
    if (spec == null) return null;
    final l = prog?.level ?? spec.startFor(p.level, p.goal);
    return l.clamp(spec.min, spec.max);
  }

  /// 세션의 총 예상 시간(분).
  static int estimateMinutes(List<PlannedExercise> plan) {
    var sec = _overheadMin * 60;
    for (final p in plan) {
      // 워밍업은 고정 준비 시간(_overheadMin)에 포함.
      if (p.warmup) continue;
      final ex = exerciseById(p.exerciseId);
      if (ex == null) continue;
      if (ex.loadType == LoadType.cardio) {
        sec += p.sets.first.targetReps * 60 + 60;
        continue;
      }
      sec += _transitionSec;
      for (final s in p.sets) {
        sec += _workSeconds(s.targetReps, ex.unilateral || p.oneSide) + p.restSeconds;
      }
      sec -= p.restSeconds;
    }
    return (sec / 60).ceil();
  }
}
