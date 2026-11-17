/// 하루 루틴을 부위·세부 부위별로 묶어 세는 도우미(한눈에 보기 창용).
library;

import '../data/body_model.dart';
import '../data/catalog.dart';
import '../models/models.dart';

/// 유산소 세부: 숨차게 짧게(인터벌·전신 동작) = 체력 증진, 꾸준히 오래 = 칼로리 소모.
const cardioBurn = '칼로리 소모';
const cardioFitness = '체력 증진';

const _intervalIds = {
  'curved_sprint', 'assault', 'ski_erg', 'jacobs', 'versa', 'jump_rope', 'battle_rope', 'box_jump',
  'burpee', 'kb_swing', 'wall_ball', 'mountain_climber', 'jumping_jack', 'sled_drag', 'boxing',
};

/// 한눈에 보기에서 보여 줄 부위 순서.
const overviewGroups = [
  MuscleGroup.cardio,
  MuscleGroup.chest,
  MuscleGroup.back,
  MuscleGroup.shoulder,
  MuscleGroup.arms,
  MuscleGroup.legs,
  MuscleGroup.abs,
];

/// 부위 안의 세부 부위 이름들.
List<String> subLabels(MuscleGroup g) => g == MuscleGroup.cardio
    ? const [cardioBurn, cardioFitness]
    : [for (final m in Muscle.values) if (m.group == g && m != Muscle.hipFlexors) m.label];

/// 이 운동이 [g] 안에서 주로 쓰는 세부 부위(유산소는 칼로리 소모/체력 증진 중 하나).
Set<String> subsOf(Exercise ex, MuscleGroup g) {
  if (g == MuscleGroup.cardio || ex.loadType == LoadType.cardio) {
    return {_intervalIds.contains(ex.id) || ex.name.contains('인터벌') ? cardioFitness : cardioBurn};
  }
  final all = subLabels(g);
  final out = {for (final m in musclesFor(ex).primary) if (m.group == g && all.contains(m.label)) m.label};
  if (out.isEmpty && all.isNotEmpty) out.add(all.first);
  return out;
}

/// 한눈에 보기에서 세는 운동(워밍업·나만 빼기 제외).
bool countsInOverview(PlannedExercise p) => !p.warmup && !p.skipMine;

/// 부위별 운동 수와 세부 부위별 운동 수.
class GroupTally {
  GroupTally(this.group);
  final MuscleGroup group;
  int exercises = 0;
  int sets = 0;

  /// 유산소 총 분.
  int minutes = 0;
  final Map<String, int> subs = {};

  /// '운동 3개 · 12세트' / 유산소는 '20분'.
  String get amount => group == MuscleGroup.cardio ? '$minutes분' : '운동 $exercises개 · $sets세트';

  /// '윗가슴 2 · 아랫가슴 1'
  String get subText => [for (final e in subs.entries) e.value > 1 ? '${e.key} ${e.value}' : e.key].join(' · ');
}

/// 날짜가 안 된 루틴을 구성으로만 한 줄: '가슴 3개·12세트 · 삼두 … · 유산소 20분'.
String compositionLine(DayPlan plan) => [
      for (final t in tallyPlan(plan).values)
        if (t.exercises > 0)
          t.group == MuscleGroup.cardio ? '${t.group.label} ${t.minutes}분' : '${t.group.label} ${t.exercises}개·${t.sets}세트',
    ].join(' · ');

Map<MuscleGroup, GroupTally> tallyPlan(DayPlan plan) {
  final out = {for (final g in overviewGroups) g: GroupTally(g)};
  for (final p in plan.exercises) {
    if (!countsInOverview(p)) continue;
    final ex = exerciseById(p.exerciseId);
    if (ex == null) continue;
    final g = ex.loadType == LoadType.cardio ? MuscleGroup.cardio : p.effectiveGroup;
    final t = out[g]!;
    t.exercises++;
    t.sets += p.sets.length;
    if (g == MuscleGroup.cardio) t.minutes += p.sets.fold<int>(0, (a, s) => a + s.targetReps);
    for (final s in subsOf(ex, g)) {
      t.subs[s] = (t.subs[s] ?? 0) + 1;
    }
  }
  return out;
}
