/// 완료한 세션들에서 부위별 밸런스·주간 빈도·운동별 무게 추이를 계산한다.
library;

import 'dart:math';

import '../data/catalog.dart';
import '../models/models.dart';

class GroupVolume {
  GroupVolume(this.group, this.sets, this.tonnage, this.sessions);
  final MuscleGroup group;
  final int sets;

  /// kg × 횟수 합. 맨몸은 0. 유산소는 분(min) 합으로 대신 넣는다.
  final double tonnage;
  final int sessions;
}

class LiftPoint {
  LiftPoint(this.date, this.weight);
  final DateTime date;
  final double weight;
}

class LiftTrend {
  LiftTrend(this.exercise, this.points);
  final Exercise exercise;
  final List<LiftPoint> points;
  double get first => points.first.weight;
  double get last => points.last.weight;
  double get delta => last - first;
}

class WeekCount {
  WeekCount(this.weekStart, this.sessions, this.sets);
  final DateTime weekStart;
  final int sessions;
  final int sets;
}

class StatsSummary {
  StatsSummary({
    required this.days,
    required this.sessions,
    required this.totalSets,
    required this.totalTonnage,
    required this.avgRpe,
    required this.groups,
    required this.weeks,
    required this.trends,
    required this.cardioMinutes,
  });

  final int days;
  final int sessions;
  final int totalSets;
  final double totalTonnage;
  final double? avgRpe;
  final List<GroupVolume> groups;
  final List<WeekCount> weeks;
  final List<LiftTrend> trends;
  final int cardioMinutes;

  /// 근력 부위별 세트 비율(%). 합이 100.
  Map<MuscleGroup, double> get sharePct {
    final strength = groups.where((g) => g.group != MuscleGroup.cardio).toList();
    final total = strength.fold<int>(0, (a, g) => a + g.sets);
    if (total == 0) return {for (final g in strength) g.group: 0};
    return {for (final g in strength) g.group: g.sets * 100 / total};
  }

  /// 근력 부위(유산소 제외) 평균 세트 대비 60% 미만이면 "부족".
  /// 세션이 3회 미만이면 아직 판단하지 않는다(한두 번으로 치우침을 말하긴 이르다).
  Set<MuscleGroup> get underTrained {
    if (sessions < 3) return {};
    final strength = groups.where((g) => g.group != MuscleGroup.cardio).toList();
    if (strength.isEmpty) return {};
    final avg = strength.fold<int>(0, (a, g) => a + g.sets) / strength.length;
    if (avg == 0) return {};
    return {for (final g in strength) if (g.sets < avg * 0.6) g.group};
  }

  MuscleGroup? get mostTrained {
    final strength = groups.where((g) => g.group != MuscleGroup.cardio && g.sets > 0).toList();
    if (strength.isEmpty) return null;
    strength.sort((a, b) => b.sets.compareTo(a.sets));
    return strength.first.group;
  }
}

class Stats {
  /// 달력 기준 기간: 이번 주(월~), 이번 달, 올해.
  static (DateTime, DateTime) rangeFor(String period, DateTime now) {
    final today = dateOnly(now);
    switch (period) {
      case 'week':
        return (today.subtract(Duration(days: today.weekday % 7)), today); // 일요일 시작
      case 'month':
        return (DateTime(today.year, today.month, 1), today);
      case 'year':
        return (DateTime(today.year, 1, 1), today);
      default:
        return (today.subtract(const Duration(days: 27)), today);
    }
  }

  /// [from]~[to] 또는 [days] 동안 완료된 계획으로 요약을 만든다.
  static StatsSummary summarize(List<DayPlan> plans, {int days = 28, DateTime? now, DateTime? from, DateTime? to}) {
    final today = to ?? dateOnly(now ?? DateTime.now());
    final start = from ?? today.subtract(Duration(days: days - 1));
    days = today.difference(start).inDays + 1;
    final done = plans
        .where((p) => p.isFinished && !p.isRest && !p.date.isBefore(start) && !p.date.isAfter(today))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final sets = <MuscleGroup, int>{};
    final ton = <MuscleGroup, double>{};
    final sess = <MuscleGroup, Set<String>>{};
    var totalSets = 0;
    var totalTon = 0.0;
    var cardioMin = 0;
    final rpes = <int>[];
    final perExercise = <String, List<LiftPoint>>{};

    for (final p in done) {
      if (p.rpe != null) rpes.add(p.rpe!);
      for (final pe in p.exercises) {
        if (pe.warmup) continue;
        final ex = exerciseById(pe.exerciseId);
        if (ex == null) continue;
        final doneSets = pe.sets.where((s) => s.completed).toList();
        if (doneSets.isEmpty) continue;
        final g = pe.effectiveGroup;
        sess.putIfAbsent(g, () => {}).add(p.id);
        if (ex.loadType == LoadType.cardio) {
          final mins = doneSets.fold<int>(0, (a, s) => a + s.effectiveReps);
          cardioMin += mins;
          ton[g] = (ton[g] ?? 0) + mins;
          sets[g] = (sets[g] ?? 0) + doneSets.length;
          continue;
        }
        sets[g] = (sets[g] ?? 0) + doneSets.length;
        totalSets += doneSets.length;
        final t = doneSets.fold<double>(0, (a, s) => a + s.effectiveWeight * s.effectiveReps);
        ton[g] = (ton[g] ?? 0) + t;
        totalTon += t;
        if (ex.loadType != LoadType.bodyweight) {
          final best = doneSets.map((s) => s.effectiveWeight).fold<double>(0, max);
          if (best > 0) perExercise.putIfAbsent(ex.id, () => []).add(LiftPoint(p.date, best));
        }
      }
    }

    // 주간 집계 (월요일 시작)
    final weeks = <WeekCount>[];
    var ws = start.subtract(Duration(days: start.weekday % 7)); // 일요일 시작
    while (!ws.isAfter(today)) {
      final we = ws.add(const Duration(days: 7));
      final inWeek = done.where((p) => !p.date.isBefore(ws) && p.date.isBefore(we)).toList();
      final s = inWeek.fold<int>(0, (a, p) => a + p.exercises.fold<int>(0, (b, e) => b + e.sets.where((x) => x.completed).length));
      weeks.add(WeekCount(ws, inWeek.length, s));
      ws = we;
    }

    // 무게 추이: 2회 이상 기록된 운동 중 상위 4개(핵심 복합운동 우선)
    final trends = perExercise.entries
        .where((e) => e.value.length >= 2)
        .map((e) => LiftTrend(exerciseById(e.key)!, e.value))
        .toList()
      ..sort((a, b) {
        final pa = (a.exercise.compound ? 10 : 0) + a.exercise.priority + a.points.length;
        final pb = (b.exercise.compound ? 10 : 0) + b.exercise.priority + b.points.length;
        return pb.compareTo(pa);
      });

    return StatsSummary(
      days: days,
      sessions: done.length,
      totalSets: totalSets,
      totalTonnage: totalTon,
      avgRpe: rpes.isEmpty ? null : rpes.reduce((a, b) => a + b) / rpes.length,
      groups: [
        for (final g in MuscleGroup.values) GroupVolume(g, sets[g] ?? 0, ton[g] ?? 0, sess[g]?.length ?? 0),
      ],
      weeks: weeks,
      trends: trends.take(4).toList(),
      cardioMinutes: cardioMin,
    );
  }
}
