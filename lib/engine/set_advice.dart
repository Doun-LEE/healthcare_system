import 'dart:math';

import '../data/catalog.dart';
import '../models/models.dart';
import 'load_estimator.dart';

/// 세트를 끝낸 직후, 다음 세트를 어떻게 할지 한 줄 추천.
/// [weight]·[reps]는 앱 내부 무게(화면 배율 적용 전) 기준으로 남은 세트에 적용할 값.
class SetAdvice {
  const SetAdvice(this.message, {required this.weight, required this.reps, this.up = true});
  final String message;
  final double weight;
  final int reps;

  /// 올리는 추천인지(색·아이콘용).
  final bool up;
}

/// 방금 끝낸 [done] 세트와 다음 세트 [next]를 보고 추천한다. 추천할 게 없으면 null.
/// [step]은 기구 무게 한 칸, [factor]는 화면 표시 배율(한쪽/양쪽 기준), [unit]은 '회'·'초'.
SetAdvice? adviseNextSet(Exercise ex, SetEntry done, SetEntry next,
    {required double step, double factor = 1, String unit = '회'}) {
  if (ex.loadType == LoadType.cardio) return null;
  final w = done.effectiveWeight;
  final r = done.effectiveReps;
  final diff = r - done.targetReps;
  final hi = ex.repRange[1];
  String kg(double v) {
    final x = v * factor;
    return '${x == x.roundToDouble() ? x.toInt() : x.toStringAsFixed(1)}kg';
  }

  final noWeight = ex.loadType == LoadType.bodyweight || w <= 0 || step <= 0;
  if (noWeight) {
    if (diff >= 3) {
      final n = next.effectiveReps + min<int>(diff - 1, 4);
      return SetAdvice('여유 있어요 → 다음 세트는 $n$unit로 늘려요', weight: next.effectiveWeight, reps: n);
    }
    if (diff <= -2) {
      return SetAdvice('힘들었어요 → 다음 세트는 $r$unit만 해도 충분해요', weight: next.effectiveWeight, reps: r < 1 ? 1 : r, up: false);
    }
    return null;
  }

  // 방금 세트로 1RM을 추정(Epley)하고, 다음 세트 목표 횟수에 맞는 무게를 거꾸로 계산한다.
  // 세트가 이어지면 피로가 쌓이니 3% 덜어 둔다. 기구 눈금에 맞춰 반올림.
  final e1rm = w * (1 + r / 30);
  double forReps(int reps) => e1rm / (1 + reps / 30) * 0.97;

  // 무게를 올려서 목표 횟수까지 해냈으면 그 무게 그대로.
  if (w > done.targetWeight && diff >= 0 && w > next.effectiveWeight) {
    final reps = next.targetReps >= done.targetReps ? next.effectiveReps : done.targetReps;
    return SetAdvice('올린 무게 성공! 다음 세트도 ${kg(w)} × $reps$unit로', weight: w, reps: reps);
  }
  if (diff >= 3) {
    // 3회 이상 남았으면 추정 1RM으로 다음 목표 횟수 무게를 잡는다(한 칸 이상, 10% 이하로).
    final want = min(forReps(next.targetReps), w * 1.1);
    final up = max(LoadEstimator.roundTo(w + step, step), (want / step).floor() * step);
    return SetAdvice('$diff회 더 했어요 → 다음 세트 ${kg(up)}로 올리고 ${next.targetReps}$unit',
        weight: up, reps: next.targetReps);
  }
  if (diff >= 1 && r < hi + 2) {
    return SetAdvice('여유 조금 → 무게는 ${kg(w)} 그대로, 횟수를 $r$unit로 늘려요', weight: w, reps: r);
  }
  if (diff <= -2) {
    // 모자랐으면 한 칸이 아니라, 방금 한 횟수로 추정한 힘에서 목표 횟수를 채울 무게로 내린다.
    final want = r <= 0 ? w * 0.85 : forReps(next.targetReps);
    final down = max(step, min(LoadEstimator.roundTo(w - step, step), (want / step).floor() * step));
    return SetAdvice('목표보다 ${-diff}회 모자랐어요 → 다음 세트 ${kg(down)}로 내리고 ${next.targetReps}$unit (또는 ${kg(w)} 그대로 $r$unit)',
        weight: down, reps: next.targetReps, up: false);
  }
  return null;
}
