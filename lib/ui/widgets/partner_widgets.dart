import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/partner.dart';
import '../../state/app_state.dart';

/// 내 정보 화면의 파트너 섹션: 이메일로 요청, 목록(대기중 표시), 삭제.
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
    final requests = state.inbox.where((i) => i.type == InboxType.partnerRequest).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('요청을 보내면 상대가 수락해야 파트너가 됩니다. 상대도 이 앱에 로그인한 적이 있어야 찾을 수 있어요.',
            style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        for (final r in requests) _RequestTile(item: r),
        for (final p in state.partners)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: p.pending ? cs.surfaceContainerHighest : null,
              child: Text(p.name.isEmpty ? '?' : p.name.characters.first),
            ),
            title: Text(p.name.isEmpty ? p.email : p.name),
            subtitle: Text(p.pending ? '${p.email} · 수락 대기 중' : p.email,
                style: TextStyle(color: p.pending ? cs.tertiary : null)),
            trailing: IconButton(
              icon: Icon(p.pending ? Icons.cancel_outlined : Icons.person_remove_outlined),
              tooltip: p.pending ? '요청 취소' : '파트너 삭제',
              onPressed: () => state.removePartner(p.uid),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => _add(context, state),
          icon: const Icon(Icons.person_add_alt),
          label: const Text('이메일로 파트너 요청'),
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
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('요청 보내기')),
        ],
      ),
    );
    if (email == null || email.trim().isEmpty || !context.mounted) return;
    final msg = await state.addPartner(email);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.item});
  final InboxItem item;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.person_add, color: cs.onPrimaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.fromName} 님의 파트너 요청', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onPrimaryContainer)),
                Text(item.fromEmail, style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer)),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              final m = await state.answerPartnerRequest(item, accept: false);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
            },
            child: const Text('거절'),
          ),
          FilledButton(
            onPressed: () async {
              final m = await state.answerPartnerRequest(item, accept: true);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
            },
            child: const Text('수락'),
          ),
        ],
      ),
    );
  }
}

/// 오늘 화면 상단: 파트너 요청과 루틴 제안.
class InboxBanner extends StatelessWidget {
  const InboxBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final notice = state.lastPartnerNotice;
    if (notice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notice)));
        state.lastPartnerNotice = null;
      });
    }
    if (state.inbox.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final item in state.inbox)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
            child: item.type == InboxType.partnerRequest
                ? Row(
                    children: [
                      Icon(Icons.person_add, color: cs.onPrimaryContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('${item.fromName} 님이 파트너 요청을 보냈어요',
                            style: text.bodyMedium?.copyWith(color: cs.onPrimaryContainer, fontWeight: FontWeight.w600)),
                      ),
                      TextButton(
                        onPressed: () async {
                          final m = await state.answerPartnerRequest(item, accept: false);
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
                        },
                        child: const Text('거절'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          final m = await state.answerPartnerRequest(item, accept: true);
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
                        },
                        child: const Text('수락'),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Icon(Icons.group, color: cs.onPrimaryContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${item.fromName} 님이 ${item.date?.month}/${item.date?.day} 같이 할 루틴을 보냈어요',
                                style: text.bodyMedium?.copyWith(color: cs.onPrimaryContainer, fontWeight: FontWeight.w600)),
                            Text(item.title, style: text.bodySmall?.copyWith(color: cs.onPrimaryContainer)),
                          ],
                        ),
                      ),
                      TextButton(onPressed: () => state.dismissInbox(item), child: const Text('무시')),
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

/// "파트너와 운동" 선택 시트. 파트너를 고르면 그 날짜의 공통 루틴을 만든다.
Future<void> showPartnerPicker(BuildContext context, DateTime date) async {
  final state = context.read<AppState>();
  if (!state.cloudSignedIn) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('계정에 로그인해야 파트너 운동을 쓸 수 있어요.')));
    return;
  }
  final ready = state.partners.where((p) => !p.pending).toList();
  if (ready.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('수락된 파트너가 없어요. 내 정보 → 운동 파트너에서 요청하세요.')));
    return;
  }
  final existing = state.planOn(date);
  final chosen = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    builder: (c) => ListView(
      shrinkWrap: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text('${date.month}/${date.day} 누구와 같이 운동하나요?', style: Theme.of(c).textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('두 사람의 그날 부위와 보유 기구를 맞춘 루틴을 만들고, 무게는 각자 기준으로 표시합니다. 파트너 앱에도 같은 루틴이 전송돼요.',
              style: Theme.of(c).textTheme.bodySmall?.copyWith(color: Theme.of(c).colorScheme.onSurfaceVariant)),
        ),
        for (final p in ready)
          ListTile(
            leading: CircleAvatar(child: Text(p.name.isEmpty ? '?' : p.name.characters.first)),
            title: Text(p.name.isEmpty ? p.email : p.name),
            subtitle: Text(p.email),
            onTap: () => Navigator.pop(c, p),
          ),
        if (existing != null && existing.partnerName != null)
          ListTile(
            leading: const Icon(Icons.person_off_outlined),
            title: const Text('파트너 운동 해제 (혼자 하는 루틴으로)'),
            onTap: () => Navigator.pop(c, 'clear'),
          ),
        const SizedBox(height: 12),
      ],
    ),
  );
  if (chosen == null || !context.mounted) return;
  if (chosen == 'clear') {
    await state.clearPartnerDay(date);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('혼자 하는 루틴으로 되돌렸어요.')));
    return;
  }
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
    msg = await state.generateJointSession(date, chosen as PartnerLink);
  } catch (e) {
    msg = '파트너 루틴 생성 실패: $e';
  }
  if (!context.mounted) return;
  Navigator.pop(context);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/// 달력 상세용 버튼: 그 날짜를 파트너 운동일로 지정/해제.
class PartnerDayButton extends StatelessWidget {
  const PartnerDayButton({super.key, required this.date, this.plan});
  final DateTime date;
  final DayPlan? plan;

  @override
  Widget build(BuildContext context) {
    final has = plan?.partnerName != null;
    return TextButton.icon(
      onPressed: () => showPartnerPicker(context, date),
      icon: Icon(has ? Icons.group : Icons.group_add_outlined),
      label: Text(has ? '${plan!.partnerName}와 파트너 운동 · 변경' : '파트너 운동일로 지정'),
    );
  }
}
