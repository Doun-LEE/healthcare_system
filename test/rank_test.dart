import 'package:fit_routine/engine/rank.dart';
import 'package:fit_routine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('랭크 점수 → 등급·구간, 다음 등급까지', () {
    expect(Rank.fromPoints(0).label, '아이언 III');
    expect(Rank.fromPoints(14.9).label, '아이언 I');
    expect(Rank.fromPoints(46).label, '골드 III');
    expect(Rank.fromPoints(59).label, '골드 I');
    expect(Rank.fromPoints(88).label, '마스터');
    expect(Rank.fromPoints(99).tier, RankTier.grandmaster);
    expect(Rank.fromPoints(99).toNext, isNull);
    expect(Rank.fromPoints(46).short, 'G3');
    expect(Rank.fromPoints(46).toNext, closeTo(4, 0.01));
  });

  test('힘이 같으면 꾸준히 한 사람이 더 높다', () {
    final p = UserProfile(id: 'a', name: 'a', weightKg: 80, squat1rm: 140, bench1rm: 100, deadlift1rm: 180);
    final lazy = Rank.of(p, sessions4w: 0);
    final busy = Rank.of(p, sessions4w: 12);
    expect(busy.points, greaterThan(lazy.points));
    expect(busy.activity, 100);
    expect(lazy.estimated, isFalse);
    expect(Rank.of(UserProfile(id: 'b', name: 'b'), sessions4w: 4).estimated, isTrue);
  });
}
