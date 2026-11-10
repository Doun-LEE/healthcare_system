import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/partner.dart';
import '../../services/routine_share.dart';
import '../../services/cloud_sync.dart';
import '../../state/app_state.dart';
import 'app_sheet.dart';

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

/// "파트너와 운동" 선택 시트. 한 명 또는 여러 명(그룹)을 고르면 그 날짜의 공통 루틴을 만든다.
Future<void> showPartnerPicker(BuildContext context, DateTime date) async {
  final state = context.read<AppState>();
  if (!state.cloudSignedIn) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('계정에 로그인해야 파트너 운동을 쓸 수 있어요.')));
    return;
  }
  final ready = state.partners.where((p) => !p.pending).toList();
  if (ready.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('수락된 파트너가 없어요. 홈 상단 친구에서 요청하세요.')));
    return;
  }
  final existing = state.planOn(date);
  final already = {for (final m in state.membersOf(existing)) m.uid};
  final picked = <String>{...already.where((u) => ready.any((p) => p.uid == u))};
  final chosen = await showAppSheet<Object>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(builder: (c, setState) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text('${date.month}/${date.day} 누구와 같이 운동하나요?', style: Theme.of(c).textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('여러 명을 고르면 그룹 운동이에요. 모두의 그날 부위·보유 기구·부상을 맞춘 루틴을 만들고, 무게는 사람마다 따로 표시합니다. 모두의 앱에 같은 루틴이 전송돼요.',
                  style: Theme.of(c).textTheme.bodySmall?.copyWith(color: Theme.of(c).colorScheme.onSurfaceVariant)),
            ),
            for (final p in ready)
              CheckboxListTile(
                value: picked.contains(p.uid),
                secondary: CircleAvatar(child: Text(p.name.isEmpty ? '?' : p.name.characters.first)),
                title: Text(p.display),
                subtitle: Text(p.handle),
                onChanged: (v) => setState(() => v == true ? picked.add(p.uid) : picked.remove(p.uid)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: FilledButton.icon(
                icon: Icon(picked.length > 1 ? Icons.groups : Icons.group),
                label: Text(picked.isEmpty
                    ? '함께할 사람을 고르세요'
                    : picked.length == 1
                        ? '이 파트너와 루틴 만들기'
                        : '${picked.length + 1}명 그룹 루틴 만들기'),
                onPressed: picked.isEmpty ? null : () => Navigator.pop(c, [for (final p in ready) if (picked.contains(p.uid)) p]),
              ),
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
    }),
  );
  if (chosen == null || !context.mounted) return;
  if (chosen == 'clear') {
    await state.clearPartnerDay(date);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('혼자 하는 루틴으로 되돌렸어요.')));
    return;
  }
  final partners = (chosen as List).cast<PartnerLink>();
  final who = partners.map((p) => p.display).join('·');
  // 어디서 운동할지: 내 헬스장 / 누군가의 헬스장 / 모두의 헬스장 공통 기구
  final profiles = <String, PartnerProfile>{};
  final closeLoading = _showBusy(context, Text(partners.length == 1 ? '파트너 헬스장 정보 받는 중…' : '${partners.length}명 헬스장 정보 받는 중…'));
  await Future.wait([
    for (final p in partners)
      CloudSync.instance.fetchPartner(p.uid).then((pp) {
        if (pp != null) profiles[p.uid] = pp;
      }).catchError((_) {}),
  ]);
  closeLoading();
  if (!context.mounted) return;
  final myUid = CloudSync.instance.user!.uid;
  // 같은 헬스장(서로 가져왔거나 같은 원본에서 가져온 것)은 한 번만: 내 헬스장으로 보여준다.
  String? srcOf(String owner, String gymId, String? linkFrom, String? linkGym) =>
      linkFrom != null && linkGym != null ? '$linkFrom/$linkGym' : '$owner/$gymId';
  final mine = {
    for (final g in state.gyms) ...{'$myUid/${g.id}', srcOf(myUid, g.id, g.sharedFrom, g.sharedGymId)},
  };
  final sameAsMine = {
    for (final p in partners)
      for (final g in profiles[p.uid]?.gyms ?? const <PartnerGym>[])
        if (mine.contains('${p.uid}/${g.id}') || mine.contains(srcOf(p.uid, g.id, g.linkFrom, g.linkGym))) '${p.uid}/${g.id}',
  };
  final options = <(String, SharedVenue?)>[
    for (final g in state.gyms)
      ('내 헬스장 · ${g.name}', SharedVenue(owner: myUid, gymId: g.id, name: g.name, types: g.availableTypes.toList(), equipment: g.equipment)),
    for (final p in partners)
      for (final g in profiles[p.uid]?.gyms ?? const <PartnerGym>[])
        if (!sameAsMine.contains('${p.uid}/${g.id}'))
        ('${p.name} 헬스장 · ${g.name}${g.equipment.isEmpty ? ' (기구 종류만)' : ' · 기구 ${g.equipment.length}개'}',
            SharedVenue(owner: p.uid, gymId: g.id, name: g.name, types: g.types.toList(), equipment: g.equipment)),
    (partners.length == 1 ? '각자 헬스장 공통 기구로' : '모두의 헬스장 공통 기구로', null),
  ];
  final pickedIndex = await showDialog<int>(
    context: context,
    builder: (c) => SimpleDialog(
      title: Text('$who와 어디서 운동해요?'),
      children: [
        for (var i = 0; i < options.length; i++)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, i),
            child: Row(children: [
              Icon(options[i].$2 == null ? Icons.join_inner : Icons.place_outlined, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(options[i].$1)),
            ]),
          ),
        if (partners.any((p) => (profiles[p.uid]?.gyms ?? const []).isEmpty))
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 4),
            child: Text('헬스장 목록이 안 보이는 사람은 새 버전으로 앱을 한 번 열면 보여요.', style: TextStyle(fontSize: 12)),
          ),
      ],
    ),
  );
  if (pickedIndex == null || !context.mounted) return;
  final venue = options[pickedIndex].$2;
  final step = ValueNotifier<String>('루틴 맞추는 중…');
  // 루틴이 바뀌면 이 화면(달력 상세)이 다시 그려져 context가 사라질 수 있으니
  // 알림·창 닫기는 미리 잡아 둔 것으로 한다.
  final messenger = ScaffoldMessenger.of(context);
  final closeBusy = _showBusy(context, ValueListenableBuilder<String>(valueListenable: step, builder: (_, v, _) => Text(v)));
  String msg;
  try {
    msg = await state.generateGroupSession(
      date,
      [for (final p in partners) GroupMember(p.uid, p.name)],
      venue: venue,
      prefetched: profiles,
      onStep: (s) => step.value = s,
    );
  } catch (e) {
    msg = '파트너 루틴 생성 실패: $e';
  }
  closeBusy();
  messenger.showSnackBar(SnackBar(content: Text(msg)));
}

/// 진행 중 창. 돌려주는 함수로 닫는다. 창 자신의 context로 닫으므로
/// 띄운 화면이 그사이 사라져도 창이 남지 않는다.
VoidCallback _showBusy(BuildContext context, Widget message) {
  BuildContext? dlg;
  var closed = false;
  var popped = false;
  void close() {
    closed = true;
    final c = dlg;
    if (popped || c == null || !c.mounted) return;
    popped = true;
    Navigator.of(c).pop();
  }
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) {
      dlg = c;
      if (closed) WidgetsBinding.instance.addPostFrameCallback((_) => close());
      return AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Expanded(child: message),
        ]),
      );
    },
  );
  return close;
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
      icon: Icon(has ? ((plan!.members.length > 1) ? Icons.groups : Icons.group) : Icons.group_add_outlined),
      label: Text(has ? '${plan!.partnerName}와 ${plan!.members.length > 1 ? '그룹' : '파트너'} 운동 · 변경' : '파트너 운동일로 지정'),
    );
  }
}
