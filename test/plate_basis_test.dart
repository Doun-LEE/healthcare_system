import 'package:fit_routine/data/brands.dart';
import 'package:fit_routine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plate-loaded machine defaults to "원판" basis and keeps new fields through JSON', () {
    final e = GymEquipment(id: 'lp', type: EquipmentType.legPress);
    expect(e.sledMatters, isTrue);
    expect(e.effectivePlateBasis, 'plates');
    expect(e.basisLabel, '원판');
    expect(e.withSled(240), isNull); // 빈 기구 무게 모름

    e.emptyKg = 40;
    e.plateBasis = 'full';
    expect(e.basisLabel, '기구 포함');
    expect(e.withoutSled(240), 200);
    final back = GymEquipment.fromJson(e.toJson());
    expect(back.emptyKg, 40);
    expect(back.plateBasis, 'full');
  });

  test('per-side plate machine halves the sled and combines labels', () {
    final e = GymEquipment(id: 'r', type: EquipmentType.lowRow, weightBasis: 'perSide', emptyKg: 10);
    expect(e.basisLabel, '한쪽 원판');
    expect(e.withSled(50), 55);
  });

  test('barbells, pin machines and dumbbells never show a plate basis', () {
    expect(GymEquipment(id: 'b', type: EquipmentType.barbell).sledMatters, isFalse);
    expect(GymEquipment(id: 'b', type: EquipmentType.barbell).basisLabel, '');
    expect(GymEquipment(id: 'p', type: EquipmentType.legExtension).sledMatters, isFalse);
    expect(GymEquipment(id: 'd', type: EquipmentType.dumbbell).basisLabel, '한 손');
    expect(GymEquipment(id: 'd', type: EquipmentType.dumbbell).sledMatters, isFalse);
  });

  test('Hammer Strength models carry the published starting resistance', () {
    final hammer = brandByKey('hammer')!;
    final linear = hammer.models.firstWhere((m) => m.name.contains('리니어 레그 프레스'));
    expect(linear.emptyKg, 53);
    expect(brandByKey('lexco')!.models.every((m) => m.emptyKg == null), isTrue); // 공개 값 없음 → 안 넣음
  });
}
