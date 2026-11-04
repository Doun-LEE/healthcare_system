import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';

/// 연결된 친구 헬스장의 기구가 바뀌었을 때 "동기화할까요?"를 묻는 카드.
/// 자동으로 바꾸지 않는다. '동기화'를 눌러야 반영되고, '이번엔 안 함'이면 다음 수정 때 다시 묻는다.
class GymUpdateBanner extends StatelessWidget {
  const GymUpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.gymUpdates;
    if (list.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(children: [
      for (final u in list)
        Card(
          margin: const EdgeInsets.only(bottom: 6),
          color: cs.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.sync, color: cs.onSecondaryContainer, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${u.friendName} 님이 ${u.gym.name} 기구를 수정했어요',
                      style: text.titleSmall?.copyWith(color: cs.onSecondaryContainer, fontWeight: FontWeight.w700)),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 2),
                child: Text('${u.summary} · 동기화하면 내 ${u.gym.name} 기구가 ${u.friendName} 님 것과 같아져요(내 사진은 유지).',
                    style: text.bodySmall?.copyWith(color: cs.onSecondaryContainer)),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: () => state.declineGymUpdate(u),
                  child: const Text('이번엔 안 함'),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: () async {
                    await state.acceptGymUpdate(u);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${u.gym.name} 기구를 ${u.friendName} 님 데이터로 맞췄어요. 이전 상태는 백업에 있어요.')));
                    }
                  },
                  child: const Text('동기화'),
                ),
              ]),
            ]),
          ),
        ),
    ]);
  }
}
