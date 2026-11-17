import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/plan_overview.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'copy_routine.dart';
import 'day_plan_view.dart';
import 'widgets/ai_coach_sheet.dart';
import 'widgets/partner_widgets.dart';
import 'widgets/place.dart';
import 'widgets/plan_overview.dart';

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
      endDrawer: plan == null || plan.isRest || plan.exercises.isEmpty ? null : PlanOverviewDrawer(plan: plan, editable: !isPast),
      drawerEdgeDragWidth: 36,
      appBar: AppBar(
        // 아이콘이 많아 좁은 폰에서 날짜가 '11월 1…'로 잘리지 않게, 잘리는 대신 살짝 줄인다.
        title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('${d.month}월 ${d.day}일 (${wd[d.weekday - 1]})${isPast ? ' · 지난 날' : isFuture ? ' · 예정' : ' · 오늘'}')),
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
              if (!isPast && (plan == null || !plan.isFinished)) const PopupMenuItem(value: 'copy', child: Text('지난 내 루틴 그대로 가져오기')),
              if (!isPast) const PopupMenuItem(value: 'import', child: Text('친구 루틴 불러오기')),
              if (!isPast && (plan == null || plan.isRest)) const PopupMenuItem(value: 'regen', child: Text('이 날 루틴 만들기')),
              if (!isPast && plan != null && !plan.isFinished) const PopupMenuItem(value: 'regen', child: Text('루틴 다시 생성')),
              if (plan == null || !plan.isFinished)
                PopupMenuItem(
                  value: 'rest',
                  child: Text(plan?.isRest == true || plan?.skipped == true
                      ? (isPast && plan?.isRest == true ? '휴식 표시 지우기' : '휴식 해제 (운동일로)')
                      : '휴식일로 표시'),
                ),
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
          : isFuture && !plan.isRest && !plan.isFinished && plan.exercises.isNotEmpty
              ? _FuturePlan(plan: plan, date: d)
              : DayPlanView(plan: plan, editable: !isPast, logging: !isFuture),
    );
  }

  Future<void> _menu(BuildContext context, AppState state, String v, DayPlan? plan) async {
    final d = dateOnly(date);
    switch (v) {
      case 'copy':
        await copyPastRoutineDialog(context, d);
      case 'import':
        await importRoutineDialog(context, d);
      case 'regen':
        if (await confirmRebuildIfStarted(context, plan)) await state.regenerateDay(d);
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

/// 아직 안 온 날: 헬스장이 정해지지 않았으니 부위·세트 구성만 보여 주고, 운동 목록은 눌러야 펼친다.
class _FuturePlan extends StatefulWidget {
  const _FuturePlan({required this.plan, required this.date});
  final DayPlan plan;
  final DateTime date;

  @override
  State<_FuturePlan> createState() => _FuturePlanState();
}

class _FuturePlanState extends State<_FuturePlan> {
  bool _list = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final state = context.watch<AppState>();
    final plan = widget.plan;
    if (_list) {
      return Column(children: [
        Material(
          color: cs.surfaceContainerHigh,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.info_outline, size: 20),
            title: const Text('운동은 예시예요 · 헬스장이 정해지면 바뀔 수 있어요'),
            trailing: TextButton(onPressed: () => setState(() => _list = false), child: const Text('구성만 보기')),
          ),
        ),
        Expanded(child: DayPlanView(plan: plan, editable: true, logging: false)),
      ]);
    }
    // 근력 부위 먼저, 유산소는 맨 뒤.
    final tally = [for (final t in tallyPlan(plan).values) if (t.exercises > 0) t]
      ..sort((a, b) => (a.group == MuscleGroup.cardio ? 1 : 0) - (b.group == MuscleGroup.cardio ? 1 : 0));
    final sets = tally.where((t) => t.group != MuscleGroup.cardio).fold<int>(0, (a, t) => a + t.sets);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      Text(plan.displayTitle, style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(
        '본운동 $sets세트${plan.estimatedMinutes > 0 ? ' · 약 ${plan.estimatedMinutes}분' : ''}${placeLabel(context, plan)}${plan.partnerName != null ? ' · 👥 ${plan.partnerName}' : ''}',
        style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      ),
      const SizedBox(height: 4),
      Text('헬스장이 아직 정해지지 않아서 부위·세트 구성만 보여요. 어떤 운동을 할지는 그날 기구에 맞춰 골라요.',
          style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      const SizedBox(height: 12),
      for (final t in tally)
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(t.group.label, style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                Text(t.amount, style: text.titleSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
              ]),
              if (t.subs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(t.subText, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ),
            ]),
          ),
        ),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (state.gyms.length > 1)
          FilledButton.tonalIcon(
            onPressed: () async {
              if (await confirmRebuildIfStarted(context, plan) && context.mounted) await makeDayWithGym(context, widget.date);
            },
            icon: const Icon(Icons.place_outlined),
            label: const Text('헬스장 정하기'),
          ),
        OutlinedButton.icon(
          onPressed: () => setState(() => _list = true),
          icon: const Icon(Icons.list),
          label: const Text('운동 목록 보기 · 수정'),
        ),
      ]),
    ]);
  }
}
