import 'package:fit_routine/data/catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('한쪽 운동 ↔ 양쪽 운동 짝: 같은 부위, 한쪽만 unilateral', () {
    expect(bothSidesOf('single_arm_pulldown')?.id, 'lat_pulldown');
    expect(oneSideOf('lat_pulldown')?.id, 'single_arm_pulldown');
    expect(bothSidesOf('lat_pulldown'), isNull);
    for (final e in exerciseCatalog.where((e) => bothSidesOf(e.id) != null)) {
      final b = bothSidesOf(e.id)!;
      expect(e.unilateral, isTrue, reason: e.id);
      expect(b.unilateral, isFalse, reason: b.id);
      expect(b.group, e.group, reason: '${e.id} → ${b.id}');
      expect(oneSideOf(b.id)?.id, e.id);
    }
  });

  test('고블릿·바벨·맨몸은 한쪽씩 하기 메뉴가 없고, 덤벨·머신은 있다', () {
    for (final id in ['goblet_squat', 'bb_squat', 'kb_swing', 'db_pullover']) {
      expect(canDoOneSide(exerciseById(id)!), isFalse, reason: id);
    }
    for (final id in ['db_curl', 'leg_ext', 'lateral_raise']) {
      expect(canDoOneSide(exerciseById(id)!), isTrue, reason: id);
    }
  });
}
