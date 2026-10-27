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

    // 팔: 굵고 각진 상완 + 이두 덩어리 + 핏줄. 내린 팔은 몸 뒤.
    void arm(Offset c, double deg, {double len = 32}) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(deg * math.pi / 180);
      final r = Rect.fromCenter(center: Offset.zero, width: 19, height: len);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(7)), skin);
      canvas.drawOval(Rect.fromCenter(center: Offset(-1, -len * 0.16), width: 16, height: len * 0.46), shade);
      canvas.drawOval(Rect.fromCenter(center: Offset(-2, -len * 0.2), width: 10, height: len * 0.28), skin);
      final v = Path()
        ..moveTo(3, len * 0.05)
        ..lineTo(1, len * 0.18)
        ..lineTo(4, len * 0.3)
        ..lineTo(2, len * 0.42);
      canvas.drawPath(v, vein);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(7)), line);
      canvas.restore();
    }
    final raised = mood == MascotMood.cheer || mood == MascotMood.flex;
    if (!raised) {
      arm(const Offset(9, 74), 10);
      arm(const Offset(91, 74), -10);
    } else if (mood == MascotMood.flex) {
      arm(const Offset(9, 74), 10);
    }

    // 반바지(허리띠 포함)
    final shorts = Path()
      ..moveTo(22, 84)
      ..lineTo(78, 84)
      ..lineTo(82, 100)
      ..lineTo(18, 100)
      ..close();
    canvas.drawPath(shorts, Paint()..color = _shorts);
    canvas.drawRect(const Rect.fromLTWH(22, 84, 56, 4), Paint()..color = _line);
    canvas.drawPath(shorts, line);

    // 몸통: 승모근이 목까지 솟고, 어깨는 각지게, 허리는 좁게.
    final torso = Path()
      ..moveTo(8, 56)
      ..lineTo(22, 46)
      ..lineTo(42, 40)
      ..lineTo(58, 40)
      ..lineTo(78, 46)
      ..lineTo(92, 56)
      ..lineTo(80, 86)
      ..lineTo(20, 86)
      ..close();
    canvas.drawPath(torso, skin);
    // 가슴: 각진 판 두 장
    final pecL = Path()
      ..moveTo(24, 52)
      ..lineTo(48, 52)
      ..lineTo(48, 64)
      ..lineTo(30, 66)
      ..close();
    final pecR = Path()
      ..moveTo(52, 52)
      ..lineTo(76, 52)
      ..lineTo(70, 66)
      ..lineTo(52, 64)
      ..close();
    canvas.drawPath(pecL, shade);
    canvas.drawPath(pecR, shade);
    canvas.drawPath(pecL, thin);
    canvas.drawPath(pecR, thin);
    // 복근 6칸 + 옆구리
    canvas.drawLine(const Offset(50, 64), const Offset(50, 84), line);
    for (final y in [70.0, 77.0]) {
      canvas.drawLine(Offset(37, y), Offset(48, y + 1), thin);
      canvas.drawLine(Offset(52, y + 1), Offset(63, y), thin);
    }
    canvas.drawLine(const Offset(36, 64), const Offset(35, 84), thin);
    canvas.drawLine(const Offset(64, 64), const Offset(65, 84), thin);
    canvas.drawLine(const Offset(26, 70), const Offset(32, 80), vein);
    canvas.drawLine(const Offset(74, 70), const Offset(68, 80), vein);
    // 승모근 선
    canvas.drawLine(const Offset(22, 46), const Offset(36, 52), thin);
    canvas.drawLine(const Offset(78, 46), const Offset(64, 52), thin);
    canvas.drawPath(torso, line);

    // 군번줄
    final chain = Path()
      ..moveTo(41, 46)
      ..quadraticBezierTo(50, 60, 59, 46);
    canvas.drawPath(chain, Paint()..color = const Color(0xFF8E9BA6)..style = PaintingStyle.stroke..strokeWidth = 1.6);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(47, 55, 6, 9), const Radius.circular(1.5)), Paint()..color = const Color(0xFFC9D3DC));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(47, 55, 6, 9), const Radius.circular(1.5)), thin);

    // 올린 팔(몸 앞)
    if (mood == MascotMood.cheer) {
      arm(const Offset(12, 50), 150, len: 34);
      arm(const Offset(88, 50), -150, len: 34);
    } else if (mood == MascotMood.flex) {
      arm(const Offset(88, 50), -150, len: 34);
    }

    // 목·머리: 각진 턱
    canvas.drawRect(const Rect.fromLTWH(43, 36, 14, 10), skin);
    canvas.drawLine(const Offset(45, 38), const Offset(45, 45), vein);
    final head = Path()
      ..moveTo(34, 20)
      ..lineTo(66, 20)
      ..lineTo(66, 36)
      ..lineTo(60, 46)
      ..lineTo(40, 46)
      ..lineTo(34, 36)
      ..close();
    canvas.drawPath(head, skin);
    // 수염 자국·흉터
    final stub = Paint()..color = _skinDark.withValues(alpha: 0.55);
    for (final p in const [Offset(39, 40), Offset(43, 43), Offset(47, 44), Offset(53, 44), Offset(57, 43), Offset(61, 40), Offset(41, 37), Offset(59, 37)]) {
      canvas.drawCircle(p, 0.9, stub);
    }
    canvas.drawLine(const Offset(60, 23), const Offset(63, 30), thin);
    canvas.drawLine(const Offset(60, 26), const Offset(63, 26), thin);
    canvas.drawPath(head, line);

    // 선글라스(각진)
    final glass = Paint()..color = _line;
    canvas.drawRect(const Rect.fromLTWH(36, 28, 12, 7), glass);
    canvas.drawRect(const Rect.fromLTWH(52, 28, 12, 7), glass);
    canvas.drawLine(const Offset(48, 31), const Offset(52, 31), line);
    final gleam = Paint()..color = Colors.white.withValues(alpha: 0.35)..strokeWidth = 1.2;
    canvas.drawLine(const Offset(38, 30), const Offset(42, 30), gleam);
    canvas.drawLine(const Offset(54, 30), const Offset(58, 30), gleam);
    // 찡그린 눈썹
    canvas.drawLine(const Offset(37, 26), const Offset(47, 27.5), line);
    canvas.drawLine(const Offset(63, 26), const Offset(53, 27.5), line);

    // 입
    switch (mood) {
      case MascotMood.happy:
      case MascotMood.flex:
        // 이 악문 입: 가로 사각 + 이빨 선
        canvas.drawRect(const Rect.fromLTWH(43, 39, 14, 4), Paint()..color = Colors.white);
        canvas.drawRect(const Rect.fromLTWH(43, 39, 14, 4), thin);
        for (final x in [46.5, 50.0, 53.5]) {
          canvas.drawLine(Offset(x, 39), Offset(x, 43), thin);
        }
      case MascotMood.cheer:
        final mouth = Path()
          ..moveTo(42, 38)
          ..lineTo(58, 38)
          ..lineTo(55, 45)
          ..lineTo(45, 45)
          ..close();
        canvas.drawPath(mouth, Paint()..color = const Color(0xFF6E1414));
        canvas.drawRect(const Rect.fromLTWH(43, 38, 14, 2.2), Paint()..color = Colors.white);
        canvas.drawPath(mouth, line);
      case MascotMood.tired:
        final m = Path()
          ..moveTo(43, 43)
          ..lineTo(50, 39)
          ..lineTo(57, 43);
        canvas.drawPath(m, line);
      case MascotMood.sleep:
        canvas.drawLine(const Offset(44, 41), const Offset(56, 41), line);
    }

    // 팔각모: 높은 팔각 크라운 + 챙 + 빨간 명찰 조각
    final cap = Path()
      ..moveTo(30, 21)
      ..lineTo(33, 12)
      ..lineTo(40, 6)
      ..lineTo(60, 6)
      ..lineTo(67, 12)
      ..lineTo(70, 21)
      ..close();
    canvas.drawPath(cap, Paint()..color = _camo);
    final patch = Paint()..color = _camoDark;
    for (final r in const [Rect.fromLTWH(36, 9, 10, 4), Rect.fromLTWH(52, 13, 9, 4), Rect.fromLTWH(44, 15, 6, 3), Rect.fromLTWH(58, 8, 6, 3)]) {
      canvas.drawOval(r, patch);
    }
    // 크라운 각 선
    canvas.drawLine(const Offset(40, 6), const Offset(42, 20), thin);
    canvas.drawLine(const Offset(60, 6), const Offset(58, 20), thin);
    canvas.drawPath(cap, line);
    canvas.drawRect(const Rect.fromLTWH(28, 20, 44, 5), Paint()..color = _camoDark);
    canvas.drawRect(const Rect.fromLTWH(28, 20, 44, 5), line);
    canvas.drawRect(const Rect.fromLTWH(45, 11, 10, 5), Paint()..color = accent);
    canvas.drawRect(const Rect.fromLTWH(45, 11, 10, 5), Paint()..color = gold..style = PaintingStyle.stroke..strokeWidth = 1.2);

    // 장식
    switch (mood) {
      case MascotMood.cheer:
        final tp = TextPainter(
          text: TextSpan(text: '악!!', style: TextStyle(color: accent, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -1)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, const Offset(66, 0));
        // 기합 선
        for (final a in [-0.9, -0.5, -0.1]) {
          final p1 = Offset(64 + math.cos(a) * 8, 14 + math.sin(a) * 8);
          final p2 = Offset(64 + math.cos(a) * 14, 14 + math.sin(a) * 14);
          canvas.drawLine(p1, p2, Paint()..color = accent..strokeWidth = 2..strokeCap = StrokeCap.round);
        }
      case MascotMood.tired:
        for (final o in const [Offset(69, 23), Offset(31, 30)]) {
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
        tp.paint(canvas, const Offset(70, 4));
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
