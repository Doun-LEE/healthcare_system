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

/// 3D 운동 성향 지도. 바닥 오른쪽 = 웨이트 양, 바닥 왼쪽 = 유산소 양, 높이 = 강도.
/// 점마다 바닥 그림자와 세로 점선을 그려, 바닥에서 웨이트·유산소를, 높이에서 강도를 읽는다.
class StyleMap extends StatelessWidget {
  const StyleMap({super.key, required this.points, this.width = 300});
  final List<StylePoint> points;
  final double width;

  static double heightFor(double width) {
    final l = (width - 60) / (2 * cos(pi / 6));
    return l + l * 0.72 + 56;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: '운동 성향 3D 지도: ${points.map((p) => '${p.label} ${p.style.name} 웨이트 ${p.style.weight.round()} 유산소 ${p.style.cardio.round()} 강도 ${p.style.intensity.round()}').join(', ')}',
      child: SizedBox(
        width: width,
        height: heightFor(width),
        child: CustomPaint(
          painter: _MapPainter(
            points: points,
            grid: cs.outlineVariant,
            floor: cs.surfaceContainerHighest.withValues(alpha: 0.6),
            wall: cs.surfaceContainerHighest.withValues(alpha: 0.28),
            zoneText: cs.onSurfaceVariant.withValues(alpha: 0.7),
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
    required this.floor,
    required this.wall,
    required this.zoneText,
    required this.axisText,
    required this.labelText,
    required this.ring,
    this.font,
  });
  final List<StylePoint> points;
  final Color grid, floor, wall, zoneText, axisText, labelText, ring;
  final String? font;

  TextPainter _tp(String s, double size, Color color, FontWeight w) => TextPainter(
        text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color, fontWeight: w, fontFamily: font)),
        textDirection: TextDirection.ltr,
      )..layout();

  Rect _text(Canvas c, String s, Offset at, {double size = 10, Color? color, FontWeight w = FontWeight.w500, Alignment align = Alignment.center}) {
    final tp = _tp(s, size, color ?? zoneText, w);
    final tl = at - Offset((align.x + 1) / 2 * tp.width, (align.y + 1) / 2 * tp.height);
    tp.paint(c, tl);
    return tl & tp.size;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = cos(pi / 6), sy = sin(pi / 6);
    final l = (size.width - 60) / (2 * cx);
    final h = l * 0.72;
    // 원점(웨이트 0·유산소 0·가볍게)은 두 벽이 만나는 뒤 모서리. 웨이트는 오른쪽 아래로, 유산소는 왼쪽 아래로 커진다.
    final o = Offset(size.width / 2, size.height - 30 - l);
    // (웨이트, 유산소, 강도) 0~1 → 화면.
    Offset p3(double u, double v, double k) => o + Offset((u - v) * l * cx, (u + v) * l * sy - k * h);
    Offset at(TrainingStyle s) => p3(s.weight / 100, s.cardio / 100, s.intensity / 100);
    Offset shadow(TrainingStyle s) => p3(s.weight / 100, s.cardio / 100, 0);
    Path poly(List<Offset> pts) => Path()..addPolygon(pts, true);
    final gp = Paint()
      ..color = grid
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    final faint = Paint()
      ..color = grid.withValues(alpha: 0.6)
      ..strokeWidth = 0.6;

    // 뒤 벽 두 장(강도 눈금): 웨이트 축 벽(유산소 0), 유산소 축 벽(웨이트 0)
    final wallW = [p3(0, 0, 0), p3(1, 0, 0), p3(1, 0, 1), p3(0, 0, 1)];
    final wallC = [p3(0, 0, 0), p3(0, 1, 0), p3(0, 1, 1), p3(0, 0, 1)];
    for (final w in [wallW, wallC]) {
      canvas.drawPath(poly(w), Paint()..color = wall);
      canvas.drawPath(poly(w), gp);
    }
    // 강도 눈금: 벽에 25·50·75 가로줄, 오른쪽 벽 끝에 숫자.
    for (final k in [0.25, 0.5, 0.75]) {
      final lp = k == 0.5 ? (Paint()
        ..color = grid
        ..strokeWidth = 0.9) : faint;
      canvas.drawLine(p3(0, 0, k), p3(1, 0, k), lp);
      canvas.drawLine(p3(0, 0, k), p3(0, 1, k), lp);
    }
    for (final k in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      _text(canvas, '${(k * 100).round()}', p3(1, 0, k) + const Offset(4, 0), size: 8.5, color: axisText, align: Alignment.centerLeft);
    }
    // 바닥(가운데 선 = 많고 적음 기준 50)
    final fl = [p3(0, 0, 0), p3(1, 0, 0), p3(1, 1, 0), p3(0, 1, 0)];
    canvas.drawPath(poly(fl), Paint()..color = floor);
    canvas.drawPath(poly(fl), gp);
    canvas.drawLine(p3(0.5, 0, 0), p3(0.5, 1, 0), faint);
    canvas.drawLine(p3(0, 0.5, 0), p3(1, 0.5, 0), faint);
    _text(canvas, '웨이트 위주', p3(0.75, 0.25, 0), size: 9);
    _text(canvas, '유산소 위주', p3(0.25, 0.75, 0), size: 9);
    _text(canvas, '둘 다 많이', p3(0.75, 0.75, 0), size: 9);
    _text(canvas, '둘 다 적게', p3(0.25, 0.25, 0), size: 9);

    // 축 이름: 축 끝(많은 쪽)에
    // 축 이름은 각 축 벽 아래쪽(바닥 모서리 위)에, 커지는 방향 화살표와 함께.
    final axisRects = <Rect>[];
    axisRects.add(_text(canvas, '웨이트 ↘', p3(0.78, 0, 0.05), size: 10, color: axisText, w: FontWeight.w800, align: Alignment.bottomCenter));
    axisRects.add(_text(canvas, '↙ 유산소', p3(0, 0.78, 0.05), size: 10, color: axisText, w: FontWeight.w800, align: Alignment.bottomCenter));
    _text(canvas, '고강도', p3(0, 1, 1) + const Offset(-4, 0), size: 9.5, color: axisText, align: Alignment.centerRight);
    _text(canvas, '가볍게', p3(0, 1, 0) + const Offset(-4, -4), size: 9.5, color: axisText, align: Alignment.bottomRight);
    _text(canvas, '↑ 강도', p3(0, 0, 1) + const Offset(0, -4), size: 9.5, color: axisText, w: FontWeight.w700, align: Alignment.bottomCenter);
    _text(canvas, '0', p3(0, 0, 0) + const Offset(0, -3), size: 8.5, color: axisText, align: Alignment.bottomCenter);

    // 바닥 그림자 + 세로 점선, 그리고 오른쪽 벽으로 수평 점선(벽 눈금에서 강도를 읽게)
    for (final p in points) {
      final w = p3(p.style.weight / 100, 0, p.style.intensity / 100);
      _dashed(canvas, at(p.style), w, Paint()
        ..color = p.color.withValues(alpha: 0.55)
        ..strokeWidth = 1);
      canvas.drawCircle(w, 3.5, Paint()..color = p.color);
      canvas.drawCircle(w, 3.5, Paint()
        ..color = ring
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke);
      axisRects.add(_text(canvas, '${p.style.intensity.round()}', w + const Offset(5, -1), size: 9, color: p.color, w: FontWeight.w800, align: Alignment.centerLeft));
      final s = shadow(p.style);
      canvas.drawOval(Rect.fromCenter(center: s, width: 12, height: 6), Paint()..color = p.color.withValues(alpha: 0.4));
      _dashed(canvas, s, at(p.style), Paint()
        ..color = p.color.withValues(alpha: 0.65)
        ..strokeWidth = 1);
    }
    // 함께 점과 사람 점 잇는 점선
    final combined = points.where((p) => p.combined).firstOrNull;
    if (combined != null) {
      final lp = Paint()
        ..color = axisText.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      for (final p in points.where((p) => !p.combined)) {
        _dashed(canvas, at(p.style), at(combined.style), lp);
      }
    }
    // 화면 위(뒤)에 있는 점부터 그려 앞 점이 위에 오게.
    final order = [...points]..sort((a, b) => at(a.style).dy.compareTo(at(b.style).dy));
    final placed = <Rect>[...axisRects];
    final dots = {for (final p in points) p: Rect.fromCircle(center: at(p.style), radius: 9)};
    for (final p in order) {
      final pt = at(p.style);
      if (p.from != null) {
        final a = at(p.from!);
        if ((a - pt).distance > 6) {
          final ap = Paint()
            ..color = p.color.withValues(alpha: 0.55)
            ..strokeWidth = 1.6
            ..style = PaintingStyle.stroke;
          canvas.drawCircle(a, 4, ap);
          canvas.drawLine(a, pt, ap);
        }
      }
      final fill = Paint()..color = p.color;
      final edge = Paint()
        ..color = ring
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      if (p.combined) {
        final d = Path()
          ..moveTo(pt.dx, pt.dy - 8)
          ..lineTo(pt.dx + 8, pt.dy)
          ..lineTo(pt.dx, pt.dy + 8)
          ..lineTo(pt.dx - 8, pt.dy)
          ..close();
        canvas.drawPath(d, fill);
        canvas.drawPath(d, edge);
      } else {
        canvas.drawCircle(pt, 7, fill);
        canvas.drawCircle(pt, 7, edge);
      }
      // 이름표: 오른쪽 → 왼쪽 → 위 → 아래 중 다른 이름표와 안 겹치는 자리
      final tp = _tp(p.label, 10, labelText, FontWeight.w800);
      final tries = [
        Offset(pt.dx + 10, pt.dy - tp.height / 2),
        Offset(pt.dx - 10 - tp.width, pt.dy - tp.height / 2),
        Offset(pt.dx - tp.width / 2, pt.dy - 10 - tp.height),
        Offset(pt.dx - tp.width / 2, pt.dy + 10),
      ];
      var spot = tries.first;
      for (final t in tries) {
        final r = t & tp.size;
        final hitsDot = dots.entries.any((e) => e.key != p && e.value.overlaps(r));
        if (r.left >= 0 && r.right <= size.width && !hitsDot && !placed.any((q) => q.overlaps(r))) {
          spot = t;
          break;
        }
      }
      placed.add(spot & tp.size);
      tp.paint(canvas, spot);
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
                  TextSpan(
                      text: '  웨이트 ${s.weight.round()} · 유산소 ${s.cardio.round()} · 강도 ${s.intensity.round()}',
                      style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
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
      final dw = s.weight - f.weight, dc = s.cardio - f.cardio, di = s.intensity - f.intensity;
      if (dw.abs() >= 1 || dc.abs() >= 1 || di.abs() >= 1) {
        trend = '지난달보다 웨이트 ${sign(dw)} · 유산소 ${sign(dc)} · 강도 ${sign(di)}${f.zone != s.zone ? ' (${f.name} → ${s.name})' : ''}';
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: LayoutBuilder(builder: (c, box) => StyleMap(points: points, width: min(340, box.maxWidth)))),
      const SizedBox(height: 2),
      Text('바닥에서 웨이트·유산소 양을, 높이에서 강도를 봐요. 웨이트 20세트·유산소 40분(한 번 기준)이면 100.',
          style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 11)),
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
