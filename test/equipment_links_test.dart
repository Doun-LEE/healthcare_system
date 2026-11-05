import 'package:flutter_test/flutter_test.dart';
import 'package:fit_routine/data/brand_catalog.dart';
import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/models/models.dart';

void main() {
  bool can(String id, Set<EquipmentType> t) => exerciseById(id)!.canDoWith(t);

  test('랫풀다운 기구만 있어도 푸시다운·스트레이트암·케이블 크런치·페이스풀', () {
    const t = {EquipmentType.latPulldown};
    for (final id in ['tri_pushdown', 'straight_arm_pd', 'cable_crunch', 'face_pull']) {
      expect(can(id, t), isTrue, reason: id);
    }
  });

  test('시티드 로우(로우 풀리)로 케이블 컬·업라이트 로우, 수평 레그프레스로 카프', () {
    expect(can('cable_curl', {EquipmentType.seatedRow}), isTrue);
    expect(can('upright_row', {EquipmentType.seatedRow}), isTrue);
    expect(can('calf_raise', {EquipmentType.horizontalLegPress}), isTrue);
    expect(can('single_arm_pulldown', {EquipmentType.latPulldownPlateLoaded}), isTrue);
  });

  test('브랜드 플레이트 로디드 인클라인 프레스는 인클라인으로 분류', () {
    for (final b in researchedBrands) {
      for (final m in b.models) {
        if (RegExp('인클라인|Incline').hasMatch(m.name) && m.type == EquipmentType.chestPressPlateLoaded) {
          fail('${m.name}이 평 체스트프레스로 분류됨');
        }
      }
    }
  });

  test('예전에 평 체스트프레스로 저장된 인클라인 기구를 불러오면 인클라인으로(원판 방식 유지)', () {
    final e = GymEquipment.fromJson({'id': 'a', 'type': 'chestPressPlateLoaded', 'customName': '뉴텍 엠토쳐 인클라인 체스트 프레스'});
    expect(e.type, EquipmentType.inclineChestPress);
    expect(e.mechanism, LoadMechanism.plate);
    final c = GymEquipment.fromJson({'id': 'b', 'type': 'shoulderPressPlateLoaded', 'customName': '뉴텍 엠토쳐2 숄더&인클라인 콤보', 'extraTypes': ['chestPressPlateLoaded']});
    expect(c.extraTypes, [EquipmentType.inclineChestPress]);
    final flat = GymEquipment.fromJson({'id': 'c', 'type': 'chestPressPlateLoaded', 'customName': '해머 아이소래터럴 체스트 프레스'});
    expect(flat.type, EquipmentType.chestPressPlateLoaded);
  });
}
