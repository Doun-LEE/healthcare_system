import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/partner.dart';
import '../../state/app_state.dart';

/// 내 정보 화면의 파트너 섹션: 이메일로 추가, 목록, 삭제.
class PartnerSection extends StatelessWidget {
  const PartnerSection({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (!state.cloudSignedIn) {
      return Text('계정에 로그인하면 파트너를 등록해 같이 운동할 루틴을 만들 수 있어요.',
          style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('파트너도 이 앱에 로그인한 적이 있어야 찾을 수 있어요.',
            style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        for (final p in state.partners)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text(p.name.isEmpty ? '?' : p.name.characters.first)),
            title: Text(p.name.isEmpty ? p.email : p.name),
            subtitle: Text(p.email),
            trailing: IconButton(
              icon: const Icon(Icons.person_remove_outlined),
              tooltip: '파트너 삭제',
              onPressed: () => state.removePartner(p.uid),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => _add(context, state),
          icon: const Icon(Icons.person_add_alt),
          label: const Text('이메일로 파트너 추가'),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context, AppState state) async {
    final c = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('파트너 이메일'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'friend@gmail.com'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('찾기')),
        ],
      ),
    );
    if (email == null || email.trim().isEmpty || !context.mounted) return;
    final msg = await state.addPartner(email);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// 오늘 화면 상단: 파트너가 보낸 루틴 제안.
class InboxBanner extends StatelessWidget {
  const InboxBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.inbox.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final item in state.inbox)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.group, color: cs.onPrimaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${item.fromName} 님이 ${item.date.month}/${item.date.day} 같이 할 루틴을 보냈어요',
                          style: text.bodyMedium?.copyWith(color: cs.onPrimaryContainer, fontWeight: FontWeight.w600)),
                      Text(item.title, style: text.bodySmall?.copyWith(color: cs.onPrimaryContainer)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => state.dismissInbox(item),
                  child: const Text('무시'),
                ),
                FilledButton(
                  onPressed: () async {
                    final msg = await state.applyInbox(item);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                  },
                  child: const Text('적용'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// "파트너와 운동" 선택 시트. 파트너를 고르면 공통 루틴을 만든다.
Future<void> showPartnerPicker(BuildContext context, DateTime date) async {
  final state = context.read<AppState>();
  if (!state.cloudSignedIn) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('계정에 로그인해야 파트너 운동을 쓸 수 있어요.')));
    return;
  }
  if (state.partners.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('내 정보 → 파트너에서 먼저 파트너를 추가하세요.')));
    return;
  }
  final chosen = await showModalBottomSheet<PartnerLink>(
    context: context,
    showDragHandle: true,
    builder: (c) => ListView(
      shrinkWrap: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text('누구와 같이 운동하나요?', style: Theme.of(c).textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('두 사람의 오늘 부위와 보유 기구를 맞춘 루틴을 만들고, 무게는 각자 기준으로 표시합니다. 파트너 앱에도 같은 루틴이 전송돼요.',
              style: Theme.of(c).textTheme.bodySmall?.copyWith(color: Theme.of(c).colorScheme.onSurfaceVariant)),
        ),
        for (final p in state.partners)
          ListTile(
            leading: CircleAvatar(child: Text(p.name.isEmpty ? '?' : p.name.characters.first)),
            title: Text(p.name.isEmpty ? p.email : p.name),
            subtitle: Text(p.email),
            onTap: () => Navigator.pop(c, p),
          ),
        const SizedBox(height: 12),
      ],
    ),
  );
  if (chosen == null || !context.mounted) return;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(children: [
        CircularProgressIndicator(),
        SizedBox(width: 16),
        Expanded(child: Text('파트너 정보를 받아 루틴을 맞추는 중…')),
      ]),
    ),
  );
  String msg;
  try {
    msg = await state.generateJointSession(date, chosen);
  } catch (e) {
    msg = '파트너 루틴 생성 실패: $e';
  }
  if (!context.mounted) return;
  Navigator.pop(context);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
