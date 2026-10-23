import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import 'day_plan_view.dart';
import 'widgets/ai_coach_sheet.dart';
import 'widgets/partner_widgets.dart';
import 'widgets/place.dart';

/// 하루 루틴 전체 화면. 달력에서 날짜를 열면 여기로 온다.
class DayPage extends StatelessWidget {
  const DayPage({super.key, required this.date});
  final DateTime date;

  static Future<void> open(BuildContext context, DateTime date) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => DayPage(date: date)));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final plan = state.planOn(date);
    final today = state.today;
    final d = dateOnly(date);
    final isPast = d.isBefore(today);
    final isFuture = d.isAfter(today);
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${d.month}월 ${d.day}일 (${wd[d.weekday - 1]})${isPast ? ' · 지난 날' : isFuture ? ' · 예정' : ' · 오늘'}'),
        actions: [
          if (plan != null && !plan.isRest && !plan.isFinished && !isPast)
            IconButton(tooltip: 'AI 코치', icon: const Icon(Icons.auto_awesome), onPressed: () => showAiCoach(context, d)),
          if (plan != null && !plan.isRest && !plan.isFinished && !isPast)
            IconButton(
              tooltip: '파트너와 운동',
              icon: Icon(plan.partnerName != null ? Icons.group : Icons.group_outlined),
              onPressed: () => showPartnerPicker(context, d),
            ),
          PopupMenuButton<String>(
            onSelected: (v) => _menu(context, state, v, plan),
            itemBuilder: (_) => [
              if (!isPast) const PopupMenuItem(value: 'import', child: Text('친구 루틴 불러오기')),
              if (!isPast && (plan == null || plan.isRest)) const PopupMenuItem(value: 'regen', child: Text('이 날 루틴 만들기')),
              if (!isPast && plan != null && !plan.isFinished) const PopupMenuItem(value: 'regen', child: Text('루틴 다시 생성')),
              if (!isPast && (plan == null || !plan.isFinished)) PopupMenuItem(value: 'rest', child: Text(plan?.isRest == true ? '휴식 해제 (운동일로)' : '휴식일로 표시')),
              if (plan != null) const PopupMenuDivider(),
              if (plan != null) const PopupMenuItem(value: 'delete', child: Text('이 날 계획 삭제')),
            ],
          ),
        ],
      ),
      body: plan == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_busy, size: 64, color: cs.onSurfaceVariant),
                  const SizedBox(height: 8),
                  Text('계획 없음', style: text.titleLarge),
                  if (!isPast)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FilledButton.icon(
                        onPressed: () => makeDayWithGym(context, d),
                        icon: const Icon(Icons.add),
                        label: const Text('이 날 루틴 만들기'),
                      ),
                    ),
                ],
              ),
            )
          : DayPlanView(plan: plan, editable: !isPast, logging: !isFuture),
    );
  }

  Future<void> _menu(BuildContext context, AppState state, String v, DayPlan? plan) async {
    final d = dateOnly(date);
    switch (v) {
      case 'import':
        await importRoutineDialog(context, d);
      case 'regen':
        await state.regenerateDay(d);
      case 'rest':
        await state.toggleRestDay(d);
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('이 날 계획을 삭제할까요?'),
            content: Text(plan?.isFinished == true
                ? '완료 기록도 함께 사라지고 통계에서 빠집니다. 되돌릴 수 없어요.'
                : '이 날짜의 루틴이 삭제됩니다. 필요하면 다시 생성할 수 있어요.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('삭제')),
            ],
          ),
        );
        if (ok == true) {
          await state.deletePlan(d);
          if (context.mounted) Navigator.of(context).pop();
        }
    }
  }
}
