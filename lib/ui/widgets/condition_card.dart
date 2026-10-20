import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';

/// 컨디션 1~10 → 기본 무게 배율. 사용자가 % 를 따로 조절할 수도 있다.
double loadFactorForCondition(int c) => switch (c) {
      <= 2 => 0.6,
      3 => 0.7,
      4 => 0.8,
      5 => 0.85,
      6 => 0.9,
      7 => 0.95,
      8 => 1.0,
      9 => 1.0,
      _ => 1.05,
    };

String conditionLabel(int c) => switch (c) {
      <= 2 => '최악',
      <= 4 => '나쁨',
      <= 6 => '보통',
      <= 8 => '좋음',
      _ => '최상',
    };

/// 애플워치식 운동 강도 라벨 (1~3 쉬움, 4~6 보통, 7~9 어려움, 10 전력투구).
String rpeLabel(int r) => switch (r) {
      <= 3 => '쉬움',
      <= 6 => '보통',
      <= 9 => '어려움',
      _ => '전력투구',
    };

/// 운동 시작 전 "오늘 컨디션" 카드. 적용하면 같은 부위 구성으로 무게·시간만 다시 뽑는다.
class ConditionCard extends StatefulWidget {
  const ConditionCard({super.key, required this.plan});
  final DayPlan plan;

  @override
  State<ConditionCard> createState() => _ConditionCardState();
}

class _ConditionCardState extends State<ConditionCard> {
  late int _condition;
  late int _percent;
  late int _minutes;
  bool _open = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _condition = p.condition ?? 8;
    _percent = (p.loadFactor * 100).round();
    _minutes = p.estimatedMinutes > 0 ? _round10(p.estimatedMinutes) : 90;
  }

  int _round10(int v) => ((v / 10).round() * 10).clamp(30, 180);

  Future<void> _apply() async {
    setState(() => _busy = true);
    final state = context.read<AppState>();
    await state.applyCondition(
      widget.plan.date,
      condition: _condition,
      loadFactor: _percent / 100,
      minutes: _minutes,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _open = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('컨디션 $_condition/10 · 무게 $_percent% · $_minutes분으로 오늘 루틴을 다시 맞췄어요.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final p = widget.plan;
    final applied = p.condition != null;
    final user = context.read<AppState>().currentUser;
    final defaultMinutes = user?.sessionMinutes ?? 120;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: cs.secondaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Row(
                children: [
                  Icon(Icons.monitor_heart_outlined, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('오늘 컨디션', style: text.titleMedium),
                        Text(
                          applied
                              ? '${p.condition}/10 ${conditionLabel(p.condition!)} · 무게 ${(p.loadFactor * 100).round()}% · 약 ${p.estimatedMinutes}분'
                              : '시작 전에 컨디션·운동 시간을 맞추면 오늘 무게가 조정됩니다',
                          style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(_open ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
            if (_open) ...[
              const SizedBox(height: 10),
              Row(children: [
                Text('컨디션', style: text.labelLarge),
                const Spacer(),
                Text('$_condition/10 · ${conditionLabel(_condition)}', style: text.labelLarge?.copyWith(color: cs.primary)),
              ]),
              Slider(
                value: _condition.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: '$_condition ${conditionLabel(_condition)}',
                onChanged: (v) => setState(() {
                  _condition = v.round();
                  _percent = (loadFactorForCondition(_condition) * 100).round();
                }),
              ),
              Row(children: [
                Text('무게 (평소 대비)', style: text.labelLarge),
                const Spacer(),
                Text('$_percent%', style: text.labelLarge?.copyWith(color: cs.primary)),
              ]),
              Slider(
                value: _percent.toDouble(),
                min: 50,
                max: 110,
                divisions: 12,
                label: '$_percent%',
                onChanged: (v) => setState(() => _percent = (v / 5).round() * 5),
              ),
              if (p.partnerName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('${p.partnerName}와 파트너 운동: 운동 구성은 그대로 두고 내 무게만 조정합니다.',
                      style: text.bodySmall?.copyWith(color: cs.secondary)),
                ),
              Row(children: [
                Text('오늘 운동 시간', style: text.labelLarge),
                const Spacer(),
                Text('$_minutes분${_minutes == defaultMinutes ? ' (기본)' : ''}', style: text.labelLarge?.copyWith(color: cs.primary)),
              ]),
              Slider(
                value: _minutes.toDouble(),
                min: 30,
                max: 180,
                divisions: 15,
                label: '$_minutes분',
                onChanged: (v) => setState(() => _minutes = (v / 10).round() * 10),
              ),
              Text(
                _percent < 85
                    ? '무게를 낮춘 날은 횟수를 2회 늘려 볼륨을 일부 보전하고, 기준 무게는 올리지 않습니다.'
                    : _percent > 100
                        ? '컨디션 최상: 평소보다 무겁게. 성공하면 기준 무게가 그만큼 올라갑니다.'
                        : '평소 무게 기준으로 진행합니다.',
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _apply,
                  icon: const Icon(Icons.check),
                  label: const Text('오늘 루틴에 적용'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 운동 후 강도 평가. 선택한 1~10을 돌려주고, 건너뛰면 null.
Future<int?> showRpePicker(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (c) {
      final cs = Theme.of(c).colorScheme;
      final text = Theme.of(c).textTheme;
      Widget group(String title, String desc, List<int> values, Color color) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleSmall),
                      Text(desc, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final v in values)
                        ActionChip(
                          label: Text('$v'),
                          backgroundColor: color.withValues(alpha: 0.18),
                          side: BorderSide(color: color.withValues(alpha: 0.5)),
                          onPressed: () => Navigator.pop(c, v),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('오늘 운동 강도는 어땠나요?', style: text.titleLarge),
            Text('다음 루틴의 무게 조절에 반영됩니다.', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            group('쉬움', '여유 있게 끝남', [1, 2, 3], Colors.lightBlue),
            group('보통', '적당히 힘듦', [4, 5, 6], Colors.green),
            group('어려움', '마지막 세트 간신히', [7, 8, 9], Colors.orange),
            group('전력투구', '한계까지', [10], Colors.red),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('건너뛰기')),
          ],
        ),
      );
    },
  );
}
