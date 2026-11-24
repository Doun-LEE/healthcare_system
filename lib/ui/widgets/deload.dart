import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/catalog.dart';
import '../../engine/plateau.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';

String _md(DateTime d) => '${d.month}/${d.day}';
String _kg(double v) => v % 1 == 0 ? '${v.toInt()}' : v.toStringAsFixed(1);

/// 루틴 위: 디로드 주면 안내, 아니고 오늘이면 디로드 추천.
class DeloadBanner extends StatelessWidget {
  const DeloadBanner({super.key, required this.plan});
  final DayPlan plan;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (plan.isFinished || plan.isRest) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final u = state.currentUser;
    if (u != null && state.deloadOn(plan.date)) {
      return Card(
        color: cs.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('🪶 디로드 주 · ${_md(u.deloadTo!)}까지', style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(
              '세트 ${(deloadVolume * 100).round()}% · 무게 ${(deloadLoad * 100).round()}%로 가볍게 맞췄어요. 쌓인 피로를 빼는 주라 기준 무게는 안 깎여요. 다음 주에 더 잘 들려요.',
              style: text.bodySmall,
            ),
            if (dateOnly(plan.date) == state.today)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => _confirmEnd(context, state), child: const Text('디로드 그만하기')),
              ),
          ]),
        ),
      );
    }
    if (dateOnly(plan.date) != state.today || plan.isStarted || plan.exercises.any((e) => e.anyCompleted)) return const SizedBox.shrink();
    final s = state.deloadSuggestion;
    if (s == null) return const SizedBox.shrink();
    return DeloadSuggestCard(advice: s);
  }
}

Future<void> _confirmEnd(BuildContext context, AppState state) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('디로드 그만할까요?'),
      content: const Text('시작 안 한 루틴은 평소 세트·무게로 돌아가요.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('계속')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('그만하기')),
      ],
    ),
  );
  if (ok == true) await state.endDeload();
}

class DeloadSuggestCard extends StatelessWidget {
  const DeloadSuggestCard({super.key, required this.advice});
  final DeloadAdvice advice;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      color: cs.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('🪶 이번 주는 디로드 어때요?', style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          for (final r in advice.reasons) Text('• $r', style: text.bodySmall),
          const SizedBox(height: 2),
          Text(
            '일주일 동안 세트 ${(deloadVolume * 100).round()}% · 무게 ${(deloadLoad * 100).round()}%로 가볍게 하면 피로가 빠지고 정체가 풀리는 경우가 많아요.',
            style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: state.snoozeDeload, child: const Text('나중에')),
            FilledButton.tonal(onPressed: state.startDeload, child: const Text('일주일 디로드')),
          ]),
        ]),
      ),
    );
  }
}

/// 통계: 정체기 운동 + 디로드 상태.
class PlateauSection extends StatelessWidget {
  const PlateauSection({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final u = state.currentUser;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final list = state.plateaus;
    final suggest = state.deloadSuggestion;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (state.deloading && u != null)
        Row(children: [
          Expanded(child: Text('🪶 디로드 중 · ${_md(u.deloadTo!)}까지', style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
          TextButton(onPressed: () => _confirmEnd(context, state), child: const Text('그만하기')),
        ])
      else if (suggest != null)
        DeloadSuggestCard(advice: suggest),
      if (list.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text('정체된 운동이 없어요. 기록이 잘 오르고 있어요!', style: text.bodyMedium?.copyWith(color: cs.primary)),
        ),
      for (final p in list)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(exerciseById(p.exerciseId)?.name ?? p.exerciseId, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  '최고 ${_kg(p.best)}kg(추정 1RM, ${_md(p.bestAt)}) · ${p.weeksSince(state.today)}주째 · ${p.since}번 못 넘음',
                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ]),
            ),
            TextButton(onPressed: () => _confirmReset(context, state, p), child: const Text('10% 낮춰\n다시 쌓기', textAlign: TextAlign.center)),
          ]),
        ),
      const SizedBox(height: 4),
      Text(
        '정체기 = 최근 12주 최고 추정 1RM(무게×(1+횟수/30))을 3주 넘게, 3번 넘게 못 넘은 운동. 컨디션·술자리·디로드로 가볍게 한 날은 빼고 봐요.',
        style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      if (!state.deloading && suggest == null && !state.awakening)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: state.startDeload,
            icon: const Icon(Icons.spa_outlined, size: 18),
            label: const Text('지금 디로드 일주일'),
          ),
        ),
    ]);
  }

  Future<void> _confirmReset(BuildContext context, AppState state, Plateau p) async {
    final name = exerciseById(p.exerciseId)?.name ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('$name 낮춰서 다시 쌓기'),
        content: const Text('기준 무게를 10% 낮추고 다시 차근차근 올려요. 같은 무게에서 계속 막힐 때 자주 쓰는 방법이에요. 앞으로 짠 루틴의 이 운동 무게도 바로 맞춰요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('낮추기')),
        ],
      ),
    );
    if (ok == true) await state.resetPlateau(p.exerciseId);
  }
}
