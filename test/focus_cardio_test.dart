import 'package:fit_routine/core/store.dart';
import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('부위를 직접 고르며 유산소를 빼면 자동 유산소도 안 붙는다(헬스장 바꿔도)', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final store = MemoryStore();
    final eq = [for (final t in EquipmentType.values) GymEquipment(id: t.name, type: t)];
    await store.save(AppData(
      currentUserId: 'u',
      profiles: [UserProfile(id: 'u', name: 'a', onboarded: true, goal: TrainingGoal.fatLoss)],
      gyms: [Gym(id: 'g1', name: 'A', equipment: eq), Gym(id: 'g2', name: 'B', equipment: eq)],
    ));
    final s = AppState(store);
    await s.load();
    bool hasCardio() => s.planOn(today)!.exercises.any((e) => !e.warmup && exerciseById(e.exerciseId)?.loadType == LoadType.cardio);
    await s.changeDayFocus(today, [MuscleGroup.chest, MuscleGroup.back], shiftFollowing: false);
    expect(hasCardio(), isFalse);
    await s.pickDayGym(s.planOn(today)!, 'g2');
    expect(hasCardio(), isFalse);
    await s.changeDayFocus(today, [MuscleGroup.chest, MuscleGroup.cardio], shiftFollowing: false);
    expect(hasCardio(), isTrue);
  });
}
