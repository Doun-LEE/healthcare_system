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

/// 근육별 회복 상태: 마지막으로 자극한 시각과 부위 권장 회복 시간으로 0~100%.
class MuscleRecovery {
  MuscleRecovery(this.muscle, {this.lastAt, this.lastPrimary = false, required this.percent, this.lastExercise});
  final Muscle muscle;
  final DateTime? lastAt;
  final bool lastPrimary;

  /// 0 = 방금 자극(피로), 100 = 완전 회복.
  final int percent;
  final String? lastExercise;

  /// '최근 운동 없음' · '17시간 전 운동 완료' · '3일 전 운동 완료'.
  String get lastLabel {
    final at = lastAt;
    if (at == null) return '최근 운동 없음';
    final d = DateTime.now().difference(at);
    if (d.inHours < 1) return '방금 운동 완료';
    if (d.inHours < 48) return '${d.inHours}시간 전 운동 완료${lastPrimary ? '' : ' (보조)'}';
    return '${d.inDays}일 전 운동 완료${lastPrimary ? '' : ' (보조)'}';
  }

  /// 최근 [days]일의 완료 세션으로 계산. 보조근은 회복에 절반만 필요하다고 본다.
  static List<MuscleRecovery> compute(List<DayPlan> plans, {DateTime? now, int days = 30}) {
    final t = now ?? DateTime.now();
    final since = t.subtract(Duration(days: days));
    final lastP = <Muscle, DateTime>{}, lastS = <Muscle, DateTime>{};
    final lastEx = <Muscle, String>{};
    for (final p in plans) {
      if (!p.isFinished || p.isRest || p.date.isBefore(since)) continue;
      final at = p.endedAt ?? p.finishedAt ?? p.date;
      for (final pe in p.exercises) {
        if (pe.warmup || !pe.sets.any((s) => s.completed)) continue;
        final ex = exerciseById(pe.exerciseId);
        if (ex == null) continue;
        final map = musclesFor(ex);
        for (final m in map.primary) {
          if (lastP[m] == null || at.isAfter(lastP[m]!)) {
            lastP[m] = at;
            lastEx[m] = ex.name;
          }
        }
        for (final m in map.secondary) {
          if (lastS[m] == null || at.isAfter(lastS[m]!)) lastS[m] = at;
        }
      }
    }
    final out = <MuscleRecovery>[];
    for (final m in Muscle.values) {
      final need = restRules[m.group]!.recoveryHours.toDouble();
      double ratio = 2;
      DateTime? last;
      var primary = false;
      final lp = lastP[m], ls = lastS[m];
      if (lp != null) {
        ratio = min(ratio, t.difference(lp).inMinutes / 60 / need);
        last = lp;
        primary = true;
      }
      if (ls != null) {
        final r = t.difference(ls).inMinutes / 60 / (need * 0.5);
        if (r < ratio) {
          ratio = r;
          if (lp == null || ls.isAfter(lp)) {
            last = ls;
            primary = false;
          }
        }
      }
      out.add(MuscleRecovery(
        m,
        lastAt: last,
        lastPrimary: primary,
        percent: (ratio * 100).clamp(0, 100).round(),
        lastExercise: lastEx[m],
      ));
    }
    // 피로한 근육(회복 낮음)부터, 같으면 부위 순.
    out.sort((a, b) => a.percent != b.percent ? a.percent.compareTo(b.percent) : a.muscle.index.compareTo(b.muscle.index));
    return out;
  }
}
