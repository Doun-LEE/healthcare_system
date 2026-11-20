import 'package:fit_routine/core/store.dart';
import 'package:fit_routine/engine/alcohol.dart';
import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('술자리 전후 시간대별 조언', () {
    final drink = DateTime(2026, 11, 20, 20); // 20시 시작 → 23시 끝
    expect(alcoholAdvice(DateTime(2026, 11, 20, 16), [drink])!.label, '술자리 6시간 전');
    expect(alcoholAdvice(DateTime(2026, 11, 20, 10), [drink])!.label, '술자리 12시간 전');
    expect(alcoholAdvice(DateTime(2026, 11, 20, 6), [drink]), isNull);
    expect(alcoholAdvice(DateTime(2026, 11, 21, 4), [drink])!.restAdvised, isTrue);
    expect(alcoholAdvice(DateTime(2026, 11, 21, 9), [drink])!.label, '술 마신 지 12시간 안');
    expect(alcoholAdvice(DateTime(2026, 11, 21, 12), [drink]), isNull);
  });

  test('술 약속을 넣으면 세트가 줄고, 지우면 되돌아온다', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final store = MemoryStore();
    final eq = [for (final t in EquipmentType.values) GymEquipment(id: t.name, type: t)];
    await store.save(AppData(
      currentUserId: 'u',
      profiles: [UserProfile(id: 'u', name: 'a', onboarded: true)],
      gyms: [Gym(id: 'g1', name: 'A', equipment: eq)],
    ));
    final s = AppState(store);
    await s.load();
    await s.changeDayFocus(today, [MuscleGroup.chest, MuscleGroup.back], shiftFollowing: false);
    int sets() => s.planOn(today)!.exercises.where((e) => !e.warmup).fold(0, (a, e) => a + e.sets.length);
    final before = sets();
    // 아침 8시 시작(11시 끝) → 오늘 19시 운동은 마시고 12시간 안
    await s.addDrink(today.add(const Duration(hours: 8)));
    expect(s.alcoholFor(s.planOn(today)!), isNotNull);
    expect(sets(), lessThan(before));
    await s.removeDrink(today.add(const Duration(hours: 8)));
    expect(s.planOn(today)!.alcVolume, 1.0);
    expect(sets(), before);
    expect(UserProfile.fromJson(UserProfile(id: 'x', name: 'b', drinks: [today]).toJson()).drinks, [today]);
  });
}
