import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/planner.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'day_plan_view.dart';
import 'widgets/ai_coach_sheet.dart';
import 'widgets/partner_widgets.dart';

/// 월간 달력. 탭=상세, 길게 누르기=휴식 토글, 상단 버튼으로 주/월 생성.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
    _selected = dateOnly(n);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final plans = {for (final p in state.myPlans) dateKey(p.date): p};
    final today = dateOnly(DateTime.now());
    final selectedPlan = _selected == null ? null : plans[dateKey(_selected!)];

    return Scaffold(
      appBar: AppBar(
        title: Text('${_month.year}년 ${_month.month}월'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.auto_awesome),
            tooltip: '루틴 생성',
            onSelected: (v) => _generate(context, state, v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'week', child: Text('이번 주 생성 (오늘부터 7일)')),
              PopupMenuItem(value: 'month', child: Text('이번 달 생성 (오늘부터 월말)')),
              PopupMenuItem(value: '4weeks', child: Text('4주 생성 (오늘부터 28일)')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'clear', child: Text('오늘 이후 미완료 계획 삭제')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _WeekdayHeader(),
          _MonthGrid(
            month: _month,
            plans: plans,
            selected: _selected,
            today: today,
            onTap: (d) => setState(() => _selected = d),
            onLongPress: (d) async {
              if (d.isBefore(today)) return;
              await state.toggleRestDay(d);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(state.planOn(d)?.isRest == true
                      ? '${d.month}/${d.day} 휴식일로 표시했어요. 루틴을 다시 생성하면 반영됩니다.'
                      : '${d.month}/${d.day} 운동일로 되돌렸어요.'),
                  duration: const Duration(seconds: 2),
                ));
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              _Legend(color: cs.primary, label: '운동'),
              _Legend(color: cs.tertiary, label: '휴식'),
              _Legend(color: cs.outline, label: '완료'),
              const Spacer(),
              Text('길게 눌러 휴식 토글', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _selected == null
                ? const SizedBox()
                : selectedPlan == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${_selected!.month}월 ${_selected!.day}일 계획 없음', style: text.titleMedium),
                            const SizedBox(height: 8),
                            if (!_selected!.isBefore(today)) ...[
                              OutlinedButton.icon(
                                onPressed: () => state.regenerateDay(_selected!),
                                icon: const Icon(Icons.add),
                                label: const Text('이 날만 루틴 만들기'),
                              ),
                              TextButton.icon(
                                onPressed: () => importRoutineDialog(context, _selected!),
                                icon: const Icon(Icons.download_outlined),
                                label: const Text('친구 루틴 불러오기'),
                              ),
                              PartnerDayButton(date: _selected!),
                            ],
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          if (!_selected!.isBefore(today) && !selectedPlan.isFinished && !selectedPlan.isRest)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Row(children: [
                                PartnerDayButton(date: _selected!, plan: selectedPlan),
                                TextButton.icon(
                                  onPressed: () => showAiCoach(context, _selected!),
                                  icon: const Icon(Icons.auto_awesome),
                                  label: const Text('AI 코치'),
                                ),
                              ]),
                            ),
                          Expanded(
                            child: DayPlanView(
                              plan: selectedPlan,
                              editable: !selectedPlan.date.isBefore(today),
                              logging: !selectedPlan.date.isAfter(today),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _generate(BuildContext context, AppState state, String mode) async {
    final today = dateOnly(DateTime.now());
    if (mode == 'clear') {
      await state.deletePlansFrom(today);
      return;
    }
    final to = switch (mode) {
      'week' => today.add(const Duration(days: 6)),
      '4weeks' => today.add(const Duration(days: 27)),
      _ => DateTime(today.year, today.month + 1, 0),
    };
    final rest = state.manualRestDays;
    final generated = await state.generatePlans(from: today, to: to, restDays: rest);
    if (!context.mounted) return;
    final summary = Planner.summarize(generated);
    final streak = Planner.maxStreak(generated);
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${today.month}/${today.day} ~ ${to.month}/${to.day} 루틴 생성'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('운동일 ${summary['운동일']}일 · 휴식일 ${summary['휴식일']}일 · 최대 연속 운동 $streak일'),
            const SizedBox(height: 8),
            Text('부위별 횟수', style: Theme.of(c).textTheme.labelLarge),
            Wrap(
              spacing: 6,
              children: [
                for (final g in MuscleGroup.values)
                  if ((summary[g.label] ?? 0) > 0)
                    Chip(label: Text('${g.label} ${summary[g.label]}'), visualDensity: VisualDensity.compact),
              ],
            ),
            const SizedBox(height: 8),
            Text('이미 완료한 날은 그대로 두고, 체크한 휴식일과 부위별 회복 시간을 반영했습니다.',
                style: Theme.of(c).textTheme.bodySmall),
          ],
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('확인'))],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Center(
                child: Text(wd[i],
                    style: TextStyle(
                      fontSize: 12,
                      color: i == 6 ? cs.error : (i == 5 ? cs.primary : cs.onSurfaceVariant),
                    )),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.plans,
    required this.selected,
    required this.today,
    required this.onTap,
    required this.onLongPress,
  });

  final DateTime month;
  final Map<String, DayPlan> plans;
  final DateTime? selected;
  final DateTime today;
  final void Function(DateTime) onTap;
  final void Function(DateTime) onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1; // 월요일 시작
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(child: _cell(context, cs, r * 7 + c - leading + 1, daysInMonth)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, ColorScheme cs, int day, int daysInMonth) {
    if (day < 1 || day > daysInMonth) return const SizedBox(height: 52);
    final date = DateTime(month.year, month.month, day);
    final plan = plans[dateKey(date)];
    final isToday = dateKey(date) == dateKey(today);
    final isSelected = selected != null && dateKey(date) == dateKey(selected!);

    Color? bg;
    Color fg = cs.onSurface;
    if (plan != null) {
      if (plan.isFinished) {
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurfaceVariant;
      } else if (plan.isRest) {
        bg = cs.tertiaryContainer;
        fg = cs.onTertiaryContainer;
      } else {
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
      }
    }

    return GestureDetector(
      onTap: () => onTap(date),
      onLongPress: () => onLongPress(date),
      child: Container(
        height: 52,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? cs.primary : (isToday ? cs.outline : Colors.transparent),
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$day', style: TextStyle(fontSize: 12, fontWeight: isToday ? FontWeight.bold : null, color: fg)),
            if (plan != null && !plan.isRest)
              Expanded(
                child: Text(
                  plan.focus.take(2).map((g) => g.label).join('·'),
                  style: TextStyle(fontSize: 10, color: fg),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            if (plan != null && plan.isRest)
              Text('휴식', style: TextStyle(fontSize: 10, color: fg)),
            Row(children: [
              if (plan != null && plan.isFinished) Icon(Icons.check, size: 12, color: cs.primary),
              if (plan != null && plan.partnerName != null) Icon(Icons.group, size: 12, color: cs.secondary),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}
