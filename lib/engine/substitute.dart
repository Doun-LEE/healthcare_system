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
    if (c.id == ex.id || exclude.contains(c.id) || !c.canDoWith(available)) continue;
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
