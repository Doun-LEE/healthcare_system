/// 기록 복원 코드: 한 날의 운동 기록(운동·세트별 횟수·무게)을 글자 하나로 옮긴다.
/// 기록이 사라졌을 때 앱에 붙여넣어 그 날을 완료한 기록으로 되돌리는 데 쓴다.
///
/// 형식: `FRREC1.` + base64url(JSON)
///   {"d":"2026-10-25","rpe":6,"x":[["bb_squat",[[10,60],[6,110]]],["stairs",[[20,0,6]]]]}
///   세트 = [횟수(유산소는 분), 화면에 보이는 무게, 유산소 레벨(선택)]
library;

import 'dart:convert';

import '../data/catalog.dart';

const _prefix = 'FRREC1.';

class RecordSet {
  const RecordSet(this.reps, this.weight, [this.level]);
  final int reps;

  /// 화면에 보이는 무게(한쪽 기준 기구면 한쪽 무게). 저장할 때 기구 설정으로 바꾼다.
  final double weight;
  final int? level;
}

class RecordExercise {
  const RecordExercise(this.exerciseId, this.sets);
  final String exerciseId;
  final List<RecordSet> sets;
}

class RecordCode {
  const RecordCode({required this.date, required this.exercises, this.rpe});
  final DateTime date;
  final List<RecordExercise> exercises;
  final int? rpe;

  int get setCount => exercises.fold(0, (a, e) => a + e.sets.length);

  String encode() {
    final j = {
      'd': '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      if (rpe != null) 'rpe': rpe,
      'x': [
        for (final e in exercises)
          [
            e.exerciseId,
            [
              for (final s in e.sets) [s.reps, s.weight, if (s.level != null) s.level],
            ],
          ],
      ],
    };
    return _prefix + base64Url.encode(utf8.encode(jsonEncode(j))).replaceAll('=', '');
  }

  /// 잘못된 코드거나 앱에 없는 운동이 있으면 null.
  static RecordCode? decode(String raw) {
    try {
      final t = raw.trim().replaceAll(RegExp(r'\s+'), '');
      if (!t.startsWith(_prefix)) return null;
      var b = t.substring(_prefix.length);
      while (b.length % 4 != 0) {
        b += '=';
      }
      final j = jsonDecode(utf8.decode(base64Url.decode(b))) as Map<String, dynamic>;
      final d = DateTime.parse(j['d'] as String);
      final xs = <RecordExercise>[];
      for (final x in j['x'] as List) {
        final id = (x as List)[0] as String;
        if (exerciseById(id) == null) return null;
        xs.add(RecordExercise(id, [
          for (final s in x[1] as List)
            RecordSet(
              ((s as List)[0] as num).toInt(),
              (s[1] as num).toDouble(),
              s.length > 2 ? (s[2] as num).toInt() : null,
            ),
        ]));
      }
      if (xs.isEmpty) return null;
      return RecordCode(date: DateTime(d.year, d.month, d.day), exercises: xs, rpe: (j['rpe'] as num?)?.toInt());
    } catch (_) {
      return null;
    }
  }
}
