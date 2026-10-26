import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/data/exercise_photos.dart';
import 'package:fit_routine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('photo maps only point at real exercises and equipment', () {
    for (final id in exercisePhotos.keys) {
      expect(exerciseById(id), isNotNull, reason: id);
    }
    final types = {for (final t in EquipmentType.values) t.name};
    for (final k in equipmentPhotos.keys) {
      expect(types, contains(k));
    }
    expect(exercisePhotoUrls('bb_squat')!.$1, startsWith('https://raw.githubusercontent.com/yuhonas/free-exercise-db/'));
    expect(exercisePhotos.length, greaterThan(150));
  });
}
