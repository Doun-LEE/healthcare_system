/// 운동 성향 3축: 웨이트 양(0~100) · 유산소 양(0~100) · 강도(가볍게 0 ↔ 고강도 100).
///
/// 웨이트와 유산소는 서로 반대가 아니라 따로 센다(둘 다 많이 하면 하이브리드).
/// 처음엔 프로필(목표·유산소 포함 여부·레벨 판정)로 점을 찍고,
/// 완료한 운동이 쌓일수록(최근 4주, 8회면 100%) 실제 기록 쪽으로 옮겨 간다.
library;

import 'dart:math';

import '../data/catalog.dart';
import '../models/models.dart';
import 'level_assessor.dart';

/// 성향 이름. 웨이트·유산소 많고 적음(50 기준) × 강도로 나눈다.
enum StyleZone {
  heavyLifter('헤비 리프터', '무겁게, 적은 횟수로 고중량'),
  bodybuilder('보디빌더', '웨이트 중심, 근비대 볼륨'),
  pumpMaker('펌핑 메이커', '머신·고반복으로 가볍게 펌핑'),
  intervalWarrior('인터벌 전사', '유산소를 숨차게, 짧고 굵게'),
  runner('러너', '유산소가 중심, 꾸준한 페이스'),
  healingWalker('힐링 워커', '가벼운 유산소로 건강 관리'),
  hybrid('하이브리드', '웨이트도 유산소도 많이, 세게'),
  allRounder('올라운더', '웨이트·유산소를 고르게 많이'),
  express('익스프레스', '양은 적게, 짧고 세게'),
  conditioning('컨디션 관리', '가볍게 조금씩 몸 관리');

  const StyleZone(this.label, this.description);
  final String label;
  final String description;
}

class TrainingStyle {
  const TrainingStyle(this.weight, this.cardio, this.intensity, {this.dataWeight = 0, this.sessions = 0});

  /// 웨이트 양: 한 번에 본세트 20세트면 100.
  final double weight;

  /// 유산소 양: 한 번에 40분이면 100.
  final double cardio;

  /// 0 = 가볍게, 100 = 고강도.
  final double intensity;

  /// 기록이 반영된 비율(0~1). 0이면 프로필로만 추정.
  final double dataWeight;

  /// 반영된 최근 4주 완료 운동 수.
  final int sessions;

  StyleZone get zone {
    final w = weight >= 50, c = cardio >= 50, i = intensity;
    if (w && !c) return i >= 65 ? StyleZone.heavyLifter : i >= 40 ? StyleZone.bodybuilder : StyleZone.pumpMaker;
    if (!w && c) return i >= 65 ? StyleZone.intervalWarrior : i >= 40 ? StyleZone.runner : StyleZone.healingWalker;
    if (w && c) return i >= 55 ? StyleZone.hybrid : StyleZone.allRounder;
    return i >= 55 ? StyleZone.express : StyleZone.conditioning;
  }

  String get name => zone.label;

  Map<String, dynamic> toJson() => {'w': weight.round(), 'c': cardio.round(), 'i': intensity.round(), 'n': sessions};

  static double _c(num v) => v.toDouble().clamp(0, 100).toDouble();

  static TrainingStyle? fromJson(Object? j) {
    if (j is! Map) return null;
    final n = (j['n'] as num?)?.toInt() ?? 0;
    final dw = min(1.0, n / 8);
    final w = j['w'] as num?, c = j['c'] as num?, i = j['i'] as num?;
    if (w != null && c != null && i != null) return TrainingStyle(_c(w), _c(c), _c(i), sessions: n, dataWeight: dw);
    // 옛 버전(가로 한 축: 유산소 0 ↔ 웨이트 100, 세로 강도).
    final x = j['x'] as num?, y = j['y'] as num?;
    if (x == null || y == null) return null;
    return TrainingStyle(_c(x), _c(100 - x), _c(y), sessions: n, dataWeight: dw);
  }

  /// 여러 사람이 함께 할 때의 성향(평균).
  static TrainingStyle combine(List<TrainingStyle> all) {
    if (all.isEmpty) return const TrainingStyle(50, 30, 50);
    double avg(double Function(TrainingStyle) f) => all.fold(0.0, (a, s) => a + f(s)) / all.length;
    return TrainingStyle(avg((s) => s.weight), avg((s) => s.cardio), avg((s) => s.intensity),
        dataWeight: all.map((s) => s.dataWeight).reduce(min));
  }

  double distanceTo(TrainingStyle o) {
    final a = weight - o.weight, b = cardio - o.cardio, c = intensity - o.intensity;
    return sqrt(a * a + b * b + c * c);
  }

  /// 두 사람 이상 성향이 얼마나 다른지 한 줄로.
  static String chemistry(List<TrainingStyle> all) {
    var d = 0.0;
    for (var i = 0; i < all.length; i++) {
      for (var j = i + 1; j < all.length; j++) {
        d = max(d, all[i].distanceTo(all[j]));
      }
    }
    if (d >= 40) return '성향 차이 큼 · 본세트는 같이, 강도는 각자 맞춰요';
    if (d >= 20) return '조금 달라요 · 무게만 각자 조절하면 충분해요';
    return '찰떡 궁합 · 같은 강도로 같이 해도 좋아요';
  }

  /// 프로필만으로 잡은 시작점.
  static TrainingStyle prior(UserProfile p) {
    final w = switch (p.goal) {
      TrainingGoal.fatLoss => 50.0,
      TrainingGoal.hypertrophy => 75.0,
      TrainingGoal.strength => 75.0,
    };
    final c = !p.includeCardio
        ? 10.0
        : p.goal == TrainingGoal.fatLoss
            ? 70.0
            : 35.0;
    final a = LevelAssessor.assess(p);
    var i = a.score ??
        switch (p.level) {
          TrainingLevel.beginner => 30.0,
          TrainingLevel.intermediate => 50.0,
          TrainingLevel.advanced => 70.0,
        };
    i += switch (p.goal) {
      TrainingGoal.strength => 12.0,
      TrainingGoal.fatLoss => -10.0,
      TrainingGoal.hypertrophy => 0.0,
    };
    return TrainingStyle(_c(w), _c(c), _c(i));
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
    final data = _fromPlans(recent, base.intensity);
    if (data == null) return base;
    final k = min(1.0, recent.length / 8);
    double mix(double a, double b) => a * (1 - k) + b * k;
    return TrainingStyle(mix(base.weight, data.$1), mix(base.cardio, data.$2), mix(base.intensity, data.$3),
        dataWeight: k, sessions: recent.length);
  }

  /// 기록만으로 (웨이트, 유산소, 강도). 완료 세트가 하나도 없으면 null.
  static (double, double, double)? _fromPlans(List<DayPlan> plans, double levelI) {
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
    final n = plans.isEmpty ? 1 : plans.length;
    final w = weightSets / n / 20 * 100;
    final c = cardioMin / n / 40 * 100;
    double clamp01(double v) => v.clamp(0.0, 1.0).toDouble();
    final avgReps = weightSets == 0 ? 15.0 : repSum / weightSets;
    final repScore = clamp01((15 - avgReps) / 10) * 100; // 5회 이하 100, 15회 이상 0
    final rpeScore = rpeN == 0 ? repScore : clamp01((rpeSum / rpeN - 3) / 6) * 100; // 체감 3 → 0, 9 → 100
    final freeScore = weightSets == 0 ? 0.0 : clamp01(freeCompound / weightSets / 0.5) * 100; // 프리웨이트 복합 절반이면 만점
    var i = 0.3 * repScore + 0.3 * rpeScore + 0.15 * freeScore + 0.25 * levelI;
    // 유산소 위주면 웨이트 강도 요소보다 체감 강도를 더 믿는다.
    if (weightSets * 2.5 < cardioMin) i = 0.6 * rpeScore + 0.4 * levelI;
    return (_c(w), _c(c), _c(i));
  }
}
