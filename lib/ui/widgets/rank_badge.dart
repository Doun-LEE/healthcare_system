import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/rank.dart';

/// 게임 랭크 마크: 등급 색 육각형 + 'G2' 같은 짧은 글자. 마스터 이상은 위에 왕관.
class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.rank, this.size = 28});
  final Rank rank;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = rank.tier;
    final crown = t.index >= RankTier.master.index;
    return Tooltip(
      message: '${rank.label} · ${rank.points.round()}점',
      child: SizedBox(
        width: size,
        height: size * (crown ? 1.18 : 1.0),
        child: CustomPaint(
          painter: _BadgePainter(t, crown: crown),
          child: Padding(
            padding: EdgeInsets.only(top: crown ? size * 0.18 : 0),
            child: Center(
              child: Text(
                rank.short,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: size * (rank.short.length > 2 ? 0.3 : 0.36),
                  height: 1,
                  shadows: const [Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 1))],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  _BadgePainter(this.tier, {required this.crown});
  final RankTier tier;
  final bool crown;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final top = crown ? w * 0.18 : 0.0;
    final c = Offset(w / 2, top + w / 2);
    final r = w / 2;
    Path hex(double rr) {
      final p = Path();
      for (var k = 0; k < 6; k++) {
        final a = -pi / 2 + k * pi / 3;
        final pt = c + Offset(cos(a) * rr, sin(a) * rr);
        k == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      return p..close();
    }

    if (crown) {
      final cp = Path()
        ..moveTo(w * 0.28, top + w * 0.1)
        ..lineTo(w * 0.3, top - w * 0.12)
        ..lineTo(w * 0.42, top - w * 0.02)
        ..lineTo(w * 0.5, top - w * 0.17)
        ..lineTo(w * 0.58, top - w * 0.02)
        ..lineTo(w * 0.7, top - w * 0.12)
        ..lineTo(w * 0.72, top + w * 0.1)
        ..close();
      canvas.save();
      canvas.translate(0, w * 0.17);
      canvas.drawPath(cp, Paint()..color = const Color(0xFFF6C744));
      canvas.drawPath(cp, Paint()
        ..color = const Color(0xFF8A6D00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, w * 0.03));
      canvas.restore();
    }
    final outer = hex(r);
    canvas.drawShadow(outer, Colors.black, 1.5, false);
    canvas.drawPath(outer, Paint()..color = tier.dark);
    final inner = hex(r * 0.82);
    canvas.drawPath(
      inner,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tier.light, tier.dark],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawPath(
      inner,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.6, w * 0.035),
    );
  }

  @override
  bool shouldRepaint(_BadgePainter old) => old.tier != tier || old.crown != crown;
}

/// 아바타 오른쪽 아래에 랭크 마크를 붙인다.
class RankedAvatar extends StatelessWidget {
  const RankedAvatar({super.key, required this.child, required this.rank, this.radius = 20});
  final Widget child;
  final Rank? rank;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final r = rank;
    if (r == null) return child;
    final s = max(16.0, radius * 0.95);
    return Stack(clipBehavior: Clip.none, children: [
      child,
      Positioned(right: -s * 0.3, bottom: -s * 0.25, child: RankBadge(rank: r, size: s)),
    ]);
  }
}

/// 프로필 머리말용: 큰 랭크 마크 + '골드 II' + 점수·다음 등급까지.
class RankPlate extends StatelessWidget {
  const RankPlate({super.key, required this.rank, this.color});
  final Rank rank;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final fg = color ?? Theme.of(context).colorScheme.onSurface;
    final next = rank.toNext;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      RankBadge(rank: rank, size: 40),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(rank.label, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: rank.tier.dark)),
        Text(
          '${rank.points.round()}점 · 힘 ${rank.strength.round()} · 꾸준함 ${rank.activity.round()}${next == null ? '' : ' · 다음까지 ${next.ceil()}점'}',
          style: text.bodySmall?.copyWith(color: fg.withValues(alpha: 0.8)),
        ),
      ]),
    ]);
  }
}
