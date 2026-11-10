import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/engine/load_estimator.dart';
import 'package:fit_routine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('빈 바조차 무거운 바벨 운동: 가벼운 여성 초보는 클로즈그립 벤치 제외, 보통 남성은 벤치 포함', () {
    final woman = LoadEstimator(UserProfile(id: 'w', name: 'w', sex: Sex.female, heightCm: 160, weightKg: 50));
    final man = LoadEstimator(UserProfile(id: 'm', name: 'm'));
    final heavyW = [for (final e in exerciseCatalog) if (woman.barTooHeavy(e)) e.id];
    final heavyM = [for (final e in exerciseCatalog) if (man.barTooHeavy(e)) e.id];
    // ignore: avoid_print
    print('woman: $heavyW\nman: $heavyM');
    expect(heavyW, contains('cgbp'));
    expect(heavyW, isNot(contains('bb_squat')));
    expect(heavyM, isNot(contains('bb_bench')));
    expect(heavyM.length, lessThan(heavyW.length));
    // EZ바 운동은 빈 바가 가벼워서 해당 없음
    expect(heavyW, isNot(contains('ez_curl')));
  });
}
