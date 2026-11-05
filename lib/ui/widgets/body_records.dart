import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';

String _n(double v) => v % 1 == 0 ? '${v.toInt()}' : v.toStringAsFixed(1);
String _d(DateTime d) => '${d.year % 100}.${d.month}.${d.day}';
String _ago(DateTime d) {
  final days = DateTime.now().difference(d).inDays;
  if (days <= 0) return '오늘';
  if (days < 7) return '$days일 전';
  if (days < 60) return '${days ~/ 7}주 전';
  return '${days ~/ 30}달 전';
}

/// 체성분(체중·골격근·체지방): 지금 값 + 지난 측정 대비 변화 + '새로 측정'.
class BodyRecordsCard extends StatelessWidget {
  const BodyRecordsCard({super.key, required this.user});
  final UserProfile user;

  /// [pick] 값이 있는 측정 중 마지막 두 개(이전, 최근).
  static (double?, double?, DateTime?) _lastTwo(List<BodyEntry> log, double? Function(BodyEntry) pick) {
    final xs = log.where((e) => pick(e) != null).toList();
    if (xs.isEmpty) return (null, null, null);
    return (xs.length > 1 ? pick(xs[xs.length - 2]) : null, pick(xs.last), xs.last.date);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final log = user.bodyLog;
    final w = _lastTwo(log, (e) => e.weightKg);
    final m = _lastTwo(log, (e) => e.skeletalMuscleKg);
    final f = _lastTwo(log, (e) => e.bodyFatPct);
    final last = log.isEmpty ? null : log.last.date;
    return _RecordCard(
      title: '체성분',
      subtitle: last == null ? '아직 측정 기록이 없어요. 재면 날짜별로 쌓여요.' : '마지막 측정 ${_ago(last)} (${_d(last)}) · ${log.length}회 기록',
      tiles: [
        _Tile(label: '체중', value: user.weightKg, unit: 'kg', prev: w.$1, cur: w.$2, goodWhenUp: null),
        _Tile(label: '골격근', value: user.skeletalMuscleKg, unit: 'kg', prev: m.$1, cur: m.$2, goodWhenUp: true),
        _Tile(label: '체지방', value: user.bodyFatPct, unit: '%', prev: f.$1, cur: f.$2, goodWhenUp: false),
      ],
      primary: FilledButton.tonalIcon(
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('새로 측정'),
        onPressed: () => _measure(context, user),
      ),
      onHistory: log.isEmpty ? null : () => _BodyHistory.show(context),
      hint: Text('인바디를 다시 재거나 체중이 바뀌면 \'새로 측정\'으로 남겨 주세요. 무게 계산·레벨 판정은 가장 최근 값으로 해요.',
          style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
    );
  }

  static Future<void> _measure(BuildContext context, UserProfile u) async {
    final state = context.read<AppState>();
    final w = TextEditingController(text: _n(u.weightKg));
    final m = TextEditingController(text: u.skeletalMuscleKg == null ? '' : _n(u.skeletalMuscleKg!));
    final f = TextEditingController(text: u.bodyFatPct == null ? '' : _n(u.bodyFatPct!));
    var date = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('새로 측정'),
          scrollable: true,
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_rounded),
              title: Text('측정일 ${_d(date)}'),
              trailing: const Icon(Icons.edit_calendar_rounded, size: 20),
              onTap: () async {
                final d = await showDatePicker(context: c, initialDate: date, firstDate: DateTime(2015), lastDate: DateTime.now());
                if (d != null) set(() => date = d);
              },
            ),
            _num(w, '체중 (kg)'),
            _num(m, '골격근량 (kg, 인바디 · 선택)'),
            _num(f, '체지방률 (%, 인바디 · 선택)'),
            const SizedBox(height: 6),
            Text('잰 것만 적으면 돼요. 비운 항목은 이전 값을 그대로 써요.', style: Theme.of(c).textTheme.bodySmall),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('기록')),
          ],
        ),
      ),
    );
    if (ok == true) {
      await state.addBodyMeasurement(
        weightKg: double.tryParse(w.text),
        skeletalMuscleKg: double.tryParse(m.text),
        bodyFatPct: double.tryParse(f.text),
        date: date,
      );
    }
  }
}

Widget _num(TextEditingController c, String label) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, isDense: true),
      ),
    );

/// 3대+OHP: 지금 기록 + 언제·어떻게(직접/자동) 바뀌었는지 + 탭해서 새 기록.
class LiftRecordsCard extends StatelessWidget {
  const LiftRecordsCard({super.key, required this.user});
  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final total = (user.squat1rm ?? 0) + (user.bench1rm ?? 0) + (user.deadlift1rm ?? 0);
    LiftEntry? lastOf(String lift) {
      final xs = user.liftLog.where((e) => e.lift == lift).toList();
      return xs.isEmpty ? null : xs.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
    }

    double? prevOf(String lift) {
      final xs = user.liftLog.where((e) => e.lift == lift).toList()..sort((a, b) => a.date.compareTo(b.date));
      return xs.length > 1 ? xs[xs.length - 2].kg : null;
    }

    return _RecordCard(
      title: '3대 기록 (1RM)',
      subtitle: total > 0 ? '3대 합계 ${_n(total)}kg' : '눌러서 입력하세요. 비우면 신체 스펙으로 추정해요.',
      tiles: [
        for (final lift in const ['squat', 'bench', 'deadlift', 'ohp'])
          _Tile(
            label: lift == 'deadlift' ? '데드' : LiftEntry.labels[lift]!,
            value: user.liftRecord(lift),
            unit: 'kg',
            prev: prevOf(lift),
            cur: user.liftRecord(lift),
            goodWhenUp: true,
            foot: switch (lastOf(lift)) {
              null => null,
              final e => '${e.auto ? '⚡' : ''}${_ago(e.date)}',
            },
            onTap: () => _edit(context, user, lift),
          ),
      ],
      onHistory: user.liftLog.isEmpty ? null : () => _LiftHistory.show(context),
      hint: Text('운동을 마치면 스쿼트·벤치·데드·OHP 세트(1~10회)의 무게×횟수로 1RM을 추정해서, 지금 기록보다 높으면 자동으로 갱신해요(⚡ 표시). 칸을 누르면 직접 고칠 수 있어요.',
          style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
    );
  }

  static Future<void> _edit(BuildContext context, UserProfile u, String lift) async {
    final state = context.read<AppState>();
    final cur = u.liftRecord(lift);
    final c = TextEditingController(text: cur == null ? '' : _n(cur));
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${LiftEntry.labels[lift]} 기록'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _num(c, '1RM 또는 최고 중량 (kg)'),
          const SizedBox(height: 4),
          Text('오늘 날짜로 기록이 남아요.', style: Theme.of(ctx).textTheme.bodySmall),
        ]),
        actions: [
          if (cur != null) TextButton(onPressed: () => Navigator.pop(ctx, 'clear'), child: const Text('비우기(추정 사용)')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('기록')),
        ],
      ),
    );
    if (r == 'clear') await state.setLiftRecord(lift, null);
    if (r == 'save') {
      final v = double.tryParse(c.text);
      if (v != null && v > 0 && v != cur) await state.setLiftRecord(lift, v);
    }
  }
}

class _Tile {
  const _Tile({required this.label, required this.value, required this.unit, this.prev, this.cur, this.goodWhenUp, this.foot, this.onTap});
  final String label;
  final double? value;
  final String unit;
  final double? prev;
  final double? cur;

  /// 오르면 좋은지(초록) 나쁜지(빨강). null이면 중립.
  final bool? goodWhenUp;
  final String? foot;
  final VoidCallback? onTap;
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.title, required this.subtitle, required this.tiles, this.primary, this.onHistory, this.hint});
  final String title;
  final String subtitle;
  final List<_Tile> tiles;
  final Widget? primary;
  final VoidCallback? onHistory;
  final Widget? hint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: text.titleSmall),
                Text(subtitle, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ]),
            ),
            if (onHistory != null)
              TextButton.icon(icon: const Icon(Icons.show_chart_rounded, size: 18), label: const Text('추이'), onPressed: onHistory),
          ]),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final (i, t) in tiles.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _TileView(t)),
            ],
          ])),
          if (primary != null) ...[const SizedBox(height: 10), SizedBox(width: double.infinity, child: primary)],
          if (hint != null) ...[const SizedBox(height: 8), hint!],
        ]),
      ),
    );
  }
}

class _TileView extends StatelessWidget {
  const _TileView(this.t);
  final _Tile t;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final diff = (t.prev != null && t.cur != null) ? t.cur! - t.prev! : null;
    Color? diffColor;
    if (diff != null && diff != 0 && t.goodWhenUp != null) {
      diffColor = (diff > 0) == t.goodWhenUp ? Colors.green.shade600 : cs.error;
    }
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: t.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(children: [
            Text(t.label, maxLines: 1, style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 2),
            FittedBox(
              child: Text.rich(TextSpan(children: [
                TextSpan(text: t.value == null ? '-' : _n(t.value!), style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                if (t.value != null) TextSpan(text: t.unit, style: text.labelSmall),
              ])),
            ),
            if (diff != null && diff != 0)
              Text('${diff > 0 ? '▲' : '▼'}${_n(diff.abs())}', style: text.labelSmall?.copyWith(color: diffColor ?? cs.onSurfaceVariant, fontWeight: FontWeight.w700))
            else if (t.foot == null)
              Text(' ', style: text.labelSmall),
            if (t.foot != null)
              Text(t.foot!, style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}

/// 날짜별 값 꺾은선(점 2개 이상일 때).
class _Trend extends StatelessWidget {
  const _Trend({required this.label, required this.points, required this.unit});
  final String label;
  final List<(DateTime, double)> points;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    if (points.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$label  ${_n(points.first.$2)} → ${_n(points.last.$2)}$unit', style: text.titleSmall),
        const SizedBox(height: 6),
        SizedBox(
          height: 90,
          width: double.infinity,
          child: points.length < 2
              ? Center(child: Text('한 번 더 재면 그래프가 생겨요', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)))
              : CustomPaint(painter: _TrendPainter(points, cs.primary, cs.outlineVariant)),
        ),
      ]),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.points, this.color, this.grid);
  final List<(DateTime, double)> points;
  final Color color;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final t0 = points.first.$1.millisecondsSinceEpoch.toDouble();
    final t1 = points.last.$1.millisecondsSinceEpoch.toDouble();
    var lo = points.map((p) => p.$2).reduce((a, b) => a < b ? a : b);
    var hi = points.map((p) => p.$2).reduce((a, b) => a > b ? a : b);
    if (hi - lo < 1) {
      hi += 0.5;
      lo -= 0.5;
    }
    const pad = 8.0;
    Offset at((DateTime, double) p) => Offset(
          pad + (t1 == t0 ? 0.5 : (p.$1.millisecondsSinceEpoch - t0) / (t1 - t0)) * (size.width - pad * 2),
          pad + (1 - (p.$2 - lo) / (hi - lo)) * (size.height - pad * 2),
        );
    final g = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height - 1), Offset(size.width, size.height - 1), g);
    final path = Path();
    for (final (i, p) in points.indexed) {
      final o = at(p);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round);
    for (final p in points) {
      canvas.drawCircle(at(p), 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.points != points || old.color != color;
}

class _BodyHistory extends StatelessWidget {
  const _BodyHistory();

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => const _BodyHistory(),
      );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final log = state.currentUser?.bodyLog ?? const <BodyEntry>[];
    final text = Theme.of(context).textTheme;
    List<(DateTime, double)> pts(double? Function(BodyEntry) f) => [for (final e in log) if (f(e) != null) (e.date, f(e)!)];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (c, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text('체성분 추이', style: text.titleLarge),
          const SizedBox(height: 12),
          _Trend(label: '체중', points: pts((e) => e.weightKg), unit: 'kg'),
          _Trend(label: '골격근', points: pts((e) => e.skeletalMuscleKg), unit: 'kg'),
          _Trend(label: '체지방', points: pts((e) => e.bodyFatPct), unit: '%'),
          Text('측정 기록', style: text.titleSmall),
          for (final e in log.reversed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(_d(e.date)),
              subtitle: Text([
                if (e.weightKg != null) '체중 ${_n(e.weightKg!)}kg',
                if (e.skeletalMuscleKg != null) '골격근 ${_n(e.skeletalMuscleKg!)}kg',
                if (e.bodyFatPct != null) '체지방 ${_n(e.bodyFatPct!)}%',
              ].join(' · ')),
              trailing: IconButton(
                tooltip: '이 기록 지우기',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => state.removeBodyEntry(e),
              ),
            ),
        ],
      ),
    );
  }
}

class _LiftHistory extends StatelessWidget {
  const _LiftHistory();

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => const _LiftHistory(),
      );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final log = [...?state.currentUser?.liftLog]..sort((a, b) => a.date.compareTo(b.date));
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (c, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text('3대 기록 추이', style: text.titleLarge),
          const SizedBox(height: 12),
          for (final lift in const ['squat', 'bench', 'deadlift', 'ohp'])
            _Trend(label: LiftEntry.labels[lift]!, points: [for (final e in log) if (e.lift == lift) (e.date, e.kg)], unit: 'kg'),
          Text('기록', style: text.titleSmall),
          for (final e in log.reversed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('${e.label} ${_n(e.kg)}kg'),
              subtitle: Text('${_d(e.date)} · ${e.auto ? '운동 기록에서 자동${e.note == null ? '' : ' (${e.note})'}' : '직접 입력'}'),
              leading: Icon(e.auto ? Icons.auto_awesome_rounded : Icons.edit_rounded, size: 20, color: e.auto ? cs.primary : cs.onSurfaceVariant),
              trailing: IconButton(
                tooltip: '이 기록 지우기',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => state.removeLiftEntry(e),
              ),
            ),
        ],
      ),
    );
  }
}
