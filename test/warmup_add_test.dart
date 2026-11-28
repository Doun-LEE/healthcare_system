import 'package:fit_routine/core/store.dart';
import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('한눈에 보기: 워밍업 추가·빼기', () async {
    final store = MemoryStore();
    final eq = [for (final t in EquipmentType.values) GymEquipment(id: t.name, type: t)];
    await store.save(AppData(
      currentUserId: 'u',
      profiles: [UserProfile(id: 'u', name: 'a', onboarded: true, splitDays: 3)],
      gyms: [Gym(id: 'g1', name: 'A', equipment: eq)],
    ));
    final s = AppState(store);
    await s.load();
    await s.changeDayFocus(s.today, [MuscleGroup.chest], shiftFollowing: false);
    final p = s.planOn(s.today)!;
    final before = p.exercises.where((e) => e.warmup).length;
    final ex = await s.addWarmup(p);
    expect(ex, isNotNull);
    final ws = p.exercises.where((e) => e.warmup).toList();
    expect(ws.length, before + 1);
    // 워밍업은 본 운동보다 앞
    final lastWarm = p.exercises.lastIndexWhere((e) => e.warmup);
    final firstMain = p.exercises.indexWhere((e) => !e.warmup);
    expect(lastWarm, lessThan(firstMain < 0 ? 999 : p.exercises.length));
    expect(await s.removeWarmup(p), isTrue);
    expect(p.exercises.where((e) => e.warmup).length, before);
  });
}
