import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/cloud_sync.dart';
import '../../state/app_state.dart';

/// 게임 세이브처럼 기록을 저장하고 불러온다. 하루 한 번 자동 저장도 된다.
class BackupSection extends StatefulWidget {
  const BackupSection({super.key});

  @override
  State<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<BackupSection> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().refreshBackups());
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('실패했어요: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _when(DateTime t) =>
      '${t.year}.${t.month}.${t.day} ${t.hour}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final text = Theme.of(context).textTheme;
    if (!state.cloudSignedIn) {
      return const Text('계정에 로그인하면 기록을 클라우드에 저장하고 불러올 수 있어요.');
    }
    final list = state.backups;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('하루 한 번 앱을 열 때 자동으로 저장돼요(최근 10개). 중요한 날엔 직접 저장해 두세요.',
          style: text.bodySmall),
      const SizedBox(height: 8),
      FilledButton.icon(
        icon: _busy
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.save_outlined),
        label: const Text('지금 저장하기'),
        onPressed: _busy
            ? null
            : () async {
                final ctrl = TextEditingController();
                final name = await showDialog<String>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('지금 기록 저장'),
                    content: TextField(
                      controller: ctrl,
                      autofocus: true,
                      decoration: const InputDecoration(hintText: '이름 (예: 보스턴짐 기구 정리 후)'),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c), child: const Text('취소')),
                      FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('저장')),
                    ],
                  ),
                );
                if (name == null || !context.mounted) return;
                final messenger = ScaffoldMessenger.of(context);
                await _run(() async {
                  await state.saveBackup(label: name);
                  messenger.showSnackBar(const SnackBar(content: Text('저장했어요.')));
                });
              },
      ),
      const SizedBox(height: 8),
      if (list.isEmpty) Text('아직 저장된 기록이 없어요.', style: text.bodySmall),
      for (final b in list)
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: Icon(b.auto ? Icons.history : Icons.bookmark_outline),
          title: Text(b.label),
          subtitle: Text('${_when(b.at)} · 완료한 운동 ${b.workouts}일 · 헬스장 ${b.gyms}곳'),
          trailing: PopupMenuButton<String>(
            enabled: !_busy,
            onSelected: (v) async {
              if (v == 'restore') await _restore(state, b);
              if (v == 'delete') await _run(() => state.deleteBackup(b));
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'restore', child: Text('불러오기')),
              PopupMenuItem(value: 'delete', child: Text('지우기')),
            ],
          ),
        ),
    ]);
  }

  Future<void> _restore(AppState state, BackupInfo b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('이 저장본을 불러올까요?'),
        content: Text('${b.label} (${_when(b.at)})\n\n'
            '헬스장·설정·루틴이 이 시점으로 돌아가요. 지금 상태는 먼저 자동 저장해 두니 언제든 되돌릴 수 있어요. '
            '그 뒤에 한 운동 기록은 지워지지 않고 합쳐져요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('불러오기')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      final done = await state.restoreBackup(b);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done ? '불러왔어요.' : '불러오지 못했어요.')));
      }
    });
  }
}
