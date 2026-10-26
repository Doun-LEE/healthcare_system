/// 다른 헬스장에 갔을 때 없는 기구의 운동을 가장 비슷한 운동으로 바꾼다.
library;

import '../data/catalog.dart';
import '../models/models.dart';

/// [ex]를 [available] 기구로 할 수 없을 때 같은 부위에서 가장 비슷한 운동.
/// 세부 타깃(emphasis)이 많이 겹치고, 복합/고립·부하 방식이 같을수록 우선.
Exercise? substituteFor(Exercise ex, Set<EquipmentType> available, {Set<String> exclude = const {}}) {
  if (ex.canDoWith(available)) return ex;
  Exercise? best;
  var bestScore = -1.0;
  for (final c in exercisesOf(ex.group)) {
    if (c.id == ex.id || c.activity || c.warmupOnly || exclude.contains(c.id) || !c.canDoWith(available)) continue;
    var s = 0.0;
    for (final m in c.emphasis) {
      if (ex.emphasis.contains(m)) s += 3;
      // '윗가슴' vs '윗가슴·전면 어깨'처럼 부분 일치도 조금 쳐준다.
      if (ex.emphasis.any((e) => e != m && (e.contains(m) || m.contains(e)))) s += 1;
    }
    if (c.compound == ex.compound) s += 2;
    if (c.loadType == ex.loadType) s += 1;
    if (c.refLift == ex.refLift) s += 1;
    s += c.priority * 0.2;
    if (s > bestScore) {
      bestScore = s;
      best = c;
    }
  }
  return best;
}

/// 교체 추천 한 개: 운동과 짧은 이유.
class SwapPick {
  const SwapPick(this.exercise, this.reasons);
  final Exercise exercise;
  final List<String> reasons;
}

/// 루틴 안에서 [index]번째 운동([day][index])을 바꿀 때 앞뒤 운동을 보고 고른 추천.
/// - 바꾸려는 운동과 역할(복합/고립·타깃)이 비슷할수록
/// - 같은 날 다른 운동이 이미 하는 타깃과 겹치지 않을수록(빠진 타깃을 채울수록)
/// - 앞뒤 운동과 같은 기구면 자리 이동이 적어 조금 더
/// - 전날·전전날 한 운동([recent])은 덜
List<SwapPick> recommendSwaps(
  List<PlannedExercise> day,
  int index,
  Set<EquipmentType> available, {
  Set<String> recent = const {},
  int take = 3,
}) {
  final cur = exerciseById(day[index].exerciseId);
  if (cur == null) return const [];
  final inDay = {for (final p in day) p.exerciseId};
  final others = [
    for (var i = 0; i < day.length; i++)
      if (i != index && !day[i].warmup) exerciseById(day[i].exerciseId),
  ].whereType<Exercise>().where((e) => e.group == cur.group).toList();
  final covered = {for (final e in others) ...e.emphasis};
  final sameGroupCompound = others.any((e) => e.compound);
  final neighbors = [
    if (index > 0) day[index - 1].equipmentType,
    if (index + 1 < day.length) day[index + 1].equipmentType,
  ];
  // 같은 부위 운동 중 몇 번째 자리인지(앞쪽이면 복합, 뒤쪽이면 고립이 자연스럽다).
  final groupSlots = [for (var i = 0; i < day.length; i++) if (exerciseById(day[i].exerciseId)?.group == cur.group) i];
  final slot = groupSlots.indexOf(index);
  final early = slot >= 0 && slot < (groupSlots.length / 2).ceil();

  final scored = <(double, SwapPick)>[];
  for (final c in exercisesOf(cur.group)) {
    if (c.id == cur.id || c.activity || c.warmupOnly || inDay.contains(c.id) || !c.canDoWith(available)) continue;
    var s = 0.0;
    final why = <String>[];
    final same = c.emphasis.where(cur.emphasis.contains).toList();
    s += same.length * 2;
    final fills = c.emphasis.where((m) => !covered.contains(m)).toList();
    final dup = c.emphasis.where(covered.contains).toList();
    s += fills.length * 2 - dup.length * 1.5;
    if (fills.isNotEmpty) why.add('오늘 빠진 ${fills.first} 채움');
    if (same.isNotEmpty && why.isEmpty) why.add('${same.first} 그대로');
    if (c.compound == cur.compound) s += 1.5;
    if (early && c.compound) {
      s += 1;
      if (!sameGroupCompound) why.add('앞쪽 자리라 복합 운동');
    }
    if (!early && !c.compound) {
      s += 1;
      if (sameGroupCompound) why.add('뒤쪽 자리라 고립 운동');
    }
    final eq = c.pickEquipment(available);
    if (neighbors.contains(eq)) {
      s += 1;
      why.add('앞뒤와 같은 기구');
    }
    if (recent.contains(c.id)) {
      s -= 3;
    }
    s += c.priority * 0.3;
    scored.add((s, SwapPick(c, why.take(2).toList())));
  }
  scored.sort((a, b) => b.$1.compareTo(a.$1));
  return [for (final x in scored.take(take)) x.$2];
}
