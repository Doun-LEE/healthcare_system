import 'package:fit_routine/core/store.dart';
import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/services/partner.dart';
import 'package:fit_routine/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('친구 헬스장에 기구 데이터가 없으면(옛 버전) 교체해도 내 기구를 지우지 않고 종류로 채운다', () async {
    final store = MemoryStore();
    final mine = Gym(id: 'g1', name: '부티크짐', equipment: [
      GymEquipment(id: 'a', type: EquipmentType.legPress, customName: '렉스코 레그 프레스'),
      GymEquipment(id: 'b', type: EquipmentType.dumbbell),
    ]);
    await store.save(AppData(currentUserId: 'u', profiles: [UserProfile(id: 'u', name: '도운', onboarded: true)], gyms: [mine]));
    final s = AppState(store);
    await s.load();

    final friend = PartnerLink(uid: 'f', name: '용현');
    final empty = PartnerGym(id: 'fg', name: '부티크짐', types: {EquipmentType.bodyweight, EquipmentType.multiStation, EquipmentType.cableMachine, EquipmentType.smithMachine});
    final g = await s.importPartnerGym(friend, empty, mode: 'replace', targetGymId: 'g1');
    final names = g.equipment.map((e) => e.displayName).toList();
    expect(names, contains('렉스코 레그 프레스'), reason: '내 기구가 남아 있어야 한다');
    expect(g.equipment.any((e) => e.type == EquipmentType.smithMachine), isTrue, reason: '친구 종류는 합쳐진다');
    expect(g.equipment.any((e) => e.type == EquipmentType.cableMachine), isFalse, reason: '멀티스테이션에 딸린 기능은 따로 만들지 않는다');
  });

  test('새로 가져올 때 기구 데이터가 없으면 종류 목록으로 만든다', () async {
    final s = AppState(MemoryStore());
    await s.load();
    final g = await s.importPartnerGym(PartnerLink(uid: 'f', name: '용현'),
        PartnerGym(id: 'fg', name: '친구짐', types: {EquipmentType.bodyweight, EquipmentType.legPress, EquipmentType.dumbbell}));
    expect(g.equipment.map((e) => e.type).toSet(), {EquipmentType.legPress, EquipmentType.dumbbell});
  });

  test("'한 대 더'는 같은 종류를 이름을 붙여 하나 더 넣고, 다시 열어도 중복 정리에서 지워지지 않는다", () async {
    final store = MemoryStore();
    await store.save(AppData(currentUserId: 'u', profiles: [UserProfile(id: 'u', name: '도운', onboarded: true)], gyms: [
      Gym(id: 'g1', name: '짐', equipment: [GymEquipment(id: 'a', type: EquipmentType.shoulderPressPlateLoaded)]),
    ]));
    final s = AppState(store);
    await s.load();
    await s.addEquipment('g1', EquipmentType.shoulderPressPlateLoaded, another: true);
    final names = s.gyms.single.equipment.map((e) => e.displayName).toList();
    expect(names.length, 2);
    expect(names.toSet().length, 2, reason: '이름이 겹치지 않게 붙는다: $names');
    final again = AppState(store);
    await again.load();
    expect(again.gyms.single.equipment.length, 2);
  });
}
