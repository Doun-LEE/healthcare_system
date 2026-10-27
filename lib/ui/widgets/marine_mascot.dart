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
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final thin = Paint()
      ..color = _line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    final skin = Paint()..color = _skin;
    final shade = Paint()..color = _skinDark;
    final vein = Paint()
      ..color = const Color(0xFF8E5A3A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    // 팔: 굵고 각진 상완 + 이두 덩어리 + 핏줄.
    void arm(Offset c, double deg, {double len = 36, double w = 22}) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(deg * math.pi / 180);
      final r = Rect.fromCenter(center: Offset.zero, width: w, height: len);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), skin);
      canvas.drawOval(Rect.fromCenter(center: Offset(-1, -len * 0.16), width: w * 0.8, height: len * 0.46), shade);
      canvas.drawOval(Rect.fromCenter(center: Offset(-2, -len * 0.2), width: w * 0.5, height: len * 0.28), skin);
      final v = Path()
        ..moveTo(3, len * 0.05)
        ..lineTo(1, len * 0.18)
        ..lineTo(4, len * 0.3)
        ..lineTo(2, len * 0.42);
      canvas.drawPath(v, vein);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), line);
      canvas.restore();
    }
    // 내린 팔(몸 뒤): 지침·잠·근육자랑(왼팔). 기본은 팔짱이라 옆팔 없음.
    if (mood == MascotMood.tired || mood == MascotMood.sleep) {
      arm(const Offset(7, 78), 8);
      arm(const Offset(93, 78), -8);
    } else if (mood == MascotMood.flex) {
      arm(const Offset(7, 78), 8);
    } else if (mood == MascotMood.happy) {
      // 팔짱: 상완만 몸 뒤에서 살짝
      arm(const Offset(8, 72), 14, len: 30);
      arm(const Offset(92, 72), -14, len: 30);
    }

    // 반바지(허리띠)
    final shorts = Path()
      ..moveTo(18, 88)
      ..lineTo(82, 88)
      ..lineTo(86, 100)
      ..lineTo(14, 100)
      ..close();
    canvas.drawPath(shorts, Paint()..color = _shorts);
    canvas.drawRect(const Rect.fromLTWH(18, 88, 64, 4), Paint()..color = _line);
    canvas.drawPath(shorts, line);

    // 몸통: 화면 꽉 차는 역삼각형. 승모근이 작은 머리 옆까지 솟는다.
    final torso = Path()
      ..moveTo(4, 56)
      ..lineTo(18, 44)
      ..lineTo(38, 36)
      ..lineTo(62, 36)
      ..lineTo(82, 44)
      ..lineTo(96, 56)
      ..lineTo(84, 90)
      ..lineTo(16, 90)
      ..close();
    canvas.drawPath(torso, skin);
    // 가슴: 각진 판 두 장
    final pecL = Path()
      ..moveTo(20, 50)
      ..lineTo(48, 50)
      ..lineTo(48, 64)
      ..lineTo(26, 66)
      ..close();
    final pecR = Path()
      ..moveTo(52, 50)
      ..lineTo(80, 50)
      ..lineTo(74, 66)
      ..lineTo(52, 64)
      ..close();
    canvas.drawPath(pecL, shade);
    canvas.drawPath(pecR, shade);
    canvas.drawPath(pecL, thin);
    canvas.drawPath(pecR, thin);
    // 복근 6칸 + 옆구리 + 핏줄
    canvas.drawLine(const Offset(50, 64), const Offset(50, 88), line);
    for (final y in [71.0, 79.0]) {
      canvas.drawLine(Offset(36, y), Offset(48, y + 1), thin);
      canvas.drawLine(Offset(52, y + 1), Offset(64, y), thin);
    }
    canvas.drawLine(const Offset(35, 64), const Offset(33, 88), thin);
    canvas.drawLine(const Offset(65, 64), const Offset(67, 88), thin);
    canvas.drawLine(const Offset(23, 72), const Offset(29, 84), vein);
    canvas.drawLine(const Offset(77, 72), const Offset(71, 84), vein);
    canvas.drawLine(const Offset(18, 44), const Offset(34, 50), thin);
    canvas.drawLine(const Offset(82, 44), const Offset(66, 50), thin);
    canvas.drawPath(torso, line);

    // 군번줄
    final chain = Path()
      ..moveTo(42, 40)
      ..quadraticBezierTo(50, 56, 58, 40);
    canvas.drawPath(chain, Paint()..color = const Color(0xFF8E9BA6)..style = PaintingStyle.stroke..strokeWidth = 1.6);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(47, 51, 6, 9), const Radius.circular(1.5)), Paint()..color = const Color(0xFFC9D3DC));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(47, 51, 6, 9), const Radius.circular(1.5)), thin);

    // 몸 앞의 팔
    switch (mood) {
      case MascotMood.happy:
        // 팔짱: 전완 두 개가 가슴 아래에서 교차
        for (final (c, deg) in [(const Offset(38, 70), -18.0), (const Offset(62, 70), 18.0)]) {
          canvas.save();
          canvas.translate(c.dx, c.dy);
          canvas.rotate(deg * math.pi / 180);
          final r = Rect.fromCenter(center: Offset.zero, width: 40, height: 16);
          canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), skin);
          canvas.drawOval(Rect.fromCenter(center: const Offset(-8, -1), width: 16, height: 10), shade);
          canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), line);
          // 주먹
          canvas.drawCircle(const Offset(17, 0), 7, skin);
          canvas.drawCircle(const Offset(17, 0), 7, line);
          canvas.restore();
        }
      case MascotMood.cheer:
        arm(const Offset(10, 46), 150, len: 38);
        arm(const Offset(90, 46), -150, len: 38);
      case MascotMood.flex:
        arm(const Offset(90, 46), -150, len: 38);
      case MascotMood.tired:
      case MascotMood.sleep:
        break;
    }

    // 목·머리: 몸에 비해 작게, 턱은 각지게
    canvas.drawRect(const Rect.fromLTWH(44, 32, 12, 8), skin);
    canvas.drawLine(const Offset(46, 33), const Offset(46, 39), vein);
    final head = Path()
      ..moveTo(38, 18)
      ..lineTo(62, 18)
      ..lineTo(62, 31)
      ..lineTo(57, 40)
      ..lineTo(43, 40)
      ..lineTo(38, 31)
      ..close();
    canvas.drawPath(head, skin);
    final stub = Paint()..color = _skinDark.withValues(alpha: 0.55);
    for (final p in const [Offset(42, 35), Offset(45, 38), Offset(49, 39), Offset(51, 39), Offset(55, 38), Offset(58, 35), Offset(43, 32), Offset(57, 32)]) {
      canvas.drawCircle(p, 0.8, stub);
    }
    canvas.drawLine(const Offset(57, 20), const Offset(60, 26), thin);
    canvas.drawLine(const Offset(57, 23), const Offset(60, 23), thin);
    canvas.drawPath(head, line);

    // 선글라스(각진) + 찡그린 눈썹
    final glass = Paint()..color = _line;
    canvas.drawRect(const Rect.fromLTWH(39, 25, 10, 6), glass);
    canvas.drawRect(const Rect.fromLTWH(51, 25, 10, 6), glass);
    canvas.drawLine(const Offset(49, 28), const Offset(51, 28), line);
    final gleam = Paint()..color = Colors.white.withValues(alpha: 0.35)..strokeWidth = 1.2;
    canvas.drawLine(const Offset(41, 27), const Offset(44, 27), gleam);
    canvas.drawLine(const Offset(53, 27), const Offset(56, 27), gleam);
    canvas.drawLine(const Offset(40, 23), const Offset(48, 24.5), line);
    canvas.drawLine(const Offset(60, 23), const Offset(52, 24.5), line);

    // 입
    switch (mood) {
      case MascotMood.happy:
      case MascotMood.flex:
        canvas.drawRect(const Rect.fromLTWH(44, 34, 12, 3.5), Paint()..color = Colors.white);
        canvas.drawRect(const Rect.fromLTWH(44, 34, 12, 3.5), thin);
        for (final x in [47.0, 50.0, 53.0]) {
          canvas.drawLine(Offset(x, 34), Offset(x, 37.5), thin);
        }
      case MascotMood.cheer:
        final mouth = Path()
          ..moveTo(43, 33)
          ..lineTo(57, 33)
          ..lineTo(55, 39)
          ..lineTo(45, 39)
          ..close();
        canvas.drawPath(mouth, Paint()..color = const Color(0xFF6E1414));
        canvas.drawRect(const Rect.fromLTWH(44, 33, 12, 2), Paint()..color = Colors.white);
        canvas.drawPath(mouth, line);
      case MascotMood.tired:
        final m = Path()
          ..moveTo(44, 38)
          ..lineTo(50, 34)
          ..lineTo(56, 38);
        canvas.drawPath(m, line);
      case MascotMood.sleep:
        canvas.drawLine(const Offset(45, 36), const Offset(55, 36), line);
    }

    // 팔각모: 높은 팔각 크라운 + 챙 + 빨간 명찰 조각
    final cap = Path()
      ..moveTo(35, 19)
      ..lineTo(37, 11)
      ..lineTo(43, 5)
      ..lineTo(57, 5)
      ..lineTo(63, 11)
      ..lineTo(65, 19)
      ..close();
    canvas.drawPath(cap, Paint()..color = _camo);
    final patch = Paint()..color = _camoDark;
    for (final r in const [Rect.fromLTWH(39, 8, 8, 3.5), Rect.fromLTWH(52, 12, 7, 3.5), Rect.fromLTWH(46, 14, 5, 2.5), Rect.fromLTWH(55, 7, 5, 2.5)]) {
      canvas.drawOval(r, patch);
    }
    canvas.drawLine(const Offset(43, 5), const Offset(44, 18), thin);
    canvas.drawLine(const Offset(57, 5), const Offset(56, 18), thin);
    canvas.drawPath(cap, line);
    canvas.drawRect(const Rect.fromLTWH(33, 18, 34, 4), Paint()..color = _camoDark);
    canvas.drawRect(const Rect.fromLTWH(33, 18, 34, 4), line);
    canvas.drawRect(const Rect.fromLTWH(46, 10, 8, 4), Paint()..color = accent);
    canvas.drawRect(const Rect.fromLTWH(46, 10, 8, 4), Paint()..color = gold..style = PaintingStyle.stroke..strokeWidth = 1.2);

    // 장식
    switch (mood) {
      case MascotMood.cheer:
        final tp = TextPainter(
          text: TextSpan(text: '악!!', style: TextStyle(color: accent, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -1)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, const Offset(66, 0));
        for (final a in [-0.9, -0.5, -0.1]) {
          final p1 = Offset(64 + math.cos(a) * 8, 14 + math.sin(a) * 8);
          final p2 = Offset(64 + math.cos(a) * 14, 14 + math.sin(a) * 14);
          canvas.drawLine(p1, p2, Paint()..color = accent..strokeWidth = 2..strokeCap = StrokeCap.round);
        }
      case MascotMood.tired:
        for (final o in const [Offset(66, 19), Offset(34, 26)]) {
          final drop = Path()
            ..moveTo(o.dx, o.dy)
            ..quadraticBezierTo(o.dx + 5, o.dy + 8, o.dx, o.dy + 10)
            ..quadraticBezierTo(o.dx - 5, o.dy + 8, o.dx, o.dy)
            ..close();
          canvas.drawPath(drop, Paint()..color = const Color(0xFF7FB8F2));
        }
      case MascotMood.sleep:
        final tp = TextPainter(
          text: const TextSpan(text: 'zZ', style: TextStyle(color: _line, fontSize: 13, fontWeight: FontWeight.w900)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, const Offset(68, 2));
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
