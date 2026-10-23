import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/quotes.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'day_plan_view.dart';
import 'widgets/ai_coach_sheet.dart';
import 'widgets/partner_widgets.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final plan = state.todayPlan;
    final user = state.currentUser!;
    final now = state.today;
    const wd = ['월', '화', '수', '목', '금', '토', '일'];

    return Scaffold(
      appBar: AppBar(
        title: Text('${now.month}월 ${now.day}일 (${wd[now.weekday - 1]})'),
        actions: [
          if (plan == null || !plan.isFinished)
            IconButton(
              tooltip: 'AI 코치로 루틴 짜기',
              icon: const Icon(Icons.auto_awesome),
              onPressed: () => showAiCoach(context, now),
            ),
          if (plan == null || !plan.isFinished)
            IconButton(
              tooltip: '파트너와 운동',
              icon: Icon(plan?.partnerName != null ? Icons.group : Icons.group_outlined),
              onPressed: () => showPartnerPicker(context, now),
            ),
          IconButton(
            tooltip: '루틴 불러오기 (공유 코드)',
            icon: const Icon(Icons.download_outlined),
            onPressed: () => importRoutineDialog(context, now),
          ),
          if (plan != null && !plan.isFinished)
            IconButton(
              tooltip: '오늘 루틴 다시 생성',
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('오늘 루틴을 다시 만들까요?'),
                    content: const Text('현재 보유 기구와 최근 이력을 반영해 새로 뽑습니다. 체크한 세트는 사라집니다.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
                      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('다시 생성')),
                    ],
                  ),
                );
                if (ok == true) await state.regenerateDay(now);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          QuoteBanner(quote: quoteFor(now)),
          const InboxBanner(),
          Expanded(child: plan == null ? _Empty(user: user) : DayPlanView(plan: plan)),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.user});
  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final hasGym = state.activeGym != null && state.activeGym!.equipment.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note, size: 72, color: cs.primary),
            const SizedBox(height: 12),
            Text('${user.name}님, 오늘 계획이 없어요', style: text.titleLarge),
            const SizedBox(height: 8),
            Text(
              hasGym
                  ? '${user.splitDays}분할 · 하루 ${user.sessionMinutes}분 기준으로 이번 주 루틴을 바로 만들 수 있어요.'
                  : '먼저 헬스장 탭에서 보유 기구를 등록하면 더 정확한 루틴이 나옵니다. (등록 없이 만들면 맨몸 운동만 나와요)',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                final today = state.today;
                await state.generatePlans(
                  from: today,
                  to: today.add(const Duration(days: 6)),
                  restDays: state.manualRestDays,
                );
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('오늘부터 1주일 루틴 생성'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => importRoutineDialog(context, state.today),
              icon: const Icon(Icons.download_outlined),
              label: const Text('친구 루틴 불러오기'),
            ),
            const SizedBox(height: 8),
            Text('휴식일을 먼저 정하고 싶다면 달력 탭에서 날짜를 길게 눌러 휴식으로 표시하세요.',
                textAlign: TextAlign.center, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
