import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/catalog.dart';
import '../engine/splits.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'widgets/condition_card.dart';
import 'widgets/exercise_sheet.dart';
import 'widgets/rest_timer.dart';
import 'widgets/set_editor.dart';

/// 공유 코드 붙여넣기 → 해당 날짜로 가져오기. 오늘/달력 화면에서 공용.
Future<void> importRoutineDialog(BuildContext context, DateTime date) async {
  final state = context.read<AppState>();
  final c = TextEditingController();
  final clip = await Clipboard.getData('text/plain');
  if (clip?.text != null && clip!.text!.contains('FR1:')) c.text = clip.text!;
  if (!context.mounted) return;
  final code = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('루틴 불러오기'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('친구가 보낸 공유 코드(FR1:…)를 붙여넣으세요. 운동·세트·횟수는 그대로, 무게는 내 기준으로 바뀝니다.'),
          const SizedBox(height: 10),
          TextField(controller: c, maxLines: 4, autofocus: true, decoration: const InputDecoration(hintText: 'FR1:…')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('가져오기')),
      ],
    ),
  );
  if (code == null || code.trim().isEmpty || !context.mounted) return;
  final plan = await state.importRoutine(code, date);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(plan == null
        ? '코드를 읽지 못했어요. 전체를 그대로 붙여넣었는지 확인하세요.'
        : '${date.month}/${date.day}에 "${plan.title}" ${plan.exercises.length}개 운동을 넣었어요.'),
  ));
}

/// 그날의 부위를 바꾼다: 분할 템플릿의 다른 날을 고르거나 부위를 직접 선택.
/// "이후 날짜도 이어서 재배치"를 켜면 분할 순서가 그날부터 다시 이어진다.
Future<void> changeDayFocusDialog(BuildContext context, DayPlan plan) async {
  final state = context.read<AppState>();
  final user = state.currentUser;
  if (user == null) return;
  final cycle = splitCycles[user.splitDays.clamp(1, 6)]!;
  final custom = <MuscleGroup>{...plan.focus};
  var shift = true;

  final result = await showModalBottomSheet<(List<MuscleGroup>, String?, bool)>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setSheet) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${plan.date.month}/${plan.date.day} 부위 바꾸기', style: Theme.of(c).textTheme.titleLarge),
            Text('예: 오늘이 하체 날인데 가슴을 하고 싶으면 "밀기"를 고르세요.',
                style: Theme.of(c).textTheme.bodySmall?.copyWith(color: Theme.of(c).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            Text('내 ${user.splitDays}분할의 날', style: Theme.of(c).textTheme.labelLarge),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final d in cycle)
                  ActionChip(
                    label: Text(d.title),
                    onPressed: () => Navigator.pop(c, (d.groups, d.title, shift)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('또는 부위 직접 선택', style: Theme.of(c).textTheme.labelLarge),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final g in MuscleGroup.values)
                  FilterChip(
                    label: Text(g.label),
                    selected: custom.contains(g),
                    onSelected: (v) => setSheet(() => v ? custom.add(g) : custom.remove(g)),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: shift,
              title: const Text('이후 날짜도 이어서 재배치'),
              subtitle: const Text('분할 순서가 이 날부터 다시 이어집니다 (완료한 날은 그대로)'),
              onChanged: (v) => setSheet(() => shift = v),
            ),
            const SizedBox(height: 4),
            FilledButton(
              onPressed: custom.isEmpty ? null : () => Navigator.pop(c, (custom.toList(), null, shift)),
              child: const Text('선택한 부위로 다시 만들기'),
            ),
          ],
        ),
      ),
    ),
  );
  if (result == null || !context.mounted) return;
  final (groups, title, doShift) = result;
  await state.changeDayFocus(plan.date, groups, title: title, shiftFollowing: doShift);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${plan.date.month}/${plan.date.day} 루틴을 ${title ?? groups.map((g) => g.label).join('·')}(으)로 바꿨어요${doShift ? ' · 이후 날짜 재배치됨' : ''}.'),
    ));
  }
}

Future<void> shareRoutine(BuildContext context, DayPlan plan) async {
  final state = context.read<AppState>();
  final code = state.shareCode(plan);
  final text = '[FitRoutine] ${plan.title ?? '루틴'} · ${plan.exercises.length}개 운동\n'
      '앱에서 "루틴 불러오기"에 아래 코드를 붙여넣으세요.\n$code';
  await Clipboard.setData(ClipboardData(text: text));
  try {
    await SharePlus.instance.share(ShareParams(text: text, subject: 'FitRoutine 루틴 공유'));
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('공유 코드를 클립보드에 복사했어요.')));
    }
  }
}

/// 하루 계획 상세. 오늘 화면과 달력 상세에서 공용으로 쓴다.
/// 세트 체크, 횟수/무게 수정, 세트 추가, 운동 교체/삭제, 완료 처리.
class DayPlanView extends StatelessWidget {
  const DayPlanView({super.key, required this.plan, this.editable = true, bool? logging})
      : logging = logging ?? editable;
  final DayPlan plan;

  /// 운동 교체/제외/세트 추가/부위 바꾸기 허용.
  final bool editable;

  /// 세트 체크·실제 수행 입력·완료 허용 (오늘/과거만).
  final bool logging;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (plan.isRest) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.self_improvement, size: 72, color: cs.tertiary),
            const SizedBox(height: 12),
            Text('휴식일', style: text.headlineSmall),
            const SizedBox(height: 4),
            Text(plan.title ?? '', style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            const Text('잘 쉬는 것도 운동입니다. 스트레칭·수면·단백질.'),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _Header(plan: plan),
        if (logging && !plan.isFinished && plan.exercises.isNotEmpty && !plan.exercises.any((e) => e.anyCompleted))
          ConditionCard(key: ValueKey('cond-${plan.id}-${plan.loadFactor}-${plan.estimatedMinutes}'), plan: plan),
        const SizedBox(height: 8),
        for (final pe in plan.exercises)
          _ExerciseCard(plan: plan, pe: pe, editable: editable && !plan.isFinished, logging: logging && !plan.isFinished),
        if (plan.exercises.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '보유 기구로 할 수 있는 운동이 없습니다. 헬스장 탭에서 기구를 추가하세요.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: 16),
        if (logging && !plan.isFinished && plan.exercises.isNotEmpty)
          FilledButton.icon(
            onPressed: () => _finish(context, state),
            icon: const Icon(Icons.flag),
            label: Text('운동 완료 (${(plan.completionRatio * 100).round()}%)'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        if (plan.isFinished)
          Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_circle, color: cs.primary),
              const SizedBox(width: 8),
              Text('완료됨 · ${(plan.completionRatio * 100).round()}% 수행', style: text.titleMedium),
            ]),
            if (plan.rpe != null)
              Text('체감 강도 ${plan.rpe}/10 · ${rpeLabel(plan.rpe!)}',
                  style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            if (logging)
              TextButton(
                onPressed: () => state.reopenDay(plan),
                child: const Text('다시 열기'),
              ),
          ]),
      ],
    );
  }

  Future<void> _finish(BuildContext context, AppState state) async {
    final ratio = plan.completionRatio;
    if (ratio < 1.0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('아직 체크하지 않은 세트가 있어요'),
          content: Text('${(ratio * 100).round()}%만 완료했습니다. 지금 끝낼까요? 안 한 세트는 실패로 기록돼 다음 강도 조절에 반영됩니다.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('계속 운동')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('끝내기')),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (!context.mounted) return;
    final rpe = await showRpePicker(context);
    if (!context.mounted) return;
    final msgs = await state.finishDay(plan, rpe: rpe);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('수고했어요! 다음 루틴 반영'),
        content: SizedBox(
          width: double.maxFinite,
          child: msgs.isEmpty
              ? const Text('수행한 세트가 없어 강도는 그대로 유지됩니다.')
              : ListView(
                  shrinkWrap: true,
                  children: msgs
                      .map((m) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text('• $m'),
                          ))
                      .toList(),
                ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('확인'))],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.plan});
  final DayPlan plan;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(plan.title ?? '운동',
                      style: text.titleLarge?.copyWith(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold)),
                ),
                if (!plan.isFinished)
                  IconButton(
                    tooltip: '부위 바꾸기',
                    icon: Icon(Icons.swap_horiz, color: cs.onPrimaryContainer),
                    onPressed: () => changeDayFocusDialog(context, plan),
                  ),
                if (plan.exercises.isNotEmpty)
                  IconButton(
                    tooltip: '루틴 공유 (파트너와 같은 운동)',
                    icon: Icon(Icons.share, color: cs.onPrimaryContainer),
                    onPressed: () => shareRoutine(context, plan),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final g in plan.focus)
                  Chip(label: Text(g.label), visualDensity: VisualDensity.compact),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.schedule, size: 16, color: cs.onPrimaryContainer),
              const SizedBox(width: 4),
              Text('예상 ${plan.estimatedMinutes}분 · ${plan.exercises.length}개 운동',
                  style: text.bodyMedium?.copyWith(color: cs.onPrimaryContainer)),
              if (plan.intensityFactor < 1.0) ...[
                const SizedBox(width: 10),
                Icon(Icons.battery_3_bar, size: 16, color: cs.onPrimaryContainer),
                Text(' 피로 누적 → 볼륨 ${(plan.intensityFactor * 100).round()}%',
                    style: text.bodySmall?.copyWith(color: cs.onPrimaryContainer)),
              ],
            ]),
            if (plan.condition != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  Icon(Icons.monitor_heart_outlined, size: 16, color: cs.onPrimaryContainer),
                  const SizedBox(width: 4),
                  Text('컨디션 ${plan.condition}/10 · 무게 ${(plan.loadFactor * 100).round()}%',
                      style: text.bodyMedium?.copyWith(color: cs.onPrimaryContainer)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.plan, required this.pe, required this.editable, required this.logging});
  final DayPlan plan;
  final PlannedExercise pe;
  final bool editable;
  final bool logging;

  @override
  Widget build(BuildContext context) {
    final ex = exerciseById(pe.exerciseId);
    if (ex == null) return const SizedBox.shrink();
    final state = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isCardio = ex.loadType == LoadType.cardio;
    final isBw = ex.loadType == LoadType.bodyweight;
    final unit = isCardio ? '분' : (ex.id == 'plank' ? '초' : '회');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => ExerciseSheet.show(context, ex, pe.equipmentType),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(ex.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(width: 6),
                          Icon(Icons.view_in_ar, size: 16, color: cs.primary),
                        ]),
                        Text('${pe.equipmentType.label} · ${ex.group.label}${pe.restSeconds > 0 ? ' · 휴식 ${pe.restSeconds}초' : ''}',
                            style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        if (pe.note != null && pe.note!.isNotEmpty)
                          Text(pe.note!, style: text.bodySmall?.copyWith(color: cs.tertiary)),
                        if (plan.partnerName != null && plan.partnerWeights.containsKey(pe.exerciseId) && !isCardio)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(children: [
                              Icon(Icons.group, size: 14, color: cs.secondary),
                              const SizedBox(width: 4),
                              Text(
                                isBw
                                    ? '${plan.partnerName}: 같은 횟수'
                                    : '${plan.partnerName}: ${_fmt(plan.partnerWeights[pe.exerciseId]!)}kg',
                                style: text.bodySmall?.copyWith(color: cs.secondary, fontWeight: FontWeight.w600),
                              ),
                            ]),
                          ),
                      ],
                    ),
                  ),
                ),
                if (editable)
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      switch (v) {
                        case 'swap':
                          await _swap(context, state, ex);
                        case 'add':
                          await state.addSet(plan, pe);
                        case 'remove':
                          await state.removeExercise(plan, pe);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'swap', child: Text('다른 운동으로 교체')),
                      PopupMenuItem(value: 'add', child: Text('세트 추가')),
                      PopupMenuItem(value: 'remove', child: Text('이 운동 제외')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < pe.sets.length; i++)
              _SetRow(
                index: i,
                set: pe.sets[i],
                unit: unit,
                showWeight: !isCardio && !isBw,
                editable: logging,
                onToggle: () async {
                  await state.toggleSet(plan, pe, i);
                  if (pe.sets[i].completed && pe.restSeconds > 0 && i < pe.sets.length - 1 && context.mounted) {
                    RestTimerSheet.show(context, pe.restSeconds);
                  }
                },
                onEdit: () => _editSet(context, state, i, unit, !isCardio && !isBw),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editSet(BuildContext context, AppState state, int i, String unit, bool showWeight) async {
    final s = pe.sets[i];
    final ex = exerciseById(pe.exerciseId);
    final result = await SetEditorSheet.show(
      context,
      title: '${ex?.name ?? ''} ${i + 1}세트 실제 수행',
      targetReps: s.targetReps,
      targetWeight: s.targetWeight,
      initialReps: s.effectiveReps,
      initialWeight: s.effectiveWeight,
      weightStep: ex?.loadType.increment ?? 2.5,
      unit: unit,
      showWeight: showWeight,
    );
    if (result != null) {
      await state.updateSet(plan, pe, i,
          reps: result.$1, weight: showWeight ? result.$2 : null, completed: true);
    }
  }

  Future<void> _swap(BuildContext context, AppState state, Exercise ex) async {
    final options = exercisesOf(ex.group)
        .where((e) => e.id != ex.id && e.canDoWith(state.availableEquipment))
        .toList();
    final chosen = await showModalBottomSheet<Exercise>(
      context: context,
      showDragHandle: true,
      builder: (c) => ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('${ex.group.label} 운동으로 교체', style: Theme.of(c).textTheme.titleMedium),
          ),
          for (final e in options)
            ListTile(
              title: Text(e.name),
              subtitle: Text(e.emphasis.join(' · ')),
              trailing: Text(e.pickEquipment(state.availableEquipment).label,
                  style: Theme.of(c).textTheme.bodySmall),
              onTap: () => Navigator.pop(c, e),
            ),
          if (options.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('교체 가능한 운동이 없습니다.')),
        ],
      ),
    );
    if (chosen != null) await state.swapExercise(plan, pe, chosen);
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.index,
    required this.set,
    required this.unit,
    required this.showWeight,
    required this.editable,
    required this.onToggle,
    required this.onEdit,
  });

  final int index;
  final SetEntry set;
  final String unit;
  final bool showWeight;
  final bool editable;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final changed = (set.doneReps != null && set.doneReps != set.targetReps) ||
        (set.doneWeight != null && set.doneWeight != set.targetWeight);
    final up = changed &&
        (set.effectiveReps > set.targetReps || set.effectiveWeight > set.targetWeight);

    return InkWell(
      onTap: editable ? onToggle : null,
      onLongPress: editable ? onEdit : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Checkbox(value: set.completed, onChanged: editable ? (_) => onToggle() : null),
            Text('${index + 1}세트', style: text.bodyMedium),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${showWeight ? '${_fmt(set.effectiveWeight)}kg × ' : ''}${set.effectiveReps}$unit',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: set.completed ? TextDecoration.lineThrough : null,
                  color: set.completed ? cs.onSurfaceVariant : cs.onSurface,
                ),
              ),
            ),
            if (changed)
              Icon(up ? Icons.trending_up : Icons.trending_down,
                  size: 18, color: up ? cs.primary : cs.error),
            if (editable)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: '실제 수행 입력',
                onPressed: onEdit,
              ),
          ],
        ),
      ),
    );
  }
}

String _fmt(double w) =>
    w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);

/// 오늘의 명언 배너.
class QuoteBanner extends StatelessWidget {
  const QuoteBanner({super.key, required this.quote});
  final String quote;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.format_quote, size: 18, color: cs.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(quote,
                style: text.bodyMedium?.copyWith(color: cs.onTertiaryContainer, fontStyle: FontStyle.italic)),
          ),
        ],
      ),
    );
  }
}
