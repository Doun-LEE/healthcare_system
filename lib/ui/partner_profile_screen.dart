import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/catalog.dart';
import '../models/models.dart';
import '../services/cloud_sync.dart';
import '../services/partner.dart';
import '../state/app_state.dart';
import 'chat_screen.dart';
import 'widgets/level_card.dart';

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
          final recent4w = finished.where((p) => DateTime.now().difference(p.date).inDays <= 28).toList();
          final volume = recent4w.fold(0.0, (a, p) => a + p.volume);
          final avgCompletion = recent4w.isEmpty ? 0 : (recent4w.map((p) => p.completion).reduce((a, b) => a + b) / recent4w.length * 100).round();
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
                      CircleAvatar(radius: 22, child: Text(pp.name.isEmpty ? '?' : pp.name.characters.first, style: const TextStyle(fontSize: 20))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(pp.name, style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
                          Text('${pp.handle.isEmpty ? '' : '${pp.handle} · '}${u.sex.label} · ${u.age}세 · ${u.heightCm.round()}cm · ${u.weightKg.round()}kg',
                              style: text.bodySmall?.copyWith(color: cs.onPrimaryContainer)),
                          Text('${u.goal.label} · ${u.splitDays}분할 · 하루 ${u.sessionMinutes}분', style: text.bodySmall?.copyWith(color: cs.onPrimaryContainer)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      _Stat(label: '스쿼트', value: u.squat1rm == null ? '-' : '${u.squat1rm!.round()}'),
                      _Stat(label: '벤치', value: u.bench1rm == null ? '-' : '${u.bench1rm!.round()}'),
                      _Stat(label: '데드', value: u.deadlift1rm == null ? '-' : '${u.deadlift1rm!.round()}'),
                      _Stat(label: '3대 합계', value: (u.squat1rm == null && u.bench1rm == null && u.deadlift1rm == null) ? '-' : '${((u.squat1rm ?? 0) + (u.bench1rm ?? 0) + (u.deadlift1rm ?? 0)).round()}'),
                    ]),
                    if (u.skeletalMuscleKg != null || u.bodyFatPct != null)
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
              // 기록 요약
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('최근 4주', style: text.titleMedium),
                    const SizedBox(height: 8),
                    Row(children: [
                      _Stat(label: '세션', value: '${recent4w.length}회', dark: true),
                      _Stat(label: '볼륨', value: volume >= 1000 ? '${(volume / 1000).toStringAsFixed(1)}t' : '${volume.round()}kg', dark: true),
                      _Stat(label: '평균 수행', value: '$avgCompletion%', dark: true),
                      _Stat(label: '예정', value: '${upcoming.length}일', dark: true),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Text('최근 운동 기록', style: text.titleMedium),
              if (finished.isEmpty)
                Padding(padding: const EdgeInsets.all(12), child: Text('아직 완료한 기록이 없어요.', style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
              for (final p in finished.take(14)) _PlanTile(plan: p),
              const SizedBox(height: 12),
              Text('예정 루틴', style: text.titleMedium),
              if (upcoming.isEmpty)
                Padding(padding: const EdgeInsets.all(12), child: Text('예정된 루틴이 없어요.', style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
              for (final p in upcoming.take(14)) _PlanTile(plan: p),
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

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.plan});
  final PartnerPlan plan;

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
          ? '${s.reps}분${s.level != null && cardioLevels[e.exerciseId] != null ? ' ${cardioLevels[e.exerciseId]!.format(s.level!)}' : ''}'
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
