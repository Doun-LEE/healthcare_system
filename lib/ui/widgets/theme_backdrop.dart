import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_theme.dart';

/// 테마 성격에 맞춘 화면 배경. 모든 페이지 뒤에 깔린다(Scaffold 는 투명).
/// 글자를 방해하지 않게 아주 옅게 그린다.
/// - 기본: 차분한 초록 빛 번짐 + 잔잔한 물결선
/// - 귀여운: 분홍→라벤더 그라데이션 + 하트·별·땡땡이
/// - 상남자: 콘크리트 거친 입자 + 아래로 갈수록 진해지는 체크 철판 + 불꽃 주황 빛
/// - 해병대: 디지털 위장무늬(픽셀) + 가장자리 어둡게
class ThemeBackdrop extends StatelessWidget {
  const ThemeBackdrop({super.key, required this.style, required this.child});
  final AppThemeStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(painter: BackdropPainter(style, theme.colorScheme, theme.brightness == Brightness.dark)),
        ),
        child,
      ],
    );
  }
}

/// 페이지 전환마다 페이지 자체에 배경을 붙인다. 그래서 전환 중에도 겹쳐 보이지 않는다.
class BackdropPageTransitionsBuilder extends PageTransitionsBuilder {
  const BackdropPageTransitionsBuilder(this.style, this.inner);
  final AppThemeStyle style;
  final PageTransitionsBuilder inner;

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget child) =>
      inner.buildTransitions(route, context, animation, secondaryAnimation, ThemeBackdrop(style: style, child: child));
}

class BackdropPainter extends CustomPainter {
  BackdropPainter(this.style, this.cs, this.dark);
  final AppThemeStyle style;
  final ColorScheme cs;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final all = Offset.zero & size;
    canvas.drawRect(all, Paint()..color = cs.surface);
    switch (style) {
      case AppThemeStyle.basic:
        _basic(canvas, size);
      case AppThemeStyle.cute:
        _cute(canvas, size);
      case AppThemeStyle.tough:
        _tough(canvas, size);
      case AppThemeStyle.marine:
        _marine(canvas, size);
    }
  }

  void _glow(Canvas canvas, Offset c, double r, Color color) {
    canvas.drawCircle(
      c,
      r,
      Paint()..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  // ── 기본: 숲속 아침처럼 잔잔하게 ──
  void _basic(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    _glow(canvas, Offset(w * 1.0, h * 0.02), w * 0.95, cs.primary.withValues(alpha: dark ? 0.16 : 0.13));
    _glow(canvas, Offset(-w * 0.1, h * 0.92), w * 0.9, cs.tertiary.withValues(alpha: dark ? 0.12 : 0.09));
    // 잔잔한 물결선(등고선 느낌)
    final line = Paint()
      ..color = cs.primary.withValues(alpha: dark ? 0.07 : 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var k = 0; k < 7; k++) {
      final y0 = h * (0.58 + k * 0.065);
      final p = Path()..moveTo(-10, y0);
      for (double x = -10; x <= w + 10; x += 8) {
        p.lineTo(x, y0 + math.sin(x / w * math.pi * 2 + k * 0.7) * (10 + k * 2.0));
      }
      canvas.drawPath(p, line);
    }
  }

  // ── 귀여운: 파스텔 + 하트·별·땡땡이 ──
  void _cute(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final all = Offset.zero & s;
    canvas.drawRect(
      all,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cs.surface, Color.lerp(cs.surface, cs.tertiaryContainer, dark ? 0.35 : 0.55)!],
        ).createShader(all),
    );
    _glow(canvas, Offset(w * 0.05, h * 0.08), w * 0.7, cs.primary.withValues(alpha: dark ? 0.14 : 0.16));
    _glow(canvas, Offset(w * 0.95, h * 0.75), w * 0.7, cs.secondary.withValues(alpha: dark ? 0.10 : 0.12));
    final rnd = math.Random(7);
    const cell = 64.0;
    final colors = [cs.primary, cs.tertiary, cs.secondary];
    var i = 0;
    for (double y = 10; y < h; y += cell) {
      for (double x = (i.isEven ? 8 : 40); x < w; x += cell) {
        final c = Offset(x + rnd.nextDouble() * 22, y + rnd.nextDouble() * 22);
        final color = colors[rnd.nextInt(3)].withValues(alpha: dark ? 0.16 : 0.18);
        final paint = Paint()..color = color;
        final kind = rnd.nextInt(5);
        final r = 3.5 + rnd.nextDouble() * 3.5;
        if (kind <= 1) {
          canvas.drawCircle(c, r * 0.6, paint);
        } else if (kind == 2 || kind == 3) {
          canvas.save();
          canvas.translate(c.dx, c.dy);
          canvas.rotate((rnd.nextDouble() - 0.5) * 0.6);
          canvas.drawPath(_heart(r * 1.4), paint);
          canvas.restore();
        } else {
          canvas.drawPath(_star(c, r * 1.3, r * 0.6), paint);
        }
      }
      i++;
    }
  }

  Path _heart(double r) => Path()
    ..moveTo(0, r * 0.9)
    ..cubicTo(-r * 1.3, 0, -r * 0.9, -r * 1.1, 0, -r * 0.35)
    ..cubicTo(r * 0.9, -r * 1.1, r * 1.3, 0, 0, r * 0.9)
    ..close();

  Path _star(Offset c, double r, double inner) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final o = Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr);
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  // ── 상남자: 콘크리트 + 체크 철판 + 불꽃 빛 ──
  void _tough(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    // 위는 어둡게 눌러 주고, 오른쪽 아래에서 불꽃 주황 빛
    final all = Offset.zero & s;
    canvas.drawRect(
      all,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: dark ? 0.35 : 0.05), Colors.transparent],
          stops: const [0.0, 0.4],
        ).createShader(all),
    );
    _glow(canvas, Offset(w * 1.05, h * 1.02), w * 1.1, cs.primary.withValues(alpha: dark ? 0.20 : 0.10));
    // 체크 철판(다이아몬드 플레이트): 아래로 갈수록 진하게
    final ink = dark ? Colors.white : Colors.black;
    const step = 22.0;
    var row = 0;
    for (double y = h * 0.35; y < h + step; y += step / 2) {
      final t = ((y - h * 0.35) / (h * 0.65)).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = ink.withValues(alpha: (dark ? 0.055 : 0.06) * t)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (double x = (row.isEven ? 0 : step / 2); x < w + step; x += step) {
        final a = row.isEven ? 1.0 : -1.0;
        canvas.drawLine(Offset(x - 4, y - 4 * a), Offset(x + 4, y + 4 * a), paint);
      }
      row++;
    }
    // 콘크리트 입자
    final rnd = math.Random(3);
    final n = (w * h / 90).round();
    final speck = Paint();
    for (var i = 0; i < n; i++) {
      final light = rnd.nextBool();
      speck.color = (light ? Colors.white : Colors.black).withValues(alpha: dark ? (light ? 0.035 : 0.25) : (light ? 0.35 : 0.06));
      canvas.drawCircle(Offset(rnd.nextDouble() * w, rnd.nextDouble() * h), 0.4 + rnd.nextDouble() * 0.9, speck);
    }
  }

  // ── 해병대: 디지털 위장무늬 ──
  void _marine(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    const cell = 7.0;
    final cols = (w / cell).ceil(), rows = (h / cell).ceil();
    final layers = dark
        ? const [Color(0x1A6B7A4A), Color(0x1A3A2E1E), Color(0x14000000)]
        : const [Color(0x158C8A5C), Color(0x126B5A3A), Color(0x0E303A22)];
    for (var k = 0; k < layers.length; k++) {
      final path = Path();
      for (var j = 0; j < rows; j++) {
        for (var i = 0; i < cols; i++) {
          final n = _noise(i / 6, j / 6, k * 31) * 0.65 + _noise(i / 2.2, j / 2.2, k * 31 + 9) * 0.35;
          if (n > 0.6) path.addRect(Rect.fromLTWH(i * cell, j * cell, cell, cell));
        }
      }
      canvas.drawPath(path, Paint()..color = layers[k]);
    }
    // 가장자리를 살짝 어둡게(훈련장 저녁 빛)
    final all = Offset.zero & s;
    canvas.drawRect(
      all,
      Paint()
        ..shader = RadialGradient(
          radius: 1.1,
          colors: [Colors.transparent, Colors.black.withValues(alpha: dark ? 0.35 : 0.10)],
          stops: const [0.55, 1.0],
        ).createShader(all),
    );
  }

  double _hash(int x, int y, int seed) {
    var n = x * 374761393 + y * 668265263 + seed * 2147483647;
    n = (n ^ (n >> 13)) * 1274126177;
    n = n ^ (n >> 16);
    return (n & 0xFFFF) / 0xFFFF;
  }

  double _noise(double x, double y, int seed) {
    final x0 = x.floor(), y0 = y.floor();
    double sm(double t) => t * t * (3 - 2 * t);
    final fx = sm(x - x0), fy = sm(y - y0);
    final a = _hash(x0, y0, seed), b = _hash(x0 + 1, y0, seed);
    final c = _hash(x0, y0 + 1, seed), d = _hash(x0 + 1, y0 + 1, seed);
    return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fy;
  }

  @override
  bool shouldRepaint(BackdropPainter old) => old.style != style || old.dark != dark || old.cs != cs;
}
