import 'package:fit_routine/data/equipment_models.dart';
import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/ui/widgets/equipment_3d.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every equipment type has a 3D model with faces', () {
    for (final t in EquipmentType.values) {
      final faces = Equipment3DView.buildFaces(t);
      expect(faces.length, greaterThan(5), reason: '${t.name} 모델이 비어 있음');
      for (final f in faces) {
        expect(f.pts.length, greaterThanOrEqualTo(3));
      }
    }
  });

  test('models sit on or above the floor and are reasonably sized', () {
    for (final t in EquipmentType.values) {
      var minY = double.infinity, maxY = -double.infinity;
      for (final p in equipmentModel(t)) {
        for (final f in p.faces()) {
          for (final v in f.pts) {
            if (v.y < minY) minY = v.y;
            if (v.y > maxY) maxY = v.y;
          }
        }
      }
      expect(minY, greaterThanOrEqualTo(-0.05), reason: '${t.name} 바닥 아래로 내려감');
      expect(maxY, lessThan(3.0), reason: '${t.name} 너무 큼');
    }
  });

  testWidgets('Equipment3DView renders without errors', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Equipment3DView(type: EquipmentType.squatRack, autoRotate: false)),
    ));
    await tester.pump();
    expect(find.byType(Equipment3DView), findsOneWidget);
    await tester.drag(find.byType(Equipment3DView), const Offset(60, 20));
    await tester.pump();
  });
}
