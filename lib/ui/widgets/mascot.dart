import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../app_theme.dart';

/// 귀여운 테마 마스코트 "애옹": 손그림 원화를 옮긴 빨간 머리띠 고양이(얼굴)와 근육 고양이 "헬창애옹"(전신).
/// 이미지 파일이 아니라 코드로 그려서 어느 크기에서도 선명하다.
enum MascotMood {
  /// 기본: 애옹 얼굴, 점 눈.
  happy,

  /// 환호: 헬창애옹 전신.
  cheer,

  /// 지침: 눈 감고 땀 한 방울.
  tired,

  /// 잠: 눈 감고 zz.
  sleep,

  /// 근육 자랑: 헬창애옹 전신.
  flex,
}

/// 지금 테마가 '귀여운'인지. 마스코트는 이 테마에서만 보인다.
bool isCuteTheme(BuildContext context) {
  final theme = context.select<AppState, String?>((s) => s.currentUser?.theme);
  return AppThemeStyle.parse(theme) == AppThemeStyle.cute;
}

/// 마스코트 한 마리. [bob] 이면 살짝 위아래로 둥실거린다.
class Mascot extends StatefulWidget {
  const Mascot({super.key, this.mood = MascotMood.happy, this.size = 72, this.bob = true});
  final MascotMood mood;
  final double size;
  final bool bob;

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void initState() {
    super.initState();
    if (widget.bob) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant Mascot old) {
    super.didUpdateWidget(old);
    if (widget.bob && !_c.isAnimating) _c.repeat();
    if (!widget.bob && _c.isAnimating) _c.stop();
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
        final t = _c.value * 2 * math.pi;
        final dy = widget.bob ? math.sin(t) * widget.size * 0.03 : 0.0;
        // 잠잘 때는 숨 쉬듯 살짝 납작해졌다 펴진다.
        final squash = widget.mood == MascotMood.sleep && widget.bob ? 1 + math.sin(t) * 0.025 : 1.0;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(scaleX: squash, scaleY: 2 - squash, alignment: Alignment.bottomCenter, child: child),
        );
      },
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _MascotPainter(widget.mood, band: cs.primary),
      ),
    );
  }
}

/// SVG 경로(절대 좌표 M·L·C·Z만)를 Flutter Path로. 캐릭터 원화를 그대로 옮기려고 쓴다.
Path svgPath(String d) {
  final p = Path();
  final t = RegExp(r'[MLCZ]|-?\d*\.?\d+').allMatches(d).map((m) => m.group(0)!).toList();
  var i = 0;
  var cmd = 'M';
  double n() => double.parse(t[i++]);
  while (i < t.length) {
    final tok = t[i];
    if (tok == 'M' || tok == 'L' || tok == 'C' || tok == 'Z') {
      cmd = tok;
      i++;
      if (cmd == 'Z') {
        p.close();
        continue;
      }
    }
    switch (cmd) {
      case 'M':
        p.moveTo(n(), n());
        cmd = 'L';
      case 'L':
        p.lineTo(n(), n());
      case 'C':
        p.cubicTo(n(), n(), n(), n(), n(), n());
      default:
        i++;
    }
  }
  return p;
}

/// 손으로 그린 원화를 옮긴 캐릭터.
/// - 애옹 얼굴: 빨간 머리띠를 두른 하얀 고양이 얼굴(기본·지침·잠).
/// - 헬창애옹: 빨간 머리띠·빨간 팬티의 근육 고양이(환호·근육 자랑).
class _MascotPainter extends CustomPainter {
  _MascotPainter(this.mood, {required this.band});
  final MascotMood mood;
  final Color band;

  static const _white = Color(0xFFFFFFFF);
  static const _line = Color(0xFF2B2B2B);
  static const _red = Color(0xFFE5484D);
  static const _earPink = Color(0xFFF5A3B8);
  static const _blush = Color(0xFFF9B8C9);
  static const _sweat = Color(0xFF7FB8F2);

  static final Map<String, Path> _cache = {};
  static Path _p(String d) => _cache.putIfAbsent(d, () => svgPath(d));

  bool get _body => mood == MascotMood.cheer || mood == MascotMood.flex;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.scale(s, s);
    final line = Paint()
      ..color = _line
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (_body) {
      _paintBody(canvas, line);
    } else {
      _paintFace(canvas, line);
    }
  }

  void _shape(Canvas c, String d, Color fill, Paint line) {
    final path = _p(d);
    c.drawPath(path, Paint()..color = fill);
    c.drawPath(path, line);
  }

  void _stroke(Canvas c, String d, Paint line) => c.drawPath(_p(d), line);

  // 애옹 얼굴 (원화 좌표 x 240~442, y 64~262)
  void _paintFace(Canvas canvas, Paint line) {
    canvas.save();
    const k = 100 / 212;
    canvas.translate(50, 50);
    canvas.scale(k, k);
    canvas.translate(-341, -163);
    line.strokeWidth = 5.2;
    _shape(canvas, 'M280 120 L274 66 L314 92 Z', _white, line);
    _shape(canvas, 'M366 91 L404 64 L400 118 Z', _white, line);
    canvas.drawPath(_p('M286 104 L284 84 L300 95 Z'), Paint()..color = _earPink);
    canvas.drawPath(_p('M392 102 L394 84 L380 94 Z'), Paint()..color = _earPink);
    const head = 'M266 180 C264 120 302 88 340 88 C380 88 418 120 414 180 C412 234 378 262 340 262 C300 262 264 234 266 180 Z';
    canvas.drawPath(_p(head), Paint()..color = _white);
    canvas.save();
    canvas.clipPath(_p(head));
    _shape(canvas, 'M260 126 C310 114 370 114 420 126 L420 148 C370 138 310 138 260 148 Z', _red, line);
    canvas.restore();
    _stroke(canvas, head, line);
    _shape(canvas, 'M410 128 C424 120 434 122 438 114 C442 130 428 138 412 138 Z', _red, line);
    _shape(canvas, 'M412 136 C428 140 432 152 442 152 C432 160 420 152 412 144 Z', _red, line);
    final blush = Paint()..color = _blush;
    canvas.drawOval(Rect.fromCenter(center: const Offset(300, 196), width: 24, height: 14), blush);
    canvas.drawOval(Rect.fromCenter(center: const Offset(378, 196), width: 24, height: 14), blush);
    final dot = Paint()..color = _line;
    switch (mood) {
      case MascotMood.tired:
        _stroke(canvas, 'M308 168 L318 174 L308 180', line);
        _stroke(canvas, 'M370 168 L360 174 L370 180', line);
      case MascotMood.sleep:
        _stroke(canvas, 'M308 174 C312 180 320 180 324 174', line);
        _stroke(canvas, 'M354 174 C358 180 366 180 370 174', line);
      default:
        canvas.drawCircle(const Offset(316, 174), 3.6, dot);
        canvas.drawCircle(const Offset(362, 174), 3.6, dot);
    }
    _stroke(canvas, 'M331 188 C334 196 339 196 340 188 C341 196 346 196 349 188', line);
    _stroke(canvas, 'M268 168 L242 160 M268 184 L240 186 M272 200 L246 210', line);
    _stroke(canvas, 'M412 168 L438 160 M412 184 L440 186 M408 200 L434 210', line);
    if (mood == MascotMood.tired) {
      canvas.drawPath(_p('M420 96 C432 112 432 124 420 124 C408 124 408 112 420 96 Z'), Paint()..color = _sweat);
    }
    canvas.restore();
    if (mood == MascotMood.sleep) {
      for (final (txt, fs, off) in [('z', 11.0, const Offset(82, 20)), ('Z', 14.0, const Offset(90, 4))]) {
        final tp = TextPainter(
          text: TextSpan(text: txt, style: TextStyle(color: _line, fontSize: fs, fontWeight: FontWeight.w700)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, off);
      }
    }
  }

  // 헬창애옹 (원화 좌표 x -74~74, y 18~320, 가운데 0)
  void _paintBody(Canvas canvas, Paint line) {
    canvas.save();
    const k = 100 / 306;
    canvas.translate(50, 0);
    canvas.scale(k, k);
    canvas.translate(0, -16);
    line.strokeWidth = 6;
    for (final side in [1.0, -1.0]) {
      canvas.save();
      canvas.scale(side, 1);
      _shape(canvas, 'M-16 247 C-32 258 -36 280 -32 298 L-36 312 C-38 316 -36 318 -32 318 L-16 318 C-14 302 -10 284 -4 252 Z', _white, line);
      _stroke(canvas, 'M-26 266 C-22 274 -22 282 -26 290', line);
      _shape(canvas, 'M-60 184 C-64 200 -60 214 -55 224 L-41 224 C-38 212 -38 200 -40 192 Z', _white, line);
      _stroke(canvas, 'M-54 200 C-50 206 -48 212 -48 218', line);
      canvas.drawCircle(const Offset(-48, 232), 10, Paint()..color = _white);
      canvas.drawCircle(const Offset(-48, 232), 10, line);
      _stroke(canvas, 'M-56 230 C-52 232 -46 232 -42 229 M-55 236 C-51 238 -46 238 -42 235', line);
      canvas.restore();
    }
    _shape(canvas, 'M-26 132 C-10 138 10 138 26 132 L30 150 C28 180 24 205 21 226 L-21 226 C-24 205 -28 180 -30 150 Z', _white, line);
    _stroke(canvas, 'M-22 150 C-12 160 -4 158 0 150 C4 158 12 160 22 150', line);
    _stroke(canvas, 'M0 160 L0 220 M-10 176 L-4 178 M10 176 L4 178 M-10 192 L-4 194 M10 192 L4 194 M-9 207 L-4 209 M9 207 L4 209', line);
    _shape(canvas, 'M-21 224 L21 224 L16 248 L5 250 L0 241 L-5 250 L-16 248 Z', _red, line);
    for (final side in [1.0, -1.0]) {
      canvas.save();
      canvas.scale(side, 1);
      _shape(canvas, 'M-26 132 C-46 126 -64 138 -62 156 C-74 162 -74 180 -62 188 C-60 196 -50 198 -42 194 C-34 196 -28 190 -28 180 C-30 165 -30 150 -26 132 Z', _white, line);
      _stroke(canvas, 'M-48 164 C-44 170 -44 178 -48 184', line);
      canvas.restore();
    }
    _shape(canvas, 'M-12 108 L-14 134 C-8 138 8 138 14 134 L12 108 Z', _white, line);
    _stroke(canvas, 'M-14 128 C-19 131 -23 132 -27 133 M14 128 C19 131 23 132 27 133', line);
    canvas.translate(0, -12);
    _shape(canvas, 'M-34 70 L-37 30 L-12 46 Z', _white, line);
    _shape(canvas, 'M12 45 L36 30 L36 68 Z', _white, line);
    canvas.drawPath(_p('M-28 50 L-30 40 L-22 46 Z'), Paint()..color = _earPink);
    canvas.drawPath(_p('M26 46 L31 40 L31 50 Z'), Paint()..color = _earPink);
    _shape(canvas, 'M-38 92 C-44 56 -20 40 0 40 C22 40 44 56 40 92 C38 118 20 130 0 130 C-22 130 -40 118 -38 92 Z', _white, line);
    _shape(canvas, 'M-41 72 C-14 66 14 66 41 72 L42 88 C14 83 -14 83 -42 88 Z', _red, line);
    _shape(canvas, 'M41 76 C52 70 60 72 62 66 C64 78 54 84 42 84 Z', _red, line);
    _shape(canvas, 'M42 82 C54 86 58 96 66 96 C58 102 48 96 42 88 Z', _red, line);
    final blush = Paint()..color = _blush;
    canvas.drawOval(Rect.fromCenter(center: const Offset(-24, 110), width: 14, height: 8), blush);
    canvas.drawOval(Rect.fromCenter(center: const Offset(22, 110), width: 14, height: 8), blush);
    final dot = Paint()..color = _line;
    canvas.drawCircle(const Offset(-14, 101), 2.6, dot);
    canvas.drawCircle(const Offset(12, 101), 2.6, dot);
    _stroke(canvas, 'M-5 109 C-3 113 0 113 0 109 C0 113 3 113 5 109', line);
    _stroke(canvas, 'M-38 100 L-60 96 M-38 108 L-60 110 M38 100 L62 96 M38 108 L62 110', line);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MascotPainter old) => old.mood != mood || old.band != band;
}

/// 마스코트 + 말풍선 한 줄. 귀여운 테마의 홈·완료 화면에서 쓴다.
class MascotSays extends StatelessWidget {
  const MascotSays({super.key, required this.text, this.mood = MascotMood.happy, this.size = 64, this.onTap, this.avatar, this.bubbleColor, this.textColor});
  final String text;
  final MascotMood mood;
  final double size;
  final VoidCallback? onTap;

  /// 말하는 캐릭터. 비우면 애옹.
  final Widget? avatar;

  /// 말풍선 색. 비우면 primaryContainer.
  final Color? bubbleColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bubble = bubbleColor ?? cs.primaryContainer;
    final fg = textColor ?? cs.onPrimaryContainer;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          avatar ?? Mascot(mood: mood, size: size),
          const SizedBox(width: 4),
          // 말풍선 꼬리
          CustomPaint(
            size: const Size(10, 16),
            painter: _TailPainter(bubble),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: bubble, borderRadius: BorderRadius.circular(18)),
              child: Text(text, style: tt.bodyMedium?.copyWith(color: fg, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  _TailPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(size.width, 2)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height - 2)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color;
}
