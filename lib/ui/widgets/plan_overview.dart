import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/catalog.dart';
import '../../engine/plan_overview.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';

/// 오른쪽에서 끌어 여는 '한눈에 보기': 운동마다 몇 세트인지, 순서 바꾸기,
/// 부위별 운동 수(숫자를 바꾸면 그 부위 운동을 골라 추가·빼기), 세부 부위(윗가슴·광배·하복부…).
class PlanOverviewDrawer extends StatelessWidget {
  const PlanOverviewDrawer({super.key, required this.plan, this.editable = true});
  final DayPlan plan;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final canEdit = editable && !plan.isFinished;
    final active = [for (final e in plan.exercises) if (!e.skipMine) e];
    final tally = tallyPlan(plan);
    final totalSets = active.fold<int>(0, (a, e) => a + e.sets.length);
    final doneSets = active.fold<int>(0, (a, e) => a + e.sets.where((s) => s.completed).length);
    final width = min(MediaQuery.sizeOf(context).width * 0.9, 440.0);

    void toast(String m) {
      final ms = ScaffoldMessenger.of(context);
      ms.hideCurrentSnackBar();
      ms.showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2)));
    }

    Future<void> add(MuscleGroup g, {String? sub}) async {
      final ex = await state.addForGroup(plan, g, sub: sub);
      toast(ex == null ? '${sub ?? g.label}: 이 헬스장 기구로 더 넣을 운동이 없어요' : '${sub ?? g.label} · ${ex.name} 추가');
    }

    Future<void> remove(MuscleGroup g) async {
      final ok = await state.removeForGroup(plan, g);
      if (!ok) toast('${g.label}: 뺄 수 있는 운동이 없어요(이미 한 운동은 남겨요)');
    }

    final groupCard = Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('부위별 운동 수', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          Text(canEdit ? '+ 누르면 그 부위 운동을 골라 넣고, 세부 부위를 누르면 그 부위 운동을 넣어요.' : '부위·세부 부위별로 몇 개 하는지',
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          _WarmupRow(plan: plan, canEdit: canEdit, toast: toast),
          for (final g in overviewGroups)
            if (canEdit || tally[g]!.exercises > 0) _GroupRow(tally: tally[g]!, canEdit: canEdit, onAdd: add, onRemove: remove),
        ]),
      ),
    );

    final header = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('한눈에 보기', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text('운동 ${active.length}개 · $totalSets세트${doneSets > 0 ? ' (완료 $doneSets)' : ''} · 약 ${plan.estimatedMinutes}분',
                  style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ]),
          ),
          IconButton(tooltip: '닫기', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).maybePop()),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Text(canEdit ? '순서 · ≡ 끌어서 바꾸기' : '순서', style: text.labelLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
      ),
    ]);

    return Drawer(
      width: width,
      child: SafeArea(
        child: ReorderableListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          header: header,
          footer: Padding(padding: const EdgeInsets.only(top: 8), child: groupCard),
          buildDefaultDragHandles: false,
          itemCount: active.length,
          onReorderItem: (o, n) {
            if (!canEdit) return;
            final list = [...active];
            final item = list.removeAt(o);
            list.insert(n.clamp(0, list.length), item);
            state.reorderActive(plan, list);
          },
          proxyDecorator: (child, i, anim) => Material(color: Colors.transparent, elevation: 6, child: child),
          itemBuilder: (c, i) => _OrderRow(key: ObjectKey(active[i]), index: i, pe: active[i], canEdit: canEdit),
        ),
      ),
    );
  }
}

/// 워밍업(스트레칭·활성화) 개수: 부위 칸과 따로.
class _WarmupRow extends StatelessWidget {
  const _WarmupRow({required this.plan, required this.canEdit, required this.toast});
  final DayPlan plan;
  final bool canEdit;
  final void Function(String m) toast;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final ws = [for (final e in plan.exercises) if (e.warmup && !e.skipMine) e];
    final n = ws.length;
    if (!canEdit && n == 0) return const SizedBox.shrink();
    final names = [for (final e in ws) exerciseById(e.exerciseId)?.name ?? ''].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(
            width: 56,
            child: Text('워밍업', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: n > 0 ? cs.onSurface : cs.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(n == 0 ? '없음' : '${ws.fold<int>(0, (a, e) => a + e.sets.length)}세트', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ),
          if (canEdit)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '워밍업 빼기',
              onPressed: n == 0
                  ? null
                  : () async {
                      if (!await state.removeWarmup(plan)) toast('뺄 수 있는 워밍업이 없어요(이미 한 건 남겨요)');
                    },
              icon: const Icon(Icons.remove_circle_outline),
            ),
          SizedBox(
            width: 28,
            child: Text('$n', textAlign: TextAlign.center, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
          if (canEdit)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '워밍업 추가',
              onPressed: () async {
                final ex = await state.addWarmup(plan);
                toast(ex == null ? '이 헬스장 기구로 더 넣을 워밍업이 없어요' : '워밍업 · ${ex.name} 추가');
              },
              icon: Icon(Icons.add_circle, color: cs.primary),
            ),
        ]),
        if (names.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Text(names, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
      ]),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.tally, required this.canEdit, required this.onAdd, required this.onRemove});
  final GroupTally tally;
  final bool canEdit;
  final Future<void> Function(MuscleGroup g, {String? sub}) onAdd;
  final Future<void> Function(MuscleGroup g) onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final g = tally.group;
    final n = tally.exercises;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(
            width: 56,
            child: Text(g.label, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: n > 0 ? cs.onSurface : cs.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(n == 0 ? '없음' : '${tally.sets}세트', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ),
          if (canEdit)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '${g.label} 운동 빼기',
              onPressed: n == 0 ? null : () => onRemove(g),
              icon: const Icon(Icons.remove_circle_outline),
            ),
          SizedBox(
            width: 28,
            child: Text('$n', textAlign: TextAlign.center, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
          if (canEdit)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '${g.label} 운동 추가',
              onPressed: () => onAdd(g),
              icon: Icon(Icons.add_circle_outline, color: cs.primary),
            ),
        ]),
        Wrap(spacing: 6, runSpacing: 4, children: [
          for (final s in subLabels(g))
            if (canEdit || (tally.subs[s] ?? 0) > 0)
              _SubChip(label: s, count: tally.subs[s] ?? 0, onTap: canEdit ? () => onAdd(g, sub: s) : null),
        ]),
      ]),
    );
  }
}

class _SubChip extends StatelessWidget {
  const _SubChip({required this.label, required this.count, this.onTap});
  final String label;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final on = count > 0;
    return Material(
      color: on ? cs.primaryContainer : cs.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          child: Text(
            on ? '$label $count' : (onTap != null ? '+ $label' : label),
            style: TextStyle(
              fontSize: 12,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
              color: on ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({super.key, required this.index, required this.pe, required this.canEdit});
  final int index;
  final PlannedExercise pe;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final ex = exerciseById(pe.exerciseId);
    final g = ex?.loadType == LoadType.cardio ? MuscleGroup.cardio : pe.effectiveGroup;
    final subs = ex == null ? const <String>{} : subsOf(ex, g);
    final done = pe.sets.where((s) => s.completed).length;
    final all = pe.allCompleted && pe.sets.isNotEmpty;
    final isCardio = ex?.loadType == LoadType.cardio;
    final amount = isCardio
        ? '${pe.sets.fold<int>(0, (a, s) => a + s.targetReps)}분'
        : '${pe.sets.length}세트';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: all ? cs.primaryContainer.withValues(alpha: 0.35) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 0, 6),
          child: Row(children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: all ? cs.primary : cs.surfaceContainerHighest,
              child: all
                  ? Icon(Icons.check, size: 16, color: cs.onPrimary)
                  : Text('${index + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ex?.name ?? pe.exerciseId, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                Text('${pe.warmup ? '워밍업 · ' : ''}${g.label}${subs.isEmpty ? '' : ' · ${subs.join(', ')}'}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ]),
            ),
            const SizedBox(width: 6),
            Text(
              done > 0 && !all && !isCardio ? '$done/${pe.sets.length}세트' : amount,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: all ? cs.primary : null),
            ),
            if (canEdit)
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Icon(Icons.drag_handle, color: cs.onSurfaceVariant),
                ),
              )
            else
              const SizedBox(width: 12),
          ]),
        ),
      ),
    );
  }
}

/// 루틴 화면 오른쪽 가장자리의 작은 손잡이. 누르거나 왼쪽으로 끌면 한눈에 보기를 연다.
class OverviewEdgeTab extends StatelessWidget {
  const OverviewEdgeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    void open() {
      final s = Scaffold.maybeOf(context);
      if (s != null && s.hasEndDrawer && !s.isEndDrawerOpen) s.openEndDrawer();
    }
    return Semantics(
      button: true,
      label: '한눈에 보기 열기',
      child: GestureDetector(
        onTap: open,
        onHorizontalDragUpdate: (d) {
          if (d.delta.dx < -3) open();
        },
        child: Container(
          width: 26,
          height: 76,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.9),
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(-1, 1))],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.chevron_left, size: 18, color: cs.onPrimary),
            for (final ch in ['요', '약'])
              Text(ch, style: TextStyle(fontSize: 11, height: 1.1, fontWeight: FontWeight.w700, color: cs.onPrimary)),
          ]),
        ),
      ),
    );
  }
}
