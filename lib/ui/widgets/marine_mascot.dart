import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mascot.dart' show MascotMood;

/// 해병대 테마 마스코트 "악병장": 팔각모 쓴 근육질 해병. 공식 휘장·기존 캐릭터를 베끼지 않도록
/// 얼굴은 선글라스, 휘장은 우리 뱃지([MarineEmblem])로 그린다. 코드로 그려서 어느 크기에서도 선명.
class MarineMascot extends StatefulWidget {
  const MarineMascot({super.key, this.mood = MascotMood.happy, this.size = 72, this.bob = true});
  final MascotMood mood;
  final double size;
  final bool bob;

  @override
  State<MarineMascot> createState() => _MarineMascotState();
}

class _MarineMascotState extends State<MarineMascot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    if (widget.bob) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        // 가슴을 들썩이듯 짧고 강하게.
        final t = _c.value * 2 * math.pi;
        final s = widget.bob ? 1 + math.max(0, math.sin(t)) * 0.02 : 1.0;
        return Transform.scale(scale: s, alignment: Alignment.bottomCenter, child: child);
      },
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _MarinePainter(widget.mood, accent: cs.primary, gold: cs.secondary),
      ),
    );
  }
}

class _MarinePainter extends CustomPainter {
  _MarinePainter(this.mood, {required this.accent, required this.gold});
  final MascotMood mood;
  final Color accent;
  final Color gold;

  static const _skin = Color(0xFFD9A066);
  static const _skinDark = Color(0xFFB07A45);
  static const _line = Color(0xFF2B1D14);
  static const _camo = Color(0xFF4F6B3A);
  static const _camoDark = Color(0xFF34492A);
  static const _shorts = Color(0xFFC8102E);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.scale(s, s);
    final line = Paint()
      ..color = _line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final skin = Paint()..color = _skin;
    final shade = Paint()..color = _skinDark;

    // 팔(기분별). 내린 팔은 몸 뒤.
    void arm(Offset c, double deg, {double len = 30}) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(deg * math.pi / 180);
      final r = Rect.fromCenter(center: Offset.zero, width: 15, height: len);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), skin);
      // 이두 볼록
      canvas.drawOval(Rect.fromCenter(center: Offset(0, -len * 0.18), width: 13, height: len * 0.42), shade);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), line);
      canvas.restore();
    }
    final raised = mood == MascotMood.cheer || mood == MascotMood.flex;
    if (!raised) {
      arm(const Offset(12, 74), 12);
      arm(const Offset(88, 74), -12);
    } else if (mood == MascotMood.flex) {
      arm(const Offset(12, 74), 12);
    }

    // 반바지
    final shorts = Path()
      ..moveTo(24, 84)
      ..lineTo(76, 84)
      ..lineTo(80, 100)
      ..lineTo(20, 100)
      ..close();
    canvas.drawPath(shorts, Paint()..color = _shorts);
    canvas.drawPath(shorts, line);

    // 몸통: 넓은 어깨 → 좁은 허리
    final torso = Path()
      ..moveTo(14, 52)
      ..cubicTo(30, 44, 70, 44, 86, 52)
      ..lineTo(76, 86)
      ..lineTo(24, 86)
      ..close();
    canvas.drawPath(torso, skin);
    // 가슴·복근 음영
    canvas.drawArc(const Rect.fromLTWH(27, 52, 22, 16), math.pi, math.pi, false, line..strokeWidth = 1.8);
    canvas.drawArc(const Rect.fromLTWH(51, 52, 22, 16), math.pi, math.pi, false, line);
    canvas.drawLine(const Offset(50, 60), const Offset(50, 82), line);
    for (final y in [68.0, 75.0]) {
      canvas.drawLine(Offset(38, y), Offset(47, y + 1), line);
      canvas.drawLine(Offset(53, y + 1), Offset(62, y), line);
    }
    line.strokeWidth = 2.2;
    canvas.drawPath(torso, line);

    // 군번줄
    final chain = Path()
      ..moveTo(40, 50)
      ..quadraticBezierTo(50, 62, 60, 50);
    canvas.drawPath(chain, Paint()..color = const Color(0xFF8E9BA6)..style = PaintingStyle.stroke..strokeWidth = 1.4);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(47, 56, 6, 8), const Radius.circular(1.5)), Paint()..color = const Color(0xFFC9D3DC));

    // 올린 팔(몸 앞)
    if (mood == MascotMood.cheer) {
      arm(const Offset(14, 52), 150, len: 32);
      arm(const Offset(86, 52), -150, len: 32);
    } else if (mood == MascotMood.flex) {
      arm(const Offset(86, 52), -150, len: 32);
    }

    // 목·머리
    canvas.drawRect(const Rect.fromLTWH(44, 40, 12, 10), skin);
    final head = RRect.fromRectAndRadius(const Rect.fromLTWH(35, 20, 30, 26), const Radius.circular(9));
    canvas.drawRRect(head, skin);
    canvas.drawRRect(head, line);
    // 턱선 그림자
    canvas.drawArc(const Rect.fromLTWH(38, 30, 24, 16), 0.3, math.pi - 0.6, false, Paint()..color = _skinDark..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // 선글라스
    final glass = Paint()..color = _line;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(37, 29, 12, 7), const Radius.circular(2)), glass);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(51, 29, 12, 7), const Radius.circular(2)), glass);
    canvas.drawLine(const Offset(49, 32), const Offset(51, 32), line);
    // 렌즈 반사
    final gleam = Paint()..color = Colors.white.withValues(alpha: 0.35)..strokeWidth = 1.2;
    canvas.drawLine(const Offset(39, 31), const Offset(42, 31), gleam);
    canvas.drawLine(const Offset(53, 31), const Offset(56, 31), gleam);

    // 입
    switch (mood) {
      case MascotMood.happy:
        canvas.drawLine(const Offset(44, 41), const Offset(56, 41), line);
      case MascotMood.flex:
        final m = Path()
          ..moveTo(44, 41)
          ..quadraticBezierTo(50, 44, 56, 41);
        canvas.drawPath(m, line);
      case MascotMood.cheer:
        final mouth = Rect.fromCenter(center: const Offset(50, 41), width: 11, height: 7);
        canvas.drawOval(mouth, Paint()..color = const Color(0xFF7A1E1E));
        canvas.drawOval(mouth, line);
      case MascotMood.tired:
        final m = Path()
          ..moveTo(44, 42)
          ..quadraticBezierTo(50, 38, 56, 42);
        canvas.drawPath(m, line);
      case MascotMood.sleep:
        canvas.drawOval(Rect.fromCenter(center: const Offset(50, 41), width: 5, height: 4), line);
    }

    // 팔각모: 윗면 팔각형 + 챙, 앞에 빨간 명찰 조각
    final cap = Path()
      ..moveTo(31, 22)
      ..lineTo(36, 10)
      ..lineTo(64, 10)
      ..lineTo(69, 22)
      ..close();
    canvas.drawPath(cap, Paint()..color = _camo);
    // 위장 무늬
    final patch = Paint()..color = _camoDark;
    canvas.drawOval(const Rect.fromLTWH(38, 12, 9, 5), patch);
    canvas.drawOval(const Rect.fromLTWH(54, 15, 8, 4), patch);
    canvas.drawOval(const Rect.fromLTWH(45, 17, 6, 3), patch);
    canvas.drawPath(cap, line);
    canvas.drawRect(const Rect.fromLTWH(29, 21, 42, 4), Paint()..color = _camoDark);
    canvas.drawRect(const Rect.fromLTWH(29, 21, 42, 4), line);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(45, 13, 10, 5), const Radius.circular(1)), Paint()..color = accent);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(45, 13, 10, 5), const Radius.circular(1)), Paint()..color = gold..style = PaintingStyle.stroke..strokeWidth = 1);

    // 장식
    switch (mood) {
      case MascotMood.cheer:
        final tp = TextPainter(
          text: TextSpan(text: '악!', style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.w900)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, const Offset(72, 6));
      case MascotMood.tired:
        final drop = Path()
          ..moveTo(68, 24)
          ..quadraticBezierTo(73, 32, 68, 34)
          ..quadraticBezierTo(63, 32, 68, 24)
          ..close();
        canvas.drawPath(drop, Paint()..color = const Color(0xFF7FB8F2));
      case MascotMood.sleep:
        final tp = TextPainter(
          text: const TextSpan(text: 'zZ', style: TextStyle(color: _line, fontSize: 12, fontWeight: FontWeight.w700)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, const Offset(70, 8));
      case MascotMood.happy:
      case MascotMood.flex:
        break;
    }
  }

  @override
  bool shouldRepaint(_MarinePainter old) => old.mood != mood || old.accent != accent || old.gold != gold;
}

/// 오리지널 해병 헬스 뱃지: 빨간 원 + 금색 로프 테두리 + 별 하나 + 교차 아령. 공식 휘장이 아니다.
class MarineEmblem extends StatelessWidget {
  const MarineEmblem({super.key, this.size = 40, this.text = '악'});
  final double size;
  final String text;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _EmblemPainter(text));
}

class _EmblemPainter extends CustomPainter {
  _EmblemPainter(this.text);
  final String text;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.scale(s, s);
    const c = Offset(50, 50);
    const gold = Color(0xFFF2C14E);
    const goldDark = Color(0xFFB8860B);
    const red = Color(0xFFC8102E);
    const navy = Color(0xFF14213D);
    canvas.drawCircle(c, 48, Paint()..color = navy);
    // 로프: 금색 원 위에 짧은 빗금
    canvas.drawCircle(c, 44, Paint()..color = gold..style = PaintingStyle.stroke..strokeWidth = 6);
    final rope = Paint()..color = goldDark..strokeWidth = 2..strokeCap = StrokeCap.round;
    for (var i = 0; i < 36; i++) {
      final a = i * math.pi / 18;
      final p1 = c + Offset(math.cos(a - 0.05) * 41, math.sin(a - 0.05) * 41);
      final p2 = c + Offset(math.cos(a + 0.05) * 47, math.sin(a + 0.05) * 47);
      canvas.drawLine(p1, p2, rope);
    }
    canvas.drawCircle(c, 38, Paint()..color = red);
    // 별
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? 13.0 : 5.5;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = Offset(50 + math.cos(a) * r, 38 + math.sin(a) * r);
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();
    canvas.drawPath(star, Paint()..color = gold);
    canvas.drawPath(star, Paint()..color = goldDark..style = PaintingStyle.stroke..strokeWidth = 1.2);
    // 교차 아령
    final bar = Paint()..color = gold..strokeWidth = 3.2..strokeCap = StrokeCap.round;
    for (final deg in [30.0, -30.0]) {
      canvas.save();
      canvas.translate(50, 62);
      canvas.rotate(deg * math.pi / 180);
      canvas.drawLine(const Offset(-16, 0), const Offset(16, 0), bar);
      for (final x in [-14.0, 14.0]) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, 0), width: 5, height: 11), const Radius.circular(1.5)), Paint()..color = gold);
      }
      canvas.restore();
    }
    // 글자
    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(50 - tp.width / 2, 74));
  }

  @override
  bool shouldRepaint(_EmblemPainter old) => old.text != text;
}
