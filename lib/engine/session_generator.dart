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
    this.now,
    this.equipmentMax = const {},
    this.seed,
  });

  final List<MuscleGroup> groups;
  final Set<EquipmentType> available;

  /// exerciseId → 진행 상태. 없는 운동은 처음 하는 것으로 본다.
  final Map<String, ExerciseProgress> progress;
  final UserProfile profile;
  final int minutesBudget;

  /// 연속 운동일 피로 등으로 볼륨을 줄일 때 <1.0.
  final double intensityFactor;
  final DateTime? now;

  /// 기구 종류별 최대 중량(사용자가 입력한 경우).
  final Map<EquipmentType, double> equipmentMax;
  final int? seed;
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
        .where((g) => g != MuscleGroup.cardio || req.profile.includeCardio)
        .toList();
    if (groups.isEmpty) return [];

    final budgetSec = max(20, req.minutesBudget - _overheadMin) * 60;
    final cardioSec = (groups.contains(MuscleGroup.cardio) ||
            req.profile.includeCardio && _shouldAppendCardio(groups))
        ? min(20 * 60, budgetSec ~/ 6)
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
      if (cardio != null) {
        final minutes = (cardioSec / 60).round().clamp(10, 30);
        picked.add(PlannedExercise(
          exerciseId: cardio.id,
          equipmentType: cardio.pickEquipment(req.available),
          restSeconds: 0,
          sets: [SetEntry(targetReps: minutes, targetWeight: 0)],
          note: '마무리 유산소 $minutes분',
        ));
      }
    }
    return picked;
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

      var score = ex.priority * 2.0;
      // 부위마다 첫 운동은 복합운동, 이후엔 고립을 섞는다. 같은 부위 복합운동은 최대 2개.
      if (ex.compound && compoundCount >= 2) continue;
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

  PlannedExercise _plan(Exercise ex) {
    final level = req.profile.level;
    final prog = req.progress[ex.id];
    final equipment = ex.pickEquipment(req.available);
    final rule = restRules[ex.group]!;

    var reps = prog?.targetReps ?? LoadEstimator.targetReps(ex, level);
    var sets = LoadEstimator.setsFor(ex, level);
    if (req.intensityFactor < 0.95) {
      sets = max(2, (sets * req.intensityFactor).round());
    }

    double weight;
    if (prog != null && prog.workingWeight > 0) {
      weight = prog.workingWeight;
    } else {
      weight = _estimator.initialWeight(ex, reps,
          maxWeightKg: req.equipmentMax[equipment]);
    }
    if (req.intensityFactor < 0.95 && weight > 0) {
      weight = LoadEstimator.roundTo(weight * 0.95, ex.loadType.increment);
    }

    final rest = ex.compound ? rule.compoundRestSec : rule.isolationRestSec;
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
