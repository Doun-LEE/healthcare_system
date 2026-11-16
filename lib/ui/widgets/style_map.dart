import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/training_style.dart';

/// 지도 위 점 하나(나·파트너·함께).
class StylePoint {
  const StylePoint(this.label, this.style, this.color, {this.combined = false, this.from});
  final String label;
  final TrainingStyle style;
  final Color color;

  /// '함께' 점은 마름모로.
  final bool combined;

  /// 지난달 위치(있으면 거기서 지금 점까지 화살표).
  final TrainingStyle? from;
}

/// 사람 점 색(나 → 파트너 순). '함께'는 [combinedColor].
const styleColors = [Color(0xFFD85A30), Color(0xFF7F77DD), Color(0xFF378ADD), Color(0xFFBA7517), Color(0xFFD4537E)];
const combinedColor = Color(0xFF1D9E75);

/// 3×3 운동 성향 지도. 가로 유산소 ↔ 웨이트, 세로 가볍게 ↔ 고강도.
class StyleMap extends StatelessWidget {
  const StyleMap({super.key, required this.points, this.size = 260});
  final List<StylePoint> points;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: '운동 성향 지도: ${points.map((p) => '${p.label} ${p.style.name}').join(', ')}',
      child: SizedBox(
        width: size + 34,
        height: size + 22,
        child: CustomPaint(
          painter: _MapPainter(
            points: points,
            grid: cs.outlineVariant,
            bg: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            zoneText: cs.onSurfaceVariant.withValues(alpha: 0.75),
            axisText: cs.onSurfaceVariant,
            labelText: cs.onSurface,
            ring: cs.surface,
            font: DefaultTextStyle.of(context).style.fontFamily,
          ),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.points,
    required this.grid,
    required this.bg,
    required this.zoneText,
    required this.axisText,
    required this.labelText,
    required this.ring,
    this.font,
  });
  final List<StylePoint> points;
  final Color grid, bg, zoneText, axisText, labelText, ring;
  final String? font;

  void _text(Canvas c, String s, Offset at, {double size = 10, Color? color, FontWeight w = FontWeight.w500, Alignment align = Alignment.center}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color ?? zoneText, fontWeight: w, fontFamily: font)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = (align.x + 1) / 2 * tp.width;
    final dy = (align.y + 1) / 2 * tp.height;
    tp.paint(c, at - Offset(dx, dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0;
    final side = min(size.width - left, size.height - 22);
    final area = Rect.fromLTWH(left, 0, side, side);
    final cell = side / 3;
    canvas.drawRRect(RRect.fromRectAndRadius(area, const Radius.circular(10)), Paint()..color = bg);
    final gp = Paint()
      ..color = grid
      ..strokeWidth = 0.8;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(Offset(area.left + cell * i, area.top), Offset(area.left + cell * i, area.bottom), gp);
      canvas.drawLine(Offset(area.left, area.top + cell * i), Offset(area.right, area.top + cell * i), gp);
    }
    canvas.drawRRect(RRect.fromRectAndRadius(area, const Radius.circular(10)), gp..style = PaintingStyle.stroke);
    // 구역 이름(위쪽 줄 = 고강도)
    const rows = [
      [StyleZone.intervalWarrior, StyleZone.hybrid, StyleZone.heavyLifter],
      [StyleZone.runner, StyleZone.allRounder, StyleZone.bodybuilder],
      [StyleZone.healingWalker, StyleZone.conditioning, StyleZone.pumpMaker],
    ];
    final active = points.map((p) => p.style.zone).toSet();
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        final z = rows[r][c];
        final on = active.contains(z);
        _text(canvas, z.label, Offset(area.left + cell * (c + 0.5), area.top + cell * r + 12),
            size: 9.5, color: on ? labelText : zoneText, w: on ? FontWeight.w700 : FontWeight.w500);
      }
    }
    // 축
    _text(canvas, '고강도', Offset(left - 4, area.top + 2), size: 9.5, color: axisText, align: Alignment.topRight);
    _text(canvas, '가볍게', Offset(left - 4, area.bottom), size: 9.5, color: axisText, align: Alignment.bottomRight);
    _text(canvas, '유산소', Offset(area.left, area.bottom + 4), size: 9.5, color: axisText, align: Alignment.topLeft);
    _text(canvas, '웨이트', Offset(area.right, area.bottom + 4), size: 9.5, color: axisText, align: Alignment.topRight);

    Offset pos(TrainingStyle s) => Offset(area.left + s.x / 100 * side, area.bottom - s.y / 100 * side);

    // 함께 점과 사람 점 잇는 점선
    final combined = points.where((p) => p.combined).firstOrNull;
    if (combined != null) {
      final lp = Paint()
        ..color = axisText.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      for (final p in points.where((p) => !p.combined)) {
        _dashed(canvas, pos(p.style), pos(combined.style), lp);
      }
    }
    for (final p in points) {
      final at = pos(p.style);
      if (p.from != null) {
        final a = pos(p.from!);
        if ((a - at).distance > 6) {
          final ap = Paint()
            ..color = p.color.withValues(alpha: 0.55)
            ..strokeWidth = 1.6
            ..style = PaintingStyle.stroke;
          canvas.drawCircle(a, 4, ap);
          canvas.drawLine(a, at, ap);
        }
      }
      final fill = Paint()..color = p.color;
      final edge = Paint()
        ..color = ring
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      if (p.combined) {
        final d = Path()
          ..moveTo(at.dx, at.dy - 8)
          ..lineTo(at.dx + 8, at.dy)
          ..lineTo(at.dx, at.dy + 8)
          ..lineTo(at.dx - 8, at.dy)
          ..close();
        canvas.drawPath(d, fill);
        canvas.drawPath(d, edge);
      } else {
        canvas.drawCircle(at, 7, fill);
        canvas.drawCircle(at, 7, edge);
      }
      // 이름표: 아래쪽이 모자라면 위에
      final below = at.dy + 22 < area.bottom;
      _text(canvas, p.label, Offset(at.dx.clamp(area.left + 16, area.right - 16), below ? at.dy + 10 : at.dy - 10),
          size: 10, color: labelText, w: FontWeight.w700, align: below ? Alignment.topCenter : Alignment.bottomCenter);
    }
  }

  void _dashed(Canvas c, Offset a, Offset b, Paint p) {
    final d = (b - a).distance;
    if (d < 1) return;
    final dir = (b - a) / d;
    for (var t = 0.0; t < d; t += 6) {
      c.drawLine(a + dir * t, a + dir * min(t + 3, d), p);
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) => true;
}

/// 지도 + 사람별 이름·점수 + (여럿이면) 함께 성향과 궁합 한 줄.
class StyleCard extends StatelessWidget {
  const StyleCard({super.key, required this.people, this.trendFrom, this.showCombined = true});

  /// (이름, 성향). 첫 번째가 '나'.
  final List<(String, TrainingStyle)> people;

  /// 첫 번째 사람의 지난달 성향(있으면 변화 표시).
  final TrainingStyle? trendFrom;
  final bool showCombined;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final many = people.length > 1 && showCombined;
    final together = many ? TrainingStyle.combine(people.map((p) => p.$2).toList()) : null;
    final points = [
      for (var i = 0; i < people.length; i++)
        StylePoint(people[i].$1, people[i].$2, styleColors[i % styleColors.length], from: i == 0 ? trendFrom : null),
      if (together != null) StylePoint('함께', together, combinedColor, combined: true),
    ];

    Widget row(Color color, String who, TrainingStyle s, {bool diamond = false, String? note}) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 5, right: 8),
              child: Transform.rotate(
                angle: diamond ? pi / 4 : 0,
                child: Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(diamond ? 1 : 5))),
              ),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: '$who  ', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  TextSpan(text: s.name, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  TextSpan(text: '  웨이트 ${s.x.round()} · 강도 ${s.y.round()}', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ])),
                Text(note ?? s.zone.description, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ]),
            ),
          ]),
        );

    String basis(TrainingStyle s) => s.sessions == 0
        ? '아직 기록이 적어 프로필(목표·레벨)로 추정했어요'
        : s.dataWeight >= 1
            ? '최근 4주 운동 ${s.sessions}회 기록으로 계산'
            : '프로필 + 최근 4주 운동 ${s.sessions}회 반영(8회부터 기록만으로)';

    String? trend;
    final f = trendFrom;
    if (f != null && people.isNotEmpty) {
      final s = people.first.$2;
      String sign(double v) => v >= 0 ? '+${v.round()}' : '${v.round()}';
      final dx = s.x - f.x, dy = s.y - f.y;
      if (dx.abs() >= 1 || dy.abs() >= 1) trend = '지난달보다 웨이트 ${sign(dx)} · 강도 ${sign(dy)}${f.zone != s.zone ? ' (${f.name} → ${s.name})' : ''}';
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: LayoutBuilder(builder: (c, box) => StyleMap(points: points, size: min(260, box.maxWidth - 40)))),
      const SizedBox(height: 4),
      for (var i = 0; i < people.length; i++)
        row(styleColors[i % styleColors.length], people[i].$1, people[i].$2,
            note: people.length == 1 ? '${people[i].$2.zone.description} · ${basis(people[i].$2)}' : null),
      if (trend != null)
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 18),
          child: Text(trend, style: text.bodySmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
        ),
      if (together != null) row(combinedColor, '함께', together, diamond: true, note: TrainingStyle.chemistry(people.map((p) => p.$2).toList())),
    ]);
  }
}
