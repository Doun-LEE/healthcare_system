/// 술자리 전후 운동 조절.
///
/// - 술 마시고 6시간 안: 알코올이 아직 남아 있음 → 쉬거나 아주 가볍게(세트 60% · 무게 70%).
/// - 술 마시고 6~12시간: 숙취·탈수로 힘·균형 저하 → 세트 75% · 무게 85%.
/// - 술 마시기 6시간 전 안: 운동 직후 술은 근회복(단백질 합성)을 떨어뜨림 → 짧게(세트 80%).
/// - 술 마시기 6~12시간 전: 조금 짧게(세트 90%).
/// '마시고'는 술자리가 끝난 뒤부터 센다(시작 + [drinkHours]).
library;

const int drinkHours = 3;

class AlcoholAdvice {
  const AlcoholAdvice({required this.label, required this.tip, required this.volume, required this.load, this.restAdvised = false});
  final String label;
  final String tip;

  /// 세트 수 배율.
  final double volume;

  /// 무게 배율.
  final double load;

  /// 쉬는 걸 권함.
  final bool restAdvised;
}

const _after6 = AlcoholAdvice(
  label: '술 마신 지 6시간 안',
  tip: '알코올이 아직 남아 있어요. 오늘은 쉬거나 가벼운 걷기·스트레칭만 권해요. 하더라도 무거운 무게·고강도는 피하고 물을 충분히.',
  volume: 0.6,
  load: 0.7,
  restAdvised: true,
);
const _after12 = AlcoholAdvice(
  label: '술 마신 지 12시간 안',
  tip: '숙취·탈수로 힘과 균형이 떨어져요. 세트·무게를 줄였어요. 최고 기록 도전은 다음에, 운동 전후로 물 500ml 이상.',
  volume: 0.75,
  load: 0.85,
);
const _before6 = AlcoholAdvice(
  label: '술자리 6시간 전',
  tip: '운동 직후 술은 근회복을 떨어뜨려요. 짧게 끝내고, 술 전에 단백질 식사와 물을 충분히.',
  volume: 0.8,
  load: 1.0,
);
const _before12 = AlcoholAdvice(
  label: '술자리 12시간 전',
  tip: '술 전에 회복할 시간이 조금 있어요. 평소보다 살짝 짧게, 운동 뒤 단백질 식사는 꼭.',
  volume: 0.9,
  load: 1.0,
);

/// [workoutAt]에 운동할 때 술자리 [drinks](시작 시각)를 고려한 조언. 상관없으면 null.
AlcoholAdvice? alcoholAdvice(DateTime workoutAt, Iterable<DateTime> drinks) {
  AlcoholAdvice? best;
  int rank(AlcoholAdvice a) => [_before12, _before6, _after12, _after6].indexOf(a);
  for (final d in drinks) {
    final end = d.add(const Duration(hours: drinkHours));
    AlcoholAdvice? a;
    if (!workoutAt.isBefore(d)) {
      // 술자리 중이거나 끝난 뒤
      final h = workoutAt.difference(end).inMinutes / 60;
      if (h < 6) {
        a = _after6;
      } else if (h < 12) {
        a = _after12;
      }
    } else {
      final h = d.difference(workoutAt).inMinutes / 60;
      if (h <= 6) {
        a = _before6;
      } else if (h <= 12) {
        a = _before12;
      }
    }
    if (a != null && (best == null || rank(a) > rank(best))) best = a;
  }
  return best;
}
