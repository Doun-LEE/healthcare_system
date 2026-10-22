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
  });

  /// 파트너 운동 시 파트너의 부상 부위(양쪽 모두 제외).
  final Set<InjuryArea> extraInjuries;

  /// 유산소 포함 여부를 프로필 대신 강제할 때(파트너 운동: 둘 다 원할 때만).
  final bool? cardioOverride;

  bool get includeCardio => cardioOverride ?? profile.includeCardio;
  Set<InjuryArea> get injuries => {...profile.injuries, ...extraInjuries};

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
    final perGroup = _exercisesPerGroup(strengthGroups.length);

    final picked = <PlannedExercise>[];
    final usedEmphasis = <String>{};
    var usedSec = 0;
    EquipmentType? lastEquipment;

    final maxExercises = _maxExercises(strengthGroups.length);

    // 1차: 부위별 할당 수만큼. 2차: 남는 시간이 있으면 보조 운동으로 채운다.
    for (var round = 0; round < 2; round++) {
      for (final g in strengthGroups) {
        final want = round == 0 ? perGroup : 1;
        final already = picked.where((p) => exerciseById(p.exerciseId)?.group == g).length;
        if (round == 1 && already >= perGroup + 1) continue;
        var added = 0;
        while (added < want && picked.length < maxExercises) {
          final candidate = _best(g, picked, usedEmphasis, lastEquipment, strengthGroups);
          if (candidate == null) break;
          final planned = _plan(candidate);
          final cost = _costSec(planned, candidate);
          if (usedSec + cost > strengthBudget) {
            // 시간이 없으면 세트 수를 줄여서라도 한 번 시도.
            final trimmed = _trim(planned, strengthBudget - usedSec, candidate);
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
      if (usedSec > strengthBudget * 0.85 || picked.length >= maxExercises) break;
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
    return orderForSession(picked, req.profile);
  }

  /// 운동 구역: 'upper'(웨이트 상체) · 'lower'(웨이트 하체) · 'abs' · 'cardio'.
  static String sectionOf(PlannedExercise p) {
    final ex = exerciseById(p.exerciseId);
    if (ex == null) return 'upper';
    if (ex.loadType == LoadType.cardio) return 'cardio';
    final g = p.effectiveGroup;
    if (g == MuscleGroup.abs) return 'abs';
    if (g == MuscleGroup.legs) return 'lower';
    return 'upper';
  }

  static const sectionKeys = ['upper', 'lower', 'abs', 'cardio'];
  static const sectionLabels = {'upper': '웨이트 · 상체', 'lower': '웨이트 · 하체', 'abs': '복근', 'cardio': '유산소'};
  static String sectionLabel(String key) => sectionLabels[key] ?? key;

  /// 세션 정렬. 구역은 프로필의 [UserProfile.sectionOrder] 순서, 웨이트 구역 안은
  /// 기본적으로 복합(고중량) → 고립 순서(덜 힘든 순서)이되, 사용자가 직접 바꾼 적이 있으면
  /// 그때 학습한 부위/운동 순위([UserProfile.groupRank], [UserProfile.exerciseRank])를 우선한다.
  static List<PlannedExercise> orderForSession(List<PlannedExercise> picked, UserProfile p) {
    final bySec = <String, List<PlannedExercise>>{};
    for (final e in picked) {
      (bySec[sectionOf(e)] ??= []).add(e);
    }
    final order = [...p.sectionOrder, for (final k in sectionKeys) if (!p.sectionOrder.contains(k)) k];
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
    final base = [...list.where(isCompound), ...list.where((e) => !isCompound(e))];
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
      // 하체 날엔 유산소를 붙이지 않는다(회복 우선). 그 외엔 붙인다.
      !groups.contains(MuscleGroup.legs);

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
      total += _workSeconds(s.targetReps, ex.unilateral) + p.restSeconds;
    }
    return total - p.restSeconds; // 마지막 세트 뒤 휴식은 전환 시간에 포함
  }

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
      if (pickedIds.contains(ex.id)) continue;
      if (!ex.canDoWith(req.available)) continue;
      if (excludedByInjury(ex, req.injuries)) continue;

      var score = ex.priority * 2.0;
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

    final rest = ((ex.compound ? rule.compoundRestSec : rule.isolationRestSec) *
            LoadEstimator.restFactor(req.profile.goal))
        .round();
    final note = prog == null
        ? '처음 하는 운동 · ${ex.emphasis.join(', ')}'
        : prog.lastPerformed == null
            ? ex.emphasis.join(', ')
            : '마지막 수행 ${(req.now ?? DateTime.now()).difference(prog.lastPerformed!).inDays}일 전 · ${ex.emphasis.join(', ')}';

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
      final ex = exerciseById(p.exerciseId);
      if (ex == null) continue;
      if (ex.loadType == LoadType.cardio) {
        sec += p.sets.first.targetReps * 60 + 60;
        continue;
      }
      sec += _transitionSec;
      for (final s in p.sets) {
        sec += _workSeconds(s.targetReps, ex.unilateral) + p.restSeconds;
      }
      sec -= p.restSeconds;
    }
    return (sec / 60).ceil();
  }
}
