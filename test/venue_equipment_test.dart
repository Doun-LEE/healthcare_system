import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/services/partner.dart';
import 'package:fit_routine/services/routine_share.dart';

void main() {
  final legPress = GymEquipment(id: 'e1', type: EquipmentType.legPress, customName: '렉스코 45° 레그 프레스', brand: 'lexco', stepKg: 5, maxWeightKg: 400, plateBasis: 'full', emptyKg: 40);
  final gym = Gym(id: 'g1', name: '보스턴 피트니스', equipment: [legPress, GymEquipment(id: 'e2', type: EquipmentType.dumbbell, hasPhoto: true)]);

  test('공개 프로필의 헬스장에 기구 데이터가 실리고(사진 유무 제외) 다시 읽힌다', () {
    final me = UserProfile(id: 'u', name: '도운');
    final j = PartnerProfile.build(uid: 'uidA', me: me, available: gym.availableTypes, progress: {}, plans: [], handle: '도운#1', gyms: [gym]);
    final back = PartnerProfile.fromJson(jsonDecode(jsonEncode(j)) as Map<String, dynamic>);
    final g = back.gyms.single;
    expect(g.name, '보스턴 피트니스');
    expect(g.equipment.length, 2);
    expect(g.equipment.first.customName, '렉스코 45° 레그 프레스');
    expect(g.equipment.first.emptyKg, 40);
    expect(g.equipment.first.plateBasis, 'full');
    expect(g.equipment.last.hasPhoto, isFalse, reason: '사진은 기기에만 있으니 공유하지 않는다');
    expect(g.types, contains(EquipmentType.legPress));
  });

  test('공유 루틴 코드의 장소(venue)에 기구 데이터가 실려 받는 쪽 계획의 venueEquipment 가 된다', () {
    final plan = DayPlan(id: 'p', userId: 'u', date: DateTime(2026, 10, 27), kind: DayKind.workout, focus: [MuscleGroup.legs], exercises: [
      PlannedExercise(exerciseId: 'leg_press', equipmentType: EquipmentType.legPress, restSeconds: 120, sets: [SetEntry(targetReps: 12, targetWeight: 240)]),
    ]);
    final venue = SharedVenue(owner: 'uidA', gymId: gym.id, name: gym.name, types: gym.availableTypes.toList(), equipment: gym.equipment);
    final code = encodeRoutine(plan, from: '도운', venue: venue);
    final shared = decodeRoutine(code)!;
    expect(shared.venue!.equipment.length, 2);
    expect(shared.venue!.equipment.first.customName, '렉스코 45° 레그 프레스');
    expect(shared.venue!.equipment.first.stepKg, 5);

    final received = DayPlan(id: 'p2', userId: 'uB', date: plan.date, kind: DayKind.workout, focus: plan.focus,
        venueOwner: 'uidA', venueGymId: gym.id, venueName: gym.name, venueTypes: shared.venue!.types, venueEquipment: shared.venue!.equipment);
    expect(received.atOtherGym, isTrue);
    final round = DayPlan.fromJson(jsonDecode(jsonEncode(received.toJson())) as Map<String, dynamic>);
    expect(round.venueEquipment.length, 2);
    expect(round.venueEquipment.first.type, EquipmentType.legPress);
    expect(round.venueEquipment.first.displayName, '렉스코 45° 레그 프레스');
  });

  test('헬스장 이름 키는 공백·괄호·대소문자를 무시한다', () {
    expect(Gym.nameKey('보스턴 피트니스'), Gym.nameKey('보스턴피트니스'));
    expect(Gym.nameKey('Boston Fitness (2층)'), Gym.nameKey('bostonfitness2층'));
    expect(Gym.nameKey('보스턴'), isNot(Gym.nameKey('보스톤')));
  });
}
