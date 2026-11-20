import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../engine/alcohol.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';

String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// 그 날짜의 술 약속 넣기·지우기 + 보통 운동 시각.
Future<void> showDrinkSheet(BuildContext context, DateTime date) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => _DrinkSheet(date: dateOnly(date)),
  );
}

class _DrinkSheet extends StatelessWidget {
  const _DrinkSheet({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final drinks = state.drinksOn(date);
    final hour = state.currentUser?.workoutHour ?? 19;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${date.month}/${date.day} 술 약속', style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            '술자리 12시간 전부터 마시고 12시간 뒤까지는 루틴의 세트·무게를 자동으로 줄여요. 술자리는 시작부터 $drinkHours시간으로 쳐요.',
            style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          if (drinks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('이 날 술 약속이 없어요.', style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ),
          for (final d in drinks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_bar),
              title: Text('${_hm(d)} 시작'),
              trailing: IconButton(icon: const Icon(Icons.delete_outline), tooltip: '지우기', onPressed: () => state.removeDrink(d)),
            ),
          FilledButton.tonalIcon(
            onPressed: () async {
              final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 19, minute: 0), helpText: '술자리 시작 시간');
              if (t == null) return;
              await state.addDrink(DateTime(date.year, date.month, date.day, t.hour, t.minute));
            },
            icon: const Icon(Icons.add),
            label: const Text('술 약속 추가'),
          ),
          const Divider(height: 28),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: const Text('보통 운동하는 시간'),
            subtitle: const Text('술자리 전후 몇 시간인지 셀 때 써요. 운동을 시작하면 시작한 시간으로 세요.'),
            trailing: TextButton(
              onPressed: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: hour, minute: 0), helpText: '보통 운동하는 시간');
                if (t != null) await state.setWorkoutHour(t.hour);
              },
              child: Text('$hour시'),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 술자리 전후인 날 루틴 위에 보이는 안내.
class AlcoholBanner extends StatelessWidget {
  const AlcoholBanner({super.key, required this.plan});
  final DayPlan plan;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final a = state.alcoholFor(plan);
    if (a == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final cut = [
      if (a.volume < 1) '세트 ${(a.volume * 100).round()}%',
      if (a.load < 1) '무게 ${(a.load * 100).round()}%',
    ].join(' · ');
    return Card(
      color: a.restAdvised ? cs.errorContainer : cs.tertiaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showDrinkSheet(context, plan.date),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(top: 2), child: Text('🍺', style: TextStyle(fontSize: 18))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${a.label}${cut.isEmpty ? '' : ' · $cut로 맞췄어요'}', style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(a.tip, style: text.bodySmall),
                if (plan.isStarted || plan.exercises.any((e) => e.anyCompleted))
                  Text('이미 시작한 루틴은 그대로 둬요.', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
