/// 정체기 찾기 · 디로드 추천.
///
/// 운동별로 완료한 날마다 추정 1RM(Epley: 무게×(1+횟수/30), 1~12회 세트)을 내고,
/// 최근 12주 최고 기록 이후 3주 넘게·3번 넘게 해도 못 넘었으면 정체기로 본다.
/// 정체기인 주 운동이 2개 이상이거나, 최근 체감 강도가 계속 높거나, 쉬는 주 없이 오래 달렸으면 디로드를 권한다.
library;

import 'dart:math';

import '../data/catalog.dart';
import '../models/models.dart';

class Plateau {
  Plateau({required this.exerciseId, required this.best, required this.bestAt, required this.since, required this.last});
  final String exerciseId;

  /// 최고 추정 1RM과 그 날.
  final double best;
  final DateTime bestAt;

  /// 최고 기록 뒤로 한 횟수.
  final int since;

  /// 마지막으로 한 날의 추정 1RM.
  final double last;

  int weeksSince(DateTime now) => now.difference(bestAt).inDays ~/ 7;
}

class DeloadAdvice {
  DeloadAdvice(this.reasons);
  final List<String> reasons;
  bool get recommended => reasons.isNotEmpty;
}

const deloadDays = 7;
const deloadVolume = 0.6;
const deloadLoad = 0.9;

/// 한 운동의 그 날 추정 1RM(완료한 1~12회 세트 중 최고). 없으면 0.
double sessionE1rm(PlannedExercise pe) {
  var best = 0.0;
  for (final s in pe.sets) {
    if (!s.completed) continue;
    final r = s.effectiveReps, w = s.effectiveWeight;
    if (r < 1 || r > 12 || w <= 0) continue;
    best = max(best, r == 1 ? w : w * (1 + r / 30));
  }
  return best;
}

/// [plans]: 내 루틴들(완료한 것만 본다).
/// [resetAt]: 운동별로 '낮춰서 다시 쌓기'를 누른 날(그 뒤 기록만 본다).
List<Plateau> findPlateaus(Iterable<DayPlan> plans, DateTime now, {Map<String, DateTime> resetAt = const {}}) {
  final from = now.subtract(const Duration(days: 84));
  final byEx = <String, List<(DateTime, double)>>{};
  for (final p in plans) {
    if (!p.isFinished || p.date.isBefore(from) || p.date.isAfter(now)) continue;
    // 컨디션·술자리·디로드로 일부러 가볍게 한 날은 빼고 본다.
    if (p.loadFactor < 0.95 || p.alcLoad < 0.95) continue;
    for (final pe in p.exercises) {
      if (pe.warmup || pe.skipMine) continue;
      final ex = exerciseById(pe.exerciseId);
      if (ex == null || ex.loadType == LoadType.cardio || ex.loadType == LoadType.bodyweight) continue;
      final r = resetAt[pe.exerciseId];
      if (r != null && !p.date.isAfter(r)) continue;
      final e = sessionE1rm(pe);
      if (e <= 0) continue;
      (byEx[pe.exerciseId] ??= []).add((p.date, e));
    }
  }
  final out = <Plateau>[];
  byEx.forEach((id, list) {
    if (list.length < 5) return;
    list.sort((a, b) => a.$1.compareTo(b.$1));
    var bi = 0;
    for (var i = 1; i < list.length; i++) {
      // 1% 넘게 올라야 새 기록으로 친다(반올림·기구 차이 흔들림 무시).
      if (list[i].$2 > list[bi].$2 * 1.01) bi = i;
    }
    final since = list.length - 1 - bi;
    final days = now.difference(list[bi].$1).inDays;
    if (since >= 3 && days >= 21) {
      out.add(Plateau(exerciseId: id, best: list[bi].$2, bestAt: list[bi].$1, since: since, last: list.last.$2));
    }
  });
  out.sort((a, b) => a.bestAt.compareTo(b.bestAt));
  return out;
}

/// 디로드를 권할 이유들(없으면 권하지 않음). [lastDeloadEnd] 이후만 본다.
DeloadAdvice deloadAdvice(Iterable<DayPlan> plans, DateTime now, {DateTime? lastDeloadEnd, List<Plateau>? plateaus}) {
  final reasons = <String>[];
  final pl = plateaus ?? findPlateaus(plans, now);
  final main = pl.where((p) => exerciseById(p.exerciseId)?.compound ?? false).toList();
  if (main.length >= 2) {
    reasons.add('주 운동 ${main.length}개가 3주 넘게 기록이 안 올라요 (${main.take(3).map((p) => exerciseById(p.exerciseId)!.name).join(', ')})');
  }
  final done = plans.where((p) => p.isFinished && !p.date.isAfter(now)).toList()..sort((a, b) => b.date.compareTo(a.date));
  final recent = done.take(4).where((p) => p.rpe != null).toList();
  if (recent.length >= 3 && recent.fold<int>(0, (a, p) => a + p.rpe!) / recent.length >= 8.5) {
    reasons.add('최근 운동 체감 강도가 계속 높아요 (평균 ${(recent.fold<int>(0, (a, p) => a + p.rpe!) / recent.length).toStringAsFixed(1)}/10)');
  }
  // 쉬는 주 없이(주 2회 이상) 몇 주 연속 했는지.
  var weeks = 0;
  final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
  for (var w = 1; w <= 20; w++) {
    final s = monday.subtract(Duration(days: 7 * w));
    final e = s.add(const Duration(days: 7));
    if (lastDeloadEnd != null && !e.isAfter(lastDeloadEnd)) break;
    final n = done.where((p) => !p.date.isBefore(s) && p.date.isBefore(e)).length;
    if (n < 2) break;
    weeks++;
  }
  if (weeks >= 10 || (weeks >= 6 && pl.isNotEmpty)) {
    reasons.add('$weeks주째 쉬는 주 없이 달렸어요');
  }
  if (lastDeloadEnd != null && now.difference(lastDeloadEnd).inDays < 28) return DeloadAdvice(const []);
  return DeloadAdvice(reasons);
}
