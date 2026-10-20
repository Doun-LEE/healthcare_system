import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/stats.dart';
import '../models/models.dart';
import '../state/app_state.dart';

/// 기록 탭: 완료한 세션으로 부위별 밸런스, 주간 빈도, 주요 운동 무게 추이.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _days = 28;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = Stats.summarize(state.myPlans, days: _days);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('기록 · 밸런스'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 14, label: Text('2주')),
                ButtonSegment(value: 28, label: Text('4주')),
                ButtonSegment(value: 84, label: Text('12주')),
              ],
              selected: {_days},
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              onSelectionChanged: (v) => setState(() => _days = v.first),
            ),
          ),
        ],
      ),
      body: s.sessions == 0
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.insights, size: 72, color: cs.primary),
                    const SizedBox(height: 12),
                    Text('아직 완료한 세션이 없어요', style: text.titleLarge),
                    const SizedBox(height: 6),
                    Text('운동을 끝내고 「운동 완료」를 누르면 여기에 밸런스와 무게 추이가 쌓입니다.',
                        textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // 요약 타일
                Row(children: [
                  _Tile(label: '세션', value: '${s.sessions}회'),
                  _Tile(label: '세트', value: '${s.totalSets}'),
                  _Tile(label: '총 볼륨', value: s.totalTonnage >= 1000 ? '${(s.totalTonnage / 1000).toStringAsFixed(1)}t' : '${s.totalTonnage.round()}kg'),
                  _Tile(label: '평균 강도', value: s.avgRpe == null ? '-' : s.avgRpe!.toStringAsFixed(1)),
                ]),
                const SizedBox(height: 14),

                // 부위별 밸런스
                _Card(
                  title: '부위별 밸런스 (완료 세트)',
                  subtitle: s.sessions < 3
                      ? '세션이 3회 이상 쌓이면 부족한 부위를 알려드려요.'
                      : s.underTrained.isEmpty
                          ? '골고루 하고 있어요.'
                          : '${s.underTrained.map((g) => g.label).join('·')} 이(가) 다른 부위보다 적어요. 다음 루틴에 보강됩니다.',
                  subtitleWarn: s.underTrained.isNotEmpty,
                  child: _BalanceBars(summary: s),
                ),

                // 주간 세션
                _Card(
                  title: '주간 세션 수',
                  subtitle: '막대 = 그 주에 완료한 세션. 숫자는 세트.',
                  child: _WeekBars(weeks: s.weeks),
                ),

                // 무게 추이
                if (s.trends.isNotEmpty)
                  _Card(
                    title: '주요 운동 무게 추이',
                    subtitle: '세션별 최고 수행 무게. 같은 운동을 2회 이상 했을 때 표시.',
                    child: Column(
                      children: [for (final t in s.trends) _TrendRow(trend: t)],
                    ),
                  ),
                if (s.cardioMinutes > 0)
                  _Card(
                    title: '유산소',
                    subtitle: '$_days일 동안 총 ${s.cardioMinutes}분 · 주 평균 ${(s.cardioMinutes / (_days / 7)).round()}분',
                    child: const SizedBox.shrink(),
                  ),
              ],
            ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Text(value, style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text(label, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.subtitle, required this.child, this.subtitleWarn = false});
  final String title, subtitle;
  final Widget child;
  final bool subtitleWarn;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.titleMedium),
            const SizedBox(height: 2),
            Row(children: [
              if (subtitleWarn) ...[
                Icon(Icons.warning_amber_rounded, size: 16, color: cs.tertiary),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(subtitle,
                    style: text.bodySmall?.copyWith(color: subtitleWarn ? cs.tertiary : cs.onSurfaceVariant)),
              ),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// 부위별 가로 막대 (단일 색, 부족한 부위는 보조색 + 아이콘으로 구분).
class _BalanceBars extends StatelessWidget {
  const _BalanceBars({required this.summary});
  final StatsSummary summary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final groups = summary.groups.where((g) => g.group != MuscleGroup.cardio).toList();
    final maxSets = groups.fold<int>(0, (a, g) => max(a, g.sets));
    final under = summary.underTrained;
    return Column(
      children: [
        for (final g in groups)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(g.group.label, style: text.bodyMedium),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (c, bc) {
                      final w = maxSets == 0 ? 0.0 : bc.maxWidth * g.sets / maxSets;
                      return Stack(
                        children: [
                          Container(height: 18, decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(4))),
                          Container(
                            height: 18,
                            width: max(w, g.sets > 0 ? 6 : 0),
                            decoration: BoxDecoration(
                              color: under.contains(g.group) ? cs.tertiary : cs.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 70,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (under.contains(g.group)) Icon(Icons.arrow_downward, size: 14, color: cs.tertiary),
                      Text('${g.sets}세트', style: text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                '총 ${summary.totalSets}세트 · 가장 많이: ${summary.mostTrained?.label ?? '-'}',
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 주간 세션 수 세로 막대 (단일 색).
class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.weeks});
  final List<WeekCount> weeks;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final maxS = weeks.fold<int>(0, (a, w) => max(a, w.sessions));
    return SizedBox(
      height: 136,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final w in weeks)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (w.sessions > 0) Text('${w.sets}', style: text.labelSmall),
                    Container(
                      height: maxS == 0 ? 2 : max(4, 70.0 * w.sessions / maxS),
                      decoration: BoxDecoration(
                        color: w.sessions == 0 ? cs.surfaceContainerHighest : cs.primary,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${w.weekStart.month}/${w.weekStart.day}', style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                    Text('${w.sessions}회', style: text.labelSmall),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 운동 하나의 무게 추이: 이름 · 시작→현재 · 스파크라인.
class _TrendRow extends StatelessWidget {
  const _TrendRow({required this.trend});
  final LiftTrend trend;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final d = trend.delta;
    final up = d > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trend.exercise.name, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                Text(
                  '${_fmt(trend.first)} → ${_fmt(trend.last)}kg  (${up ? '+' : ''}${_fmt(d)})',
                  style: text.bodySmall?.copyWith(color: up ? cs.primary : (d < 0 ? cs.error : cs.onSurfaceVariant)),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 36,
              child: CustomPaint(painter: _Spark(trend.points.map((p) => p.weight).toList(), cs.primary, cs.surfaceContainerHighest)),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double w) => w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);
}

class _Spark extends CustomPainter {
  _Spark(this.values, this.color, this.grid);
  final List<double> values;
  final Color color, grid;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final lo = values.reduce(min), hi = values.reduce(max);
    final span = (hi - lo) == 0 ? 1.0 : (hi - lo);
    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = 4 + (size.width - 8) * i / (values.length - 1);
      final y = size.height - 4 - (size.height - 8) * (values[i] - lo) / span;
      pts.add(Offset(x, y));
    }
    canvas.drawLine(Offset(0, size.height - 1), Offset(size.width, size.height - 1), Paint()..color = grid..strokeWidth = 1);
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path, p);
    canvas.drawCircle(pts.last, 4, Paint()..color = color);
    canvas.drawCircle(pts.last, 4, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _Spark old) => old.values != values || old.color != color;
}
