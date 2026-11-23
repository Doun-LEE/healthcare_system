import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';

String _md(DateTime d) => '${d.month}/${d.day}';

/// 내 정보: 각성모드 시작(기간 고르기) / 진행 중 표시. 시작하면 끝날 때까지 끌 수 없다.
class AwakenCard extends StatelessWidget {
  const AwakenCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final u = state.currentUser;
    if (u == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (state.awakening) {
      final left = dateOnly(u.awakenTo!).difference(state.today).inDays + 1;
      return Card(
        color: cs.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('🔥 각성모드 진행 중', style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.onErrorContainer)),
            const SizedBox(height: 4),
            Text(
              '${_md(u.awakenFrom!)} ~ ${_md(u.awakenTo!)} · $left일 남음 · 남은 운동 ${state.awakenLeft}일\n'
              '끝날 때까지 루틴을 빼거나 바꿀 수 없고, 쉬면 남은 휴식일로 옮겨서 다 끝내요.',
              style: text.bodySmall?.copyWith(color: cs.onErrorContainer),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('기간 늘리기'),
                onPressed: () => _extend(context, state),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.tune),
                label: const Text('남은 루틴 무게 다시 맞추기'),
                onPressed: () async {
                  final n = await state.rebalanceAwakenWeights();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(n == 0 ? '이미 지금 기준에 맞는 무게예요.' : '$n일 루틴 무게를 다시 맞췄어요. 운동·세트는 그대로예요.'),
                  ));
                },
              ),
            ]),
          ]),
        ),
      );
    }
    return Card(
      child: ListTile(
        leading: const Text('🔥', style: TextStyle(fontSize: 24)),
        title: const Text('각성모드'),
        subtitle: const Text('정한 기간 동안 나한테만 집중. 루틴은 빼는 것 없이 다 끝내요.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _start(context, state),
      ),
    );
  }

  Future<void> _extend(BuildContext context, AppState state) async {
    final u = state.currentUser!;
    final days = await showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('🔥 각성모드 기간 늘리기'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('늘린 만큼은 다시 줄일 수 없어요.', style: TextStyle(fontSize: 13)),
          ),
          for (final (d, label) in [(7, '1주'), (14, '2주'), (28, '4주')])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, d),
              child: Text('$label 더 (~${_md(dateOnly(u.awakenTo!).add(Duration(days: d)))})'),
            ),
        ],
      ),
    );
    if (days == null) return;
    await state.extendAwakening(days);
  }

  Future<void> _start(BuildContext context, AppState state) async {
    final days = await showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('🔥 각성모드 기간'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              '• 기간 동안 루틴(운동·세트·부위)을 빼거나 바꿀 수 없어요\n'
              '• 파트너 운동 없이 나한테만 집중해요\n'
              '• 일이 생기면 쉬어도 되지만, 그 루틴은 남은 휴식일로 옮겨서 기간 안에 다 끝내요\n'
              '• 시작하면 기간이 끝날 때까지 끌 수 없어요',
              style: TextStyle(fontSize: 13),
            ),
          ),
          for (final (d, label) in [(7, '1주'), (14, '2주'), (28, '4주'), (56, '8주')])
            SimpleDialogOption(onPressed: () => Navigator.pop(c, d), child: Text('$label ($d일)')),
        ],
      ),
    );
    if (days == null || !context.mounted) return;
    final end = state.today.add(Duration(days: days - 1));
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('정말 시작할까요?'),
        content: Text('${_md(state.today)} ~ ${_md(end)} 동안 끌 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('각성 시작')),
        ],
      ),
    );
    if (ok != true) return;
    await state.startAwakening(days);
  }
}

/// 각성모드 기간인 날 루틴 위에 보이는 띠.
class AwakenBanner extends StatelessWidget {
  const AwakenBanner({super.key, required this.plan});
  final DayPlan plan;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.awakeningOn(plan.date) || plan.isFinished) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final u = state.currentUser!;
    final left = dateOnly(u.awakenTo!).difference(state.today).inDays + 1;
    return Card(
      color: cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Text(
          '🔥 각성모드 · $left일 남음 · 빼는 것 없이 전부. 모든 세트를 끝내야 완료할 수 있어요.',
          style: TextStyle(color: cs.onErrorContainer, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
