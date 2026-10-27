import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/chat.dart';
import '../services/cloud_sync.dart';
import '../services/partner.dart';
import '../state/app_state.dart';
import 'chat_screen.dart';
import 'partner_profile_screen.dart';

/// 친구(운동 파트너) 목록 화면: 안 읽은 메시지·마지막 메시지, 요청 수락, ID로 추가.
class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FriendsScreen()));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final requests = state.inbox.where((i) => i.type == InboxType.partnerRequest).toList();
    final friends = state.partners.where((p) => !p.pending).toList()
      ..sort((a, b) {
        final ua = state.unreadFor(a), ub = state.unreadFor(b);
        if ((ua > 0) != (ub > 0)) return ua > 0 ? -1 : 1;
        final ta = state.lastChat(a)?.at ?? DateTime(2000), tb = state.lastChat(b)?.at ?? DateTime(2000);
        return tb.compareTo(ta);
      });
    final pending = state.partners.where((p) => p.pending).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('친구'),
        actions: [
          IconButton(tooltip: '새로고침', icon: const Icon(Icons.refresh), onPressed: () => state.refreshInbox()),
        ],
      ),
      body: !state.cloudSignedIn
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('계정에 로그인하면 친구를 등록해 같이 운동하고 채팅할 수 있어요.\n내 정보 → 계정에서 로그인하세요.',
                    textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (state.myHandle != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Icon(Icons.badge_outlined, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text('내 ID: ${state.myHandle}', style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                      IconButton(
                        tooltip: 'ID 복사',
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: state.myHandle!));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID를 복사했어요. 친구에게 보내세요.')));
                        },
                      ),
                    ]),
                  ),
                for (final r in requests) _RequestTile(item: r),
                if (friends.isEmpty && pending.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('아직 친구가 없어요. 친구에게 내 ID를 알려주거나, 친구 ID로 요청을 보내세요.',
                        textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  ),
                for (final p in friends) _FriendTile(partner: p),
                if (pending.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 2),
                    child: Text('수락 기다리는 중', style: text.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
                  ),
                  for (final p in pending)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: CircleAvatar(backgroundColor: cs.surfaceContainerHighest, child: Text(p.display.characters.first)),
                      title: Text(p.display),
                      subtitle: Text('${p.handle} · 상대가 수락하면 친구가 돼요', style: TextStyle(color: cs.tertiary)),
                      trailing: IconButton(
                        icon: const Icon(Icons.cancel_outlined),
                        tooltip: '요청 취소',
                        onPressed: () => state.removePartner(p.uid),
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => requestPartnerById(context),
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('ID로 친구 요청'),
                ),
                const SizedBox(height: 6),
                Text('이메일은 서로 보이지 않아요. 친구를 누르면 채팅, 길게 누르면 프로필·삭제.',
                    textAlign: TextAlign.center, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
    );
  }
}

/// 친구 ID(닉네임#1234)로 파트너 요청 보내기.
Future<void> requestPartnerById(BuildContext context) async {
  final state = context.read<AppState>();
  if (!state.cloudSignedIn) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('계정에 로그인해야 친구를 추가할 수 있어요.')));
    return;
  }
  final c = TextEditingController();
  final q = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('친구 ID'),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: const InputDecoration(hintText: '예: 용현#4821 (또는 이메일)'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('요청 보내기')),
      ],
    ),
  );
  if (q == null || q.trim().isEmpty || !context.mounted) return;
  final msg = await state.addPartner(q);
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.partner});
  final PartnerLink partner;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final unread = state.unreadFor(partner);
    final last = state.lastChat(partner);
    final preview = last == null
        ? partner.handle
        : '${last.fromUid == CloudSync.instance.user?.uid ? '나: ' : ''}${chatPreview(last)}';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: FriendAvatar(partner: partner, unread: unread, radius: 22),
      title: Text(partner.display, style: TextStyle(fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500)),
      subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: unread > 0 ? cs.onSurface : cs.onSurfaceVariant, fontWeight: unread > 0 ? FontWeight.w600 : null)),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (last != null) Text(chatTimeLabel(last.at), style: text.labelSmall?.copyWith(color: unread > 0 ? cs.primary : cs.onSurfaceVariant)),
        if (unread > 0)
          Container(
            margin: const EdgeInsets.only(top: 3),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(color: cs.error, borderRadius: BorderRadius.circular(10)),
            child: Text('$unread', style: TextStyle(color: cs.onError, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
      ]),
      onTap: () => PartnerChatScreen.open(context, partner),
      onLongPress: () => _menu(context, state),
    );
  }

  Future<void> _menu(BuildContext context, AppState state) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.chat_bubble_outline), title: const Text('채팅'), onTap: () => Navigator.pop(c, 'chat')),
          ListTile(leading: const Icon(Icons.person_outline), title: Text('${partner.display} 프로필·기록 보기'), onTap: () => Navigator.pop(c, 'profile')),
          ListTile(
            leading: Icon(Icons.person_remove_outlined, color: Theme.of(c).colorScheme.error),
            title: Text('친구 삭제', style: TextStyle(color: Theme.of(c).colorScheme.error)),
            onTap: () => Navigator.pop(c, 'remove'),
          ),
        ]),
      ),
    );
    if (v == null || !context.mounted) return;
    switch (v) {
      case 'chat':
        PartnerChatScreen.open(context, partner);
      case 'profile':
        PartnerProfileScreen.open(context, partner);
      case 'remove':
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text('${partner.display} 삭제'),
            content: const Text('친구 목록에서 뺍니다. 같이 짠 루틴은 남아요.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('삭제')),
            ],
          ),
        );
        if (ok == true) await state.removePartner(partner.uid);
    }
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
                Text('${item.fromName} 님의 친구 요청', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onPrimaryContainer)),
                Text(item.fromHandle, style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer)),
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

/// 친구 아바타(이름 첫 글자) + 안 읽은 수 배지.
class FriendAvatar extends StatelessWidget {
  const FriendAvatar({super.key, required this.partner, this.unread = 0, this.radius = 20});
  final PartnerLink partner;
  final int unread;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Badge(
      isLabelVisible: unread > 0,
      label: Text('$unread'),
      offset: const Offset(2, -2),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: partner.pending ? cs.surfaceContainerHighest : cs.primaryContainer,
        child: Text(partner.display.characters.first,
            style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w700, fontSize: radius * 0.85)),
      ),
    );
  }
}

/// 홈 상단 친구 띠: 아바타를 가로로 늘어놓고 안 읽은 메시지를 배지로. 누르면 채팅, 길게 누르면 프로필.
class FriendsStrip extends StatelessWidget {
  const FriendsStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (!state.cloudSignedIn) return const SizedBox.shrink();
    final friends = state.partners.where((p) => !p.pending).toList()
      ..sort((a, b) => state.unreadFor(b).compareTo(state.unreadFor(a)));
    final requests = state.inbox.where((i) => i.type == InboxType.partnerRequest).length;
    return SizedBox(
      height: 84,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        children: [
          _StripItem(
            label: '친구',
            onTap: () => FriendsScreen.open(context),
            child: Badge(
              isLabelVisible: requests > 0,
              label: Text('$requests'),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: cs.secondaryContainer,
                child: Icon(friends.isEmpty ? Icons.person_add_alt : Icons.people_outline, color: cs.onSecondaryContainer),
              ),
            ),
          ),
          for (final p in friends)
            _StripItem(
              label: p.display,
              bold: state.unreadFor(p) > 0,
              onTap: () => PartnerChatScreen.open(context, p),
              onLongPress: () => PartnerProfileScreen.open(context, p),
              child: FriendAvatar(partner: p, unread: state.unreadFor(p), radius: 24),
            ),
          if (friends.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 14),
              child: Text('친구를 추가하면 여기서 바로 채팅해요', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}

class _StripItem extends StatelessWidget {
  const _StripItem({required this.label, required this.child, required this.onTap, this.onLongPress, this.bold = false});
  final String label;
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool bold;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            child,
            const SizedBox(height: 4),
            SizedBox(
              width: 56,
              child: Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: bold ? FontWeight.w700 : null)),
            ),
          ]),
        ),
      );
}

/// 마지막 메시지 미리보기 한 줄.
String chatPreview(ChatMessage m) => m.isEmoji ? (m.burst > 1 ? '${m.emoji} 폭탄 ×${m.burst}' : m.emoji) : m.text;

/// '방금' · 'n분 전' · 'n시간 전' · '어제' · 'M/d'.
String chatTimeLabel(DateTime at) {
  final now = DateTime.now();
  final d = now.difference(at);
  if (d.inMinutes < 1) return '방금';
  if (d.inMinutes < 60) return '${d.inMinutes}분 전';
  if (d.inHours < 24 && at.day == now.day) return '${d.inHours}시간 전';
  final yesterday = now.subtract(const Duration(days: 1));
  if (at.year == yesterday.year && at.month == yesterday.month && at.day == yesterday.day) return '어제';
  return '${at.month}/${at.day}';
}
