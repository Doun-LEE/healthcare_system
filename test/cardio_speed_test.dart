import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/services/supa_rows.dart';

void main() {
  test('마운틴 클라이머 머신: 인클라인과 속도를 따로 보여 준다', () {
    final spec = cardioLevels['versa']!;
    expect(spec.second, isNotNull);
    expect(spec.format(15, s: 75), '인클라인 15% · 속도 7.5');
    expect(spec.second!.max, 120); // 12.0까지
    expect(spec.second!.parse('7.3'), 73);
    expect(spec.format(15), '인클라인 15%');
    expect(cardioLevels['treadmill_walk']!.format(9, s: 55), '경사 9% · 속도 5.5km/h');
  });

  test('세트 속도(처방·실제)가 서버 행 왕복에서 살아남는다', () {
    final plan = DayPlan(
      id: 'p1',
      userId: 'u',
      date: DateTime(2026, 11, 17),
      kind: DayKind.workout,
      focus: [MuscleGroup.cardio],
      title: '유산소',
      exercises: [
        PlannedExercise(
          exerciseId: 'versa',
          equipmentType: EquipmentType.versaClimber,
          restSeconds: 0,
          sets: [
            SetEntry(targetReps: 20, targetWeight: 0, level: 15, speed: 20)
              ..doneSpeed = 25
              ..doneLevel = 18
              ..completed = true,
            SetEntry(targetReps: 5, targetWeight: 0, level: 15, speed: 20, extra: true),
          ],
        ),
      ],
    );
    Map<String, dynamic> j(Map<String, dynamic> m) => jsonDecode(jsonEncode(m)) as Map<String, dynamic>;
    final back = planFromRows(j(planRow(plan, 'uidA')), planExerciseRows(plan).map(j).toList(),
        setRows(plan, 'uidA').map(j).toList(), const [], localUserId: 'u');
    expect(jsonEncode(back.toJson()), jsonEncode(plan.toJson()));
    expect(back.exercises.single.sets.first.effectiveSpeed, 25);
  });
}
