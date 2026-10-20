import 'dart:io';

import 'package:fit_routine/core/store.dart';
import 'package:fit_routine/data/catalog.dart';
import 'package:fit_routine/engine/load_estimator.dart';
import 'package:fit_routine/engine/planner.dart';
import 'package:fit_routine/engine/progression.dart';
import 'package:fit_routine/engine/session_generator.dart';
import 'package:fit_routine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _user({int split = 3, int minutes = 120, TrainingLevel level = TrainingLevel.beginner}) =>
    UserProfile(
      id: 'u1',
      name: '테스트',
      sex: Sex.male,
      heightCm: 175,
      weightKg: 75,
      age: 28,
      level: level,
      splitDays: split,
      sessionMinutes: minutes,
    );

const _fullGym = {
  EquipmentType.barbell,
  EquipmentType.dumbbell,
  EquipmentType.flatBench,
  EquipmentType.inclineBench,
  EquipmentType.squatRack,
  EquipmentType.cableMachine,
  EquipmentType.latPulldown,
  EquipmentType.seatedRow,
  EquipmentType.legPress,
  EquipmentType.legCurl,
  EquipmentType.pullUpBar,
  EquipmentType.treadmill,
  EquipmentType.bodyweight,
};

int _counter = 0;
String _id() => 'id${_counter++}';

void main() {
  group('LoadEstimator', () {
    test('estimates sane starting weights and rounds to equipment increments', () {
      final est = LoadEstimator(_user());
      final bench = exerciseById('bb_bench')!;
      final w = est.initialWeight(bench, 10);
      expect(w, greaterThanOrEqualTo(20));
      expect(w, lessThan(80));
      expect((w / 2.5).roundToDouble() * 2.5, w);

      final db = exerciseById('db_bench')!;
      final dw = est.initialWeight(db, 10);
      expect(dw % 2.0, 0);
      expect(dw, lessThan(w)); // 덤벨 한 손은 바벨보다 가볍다
    });

    test('inbody muscle mass raises estimates, high body fat lowers them', () {
      final base = LoadEstimator(_user()).oneRepMax(RefLift.squat);
      final muscular = _user()..skeletalMuscleKg = 40; // 75kg 중 40kg → 평균 이상
      final fat = _user()..bodyFatPct = 32;
      expect(LoadEstimator(muscular).oneRepMax(RefLift.squat), greaterThan(base));
      expect(LoadEstimator(fat).oneRepMax(RefLift.squat), lessThan(base));
    });

    test('bodyweight and cardio have no load', () {
      final est = LoadEstimator(_user());
      expect(est.initialWeight(exerciseById('pullup')!, 8), 0);
      expect(est.initialWeight(exerciseById('bike')!, 20), 0);
    });
  });

  group('Progression', () {
    PlannedExercise planned(String id, double w, int reps, int sets) => PlannedExercise(
          exerciseId: id,
          equipmentType: EquipmentType.barbell,
          restSeconds: 120,
          sets: List.generate(sets, (_) => SetEntry(targetReps: reps, targetWeight: w)),
        );

    test('all sets hit → weight goes up one increment', () {
      final p = planned('bb_bench', 50, 10, 3);
      for (final s in p.sets) {
        s.completed = true;
      }
      final prog = ExerciseProgress(exerciseId: 'bb_bench', workingWeight: 50, targetReps: 10);
      final r = Progression.apply(p, prog, DateTime(2026, 10, 20));
      expect(r.progress.workingWeight, 52.5);
      expect(r.progress.consecutiveSuccess, 1);
    });

    test('user lifted heavier than prescribed → new baseline + bump', () {
      final p = planned('bb_bench', 50, 10, 3);
      for (final s in p.sets) {
        s.completed = true;
        s.doneWeight = 55;
        s.doneReps = 12; // 여유 있게
      }
      final prog = ExerciseProgress(exerciseId: 'bb_bench', workingWeight: 50, targetReps: 10);
      final r = Progression.apply(p, prog, DateTime(2026, 10, 20));
      expect(r.progress.workingWeight, 60); // 55 + 2×2.5
    });

    test('manually lowering the weight makes it the new baseline (no bump)', () {
      final p = planned('bb_bench', 60, 10, 3);
      for (final s in p.sets) {
        s.completed = true;
        s.doneWeight = 50;
      }
      final prog = ExerciseProgress(exerciseId: 'bb_bench', workingWeight: 60, targetReps: 10);
      final r = Progression.apply(p, prog, DateTime(2026, 10, 20));
      expect(r.progress.workingWeight, 50);
      expect(r.message, contains('낮춰'));
    });

    test('two consecutive failures → 10% deload', () {
      final prog = ExerciseProgress(exerciseId: 'bb_bench', workingWeight: 60, targetReps: 10);
      for (var i = 0; i < 2; i++) {
        final p = planned('bb_bench', 60, 10, 3);
        p.sets[0].completed = true;
        p.sets[0].doneReps = 6; // 실패
        p.sets[1].completed = true;
        p.sets[1].doneReps = 5;
        Progression.apply(p, prog, DateTime(2026, 10, 20 + i));
      }
      expect(prog.workingWeight, 55); // 60×0.9=54 → 2.5 단위 반올림 55
    });

    test('light day (load factor < 1) keeps the working weight even on success', () {
      final p = planned('bb_bench', 42.5, 10, 3);
      for (final s in p.sets) {
        s.completed = true;
      }
      final prog = ExerciseProgress(exerciseId: 'bb_bench', workingWeight: 60, targetReps: 10);
      final r = Progression.apply(p, prog, DateTime(2026, 10, 20), loadFactor: 0.7);
      expect(r.progress.workingWeight, 60);
      expect(r.message, contains('유지'));
    });

    test('RPE tunes the bump: easy → double, max effort → hold', () {
      ExerciseProgress run(int rpe) {
        final p = planned('bb_bench', 60, 10, 3);
        for (final s in p.sets) {
          s.completed = true;
        }
        final prog = ExerciseProgress(exerciseId: 'bb_bench', workingWeight: 60, targetReps: 10);
        return Progression.apply(p, prog, DateTime(2026, 10, 20), rpe: rpe).progress;
      }
      expect(run(2).workingWeight, 65);
      expect(run(6).workingWeight, 62.5);
      expect(run(10).workingWeight, 60);
    });

    test('bodyweight exercise adjusts reps instead of weight', () {
      final p = PlannedExercise(
        exerciseId: 'pullup',
        equipmentType: EquipmentType.pullUpBar,
        restSeconds: 90,
        sets: List.generate(3, (_) => SetEntry(targetReps: 8, targetWeight: 0)..completed = true),
      );
      final prog = ExerciseProgress(exerciseId: 'pullup', workingWeight: 0, targetReps: 8);
      Progression.apply(p, prog, DateTime(2026, 10, 20));
      expect(prog.workingWeight, 0);
      expect(prog.targetReps, 10);
    });
  });

  group('SessionGenerator', () {
    test('full-body session fits in 2 hours and covers every group', () {
      final plan = SessionGenerator(SessionRequest(
        groups: [MuscleGroup.legs, MuscleGroup.chest, MuscleGroup.back, MuscleGroup.shoulder, MuscleGroup.arms, MuscleGroup.abs],
        available: _fullGym,
        progress: {},
        profile: _user(split: 1),
        minutesBudget: 120,
        now: DateTime(2026, 10, 20),
        seed: 1,
      )).generate();
      expect(plan, isNotEmpty);
      expect(SessionGenerator.estimateMinutes(plan), lessThanOrEqualTo(120));
      final groups = plan.map((p) => exerciseById(p.exerciseId)!.group).toSet();
      for (final g in [MuscleGroup.legs, MuscleGroup.chest, MuscleGroup.back, MuscleGroup.shoulder]) {
        expect(groups, contains(g), reason: '${g.label} 누락');
      }
    });

    test('only uses exercises possible with the gym equipment', () {
      final tiny = {EquipmentType.dumbbell, EquipmentType.flatBench, EquipmentType.bodyweight};
      final plan = SessionGenerator(SessionRequest(
        groups: [MuscleGroup.chest, MuscleGroup.back, MuscleGroup.legs],
        available: tiny,
        progress: {},
        profile: _user(),
        minutesBudget: 90,
        seed: 2,
      )).generate();
      expect(plan, isNotEmpty);
      for (final p in plan) {
        expect(tiny, contains(p.equipmentType));
        expect(exerciseById(p.exerciseId)!.canDoWith(tiny), isTrue);
      }
    });

    test('recently performed exercises are rotated out (requirement 8)', () {
      final now = DateTime(2026, 10, 20);
      final first = SessionGenerator(SessionRequest(
        groups: [MuscleGroup.chest],
        available: _fullGym,
        progress: {},
        profile: _user(),
        minutesBudget: 60,
        now: now,
        seed: 3,
      )).generate();
      final progress = {
        for (final p in first)
          p.exerciseId: ExerciseProgress(
            exerciseId: p.exerciseId,
            workingWeight: p.sets.first.targetWeight,
            lastPerformed: now,
          ),
      };
      final second = SessionGenerator(SessionRequest(
        groups: [MuscleGroup.chest],
        available: _fullGym,
        progress: progress,
        profile: _user(),
        minutesBudget: 60,
        now: now.add(const Duration(days: 2)),
        seed: 4,
      )).generate();
      final firstIds = first.map((p) => p.exerciseId).toSet();
      final overlap = second.where((p) => firstIds.contains(p.exerciseId)).length;
      expect(overlap, lessThan(second.length), reason: '다음 루틴에 새 운동이 하나도 없음');
    });

    test('short budget still produces something and respects it', () {
      final plan = SessionGenerator(SessionRequest(
        groups: [MuscleGroup.legs],
        available: _fullGym,
        progress: {},
        profile: _user(),
        minutesBudget: 40,
        seed: 5,
      )).generate();
      expect(plan, isNotEmpty);
      expect(SessionGenerator.estimateMinutes(plan), lessThanOrEqualTo(45));
    });

    test('load factor scales prescribed weights and adds reps on light days', () {
      final prog = {
        'bb_squat': ExerciseProgress(exerciseId: 'bb_squat', workingWeight: 100, targetReps: 6, lastPerformed: DateTime(2026, 10, 1)),
        for (final e in exercisesOf(MuscleGroup.legs))
          if (e.id != 'bb_squat') e.id: ExerciseProgress(exerciseId: e.id, workingWeight: 20, lastPerformed: DateTime(2026, 10, 19)),
      };
      final plan = SessionGenerator(SessionRequest(
        groups: [MuscleGroup.legs],
        available: _fullGym,
        progress: prog,
        profile: _user(),
        minutesBudget: 120,
        loadFactor: 0.7,
        now: DateTime(2026, 10, 20),
        seed: 6,
      )).generate();
      final squat = plan.firstWhere((p) => p.exerciseId == 'bb_squat');
      expect(squat.sets.first.targetWeight, 70);
      expect(squat.sets.first.targetReps, 8); // 6 + 2
    });

    test('uses working weight from progress when available', () {
      // 다른 하체 운동은 모두 어제 했고 스쿼트만 3주 전 → 스쿼트가 뽑혀야 한다.
      final prog = {
        for (final e in exercisesOf(MuscleGroup.legs))
          if (e.id != 'bb_squat')
            e.id: ExerciseProgress(exerciseId: e.id, workingWeight: 20, lastPerformed: DateTime(2026, 10, 19)),
        'bb_squat': ExerciseProgress(exerciseId: 'bb_squat', workingWeight: 100, targetReps: 6, lastPerformed: DateTime(2026, 10, 1)),
      };
      final plan = SessionGenerator(SessionRequest(
        groups: [MuscleGroup.legs],
        available: _fullGym,
        progress: prog,
        profile: _user(),
        minutesBudget: 120,
        now: DateTime(2026, 10, 20),
        seed: 6,
      )).generate();
      final squat = plan.where((p) => p.exerciseId == 'bb_squat').firstOrNull;
      expect(squat, isNotNull);
      expect(squat!.sets.first.targetWeight, 100);
      expect(squat.sets.first.targetReps, 6);
    });
  });

  group('Planner', () {
    PlannerInput input({
      required DateTime from,
      required DateTime to,
      Set<String> rest = const {},
      List<DayPlan> history = const [],
      int split = 3,
    }) =>
        PlannerInput(
          profile: _user(split: split),
          from: from,
          to: to,
          restDays: rest,
          available: _fullGym,
          progress: {},
          history: history,
          newId: _id,
        );

    test('manual rest days are honored and workouts follow the split cycle', () {
      final from = DateTime(2026, 10, 19); // 월
      final plans = Planner(input(
        from: from,
        to: from.add(const Duration(days: 6)),
        rest: {'2026-10-21', '2026-10-25'},
      )).build();
      expect(plans.length, 7);
      expect(plans[2].isRest, isTrue);
      expect(plans[6].isRest, isTrue);
      final titles = plans.where((p) => !p.isRest).map((p) => p.title).toList();
      expect(titles.first, contains('밀기'));
      expect(titles[1], contains('당기기'));
      expect(titles[2], contains('하체'));
    });

    test('never schedules more than 6 consecutive workout days', () {
      final from = DateTime(2026, 11, 1);
      final plans = Planner(input(from: from, to: from.add(const Duration(days: 29)), split: 6)).build();
      expect(Planner.maxStreak(plans), lessThanOrEqualTo(6));
      expect(plans.where((p) => p.isRest).length, greaterThan(0));
    });

    test('reduces intensity after 4 consecutive workout days', () {
      final from = DateTime(2026, 11, 1);
      final plans = Planner(input(from: from, to: from.add(const Duration(days: 6)), split: 6)).build();
      expect(plans[4].intensityFactor, lessThan(1.0));
      expect(plans[0].intensityFactor, 1.0);
    });

    test('3-split: lighter on day 4, forced rest on day 5 when no rest days are set', () {
      final from = DateTime(2026, 11, 1);
      final plans = Planner(input(from: from, to: from.add(const Duration(days: 6)), split: 3)).build();
      expect(plans[3].isRest, isFalse);
      expect(plans[3].intensityFactor, lessThan(1.0));
      expect(plans[4].isRest, isTrue);
      expect(Planner.maxStreak(plans), 4);
    });

    test('session never exceeds 9 strength exercises', () {
      final plan = SessionGenerator(SessionRequest(
        groups: [MuscleGroup.chest, MuscleGroup.shoulder, MuscleGroup.arms],
        available: _fullGym,
        progress: {},
        profile: _user(minutes: 150),
        minutesBudget: 150,
        seed: 9,
      )).generate();
      final strength = plan.where((p) => exerciseById(p.exerciseId)!.group != MuscleGroup.cardio);
      expect(strength.length, lessThanOrEqualTo(9));
    });

    test('respects per-muscle recovery hours when picking the next split day', () {
      // 어제 하체를 했으면 오늘 3분할 순서가 하체라도 하체를 피한다.
      final from = DateTime(2026, 10, 20);
      final yesterday = DayPlan(
        id: 'h1',
        userId: 'u1',
        date: DateTime(2026, 10, 19),
        kind: DayKind.workout,
        focus: [MuscleGroup.legs, MuscleGroup.abs],
        title: '하체',
        finishedAt: DateTime(2026, 10, 19, 20),
      );
      final pull = DayPlan(
        id: 'h0',
        userId: 'u1',
        date: DateTime(2026, 10, 18),
        kind: DayKind.workout,
        focus: [MuscleGroup.back, MuscleGroup.arms, MuscleGroup.abs],
        title: '당기기 (등·이두)',
        finishedAt: DateTime(2026, 10, 18, 20),
      );
      final plans = Planner(input(from: from, to: from, history: [pull, yesterday])).build();
      expect(plans.single.focus, isNot(contains(MuscleGroup.legs)));
    });

    test('summary counts workouts and rests', () {
      final from = DateTime(2026, 10, 19);
      final plans = Planner(input(from: from, to: from.add(const Duration(days: 6)), rest: {'2026-10-22'})).build();
      final s = Planner.summarize(plans);
      expect(s['운동일'], 6);
      expect(s['휴식일'], 1);
    });
  });

  group('LocalStore', () {
    test('round-trips all data through JSON', () async {
      final dir = await Directory.systemTemp.createTemp('fitroutine_test');
      final store = LocalStore(File('${dir.path}/data.json'));
      final data = AppData();
      final u = _user();
      data.profiles.add(u);
      data.currentUserId = u.id;
      data.gyms.add(Gym(id: 'g1', name: '짐', equipment: [
        GymEquipment(id: 'e1', type: EquipmentType.legPress, customName: '해머', maxWeightKg: 300),
      ]));
      final plans = Planner(PlannerInput(
        profile: u,
        from: DateTime(2026, 10, 20),
        to: DateTime(2026, 10, 22),
        restDays: {'2026-10-21'},
        available: _fullGym,
        progress: {},
        history: [],
        newId: _id,
      )).build();
      plans[0].exercises.first.sets.first.completed = true;
      plans[0].exercises.first.sets.first.doneReps = 12;
      data.plans.addAll(plans);
      data.progress['u1'] = {
        'bb_bench': ExerciseProgress(exerciseId: 'bb_bench', workingWeight: 60, lastPerformed: DateTime(2026, 10, 1)),
      };

      await store.save(data);
      final loaded = await store.load();

      expect(loaded.accessCode, '23007344');
      expect(loaded.profiles.single.name, '테스트');
      expect(loaded.gyms.single.equipment.single.maxWeightKg, 300);
      expect(loaded.plans.length, 3);
      expect(loaded.plans.where((p) => p.isRest).single.date, DateTime(2026, 10, 21));
      final ex = loaded.plans.firstWhere((p) => dateKey(p.date) == '2026-10-20').exercises.first;
      expect(ex.sets.first.completed, isTrue);
      expect(ex.sets.first.doneReps, 12);
      expect(loaded.progress['u1']!['bb_bench']!.workingWeight, 60);
      await dir.delete(recursive: true);
    });

    test('corrupt file falls back to empty data', () async {
      final dir = await Directory.systemTemp.createTemp('fitroutine_test');
      final f = File('${dir.path}/data.json');
      await f.writeAsString('{not json');
      final loaded = await LocalStore(f).load();
      expect(loaded.profiles, isEmpty);
      await dir.delete(recursive: true);
    });
  });

  test('catalog integrity: every exercise references a known equipment and has rest rule', () {
    final ids = <String>{};
    for (final e in exerciseCatalog) {
      expect(ids.add(e.id), isTrue, reason: '중복 id ${e.id}');
      expect(e.equipment, isNotEmpty);
      expect(restRules[e.group], isNotNull);
      expect(e.repRange.length, 2);
      expect(e.repRange[0], lessThanOrEqualTo(e.repRange[1]));
    }
    for (final t in EquipmentType.values) {
      expect(() => equipmentInfo(t), returnsNormally, reason: '${t.name} 카탈로그 정보 없음');
    }
  });
}
