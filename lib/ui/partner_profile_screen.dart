import 'widgets/style_map.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/catalog.dart';
import '../models/models.dart';
import '../services/cloud_sync.dart';
import '../services/partner.dart';
import '../state/app_state.dart';
import 'chat_screen.dart';
import 'widgets/level_card.dart';
import 'widgets/rank_badge.dart';

/// 친구 프로필: 스탯 카드(레벨), 기록 요약, 최근 운동 기록, 예정 루틴.
class PartnerProfileScreen extends StatefulWidget {
  const PartnerProfileScreen({super.key, required this.partner, this.preloaded, this.isMe = false, this.onEditMe});
  final PartnerLink partner;

  /// 내 스탯 카드처럼 이미 만들어 둔 프로필을 보여줄 때.
  final PartnerProfile? preloaded;
  final bool isMe;
  final VoidCallback? onEditMe;

  static Future<void> open(BuildContext context, PartnerLink partner) {
    if (!CloudSync.instance.signedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('계정에 로그인해야 친구 프로필을 볼 수 있어요.')));
      return Future.value();
    }
    return Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartnerProfileScreen(partner: partner)));
  }

  /// 내 데이터를 친구가 보는 것과 같은 스탯 카드 형식으로.
  static Future<void> openMine(BuildContext context, {VoidCallback? onEdit}) {
    final state = context.read<AppState>();
    final u = state.currentUser;
    if (u == null) return Future.value();
    final uid = state.cloudSignedIn ? CloudSync.instance.user!.uid : 'me';
    final pp = PartnerProfile.fromJson(PartnerProfile.build(
      uid: uid,
      me: u,
      available: state.availableEquipment,
      progress: state.progress,
      plans: state.myPlans,
      handle: state.myHandle ?? '',
    ));
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PartnerProfileScreen(
        partner: PartnerLink(uid: uid, name: u.name, handle: state.myHandle ?? ''),
        preloaded: pp,
        isMe: true,
        onEditMe: onEdit,
      ),
    ));
  }

  @override
  State<PartnerProfileScreen> createState() => _PartnerProfileScreenState();
}

class _PartnerProfileScreenState extends State<PartnerProfileScreen> {
  late Future<PartnerProfile?> _future = widget.preloaded != null ? Future.value(widget.preloaded) : CloudSync.instance.fetchPartner(widget.partner.uid);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isMe ? '내 스탯 카드' : widget.partner.display),
        actions: [
          if (widget.isMe)
            IconButton(
              tooltip: '내 정보 수정',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                Navigator.pop(context);
                widget.onEditMe?.call();
              },
            )
          else ...[
            IconButton(tooltip: '채팅', icon: const Icon(Icons.chat_bubble_outline), onPressed: () => PartnerChatScreen.open(context, widget.partner)),
            IconButton(tooltip: '새로고침', icon: const Icon(Icons.refresh), onPressed: () => setState(() => _future = CloudSync.instance.fetchPartner(widget.partner.uid))),
          ],
        ],
      ),
      body: FutureBuilder<PartnerProfile?>(
        future: _future,
        builder: (c, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final pp = snap.data;
          if (pp == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${widget.partner.display} 님의 정보를 아직 받을 수 없어요.\n상대가 앱을 한 번 열면 됩니다.', textAlign: TextAlign.center),
              ),
            );
          }
          final finished = pp.finishedPlans;
          final upcoming = pp.upcomingPlans;
          final r = pp.recent;
          final volume = r.volume;
          final avgCompletion = (r.completion * 100).round();
          final diff = r.diff;
          final u = pp.profile;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // 스탯 카드
              Card(
                color: cs.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      RankedAvatar(
                        rank: pp.rank,
                        radius: 22,
                        child: CircleAvatar(radius: 22, child: Text(pp.name.isEmpty ? '?' : pp.name.characters.first, style: const TextStyle(fontSize: 20))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(pp.name, style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
                          Text('${pp.handle.isEmpty ? '' : '${pp.handle} · '}${u.sex.label}${u.showBodyInfo ? ' · ${u.age}세 · ${u.heightCm.round()}cm · ${u.weightKg.round()}kg' : ''}',
                              style: text.bodySmall?.copyWith(color: cs.onPrimaryContainer)),
                          Text('${u.goal.label} · ${u.splitDays}분할 · 하루 ${u.sessionMinutes}분 설정${pp.recent.avgMinutes == null ? '' : ' (실제 평균 ${pp.recent.avgMinutes}분)'}', style: text.bodySmall?.copyWith(color: cs.onPrimaryContainer)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    RankPlate(rank: pp.rank, color: cs.onPrimaryContainer),
                    const SizedBox(height: 10),
                    Row(children: [
                      _Stat(label: '스쿼트', value: u.squat1rm == null ? '-' : '${u.squat1rm!.round()}'),
                      _Stat(label: '벤치', value: u.bench1rm == null ? '-' : '${u.bench1rm!.round()}'),
                      _Stat(label: '데드', value: u.deadlift1rm == null ? '-' : '${u.deadlift1rm!.round()}'),
                      _Stat(label: '3대 합계', value: (u.squat1rm == null && u.bench1rm == null && u.deadlift1rm == null) ? '-' : '${((u.squat1rm ?? 0) + (u.bench1rm ?? 0) + (u.deadlift1rm ?? 0)).round()}'),
                    ]),
                    if (u.showBodyInfo && (u.skeletalMuscleKg != null || u.bodyFatPct != null))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('골격근 ${u.skeletalMuscleKg?.toStringAsFixed(1) ?? '-'}kg · 체지방 ${u.bodyFatPct?.toStringAsFixed(1) ?? '-'}%',
                            style: text.bodySmall?.copyWith(color: cs.onPrimaryContainer)),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('레벨', style: text.titleMedium),
                    const SizedBox(height: 8),
                    LevelCard(profile: u),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.isMe ? '운동 성향' : '운동 성향 · 나와 비교', style: text.titleMedium),
                    const SizedBox(height: 8),
                    widget.isMe
                        ? StyleCard(people: [('나', pp.style)], trendFrom: context.read<AppState>().myStyleLastMonth)
                        : StyleCard(people: [('나', context.read<AppState>().myStyle), (pp.name, pp.style)]),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              // 기록 요약
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('최근 4주', style: text.titleMedium),
                    const SizedBox(height: 8),
                    Row(children: [
                      _Stat(label: '세션', value: '${r.sessions}회', dark: true),
                      _Stat(label: '볼륨', value: volume >= 1000 ? '${(volume / 1000).toStringAsFixed(1)}t' : '${volume.round()}kg', dark: true),
                      _Stat(label: '평균 수행', value: '$avgCompletion%', dark: true),
                      _Stat(label: '예정', value: '${upcoming.length}일', dark: true),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      _Stat(label: '실제 평균 운동 시간', value: r.avgMinutes == null ? '-' : '${r.avgMinutes}분', dark: true),
                      _Stat(label: '루틴 예상 평균', value: r.avgPlanned == null ? '-' : '${r.avgPlanned}분', dark: true),
                      _Stat(
                        label: '예상 대비',
                        value: diff == null ? '-' : diff == 0 ? '딱 맞춤' : diff > 0 ? '+$diff분' : '$diff분',
                        dark: true,
                      ),
                      _Stat(label: '예상보다 길게', value: r.timed == 0 ? '-' : '${r.over}/${r.timed}회', dark: true),
                    ]),
                    if (diff != null && r.avgPlanned != null && r.avgPlanned! > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          diff > r.avgPlanned! * 0.1
                              ? '루틴 예상보다 평균 $diff분(${(diff / r.avgPlanned! * 100).round()}%) 더 오래 운동해요. 쉬는 시간이 길거나 세트를 더 하는 편이에요.'
                              : diff < -r.avgPlanned! * 0.1
                                  ? '루틴 예상보다 평균 ${-diff}분 빨리 끝내요. 휴식을 짧게 가져가는 편이에요.'
                                  : '루틴 예상 시간과 거의 비슷하게 운동해요.',
                          style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Text('운동 달력', style: text.titleMedium),
              _PartnerCalendar(plans: [...finished, ...upcoming]),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.dark = false});
  final String label, value;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = dark ? cs.onSurface : cs.onPrimaryContainer;
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
        Text(label, style: text.labelSmall?.copyWith(color: color.withValues(alpha: 0.7))),
      ]),
    );
  }
}

/// 친구 루틴 달력: 내 달력처럼 한 달을 칸으로 보여 주고, 날짜를 누르면 아래에 그날 운동.
class _PartnerCalendar extends StatefulWidget {
  const _PartnerCalendar({required this.plans});
  final List<PartnerPlan> plans;

  @override
  State<_PartnerCalendar> createState() => _PartnerCalendarState();
}

class _PartnerCalendarState extends State<_PartnerCalendar> {
  late DateTime _month;
  DateTime? _selected;

  static String _k(DateTime d) => '${d.year}-${d.month}-${d.day}';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    // 처음엔 오늘(루틴 있으면) 또는 가장 최근 완료한 날.
    final today = widget.plans.where((p) => _k(p.date) == _k(now));
    final done = widget.plans.where((p) => p.finished).toList()..sort((a, b) => b.date.compareTo(a.date));
    _selected = today.isNotEmpty ? now : (done.isNotEmpty ? done.first.date : null);
    if (_selected != null) _month = DateTime(_selected!.year, _selected!.month);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final byDay = {for (final p in widget.plans) _k(p.date): p};
    final first = DateTime(_month.year, _month.month, 1);
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday % 7;
    final rows = ((lead + days) / 7).ceil();
    final now = DateTime.now();
    final sel = _selected == null ? null : byDay[_k(_selected!)];
    const wd = ['일', '월', '화', '수', '목', '금', '토'];

    Widget cell(int day) {
      if (day < 1 || day > days) return const SizedBox(height: 50);
      final date = DateTime(_month.year, _month.month, day);
      final p = byDay[_k(date)];
      final isToday = _k(date) == _k(now);
      final isSel = _selected != null && _k(date) == _k(_selected!);
      final bg = p == null ? null : (p.finished ? cs.surfaceContainerHighest : cs.primaryContainer);
      final fg = p == null ? cs.onSurface : (p.finished ? cs.onSurfaceVariant : cs.onPrimaryContainer);
      return GestureDetector(
        onTap: () => setState(() => _selected = date),
        child: Container(
          height: 50,
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSel ? cs.primary : (isToday ? cs.outline : Colors.transparent), width: isSel ? 2 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('$day', style: TextStyle(fontSize: 12, fontWeight: isToday ? FontWeight.bold : null, color: fg)),
              const Spacer(),
              if (p != null && p.finished) Icon(Icons.check, size: 11, color: cs.primary),
            ]),
            if (p != null)
              Flexible(
                child: Text(focusTitle(p.focus), maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9.5, height: 1.15, color: fg)),
              ),
          ]),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Column(children: [
            Row(children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              ),
              Expanded(child: Center(child: Text('${_month.year}년 ${_month.month}월', style: text.titleSmall))),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
              ),
            ]),
            Row(children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(wd[i], style: TextStyle(fontSize: 12, color: i == 0 ? cs.error : (i == 6 ? cs.primary : cs.onSurfaceVariant))),
                  ),
                ),
            ]),
            for (var r = 0; r < rows; r++)
              Row(children: [for (var c = 0; c < 7; c++) Expanded(child: cell(r * 7 + c - lead + 1))]),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Text('최근 5주 기록과 2주 뒤까지 예정 루틴이 보여요.', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ),
          ]),
        ),
      ),
      if (_selected != null)
        sel == null
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: Text('${_selected!.month}/${_selected!.day} 운동 없음', style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              )
            : _PlanTile(key: ValueKey(_k(sel.date)), plan: sel, expanded: true),
    ]);
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({super.key, required this.plan, this.expanded = false});
  final PartnerPlan plan;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final d = plan.date;
    final sub = plan.finished
        ? '${plan.doneSets}/${plan.totalSets}세트 · ${(plan.completion * 100).round()}%'
            '${plan.volume > 0 ? ' · ${plan.volume >= 1000 ? '${(plan.volume / 1000).toStringAsFixed(1)}t' : '${plan.volume.round()}kg'}' : ''}'
            '${plan.actualMinutes != null ? ' · ${plan.actualMinutes}분' : ''}${plan.rpe != null ? ' · 체감 ${plan.rpe}/10' : ''}'
        : '${plan.exercises.length}개 운동 · 약 ${plan.estimatedMinutes}분';
    return Card(
      child: ExpansionTile(
        initiallyExpanded: expanded,
        leading: SizedBox(
          width: 44,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${d.month}/${d.day}', style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            Icon(plan.finished ? Icons.check_circle : Icons.schedule, size: 16, color: plan.finished ? cs.primary : cs.onSurfaceVariant),
          ]),
        ),
        title: Text(plan.title.isEmpty ? plan.focus.map((g) => g.label).join('·') : plan.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(sub, style: text.bodySmall),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final e in plan.exercises)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 4, child: Text(exerciseById(e.exerciseId)?.name ?? e.exerciseId, style: text.bodyMedium)),
                Expanded(
                  flex: 6,
                  child: Text(_setsText(e), textAlign: TextAlign.right, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  String _setsText(PartnerExercise e) {
    final ex = exerciseById(e.exerciseId);
    final cardio = ex?.loadType == LoadType.cardio;
    final parts = <String>[];
    for (final s in e.sets) {
      final w = s.weight;
      final core = cardio
          ? '${s.reps}분${s.level != null && cardioLevels[e.exerciseId] != null ? ' ${cardioLevels[e.exerciseId]!.format(s.level!, s: s.speed)}' : ''}'
          : (w > 0 ? '${w % 1 == 0 ? w.toInt() : w}kg×${s.reps}' : '${s.reps}회');
      parts.add(plan.finished && !s.done ? '($core)' : core);
    }
    final out = <String>[];
    var k = 0;
    while (k < parts.length) {
      var n = 1;
      while (k + n < parts.length && parts[k + n] == parts[k]) {
        n++;
      }
      out.add(n > 1 ? '${parts[k]} ×$n' : parts[k]);
      k += n;
    }
    return out.join(', ');
  }
}
