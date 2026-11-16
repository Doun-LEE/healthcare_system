/// 운동 성향 지도: 가로 = 운동 종류(유산소 0 ↔ 웨이트 100), 세로 = 강도(가볍게 0 ↔ 고강도 100).
///
/// 처음엔 프로필(목표·숙련도·레벨 판정·성별/체중 기준)로 점을 찍고,
/// 완료한 운동이 쌓일수록(최근 4주, 8회면 100%) 실제 기록 쪽으로 옮겨 간다.
library;

import 'dart:math';

import '../data/catalog.dart';
import '../models/models.dart';
import 'level_assessor.dart';

/// 3×3 구역.
enum StyleZone {
  intervalWarrior('인터벌 전사', '유산소를 숨차게, 짧고 굵게'),
  hybrid('하이브리드', '웨이트도 유산소도 세게'),
  heavyLifter('헤비 리프터', '무겁게, 적은 횟수로 고중량'),
  runner('러너', '유산소가 중심, 꾸준한 페이스'),
  allRounder('올라운더', '웨이트·유산소를 고르게'),
  bodybuilder('보디빌더', '웨이트 중심, 근비대 볼륨'),
  healingWalker('힐링 워커', '가벼운 유산소로 건강 관리'),
  conditioning('컨디션 관리', '가볍게 섞어서 몸 관리'),
  pumpMaker('펌핑 메이커', '머신·고반복으로 가볍게 펌핑');

  const StyleZone(this.label, this.description);
  final String label;
  final String description;
}

class TrainingStyle {
  const TrainingStyle(this.x, this.y, {this.dataWeight = 0, this.sessions = 0});

  /// 0 = 유산소, 100 = 웨이트.
  final double x;

  /// 0 = 가볍게, 100 = 고강도.
  final double y;

  /// 기록이 반영된 비율(0~1). 0이면 프로필로만 추정.
  final double dataWeight;

  /// 반영된 최근 4주 완료 운동 수.
  final int sessions;

  static int _band(double v) => v < 35 ? 0 : v <= 65 ? 1 : 2;

  StyleZone get zone {
    final c = _band(x);
    final r = _band(y);
    const grid = [
      [StyleZone.healingWalker, StyleZone.conditioning, StyleZone.pumpMaker],
      [StyleZone.runner, StyleZone.allRounder, StyleZone.bodybuilder],
      [StyleZone.intervalWarrior, StyleZone.hybrid, StyleZone.heavyLifter],
    ];
    return grid[r][c];
  }

  String get name => zone.label;

  Map<String, dynamic> toJson() => {'x': x.round(), 'y': y.round(), 'n': sessions};

  static TrainingStyle? fromJson(Object? j) {
    if (j is! Map) return null;
    final x = (j['x'] as num?)?.toDouble();
    final y = (j['y'] as num?)?.toDouble();
    if (x == null || y == null) return null;
    final n = (j['n'] as num?)?.toInt() ?? 0;
    return TrainingStyle(x.clamp(0, 100).toDouble(), y.clamp(0, 100).toDouble(), sessions: n, dataWeight: min(1.0, n / 8));
  }

  /// 여러 사람이 함께 할 때의 성향(평균).
  static TrainingStyle combine(List<TrainingStyle> all) {
    if (all.isEmpty) return const TrainingStyle(50, 50);
    final x = all.fold(0.0, (a, s) => a + s.x) / all.length;
    final y = all.fold(0.0, (a, s) => a + s.y) / all.length;
    return TrainingStyle(x, y, dataWeight: all.map((s) => s.dataWeight).reduce(min));
  }

  /// 두 사람 이상 성향이 얼마나 다른지 한 줄로.
  static String chemistry(List<TrainingStyle> all) {
    var d = 0.0;
    for (var i = 0; i < all.length; i++) {
      for (var j = i + 1; j < all.length; j++) {
        final dx = all[i].x - all[j].x, dy = all[i].y - all[j].y;
        d = max(d, sqrt(dx * dx + dy * dy));
      }
    }
    if (d >= 35) return '성향 차이 큼 · 본세트는 같이, 강도는 각자 맞춰요';
    if (d >= 18) return '조금 달라요 · 무게만 각자 조절하면 충분해요';
    return '찰떡 궁합 · 같은 강도로 같이 해도 좋아요';
  }

  /// 프로필만으로 잡은 시작점.
  static TrainingStyle prior(UserProfile p) {
    var x = switch (p.goal) {
      TrainingGoal.fatLoss => 40.0,
      TrainingGoal.hypertrophy => 75.0,
      TrainingGoal.strength => 85.0,
    };
    if (!p.includeCardio) x += 8;
    final a = LevelAssessor.assess(p);
    var y = a.score ??
        switch (p.level) {
          TrainingLevel.beginner => 30.0,
          TrainingLevel.intermediate => 50.0,
          TrainingLevel.advanced => 70.0,
        };
    y += switch (p.goal) {
      TrainingGoal.strength => 12.0,
      TrainingGoal.fatLoss => -10.0,
      TrainingGoal.hypertrophy => 0.0,
    };
    return TrainingStyle(x.clamp(0, 100).toDouble(), y.clamp(0, 100).toDouble());
  }

  /// 프로필 + 최근 4주([now] 기준) 완료 기록.
  static TrainingStyle of(UserProfile p, List<DayPlan> plans, {DateTime? now}) {
    final base = prior(p);
    final t = now ?? DateTime.now();
    final recent = plans.where((d) {
      if (!d.isFinished || d.isOff) return false;
      final days = t.difference(d.date).inDays;
      return days >= 0 && days <= 28;
    }).toList();
    final data = _fromPlans(recent, base.y, p);
    if (data == null) return base;
    final w = min(1.0, recent.length / 8);
    return TrainingStyle(
      base.x * (1 - w) + data.$1 * w,
      base.y * (1 - w) + data.$2 * w,
      dataWeight: w,
      sessions: recent.length,
    );
  }

  /// 기록만으로 (x, y). 완료 세트가 하나도 없으면 null.
  static (double, double)? _fromPlans(List<DayPlan> plans, double levelY, UserProfile p) {
    var cardioMin = 0.0, weightSets = 0, repSum = 0, freeCompound = 0;
    var rpeSum = 0, rpeN = 0;
    for (final d in plans) {
      if (d.rpe != null) {
        rpeSum += d.rpe!;
        rpeN++;
      }
      for (final e in d.exercises) {
        if (e.warmup || e.skipMine) continue;
        final ex = exerciseById(e.exerciseId);
        if (ex == null) continue;
        for (final s in e.sets) {
          if (!s.completed) continue;
          if (ex.loadType == LoadType.cardio) {
            cardioMin += s.effectiveReps;
          } else {
            weightSets++;
            repSum += s.effectiveReps;
            if (ex.compound && (ex.loadType == LoadType.barbell || ex.loadType == LoadType.dumbbell)) freeCompound++;
          }
        }
      }
    }
    if (weightSets == 0 && cardioMin == 0) return null;
    // 웨이트 한 세트 ≈ 세트+휴식 2.5분으로 시간 비중을 잡는다.
    final weightMin = weightSets * 2.5;
    final x = weightMin / (weightMin + cardioMin) * 100;
    double clamp01(double v) => v.clamp(0.0, 1.0).toDouble();
    final avgReps = weightSets == 0 ? 15.0 : repSum / weightSets;
    final repScore = clamp01((15 - avgReps) / 10) * 100; // 5회 이하 100, 15회 이상 0
    final rpeScore = rpeN == 0 ? repScore : clamp01((rpeSum / rpeN - 3) / 6) * 100; // 체감 3 → 0, 9 → 100
    final freeScore = weightSets == 0 ? 0.0 : clamp01(freeCompound / weightSets / 0.5) * 100; // 프리웨이트 복합 절반이면 만점
    var y = 0.3 * repScore + 0.3 * rpeScore + 0.15 * freeScore + 0.25 * levelY;
    // 유산소 위주면 웨이트 강도 요소보다 체감 강도를 더 믿는다.
    if (x < 35) y = 0.6 * rpeScore + 0.4 * levelY;
    return (x.clamp(0, 100).toDouble(), y.clamp(0, 100).toDouble());
  }
}
