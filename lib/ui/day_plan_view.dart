import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/catalog.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'widgets/exercise_sheet.dart';
import 'widgets/rest_timer.dart';

/// 하루 계획 상세. 오늘 화면과 달력 상세에서 공용으로 쓴다.
/// 세트 체크, 횟수/무게 수정, 세트 추가, 운동 교체/삭제, 완료 처리.
class DayPlanView extends StatelessWidget {
  const DayPlanView({super.key, required this.plan, this.editable = true});
  final DayPlan plan;
  final bool editable;

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
        const SizedBox(height: 8),
        for (final pe in plan.exercises)
          _ExerciseCard(plan: plan, pe: pe, editable: editable && !plan.isFinished),
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
        if (editable && !plan.isFinished && plan.exercises.isNotEmpty)
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
            if (editable)
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
    final msgs = await state.finishDay(plan);
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
            Text(plan.title ?? '운동', style: text.titleLarge?.copyWith(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold)),
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
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.plan, required this.pe, required this.editable});
  final DayPlan plan;
  final PlannedExercise pe;
  final bool editable;

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
                editable: editable,
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
    final reps = TextEditingController(text: s.effectiveReps.toString());
    final weight = TextEditingController(text: _fmt(s.effectiveWeight));
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${i + 1}세트 실제 수행'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('처방: ${showWeight ? '${_fmt(s.targetWeight)}kg × ' : ''}${s.targetReps}$unit',
                style: TextStyle(color: Theme.of(c).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            TextField(
              controller: reps,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '실제 $unit'),
            ),
            if (showWeight) ...[
              const SizedBox(height: 8),
              TextField(
                controller: weight,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: '실제 무게 (kg)'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('저장 + 완료')),
        ],
      ),
    );
    if (ok == true) {
      await state.updateSet(plan, pe, i,
          reps: int.tryParse(reps.text),
          weight: showWeight ? double.tryParse(weight.text) : null,
          completed: true);
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
