import 'package:fit_routine/data/body_model.dart';
import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/data/how_to.dart';
import 'package:fit_routine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every exercise maps to at least one primary muscle in its own group', () {
    for (final ex in exerciseCatalog) {
      final m = musclesFor(ex);
      expect(m.primary, isNotEmpty, reason: '${ex.id} has no primary muscle');
      if (ex.group != MuscleGroup.cardio) {
        expect(m.primary.any((x) => x.group == ex.group), isTrue, reason: '${ex.id} primary not in ${ex.group}');
      }
      expect(m.primary.intersection(m.secondary), isEmpty, reason: '${ex.id} overlap');
    }
  });

  test('bench press hits chest primarily, triceps/front delt secondarily; pull-up prefers back view', () {
    final bench = musclesFor(exerciseCatalog.firstWhere((e) => e.id == 'bb_bench'));
    expect(bench.primary, contains(Muscle.chestMid));
    expect(bench.secondary, containsAll([Muscle.triceps, Muscle.deltFront]));
    expect(bench.preferBack, isFalse);
    final pull = musclesFor(exerciseCatalog.firstWhere((e) => e.id == 'pullup'));
    expect(pull.primary, contains(Muscle.lats));
    expect(pull.preferBack, isTrue);
  });

  test('every exercise has explicit how-to steps', () {
    for (final ex in exerciseCatalog) {
      expect(howTo.containsKey(ex.id), isTrue, reason: '${ex.id} missing how-to');
      expect(howToFor(ex).length, greaterThanOrEqualTo(2));
    }
    // 카탈로그에 없는 id가 남아 있지 않은지
    final ids = exerciseCatalog.map((e) => e.id).toSet();
    expect(howTo.keys.where((k) => !ids.contains(k)), isEmpty);
  });

  test('body model renders faces and stands on the floor', () {
    final faces = bodyFaces(const MuscleMap(primary: {Muscle.quads}, secondary: {Muscle.glutes}));
    expect(faces.length, greaterThan(100));
    var minY = double.infinity, maxY = -double.infinity;
    for (final f in faces) {
      for (final p in f.pts) {
        if (p.y < minY) minY = p.y;
        if (p.y > maxY) maxY = p.y;
      }
    }
    expect(minY, greaterThanOrEqualTo(-0.01));
    expect(maxY, lessThan(2.0));
  });
}
