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
  static const _skinHi = Color(0xFFF2C893);
  static const _skinDeep = Color(0xFF8A5530);

  /// 원통형 명암(왼쪽 위 빛): 밝은 면 → 기본 → 어두운 면.
  static Paint _cyl(Rect r) => Paint()
    ..shader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [_skinHi, _skin, _skinDark, _skinDeep],
      stops: [0.0, 0.35, 0.8, 1.0],
    ).createShader(r);

  /// 근육 덩어리 볼륨: 가운데 위가 밝고 가장자리가 어둡다.
  static Paint _bulge(Rect r) => Paint()
    ..shader = const RadialGradient(
      center: Alignment(-0.35, -0.45),
      radius: 0.95,
      colors: [_skinHi, _skin, _skinDark],
      stops: [0.0, 0.5, 1.0],
    ).createShader(r);

  static final _softShadow = Paint()
    ..color = const Color(0x66301A0C)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2);

  /// 땀 광택(하이라이트).
  static final _sheen = Paint()
    ..color = const Color(0x8CFFFFFF)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.9);
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
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), _cyl(r));
      final bi = Rect.fromCenter(center: Offset(-1, -len * 0.18), width: w * 0.86, height: len * 0.5);
      canvas.drawOval(bi.shift(const Offset(1.2, 1.6)), _softShadow);
      canvas.drawOval(bi, _bulge(bi));
      canvas.drawOval(Rect.fromCenter(center: Offset(-w * 0.18, -len * 0.27), width: w * 0.22, height: len * 0.14), _sheen);
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
    canvas.drawPath(torso, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_skinHi, _skin, _skinDark, _skinDeep],
        stops: [0.0, 0.3, 0.75, 1.0],
      ).createShader(const Rect.fromLTWH(4, 36, 92, 54)));
    // 어깨(삼각근) 볼륨
    for (final r in const [Rect.fromLTWH(4, 42, 22, 18), Rect.fromLTWH(74, 42, 22, 18)]) {
      canvas.drawOval(r, _bulge(r));
    }
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
    // 가슴 아래 그림자(가슴이 튀어나와 보이게)
    canvas.drawPath(pecL.shift(const Offset(0.8, 2.4)), _softShadow);
    canvas.drawPath(pecR.shift(const Offset(0.8, 2.4)), _softShadow);
    canvas.drawPath(pecL, _bulge(const Rect.fromLTWH(20, 50, 28, 16)));
    canvas.drawPath(pecR, _bulge(const Rect.fromLTWH(52, 50, 28, 16)));
    canvas.drawOval(const Rect.fromLTWH(26, 52, 9, 3.5), _sheen);
    canvas.drawOval(const Rect.fromLTWH(57, 52, 9, 3.5), _sheen);
    canvas.drawPath(pecL, thin);
    canvas.drawPath(pecR, thin);
    // 복근 6칸: 선 대신 볼록한 블록(사이 홈은 어둡게)
    canvas.drawRect(const Rect.fromLTWH(35, 64, 30, 25), Paint()..color = _skinDeep.withValues(alpha: 0.55));
    for (final row in const [65.5, 72.5, 79.5]) {
      for (final x in const [36.5, 50.8]) {
        final r = Rect.fromLTWH(x, row, 12.7, 6.2);
        canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2.6)), _bulge(r));
      }
    }
    for (final o in const [Offset(39, 66.5), Offset(53, 66.5), Offset(39, 73.5)]) {
      canvas.drawOval(Rect.fromLTWH(o.dx, o.dy, 4, 1.6), _sheen);
    }
    canvas.drawLine(const Offset(50, 64), const Offset(50, 88), thin);
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
          canvas.drawRRect(RRect.fromRectAndRadius(r.shift(const Offset(0, 2)), const Radius.circular(8)), _softShadow);
          canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)), Paint()
            ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_skinHi, _skin, _skinDeep], stops: [0.0, 0.45, 1.0]).createShader(r));
          canvas.drawOval(Rect.fromCenter(center: const Offset(-8, -1), width: 16, height: 10), _bulge(Rect.fromCenter(center: const Offset(-8, -1), width: 16, height: 10)));
          canvas.drawOval(Rect.fromCenter(center: const Offset(-4, -4), width: 10, height: 2.4), _sheen);
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
    canvas.drawPath(head, Paint()
      ..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_skinHi, _skin, _skinDark]).createShader(const Rect.fromLTWH(38, 18, 24, 22)));
    canvas.drawRect(const Rect.fromLTWH(43, 38.5, 14, 1.8), _softShadow);
    canvas.drawOval(const Rect.fromLTWH(41, 20, 6, 1.8), _sheen);
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

/// 해병 헬스 뱃지(애니풍): 남색 바탕 + 노란 밧줄 테두리 + 빨간 원 + 흰 독수리 + 금색 닻 + 흑백 별.
/// 해병대 상징의 분위기를 만화풍으로 다시 그린 것으로, 공식 휘장이 아니다(공식 문구 대신 헬스 문구).
class MarineEmblem extends StatelessWidget {
  const MarineEmblem({super.key, this.size = 40, this.top = '악! 해병 헬스', this.bottom = 'FIT MARINE', this.motto = '근성과 땀을 위하여'});
  final double size;
  final String top;
  final String bottom;
  final String motto;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _EmblemPainter(top, bottom, motto));
}

class _EmblemPainter extends CustomPainter {
  _EmblemPainter(this.top, this.bottom, this.motto);
  final String top;
  final String bottom;
  final String motto;

  static const _navy = Color(0xFF1F2B5C);
  static const _yellow = Color(0xFFFFE04A);
  static const _yellowDark = Color(0xFFC9A400);
  static const _red = Color(0xFFE2463F);
  static const _ink = Color(0xFF151A33);
  static const _gold = Color(0xFFF5C518);
  static const _goldDark = Color(0xFFB8860B);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.scale(s, s);
    const c = Offset(50, 50);
    final ink = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // 바탕·밧줄 두 줄
    canvas.drawCircle(c, 49.5, Paint()..color = _navy);
    _rope(canvas, c, 46.5, 3.2, 44);
    _rope(canvas, c, 34.8, 2.6, 32);
    canvas.drawCircle(c, 33.2, Paint()..color = _red);
    canvas.drawCircle(c, 33.2, Paint()..color = const Color(0x22000000)..style = PaintingStyle.stroke..strokeWidth = 2);

    // 둥근 글자(위는 바깥을 향해, 아래는 읽기 좋게 뒤집어)
    _arcText(canvas, c, 40.5, top, -math.pi / 2, 0.21, upper: true);
    _arcText(canvas, c, 40.5, bottom, math.pi / 2, 0.165, upper: false);
    // 양옆 별
    for (final x in [9.5, 90.5]) {
      canvas.drawPath(_star(Offset(x, 50), 3.6, 1.5), Paint()..color = _yellow);
    }

    // 금색 닻(뒤)
    final anchor = Paint()
      ..color = _gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round;
    final anchorEdge = Paint()
      ..color = _goldDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.6
      ..strokeCap = StrokeCap.round;
    final shank = Path()..moveTo(68, 36)..lineTo(38, 80);
    final stock = Path()..moveTo(61, 37)..lineTo(76, 47);
    final crown = Path()
      ..moveTo(26, 70)
      ..quadraticBezierTo(30, 86, 46, 87);
    for (final p in [shank, stock, crown]) {
      canvas.drawPath(p, anchorEdge);
      canvas.drawPath(p, anchor);
    }
    canvas.drawCircle(const Offset(70, 33), 3.2, Paint()..color = _goldDark..style = PaintingStyle.stroke..strokeWidth = 2.6);
    canvas.drawCircle(const Offset(70, 33), 3.2, Paint()..color = _gold..style = PaintingStyle.stroke..strokeWidth = 1.6);
    for (final tip in const [Offset(26, 70), Offset(46, 87)]) {
      canvas.drawCircle(tip, 3, Paint()..color = _gold);
      canvas.drawCircle(tip, 3, Paint()..color = _goldDark..style = PaintingStyle.stroke..strokeWidth = 0.8);
    }
    // 닻줄
    final rope = Path()
      ..moveTo(70, 36)
      ..cubicTo(80, 46, 72, 58, 62, 60)
      ..cubicTo(52, 62, 46, 74, 34, 74);
    canvas.drawPath(rope, Paint()..color = const Color(0xFFF7E7B0)..style = PaintingStyle.stroke..strokeWidth = 1.8);

    // 흑백 별(입체)
    _bevelStar(canvas, const Offset(50, 69), 12.5, 5.2);

    // 독수리: 펼친 날개 + 몸통 + 왼쪽을 보는 머리
    final white = Paint()..color = Colors.white;
    for (final side in [-1.0, 1.0]) {
      final wing = Path()..moveTo(50 + side * 3, 50);
      // 깃털 끝 5개(톱니)
      final tips = [
        Offset(50 + side * 10, 38),
        Offset(50 + side * 20, 34),
        Offset(50 + side * 29, 33),
        Offset(50 + side * 33, 37),
        Offset(50 + side * 31, 42),
      ];
      wing.lineTo(tips[0].dx, tips[0].dy);
      for (var i = 1; i < tips.length; i++) {
        final mid = Offset((tips[i - 1].dx + tips[i].dx) / 2, (tips[i - 1].dy + tips[i].dy) / 2 + 3);
        wing.quadraticBezierTo(mid.dx, mid.dy, tips[i].dx, tips[i].dy);
      }
      wing
        ..quadraticBezierTo(50 + side * 22, 46, 50 + side * 15, 50)
        ..quadraticBezierTo(50 + side * 9, 53, 50 + side * 3, 54)
        ..close();
      canvas.drawPath(wing, white);
      canvas.drawPath(wing, ink);
      // 깃털 결
      for (var k = 0; k < 4; k++) {
        final a = Offset(50 + side * (8 + k * 5.5), 46 - k * 0.6);
        final b = Offset(50 + side * (12 + k * 5.5), 40 - k * 1.2);
        canvas.drawLine(a, b, Paint()..color = const Color(0xFF9AA3B5)..strokeWidth = 0.7..strokeCap = StrokeCap.round);
      }
    }
    final body = Path()
      ..moveTo(45, 44)
      ..quadraticBezierTo(50, 40, 55, 44)
      ..quadraticBezierTo(57, 52, 53, 58)
      ..lineTo(50, 61)
      ..lineTo(47, 58)
      ..quadraticBezierTo(43, 52, 45, 44)
      ..close();
    canvas.drawPath(body, white);
    canvas.drawPath(body, ink);
    // 머리(왼쪽을 봄) + 노란 부리 + 눈
    final head = Path()
      ..moveTo(47, 44)
      ..quadraticBezierTo(44, 36, 48.5, 33.5)
      ..quadraticBezierTo(53.5, 32.5, 54, 38)
      ..quadraticBezierTo(54, 42, 52, 44)
      ..close();
    canvas.drawPath(head, white);
    canvas.drawPath(head, ink);
    final beak = Path()
      ..moveTo(46.5, 36)
      ..lineTo(42, 37.6)
      ..quadraticBezierTo(43, 39.6, 46.8, 38.8)
      ..close();
    canvas.drawPath(beak, Paint()..color = _yellow);
    canvas.drawPath(beak, ink);
    canvas.drawCircle(const Offset(48.6, 35.6), 0.9, Paint()..color = _ink);

    // 부리에서 늘어진 리본 + 문구
    final ribbon = Path()
      ..moveTo(44, 37.5)
      ..quadraticBezierTo(46, 30, 54, 27)
      ..lineTo(76, 24.5)
      ..lineTo(73, 28)
      ..lineTo(77, 31)
      ..lineTo(55, 32.5)
      ..quadraticBezierTo(49, 34, 46.5, 38.5)
      ..close();
    canvas.drawPath(ribbon, white);
    canvas.drawPath(ribbon, ink);
    final tp = TextPainter(
      text: TextSpan(text: motto, style: const TextStyle(color: _ink, fontSize: 3.6, fontWeight: FontWeight.w800, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 22);
    canvas.save();
    canvas.translate(54.5, 27.6);
    canvas.rotate(-0.07);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
  }

  /// 꼬인 밧줄: 노란 띠 위에 짧은 빗금.
  void _rope(Canvas canvas, Offset c, double r, double w, int twists) {
    canvas.drawCircle(c, r, Paint()..color = _yellow..style = PaintingStyle.stroke..strokeWidth = w);
    final p = Paint()
      ..color = _yellowDark
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < twists; i++) {
      final a = i * 2 * math.pi / twists;
      final p1 = c + Offset(math.cos(a - 0.04) * (r - w / 2), math.sin(a - 0.04) * (r - w / 2));
      final p2 = c + Offset(math.cos(a + 0.06) * (r + w / 2), math.sin(a + 0.06) * (r + w / 2));
      canvas.drawLine(p1, p2, p);
    }
  }

  /// 원을 따라 글자를 배치. [center]는 글자열 가운데 각도, [step]은 글자 간격(라디안).
  void _arcText(Canvas canvas, Offset c, double r, String text, double center, double step, {required bool upper}) {
    final chars = text.characters.toList();
    final start = center - step * (chars.length - 1) / 2 * (upper ? 1 : -1);
    for (var i = 0; i < chars.length; i++) {
      final a = start + step * i * (upper ? 1 : -1);
      final tp = TextPainter(
        text: TextSpan(text: chars[i], style: const TextStyle(color: _yellow, fontSize: 9, fontWeight: FontWeight.w900, height: 1)),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      canvas.rotate(upper ? a + math.pi / 2 : a - math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  Path _star(Offset c, double r, double inner) {
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr);
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    return star..close();
  }

  /// 꼭짓점마다 반은 흰색·반은 검정으로 나눠 입체감을 주는 별.
  void _bevelStar(Canvas canvas, Offset c, double r, double inner) {
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      final tip = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      final l = Offset(c.dx + math.cos(a - math.pi / 5) * inner, c.dy + math.sin(a - math.pi / 5) * inner);
      final rr = Offset(c.dx + math.cos(a + math.pi / 5) * inner, c.dy + math.sin(a + math.pi / 5) * inner);
      canvas.drawPath(Path()..moveTo(c.dx, c.dy)..lineTo(l.dx, l.dy)..lineTo(tip.dx, tip.dy)..close(), Paint()..color = Colors.white);
      canvas.drawPath(Path()..moveTo(c.dx, c.dy)..lineTo(tip.dx, tip.dy)..lineTo(rr.dx, rr.dy)..close(), Paint()..color = _ink);
    }
    canvas.drawPath(_star(c, r, inner), Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = 0.9..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_EmblemPainter old) => old.top != top || old.bottom != bottom || old.motto != motto;
}
