import 'package:fit_routine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('사진 찍은 사람은 저장되지만 기구 비교(수정 알림)에는 안 들어간다', () {
    final a = GymEquipment(id: 'e1', type: EquipmentType.legPress);
    final b = GymEquipment.fromJson(a.toJson()..['photoBy'] = 'friend');
    expect(b.photoBy, 'friend');
    expect(GymEquipment.fromJson(b.toJson()).photoBy, 'friend');
    expect(equipmentSignature([a]), equipmentSignature([b]));
  });
}
