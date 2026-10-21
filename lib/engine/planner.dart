/// 주/월 단위 플래너 (요구사항 6, 10).
///
/// 입력: 기간, 사용자가 달력에서 찍은 휴식일, 분할 수, 과거 계획(부위별 마지막 훈련일).
/// 출력: 날짜별 [DayPlan] (운동일/휴식일).
///
/// 규칙:
/// - 휴식일로 체크된 날은 반드시 휴식.
/// - 운동일은 분할 사이클을 순서대로 배정하되, 그날의 주요 부위가 아직 회복
///   시간([RestRule.recoveryHours]) 안이면 사이클에서 회복된 다음 날을 앞당긴다.
/// - 연속 운동일이 분할 수에 비례한 한도를 넘으면 강도 계수를 낮추고(0.85),
///   그보다 더 길어지면 자동 휴식을 넣는다 (3분할: 3일 뒤 볼륨↓, 4일 뒤 휴식).
/// - 휴식일이 너무 많아 어떤 부위가 8일 이상 자극되지 않으면 그 부위를 다음 운동일에 끼워넣는다.
///   (너무 쉬지도 않게)
library;

import 'dart:math';

import '../data/catalog.dart';
import '../models/models.dart';
import 'session_generator.dart';
import 'splits.dart';

class PlannerInput {
  PlannerInput({
    required this.profile,
    required this.from,
    required this.to,
    required this.restDays,
    required this.available,
    required this.progress,
    required this.history,
    required this.newId,
    this.equipmentMax = const {},
    this.equipmentStep = const {},
    this.now,
    this.fixed = const {},
  });

  final UserProfile profile;
  final DateTime from;
  final DateTime to;

  /// 사용자가 달력에서 휴식으로 체크한 날짜 키('yyyy-MM-dd').
  final Set<String> restDays;
  final Set<EquipmentType> available;
  final Map<String, ExerciseProgress> progress;

  /// 기간 이전의 기존 계획(부위별 마지막 훈련일 계산용).
  final List<DayPlan> history;
  final String Function() newId;
  final Map<EquipmentType, double> equipmentMax;
  final Map<EquipmentType, double> equipmentStep;
  final DateTime? now;

  /// 기간 안에서 그대로 두어야 하는 날(dateKey → 계획). 파트너 운동일 등.
  /// 플래너는 이 날을 건드리지 않고, 그 부위를 훈련한 것으로 보고 다음 날을 고른다.
  final Map<String, DayPlan> fixed;
}

class Planner {
  Planner(this.input);
  final PlannerInput input;

  static const int _maxIdleDaysPerGroup = 8;

  /// 분할 수에 비례한 연속 운동일 한도. 3분할이면 3일 뒤 볼륨↓, 4일 뒤 자동 휴식.
  /// 6분할은 6일 연속(6 on / 1 off)까지 허용.
  static int deloadAfter(int splitDays) => splitDays.clamp(2, 4);
  static int forcedRestAfter(int splitDays) => (splitDays + 1).clamp(3, 6);

  List<DayPlan> build() {
    final split = input.profile.splitDays.clamp(1, 6);
    final cycle = splitCycles[split]!;
    final deloadStreak = deloadAfter(split);
    final restStreak = forcedRestAfter(split);
    final plans = <DayPlan>[];

    // 부위별 마지막 훈련일(기록 기준).
    final lastTrained = <MuscleGroup, DateTime>{};
    for (final h in input.history) {
      if (h.isRest || h.date.isAfter(input.to)) continue;
      for (final g in h.focus) {
        final prev = lastTrained[g];
        if (prev == null || h.date.isAfter(prev)) lastTrained[g] = h.date;
      }
    }

    // 사이클 위치: 이력에서 마지막 운동일의 타이틀을 찾아 이어간다.
    var cycleIdx = 0;
    final lastWorkout = input.history
        .where((h) => !h.isRest && h.date.isBefore(input.from))
        .fold<DayPlan?>(null, (a, b) => a == null || b.date.isAfter(a.date) ? b : a);
    if (lastWorkout != null) {
      final i = cycle.indexWhere((d) => d.title == lastWorkout.title);
      if (i >= 0) cycleIdx = (i + 1) % cycle.length;
    }

    var streak = _streakBefore(input.from);
    final totalDays = input.to.difference(input.from).inDays + 1;

    for (var i = 0; i < totalDays; i++) {
      final date = dateOnly(input.from.add(Duration(days: i)));
      final key = dateKey(date);

      final fixedDay = input.fixed[key];
      if (fixedDay != null) {
        plans.add(fixedDay);
        if (fixedDay.isRest) {
          streak = 0;
        } else {
          for (final g in fixedDay.focus) {
            lastTrained[g] = date;
          }
          // 고정된 날이 분할의 어느 날과 같으면 사이클을 그 다음으로 넘긴다.
          final i = cycle.indexWhere((d) => d.groups.every(fixedDay.focus.contains));
          if (i >= 0) cycleIdx = (i + 1) % cycle.length;
          streak++;
        }
        continue;
      }
      if (input.restDays.contains(key)) {
        plans.add(_rest(date, '휴식 (직접 설정)'));
        streak = 0;
        continue;
      }
      if (streak >= restStreak) {
        plans.add(_rest(date, '휴식 (연속 $streak일 운동 → 자동 휴식)'));
        streak = 0;
        continue;
      }

      // 회복이 끝난 분할 날을 고른다. 전부 회복 중이면 원래 순서대로.
      var chosen = cycleIdx;
      for (var k = 0; k < cycle.length; k++) {
        final idx = (cycleIdx + k) % cycle.length;
        if (_recovered(cycle[idx].groups, lastTrained, date)) {
          chosen = idx;
          break;
        }
      }
      final day = cycle[chosen];
      final groups = List<MuscleGroup>.from(day.groups);

      // 너무 오래 쉰 부위를 끼워넣는다 (너무 쉬지도 않게).
      final idle = _idleGroups(lastTrained, date, groups);
      groups.addAll(idle);

      final intensity = streak >= deloadStreak ? 0.85 : 1.0;
      final exercises = SessionGenerator(SessionRequest(
        groups: groups,
        available: input.available,
        progress: input.progress,
        profile: input.profile,
        minutesBudget: input.profile.sessionMinutes,
        intensityFactor: intensity,
        now: date,
        equipmentMax: input.equipmentMax,
        equipmentStep: input.equipmentStep,
        seed: date.millisecondsSinceEpoch ~/ 86400000,
      )).generate();

      plans.add(DayPlan(
        id: input.newId(),
        userId: input.profile.id,
        date: date,
        kind: DayKind.workout,
        focus: groups,
        exercises: exercises,
        estimatedMinutes: SessionGenerator.estimateMinutes(exercises),
        intensityFactor: intensity,
        title: idle.isEmpty
            ? day.title
            : '${day.title} + ${idle.map((g) => g.label).join('·')}',
      ));

      for (final g in groups) {
        lastTrained[g] = date;
      }
      // 회복 때문에 순서를 건너뛰었어도 사이클은 선택한 날의 다음으로 진행.
      cycleIdx = (chosen + 1) % cycle.length;
      streak++;
    }
    return plans;
  }

  int _streakBefore(DateTime from) {
    var streak = 0;
    var d = from.subtract(const Duration(days: 1));
    while (true) {
      final p = input.history.where((h) => dateKey(h.date) == dateKey(d)).toList();
      if (p.isEmpty || p.first.isRest) break;
      streak++;
      d = d.subtract(const Duration(days: 1));
      if (streak > 10) break;
    }
    return streak;
  }

  /// 그날의 주요 부위가 모두 회복됐는가.
  ///
  /// 복근·유산소는 매일 해도 되고, 팔은 밀기/당기기 날에 보조로 따라붙으므로
  /// 그날의 첫 부위(주인공)일 때만 회복을 따진다. 그렇지 않으면 PPL에서
  /// 밀기 다음 날 당기기가 "팔이 아직 회복 중"이라며 밀려버린다.
  bool _recovered(
      List<MuscleGroup> groups, Map<MuscleGroup, DateTime> last, DateTime date) {
    for (var i = 0; i < groups.length; i++) {
      final g = groups[i];
      if (g == MuscleGroup.abs || g == MuscleGroup.cardio) continue;
      if (g == MuscleGroup.arms && i > 0) continue;
      final l = last[g];
      if (l == null) continue;
      final hours = date.difference(l).inHours;
      if (hours < restRules[g]!.recoveryHours) return false;
    }
    return true;
  }

  List<MuscleGroup> _idleGroups(
      Map<MuscleGroup, DateTime> last, DateTime date, List<MuscleGroup> already) {
    final out = <MuscleGroup>[];
    for (final g in MuscleGroup.values) {
      if (g == MuscleGroup.cardio || already.contains(g)) continue;
      final l = last[g];
      if (l == null) continue; // 이력이 없으면 사이클이 알아서 돌아온다
      if (date.difference(l).inDays >= _maxIdleDaysPerGroup) out.add(g);
      if (out.isNotEmpty) break; // 하루에 하나만 끼워넣어 과부하 방지
    }
    return out;
  }

  DayPlan _rest(DateTime date, String title) => DayPlan(
        id: input.newId(),
        userId: input.profile.id,
        date: date,
        kind: DayKind.rest,
        focus: const [],
        title: title,
      );

  /// 미리보기용: 기간 내 운동일/휴식일 수와 부위별 횟수.
  static Map<String, int> summarize(List<DayPlan> plans) {
    final m = <String, int>{'운동일': 0, '휴식일': 0};
    for (final p in plans) {
      if (p.isRest) {
        m['휴식일'] = m['휴식일']! + 1;
      } else {
        m['운동일'] = m['운동일']! + 1;
        for (final g in p.focus) {
          m[g.label] = (m[g.label] ?? 0) + 1;
        }
      }
    }
    return m;
  }

  static int maxStreak(List<DayPlan> plans) {
    var best = 0, cur = 0;
    for (final p in plans) {
      cur = p.isRest ? 0 : cur + 1;
      best = max(best, cur);
    }
    return best;
  }
}
