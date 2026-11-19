import 'package:fit_routine/core/store.dart';
import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('미리 짠 루틴은 당일 헬스장을 묻고, 고르면 다시 묻지 않는다', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final store = MemoryStore();
    await store.save(AppData(
      currentUserId: 'u',
      profiles: [UserProfile(id: 'u', name: 'a', onboarded: true)],
      gyms: [
        Gym(id: 'g1', name: '집앞', equipment: [GymEquipment(id: 'a', type: EquipmentType.dumbbell)]),
        Gym(id: 'g2', name: '회사', equipment: [GymEquipment(id: 'b', type: EquipmentType.legPress)]),
      ],
    ));
    final s = AppState(store);
    await s.load();
    await s.generatePlans(from: today, to: today, restDays: {});
    final plan = s.planOn(today)!;
    if (plan.isRest) return; // 분할상 휴식일이면 물을 것 없음
    expect(s.needsGymPick(plan), isTrue);
    await s.pickDayGym(plan, 'g1');
    expect(s.needsGymPick(s.planOn(today)!), isFalse);

    // 저장했다 다시 읽어도 유지
    expect(DayPlan.fromJson(s.planOn(today)!.toJson()).gymConfirmed, isTrue);
  });
}
