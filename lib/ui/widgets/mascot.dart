import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../app_theme.dart';

/// FitRoutine 오리지널 마스코트 "뭉치": 크림색 찹쌀떡 몸통에 새싹 하나, 빨간 운동 머리띠.
/// 외부 캐릭터를 베끼지 않도록 실루엣(납작한 떡 + 새싹 + 머리띠)과 표정을 우리 것으로 그렸다.
/// 이미지 파일이 아니라 코드로 그려서 어느 크기에서도 선명하고, 테마 색에 맞출 수 있다.
enum MascotMood {
  /// 기본: 점 눈, 방긋.
  happy,

  /// 환호: 두 팔 번쩍, 입 벌림.
  cheer,

  /// 지침: 눈 감고 땀 한 방울.
  tired,

  /// 잠: 눈 감고 zz.
  sleep,

  /// 근육 자랑: 한 팔 들고 아령.
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

class _MascotPainter extends CustomPainter {
  _MascotPainter(this.mood, {required this.band});
  final MascotMood mood;
  final Color band;

  static const _cream = Color(0xFFFFF4DC);
  static const _line = Color(0xFF4A3B2E);
  static const _blush = Color(0x66FF8FAE);
  static const _leaf = Color(0xFF7CC47F);
  static const _leafDark = Color(0xFF4F9A55);
  static const _sweat = Color(0xFF7FB8F2);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.scale(s, s);
    final fill = Paint()..color = _cream;
    final line = Paint()
      ..color = _line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 발(몸 뒤에 살짝)
    for (final x in [40.0, 60.0]) {
      final foot = Rect.fromCenter(center: Offset(x, 89), width: 15, height: 8);
      canvas.drawOval(foot, fill);
      canvas.drawOval(foot, line);
    }

    // 팔(기분에 따라 위치)
    void arm(Offset c, double angleDeg, {double len = 16}) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angleDeg * math.pi / 180);
      final r = Rect.fromCenter(center: Offset.zero, width: len, height: 8);
      canvas.drawOval(r, fill);
      canvas.drawOval(r, line);
      canvas.restore();
    }
    // 내린 팔은 몸통 뒤에, 올린 팔은 몸통 뒤에 가려지지 않게 몸통 다음에 그린다.
    switch (mood) {
      case MascotMood.cheer:
        break;
      case MascotMood.flex:
        arm(const Offset(17, 66), 10);
      case MascotMood.sleep:
        arm(const Offset(22, 72), 20);
        arm(const Offset(78, 72), -20);
      case MascotMood.happy:
      case MascotMood.tired:
        arm(const Offset(17, 66), 10);
        arm(const Offset(83, 66), -10);
    }

    // 몸통: 납작한 찹쌀떡
    final body = Path()
      ..moveTo(14, 60)
      ..cubicTo(14, 36, 30, 26, 50, 26)
      ..cubicTo(70, 26, 86, 36, 86, 60)
      ..cubicTo(86, 78, 70, 88, 50, 88)
      ..cubicTo(30, 88, 14, 78, 14, 60)
      ..close();
    canvas.drawPath(body, fill);
    canvas.drawPath(body, line);

    // 올린 팔(몸통 앞): 환호는 양팔, 근육 자랑은 오른팔
    switch (mood) {
      case MascotMood.cheer:
        arm(const Offset(14, 40), 56, len: 18);
        arm(const Offset(86, 40), -56, len: 18);
      case MascotMood.flex:
        arm(const Offset(86, 40), -56, len: 18);
      case MascotMood.happy:
      case MascotMood.tired:
      case MascotMood.sleep:
        break;
    }

    // 새싹
    canvas.drawLine(const Offset(50, 26), const Offset(50, 17), line..strokeWidth = 2.2);
    canvas.save();
    canvas.translate(50, 17);
    canvas.rotate(-0.55);
    final leaf = Rect.fromCenter(center: const Offset(6, -1.5), width: 13, height: 7);
    canvas.drawOval(leaf, Paint()..color = _leaf);
    canvas.drawOval(leaf, Paint()..color = _leafDark..style = PaintingStyle.stroke..strokeWidth = 1.6);
    canvas.restore();
    line.strokeWidth = 2.4;

    // 머리띠(테마 포인트색)
    final bandPath = Path()
      ..moveTo(19, 46)
      ..cubicTo(30, 36, 70, 36, 81, 46)
      ..lineTo(81, 52)
      ..cubicTo(70, 42, 30, 42, 19, 52)
      ..close();
    canvas.drawPath(bandPath, Paint()..color = band);
    canvas.drawPath(bandPath, line..strokeWidth = 1.8);
    line.strokeWidth = 2.4;

    // 볼터치
    final blush = Paint()..color = _blush;
    canvas.drawOval(Rect.fromCenter(center: const Offset(29, 66), width: 11, height: 6), blush);
    canvas.drawOval(Rect.fromCenter(center: const Offset(71, 66), width: 11, height: 6), blush);

    // 눈
    final dot = Paint()..color = _line;
    final eyeL = const Offset(38, 60), eyeR = const Offset(62, 60);
    switch (mood) {
      case MascotMood.happy:
      case MascotMood.cheer:
      case MascotMood.flex:
        canvas.drawCircle(eyeL, 2.8, dot);
        canvas.drawCircle(eyeR, 2.8, dot);
        // 눈 반짝
        canvas.drawCircle(eyeL + const Offset(-1, -1), 0.9, Paint()..color = Colors.white);
        canvas.drawCircle(eyeR + const Offset(-1, -1), 0.9, Paint()..color = Colors.white);
      case MascotMood.tired:
        // > <  처럼 찡그린 눈
        for (final e in [eyeL, eyeR]) {
          final d = e == eyeL ? 1.0 : -1.0;
          canvas.drawLine(e + Offset(-3 * d, -3), e + Offset(2 * d, 0), line);
          canvas.drawLine(e + Offset(2 * d, 0), e + Offset(-3 * d, 3), line);
        }
      case MascotMood.sleep:
        // 감은 눈: 아래로 볼록한 호
        for (final e in [eyeL, eyeR]) {
          canvas.drawArc(Rect.fromCenter(center: e - const Offset(0, 1), width: 8, height: 6), 0.2, math.pi - 0.4, false, line);
        }
    }

    // 입
    switch (mood) {
      case MascotMood.happy:
      case MascotMood.flex:
        final m = Path()
          ..moveTo(45, 68)
          ..quadraticBezierTo(50, 73, 55, 68);
        canvas.drawPath(m, line);
      case MascotMood.cheer:
        final mouth = Rect.fromCenter(center: const Offset(50, 71), width: 10, height: 8);
        canvas.drawOval(mouth, Paint()..color = const Color(0xFFE2636E));
        canvas.drawOval(mouth, line);
      case MascotMood.tired:
        final m = Path()
          ..moveTo(45, 71)
          ..quadraticBezierTo(48, 68, 50, 71)
          ..quadraticBezierTo(52, 74, 55, 71);
        canvas.drawPath(m, line);
      case MascotMood.sleep:
        canvas.drawOval(Rect.fromCenter(center: const Offset(50, 71), width: 5, height: 4), line);
    }

    // 장식: 땀 / zz / 아령
    switch (mood) {
      case MascotMood.tired:
        final drop = Path()
          ..moveTo(78, 40)
          ..quadraticBezierTo(83, 48, 78, 50)
          ..quadraticBezierTo(73, 48, 78, 40)
          ..close();
        canvas.drawPath(drop, Paint()..color = _sweat);
      case MascotMood.sleep:
        final tp = TextPainter(
          text: const TextSpan(text: 'z', style: TextStyle(color: _line, fontSize: 11, fontWeight: FontWeight.w700)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, const Offset(80, 28));
        final tp2 = TextPainter(
          text: const TextSpan(text: 'Z', style: TextStyle(color: _line, fontSize: 14, fontWeight: FontWeight.w700)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp2.paint(canvas, const Offset(88, 14));
      case MascotMood.flex:
        // 든 팔 끝의 작은 아령
        final bar = Paint()
          ..color = _line
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(84, 31), const Offset(98, 31), bar);
        for (final x in [84.0, 98.0]) {
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, 31), width: 4, height: 11), const Radius.circular(1.5)), Paint()..color = band);
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, 31), width: 4, height: 11), const Radius.circular(1.5)), line..strokeWidth = 1.4);
        }
      case MascotMood.happy:
      case MascotMood.cheer:
        break;
    }
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

  /// 말하는 캐릭터. 비우면 뭉치.
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
