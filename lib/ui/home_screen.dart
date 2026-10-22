import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/catalog.dart';
import '../data/quotes.dart';
import '../engine/stats.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'day_plan_view.dart';
import 'widgets/ai_coach_sheet.dart';
import 'widgets/partner_widgets.dart';

/// 홈: 오늘 운동 요약, 이번 주 현황, 파트너, 바로가기.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onGoToTab});

  /// 탭 인덱스로 이동 (0 홈, 1 오늘, 2 달력, 3 기록, 4 헬스장, 5 내 정보).
  final void Function(int) onGoToTab;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.currentUser!;
    final now = DateTime.now();
    final today = dateOnly(now);
    final plan = state.todayPlan;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (wFrom, wTo) = Stats.rangeFor('week', now);
    final week = Stats.summarize(state.myPlans, from: wFrom, to: wTo);
    final plannedThisWeek = state.myPlans.where((p) => !p.isRest && !p.date.isBefore(wFrom) && p.date.isBefore(wFrom.add(const Duration(days: 7)))).length;
    final upcoming = state.myPlans.where((p) => p.date.isAfter(today) && !p.isRest).take(3).toList();
    final hour = now.hour;
    final greet = hour < 5 ? '늦은 밤이에요' : hour < 11 ? '좋은 아침이에요' : hour < 17 ? '좋은 오후예요' : '좋은 저녁이에요';

    return Scaffold(
      appBar: AppBar(
        title: Text('$greet, ${user.name}님'),
        actions: [
          IconButton(tooltip: '동기화', icon: Icon(state.cloudSignedIn ? Icons.cloud_done_outlined : Icons.cloud_off_outlined), onPressed: state.cloudSignedIn ? () => state.syncNow() : () => onGoToTab(5)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          QuoteBanner(quote: quoteFor(now)),
          const SizedBox(height: 4),
          const InboxBanner(),
          const SizedBox(height: 10),

          // 오늘 운동 카드
          Card(
            color: plan == null || plan.isRest ? cs.surfaceContainerHigh : cs.primaryContainer,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onGoToTab(1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(plan == null ? Icons.event_note : plan.isRest ? Icons.self_improvement : Icons.fitness_center,
                          color: plan == null || plan.isRest ? cs.onSurface : cs.onPrimaryContainer),
                      const SizedBox(width: 8),
                      Text('오늘 운동', style: text.labelLarge?.copyWith(color: plan == null || plan.isRest ? cs.onSurfaceVariant : cs.onPrimaryContainer)),
                      const Spacer(),
                      if (plan != null && plan.isFinished) Icon(Icons.check_circle, color: cs.primary),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      plan == null ? '계획 없음' : plan.isRest ? '휴식일' : plan.title ?? '운동',
                      style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: plan == null || plan.isRest ? cs.onSurface : cs.onPrimaryContainer),
                    ),
                    if (plan != null && !plan.isRest) ...[
                      const SizedBox(height: 6),
                      Text(
                        plan.isFinished
                            ? '완료 · ${(plan.completionRatio * 100).round()}% 수행${plan.rpe != null ? ' · 강도 ${plan.rpe}/10' : ''}'
                            : '${plan.exercises.length}개 운동 · 약 ${plan.estimatedMinutes}분${plan.partnerName != null ? ' · ${plan.partnerName}와 함께' : ''}',
                        style: text.bodyMedium?.copyWith(color: cs.onPrimaryContainer),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.exercises.take(4).map((e) => exerciseById(e.exerciseId)?.name ?? '').join(' · ') + (plan.exercises.length > 4 ? ' …' : ''),
                        style: text.bodySmall?.copyWith(color: cs.onPrimaryContainer),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (plan == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: FilledButton.tonalIcon(
                          onPressed: () => state.generatePlans(from: today, to: today.add(const Duration(days: 6)), restDays: state.manualRestDays),
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('이번 주 루틴 생성'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // 바로가기
          const SizedBox(height: 6),
          Row(children: [
            _Quick(icon: Icons.auto_awesome, label: 'AI 코치', onTap: () => showAiCoach(context, today)),
            _Quick(icon: Icons.group_outlined, label: '파트너 운동', onTap: () => showPartnerPicker(context, today)),
            _Quick(icon: Icons.calendar_month_outlined, label: '달력', onTap: () => onGoToTab(2)),
            _Quick(icon: Icons.insights_outlined, label: '기록', onTap: () => onGoToTab(3)),
          ]),

          // 이번 주
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('이번 주', style: text.titleMedium),
                    const Spacer(),
                    Text('${week.sessions}/$plannedThisWeek회 완료', style: text.bodyMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: _DayDot(
                          date: wFrom.add(Duration(days: i)),
                          plan: state.planOn(wFrom.add(Duration(days: i))),
                          isToday: i == today.weekday % 7,
                        ),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    '세트 ${week.totalSets} · 볼륨 ${week.totalTonnage >= 1000 ? '${(week.totalTonnage / 1000).toStringAsFixed(1)}t' : '${week.totalTonnage.round()}kg'} · 연속 ${state.currentStreakWeeks}주',
                    style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),

          // 다음 일정
          if (upcoming.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('다음 운동', style: text.titleMedium),
                    const SizedBox(height: 6),
                    for (final p in upcoming)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Text('${p.date.month}/${p.date.day}', style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        title: Text(p.title ?? ''),
                        subtitle: Text('${p.exercises.length}개 · ${p.estimatedMinutes}분${p.partnerName != null ? ' · 👥 ${p.partnerName}' : ''}'),
                        onTap: () => onGoToTab(2),
                      ),
                  ],
                ),
              ),
            ),

          // 파트너
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('운동 파트너', style: text.titleMedium),
                    const Spacer(),
                    TextButton(onPressed: () => onGoToTab(5), child: const Text('관리')),
                  ]),
                  if (!state.cloudSignedIn)
                    Text('계정에 로그인하면 파트너와 같은 루틴으로 운동할 수 있어요.', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant))
                  else if (state.partners.isEmpty)
                    Text('아직 파트너가 없어요. 내 정보 → 운동 파트너에서 ID로 요청하세요.', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final p in state.partners)
                          Chip(
                            avatar: CircleAvatar(child: Text(p.display.characters.first)),
                            label: Text(p.pending ? '${p.display} (대기)' : p.display),
                            backgroundColor: p.pending ? cs.surfaceContainerHighest : null,
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(children: [
            CircleAvatar(backgroundColor: cs.secondaryContainer, child: Icon(icon, color: cs.onSecondaryContainer)),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ]),
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.date, required this.plan, required this.isToday});
  final DateTime date;
  final DayPlan? plan;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const wd = ['일', '월', '화', '수', '목', '금', '토'];
    Color c;
    IconData? icon;
    if (plan == null) {
      c = cs.surfaceContainerHighest;
    } else if (plan!.isRest) {
      c = cs.tertiaryContainer;
      icon = Icons.self_improvement;
    } else if (plan!.isFinished) {
      c = cs.primary;
      icon = Icons.check;
    } else {
      c = cs.primaryContainer;
      icon = Icons.fitness_center;
    }
    return Column(children: [
      Text(wd[date.weekday % 7], style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: isToday ? FontWeight.bold : null)),
      const SizedBox(height: 4),
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: isToday ? Border.all(color: cs.primary, width: 2) : null),
        child: icon == null ? null : Icon(icon, size: 16, color: plan!.isFinished ? cs.onPrimary : cs.onSurface),
      ),
    ]);
  }
}
