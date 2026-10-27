import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/ui/widgets/workout_card.dart';

void main() {
  PlannedExercise pe(String id, EquipmentType t, List<(double, int)> sets) => PlannedExercise(
        exerciseId: id,
        equipmentType: t,
        restSeconds: 90,
        sets: [
          for (final (w, r) in sets)
            SetEntry(targetReps: r, targetWeight: w)
              ..completed = true
              ..doneReps = r
              ..doneWeight = w,
        ],
      );

  testWidgets('완료 카드: 긴 이름·세트 많은 날도 넘침 없이 그려지고 최고 기록을 보여준다', (tester) async {
    final plan = DayPlan(
      id: 'p1',
      userId: 'u1',
      date: DateTime(2026, 10, 25),
      kind: DayKind.workout,
      focus: [MuscleGroup.legs, MuscleGroup.chest, MuscleGroup.back],
      title: '전신',
      finishedAt: DateTime(2026, 10, 25, 20),
      exercises: [
        pe('stairs', EquipmentType.stairClimber, [(0, 20)]),
        pe('bb_squat', EquipmentType.squatRack, [(60, 10), (110, 6), (140, 1), (120, 3)]),
        pe('deadlift', EquipmentType.barbell, [(100, 6), (120, 4), (100, 8)]),
        pe('db_bench', EquipmentType.dumbbell, [(32, 10), (36, 10), (40, 8)]),
        pe('hammer_chest', EquipmentType.chestPressPlateLoaded, [(30, 12), (40, 10), (35, 12)]),
        pe('monster_glute', EquipmentType.monsterGlute, [(5, 20), (5, 20), (10, 15)]),
        pe('db_pullover', EquipmentType.dumbbell, [(50, 12), (50, 12), (50, 12)]),
        pe('hanging_leg_raise', EquipmentType.pullUpBar, [(0, 30), (0, 25), (0, 20), (0, 15)]),
      ],
    )..rpe = 6;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Center(
            child: WorkoutSummaryCard(plan: plan, userName: '이도운', showAll: true, equipmentLabel: (e) => '렉스코 ${e.equipmentType.label}'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull); // RenderFlex overflow 등 없음
    expect(find.text('전신'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget); // 수행률 링
    expect(find.textContaining('체감 6/10'), findsOneWidget);
    // 최고 기록: 140kg × 1
    expect(find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('140kg × 1')), findsOneWidget);
    // 세트가 이름 아래 줄로 내려가 잘리지 않는다(같은 세트 묶기 포함)
    expect(find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('50kg×12 ×3')), findsOneWidget);
  });
}
