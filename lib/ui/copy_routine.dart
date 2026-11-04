import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/catalog.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'day_plan_view.dart';
import 'widgets/app_sheet.dart';

/// 며칠 전 내 루틴을 골라 [date]에 그대로 넣는다.
Future<void> copyPastRoutineDialog(BuildContext context, DateTime date) async {
  final state = context.read<AppState>();
  final list = state.pastRoutines();
  if (list.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('최근 60일 안에 가져올 운동 기록이 없어요.')));
    return;
  }
  final picked = await showAppSheet<DayPlan>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PastRoutineSheet(plans: list, target: date),
  );
  if (picked == null || !context.mounted) return;
  if (!await confirmRebuildIfStarted(context, state.planOn(date))) return;
  final plan = await state.copyRoutineFrom(picked, date);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(plan == null
        ? '가져오지 못했어요. 그날은 이미 완료한 날이에요.'
        : '${date.month}/${date.day}에 ${picked.date.month}/${picked.date.day} 루틴 ${plan.exercises.length}개 운동을 그대로 넣었어요.'),
  ));
}

class _PastRoutineSheet extends StatelessWidget {
  const _PastRoutineSheet({required this.plans, required this.target});
  final List<DayPlan> plans;
  final DateTime target;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text('지난 루틴 그대로 가져오기', style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('${target.month}/${target.day}에 넣을 날을 고르세요. 운동·순서·세트는 그대로, 실제로 한 세트는 그때 한 횟수·무게로 들어가요.',
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: ListView.separated(
              controller: scroll,
              itemCount: plans.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = plans[i];
                final main = p.exercises.where((e) => !e.warmup).toList();
                final names = main.map((e) => exerciseById(e.exerciseId)?.name ?? e.exerciseId).join(', ');
                final sets = main.fold<int>(0, (a, e) => a + e.sets.length);
                return ListTile(
                  onTap: () => Navigator.pop(context, p),
                  leading: CircleAvatar(
                    backgroundColor: p.isFinished ? cs.primaryContainer : cs.surfaceContainerHighest,
                    child: Icon(p.isFinished ? Icons.check : Icons.event_note, color: p.isFinished ? cs.onPrimaryContainer : cs.onSurfaceVariant, size: 20),
                  ),
                  title: Text('${p.date.month}/${p.date.day} (${wd[p.date.weekday - 1]}) · ${p.displayTitle}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${main.length}개 운동 · $sets세트${p.isFinished ? '' : ' · 계획만'}\n$names', maxLines: 2, overflow: TextOverflow.ellipsis),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
