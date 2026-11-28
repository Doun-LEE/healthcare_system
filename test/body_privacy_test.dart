import 'package:fit_routine/services/partner.dart';
import 'package:fit_routine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('신체 정보 숨김: 체중·키·나이·체성분은 안 올리고 레벨은 등급만', () {
    final me = UserProfile(id: 'u', name: 'a', weightKg: 87, heightCm: 178, age: 31, skeletalMuscleKg: 41, bodyFatPct: 19.6, squat1rm: 150, bench1rm: 120);
    final j = PartnerProfile.build(uid: 'u', me: me, available: const {}, progress: const {}, plans: const []);
    final pj = j['profile'] as Map;
    for (final k in ['weightKg', 'heightCm', 'age', 'skeletalMuscleKg', 'bodyFatPct']) {
      expect(pj.containsKey(k), isFalse, reason: k);
    }
    final pp = PartnerProfile.fromJson(j);
    final mine = PartnerProfile.fromJson(PartnerProfile.build(uid: 'u', me: me..showBodyInfo = true, available: const {}, progress: const {}, plans: const []));
    expect(pp.assessment.score, mine.assessment.score); // 같은 레벨
    expect(pp.rank.points, mine.rank.points);
    final text = pp.assessment.items.map((i) => i.detail).join(' ');
    expect(text.contains('체중'), isFalse);
    expect(text.contains('41'), isFalse);
  });
}
