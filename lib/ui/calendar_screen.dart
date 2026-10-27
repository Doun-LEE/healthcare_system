import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/planner.dart';
import '../data/catalog.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'day_page.dart';
import 'day_plan_view.dart';
import 'widgets/place.dart';
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

  /// 연·월 직접 고르기: 연도 좌우 이동 + 12개월 버튼. '오늘'로 바로 가기도.
  Future<void> _pickMonth(BuildContext context) async {
    var year = _month.year;
    final now = DateTime.now();
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setDialog) {
        final cs = Theme.of(c).colorScheme;
        return AlertDialog(
          title: Row(children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setDialog(() => year--)),
            Expanded(child: Text('$year년', textAlign: TextAlign.center)),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setDialog(() => year++)),
          ]),
          content: SizedBox(
            width: 300,
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.6,
              children: [
                for (var m = 1; m <= 12; m++)
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: year == _month.year && m == _month.month ? cs.primary : (year == now.year && m == now.month ? cs.tertiaryContainer : null),
                      foregroundColor: year == _month.year && m == _month.month ? cs.onPrimary : null,
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () => Navigator.pop(c, DateTime(year, m)),
                    child: Text('$m월'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, DateTime(now.year, now.month)), child: const Text('오늘')),
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('취소')),
          ],
        );
      }),
    );
    if (picked != null && mounted) setState(() => _month = picked);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final plans = {for (final p in state.myPlans) dateKey(p.date): p};
    final today = context.read<AppState>().today;
    final selectedPlan = _selected == null ? null : plans[dateKey(_selected!)];

    return Scaffold(
      appBar: AppBar(
        // 제목을 누르면 연·월을 직접 고른다(멀리 있는 달로 바로 이동).
        title: InkWell(
          onTap: () => _pickMonth(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${_month.year}년 ${_month.month}월'),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 22),
            ]),
          ),
        ),
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
                : _DaySummary(
                    date: _selected!,
                    plan: selectedPlan,
                    isPast: _selected!.isBefore(today),
                    onOpen: () => DayPage.open(context, _selected!),
                    onMake: () => makeDayWithGym(context, _selected!),
                    onImport: () => importRoutineDialog(context, _selected!),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _generate(BuildContext context, AppState state, String mode) async {
    final today = context.read<AppState>().today;
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
    const wd = ['일', '월', '화', '수', '목', '금', '토'];
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
                      color: i == 0 ? cs.error : (i == 6 ? cs.primary : cs.onSurfaceVariant),
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
    final leading = first.weekday % 7; // 일요일 시작
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
      } else if (plan.isRest || plan.skipped) {
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
              Flexible(
                child: Text(
                  _focusLabel(plan),
                  style: TextStyle(fontSize: plan.focus.length > 3 ? 8.5 : 10, height: 1.15, color: fg, decoration: plan.skipped ? TextDecoration.lineThrough : null),
                  overflow: TextOverflow.ellipsis,
                  maxLines: plan.skipped ? 1 : 3,
                ),
              ),
            if (plan != null && plan.isRest)
              Text('휴식', style: TextStyle(fontSize: 10, color: fg)),
            if (plan != null && plan.skipped)
              Text('휴식', style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.bold)),
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

/// 달력 아래 요약 카드. 탭하면 전체 화면으로.
class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.date, required this.plan, required this.isPast, required this.onOpen, required this.onMake, required this.onImport});
  final DateTime date;
  final DayPlan? plan;
  final bool isPast;
  final VoidCallback onOpen, onMake, onImport;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final p = plan;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Card(
        color: p == null ? cs.surfaceContainerHigh : p.isRest ? cs.tertiaryContainer : cs.primaryContainer,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: p == null ? null : onOpen,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      p == null ? '${date.month}/${date.day} 계획 없음' : p.isRest ? '${date.month}/${date.day} 휴식일' : p.displayTitle,
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (p != null) const Icon(Icons.open_in_full, size: 18),
                ]),
                if (p != null && !p.isRest) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${p.exercises.length}개 운동 · 약 ${p.estimatedMinutes}분'
                    '${placeLabel(context, p)}'
                    '${p.partnerName != null ? ' · 👥 ${p.partnerName}' : ''}'
                    '${p.isFinished ? ' · 완료 ${(p.completionRatio * 100).round()}%' : ''}',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.exercises.map((e) => exerciseById(e.exerciseId)?.name ?? '').join(' · '),
                    style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    if (!p.isFinished) Expanded(child: Align(alignment: Alignment.centerLeft, child: PartnerDayButton(date: date, plan: p))),
                    if (p.isFinished) const Spacer(),
                    FilledButton.tonalIcon(onPressed: onOpen, icon: const Icon(Icons.open_in_full, size: 16), label: const Text('자세히 · 수정')),
                  ]),
                ],
                if (p != null && p.isRest)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      Expanded(child: Text(p.displayTitle, style: text.bodySmall)),
                      TextButton(onPressed: onOpen, child: const Text('열기')),
                    ]),
                  ),
                if (p == null && !isPast)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(spacing: 8, children: [
                      OutlinedButton.icon(onPressed: onMake, icon: const Icon(Icons.add), label: const Text('이 날 루틴 만들기')),
                      PartnerDayButton(date: date),
                      TextButton.icon(onPressed: onImport, icon: const Icon(Icons.download_outlined), label: const Text('친구 루틴 불러오기')),
                    ]),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 달력 칸의 부위 글자: 전신(큰 부위 4개 이상)이면 '전신', 아니면 부위를 전부(복근·유산소는 뒤에) 보여준다.
String _focusLabel(DayPlan plan) => focusTitle(plan.focus);
