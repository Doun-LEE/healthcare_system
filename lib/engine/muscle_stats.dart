/// 완료한 세션을 근육(22개) 단위로 집계한다.
///
/// 점수 = 유효 세트(effective sets): 주동근은 세트당 1.0, 보조근은 0.4(흔히 쓰는 분할 세트 계산).
/// 볼륨(kg×회)도 같은 비율로 나눠 붙인다. 유산소는 워치 기록(시간·심박·칼로리)이 있으면
/// 그걸로 강도를 보정해 다리 근육에 작은 세트 값으로 더한다.
library;

import 'dart:math';

import '../data/body_model.dart';
import '../data/catalog.dart';
import '../models/models.dart';

const primaryWeight = 1.0;
const secondaryWeight = 0.4;

class MuscleScore {
  MuscleScore(this.muscle);
  final Muscle muscle;

  /// 유효 세트(주동 1.0 + 보조 0.4 + 유산소 환산).
  double score = 0;
  double primarySets = 0;
  double secondarySets = 0;
  double cardioSets = 0;
  double tonnage = 0;
  final Set<String> sessionIds = {};

  /// 이 근육을 가장 많이 자극한 운동(유효 세트 기준) → 세트 수.
  final Map<String, double> byExercise = {};

  int get sessions => sessionIds.length;
}

/// 워치·러닝 앱 기록 합계(사진으로 읽어 들인 것).
class WatchSummary {
  int sessions = 0;
  int durationSec = 0;
  double distanceKm = 0;
  int activeKcal = 0;
  int maxHr = 0;
  double _hrWeighted = 0;
  int _hrSec = 0;
  int elevationM = 0;
  final List<int> efforts = [];

  int? get avgHr => _hrSec == 0 ? null : (_hrWeighted / _hrSec).round();
  double? get avgEffort => efforts.isEmpty ? null : efforts.reduce((a, b) => a + b) / efforts.length;
  bool get isEmpty => sessions == 0;

  void add(CardioStats c) {
    sessions++;
    final sec = c.durationSec ?? 0;
    durationSec += sec;
    distanceKm += c.distanceKm ?? 0;
    activeKcal += c.activeKcal ?? c.totalKcal ?? 0;
    if (c.maxHr != null) maxHr = max(maxHr, c.maxHr!);
    if (c.avgHr != null && sec > 0) {
      _hrWeighted += c.avgHr! * sec;
      _hrSec += sec;
    }
    elevationM += c.elevationM ?? 0;
    if (c.effort != null) efforts.add(c.effort!);
  }
}

class MuscleStats {
  MuscleStats({required this.days, required this.sessions, required this.scores, required this.watch});
  final int days;
  final int sessions;
  final Map<Muscle, MuscleScore> scores;
  final WatchSummary watch;

  double get weeks => max(1, days) / 7;
  double get maxScore => scores.values.fold(0, (a, s) => max(a, s.score));

  /// 점수 높은 순.
  List<MuscleScore> get ranked => scores.values.where((s) => s.score > 0).toList()..sort((a, b) => b.score.compareTo(a.score));

  /// 0~1 열지도(최대 점수 대비).
  Map<Muscle, double> get heat {
    final m = maxScore;
    if (m == 0) return const {};
    return {for (final s in scores.values) if (s.score > 0) s.muscle: (s.score / m).clamp(0.0, 1.0)};
  }

  /// 주당 유효 세트.
  double weekly(Muscle m) => (scores[m]?.score ?? 0) / weeks;

  /// 근육별 상태: 주당 유효 세트 기준(근비대 가이드 10~20세트/주를 근육 하나 기준으로 완화).
  MuscleStatus statusOf(Muscle m) {
    if (sessions < 2) return MuscleStatus.unknown;
    final w = weekly(m);
    if (w <= 0.5) return MuscleStatus.none;
    if (w < 4) return MuscleStatus.low;
    if (w <= 14) return MuscleStatus.good;
    return MuscleStatus.high;
  }

  /// 부위(MuscleGroup)별 합계 점수.
  Map<MuscleGroup, double> get byGroup {
    final out = <MuscleGroup, double>{};
    for (final s in scores.values) {
      out[s.muscle.group] = (out[s.muscle.group] ?? 0) + s.score;
    }
    return out;
  }

  /// [from]~[to] 완료 세션으로 집계.
  static MuscleStats compute(List<DayPlan> plans, {required DateTime from, required DateTime to}) {
    final done = plans.where((p) => p.isFinished && !p.isRest && !p.date.isBefore(from) && !p.date.isAfter(to)).toList();
    final scores = {for (final m in Muscle.values) m: MuscleScore(m)};
    final watch = WatchSummary();

    void add(Muscle m, double sets, double ton, String sessionId, String exerciseName, {bool cardio = false, bool primary = false}) {
      final s = scores[m]!;
      s.score += sets;
      if (cardio) {
        s.cardioSets += sets;
      } else if (primary) {
        s.primarySets += sets;
      } else {
        s.secondarySets += sets;
      }
      s.tonnage += ton;
      s.sessionIds.add(sessionId);
      s.byExercise[exerciseName] = (s.byExercise[exerciseName] ?? 0) + sets;
    }

    for (final p in done) {
      for (final pe in p.exercises) {
        if (pe.warmup) continue;
        final ex = exerciseById(pe.exerciseId);
        if (ex == null) continue;
        final doneSets = pe.sets.where((s) => s.completed).toList();
        if (doneSets.isEmpty) continue;
        final map = musclesFor(ex);

        if (ex.loadType == LoadType.cardio) {
          final c = pe.cardio;
          final mins = c?.durationSec != null ? c!.durationSec! / 60 : doneSets.fold<double>(0, (a, s) => a + s.effectiveReps);
          if (c != null && !c.isEmpty) watch.add(c);
          // 강도 보정: 평균 심박(또는 워치 강도)으로 0.6~1.4배. 없으면 1.0.
          var k = 1.0;
          if (c?.avgHr != null) {
            k = (c!.avgHr! / 140).clamp(0.6, 1.4);
          } else if (c?.effort != null) {
            k = (0.5 + c!.effort! / 10).clamp(0.6, 1.4);
          }
          // 유산소 20분 ≈ 주동근 1세트, 보조근은 그 0.4.
          final eq = mins / 20 * k;
          for (final m in map.primary) {
            add(m, eq * primaryWeight, 0, p.id, ex.name, cardio: true);
          }
          for (final m in map.secondary) {
            add(m, eq * secondaryWeight, 0, p.id, ex.name, cardio: true);
          }
          continue;
        }

        final n = doneSets.length.toDouble();
        final ton = doneSets.fold<double>(0, (a, s) => a + s.effectiveWeight * s.effectiveReps);
        // 한쪽씩(원레그·원암)은 좌우 각각이라 세트 가치는 같다.
        for (final m in map.primary) {
          add(m, n * primaryWeight, ton * primaryWeight / max(1, map.primary.length), p.id, ex.name, primary: true);
        }
        for (final m in map.secondary) {
          add(m, n * secondaryWeight, ton * secondaryWeight / max(1, map.secondary.length), p.id, ex.name);
        }
      }
    }

    return MuscleStats(
      days: to.difference(from).inDays + 1,
      sessions: done.length,
      scores: scores,
      watch: watch,
    );
  }
}

enum MuscleStatus {
  unknown('판단 보류'),
  none('안 함'),
  low('부족'),
  good('적정'),
  high('많음');

  const MuscleStatus(this.label);
  final String label;
}
