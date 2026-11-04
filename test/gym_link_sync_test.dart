import 'dart:convert';

import 'package:fit_routine/core/store.dart';
import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/services/partner.dart';
import 'package:fit_routine/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

PartnerGym _published(Gym g) {
  final j = PartnerProfile.build(uid: 'A', me: UserProfile(id: 'a', name: '용현'), available: g.availableTypes, progress: {}, plans: [], gyms: [g]);
  return PartnerProfile.fromJson(jsonDecode(jsonEncode(j)) as Map<String, dynamic>).gyms.single;
}

void main() {
  final t0 = DateTime.utc(2026, 11, 1);
  final t1 = DateTime.utc(2026, 11, 3);

  Gym friendGym() => Gym(id: 'fg', name: '부티크짐', equipment: [
        GymEquipment(id: 'e1', type: EquipmentType.legPress, customName: '렉스코 레그 프레스', stepKg: 5),
        GymEquipment(id: 'e2', type: EquipmentType.dumbbell, hasPhoto: true),
      ], equipEditedAt: t1);

  test('공개 프로필을 거쳐도 기구 서명이 같다(사진 유무 무시)', () {
    final g = friendGym();
    final pg = _published(g);
    expect(pg.editedAt, t1);
    expect(equipmentSignature(pg.equipment), g.equipSignature);
  });

  test('친구가 더 최근에 고쳤고 내용이 다를 때만 묻는다', () {
    final remote = _published(friendGym());
    final mine = Gym(id: 'mg', name: '부티크짐', sharedFrom: 'A', sharedGymId: 'fg', equipEditedAt: t0, equipment: [
      GymEquipment(id: 'e1', type: EquipmentType.legPress, customName: '렉스코 레그 프레스', stepKg: 5),
    ]);
    final u = AppState.gymUpdateFor(mine, 'A', '용현', remote, 'B');
    expect(u, isNotNull);
    expect(u!.summary, '추가 1');

    // 내가 더 최근에 고쳤으면 묻지 않는다(친구 쪽에서 묻게 된다).
    mine.equipEditedAt = t1.add(const Duration(hours: 1));
    expect(AppState.gymUpdateFor(mine, 'A', '용현', remote, 'B'), isNull);

    // 이번 수정을 거절했으면 같은 수정은 다시 묻지 않는다.
    mine.equipEditedAt = t0;
    mine.syncDeclined['A'] = t1;
    expect(AppState.gymUpdateFor(mine, 'A', '용현', remote, 'B'), isNull);

    // 연결 안 된 헬스장은 묻지 않는다.
    final other = Gym(id: 'x', name: '다른짐', equipment: []);
    expect(AppState.gymUpdateFor(other, 'A', '용현', remote, 'B'), isNull);
  });

  test('반대 방향: 친구가 내 헬스장을 가져가서 고쳤으면 원본 주인인 나에게 묻는다', () {
    final copy = Gym(id: 'bg', name: '부티크짐', sharedFrom: 'ME', sharedGymId: 'og', equipEditedAt: t1, equipment: [
      GymEquipment(id: 'e1', type: EquipmentType.legPress, stepKg: 10),
    ]);
    final remote = _published(copy);
    expect(remote.linkFrom, 'ME');
    expect(remote.linkGym, 'og');
    final origin = Gym(id: 'og', name: '부티크짐', equipEditedAt: t0, equipment: [GymEquipment(id: 'e1', type: EquipmentType.legPress, stepKg: 5)]);
    final u = AppState.gymUpdateFor(origin, 'B', '도운', remote, 'ME');
    expect(u, isNotNull);
    expect(u!.summary, '설정 변경 1');
  });

  test('내가 기구를 고치면 기구 수정 시각이 찍히고, 동기화하면 친구 것과 같아진다', () async {
    final store = MemoryStore();
    await store.save(AppData(currentUserId: 'u', profiles: [UserProfile(id: 'u', name: '도운', onboarded: true)], gyms: [
      Gym(id: 'mg', name: '부티크짐', sharedFrom: 'A', sharedGymId: 'fg', equipment: [GymEquipment(id: 'e1', type: EquipmentType.legPress)]),
    ]));
    final s = AppState(store);
    await s.load();
    final g = s.gyms.single;
    expect(g.equipEditedAt, isNull);
    await s.addEquipment('mg', EquipmentType.smithMachine);
    expect(g.equipEditedAt, isNotNull);

    final remote = _published(friendGym());
    final u = AppState.gymUpdateFor(g..equipEditedAt = t0, 'A', '용현', remote, 'B')!;
    await s.acceptGymUpdate(u);
    expect(g.equipSignature, equipmentSignature(remote.equipment));
    expect(g.equipEditedAt, t1);
    expect(AppState.gymUpdateFor(g, 'A', '용현', remote, 'B'), isNull, reason: '맞춘 뒤엔 다시 묻지 않는다');
  });
}
