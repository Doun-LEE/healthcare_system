import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'mascot.dart';

/// 테마 성격에 맞춘 화면 배경 사진. 모든 페이지 뒤에 깔린다(Scaffold 는 투명).
/// 사진 위에 바탕색을 덮어 글자가 묻히지 않게 한다.
/// - 기본: 식물과 요가매트가 있는 차분한 방구석
/// - 귀여운: 손그림 원화 느낌의 분홍 물방울 배경 + 헬창애옹
/// - 상남자: 불 꺼진 쇳덩이 체육관(흑백 + 녹슨 주황)
/// - 해병대: IBS 보트를 들고 해변을 달리는 해병
class ThemeBackdrop extends StatelessWidget {
  const ThemeBackdrop({super.key, required this.style, required this.child});
  final AppThemeStyle style;
  final Widget child;

  /// 사진을 얼마나 덮을지(0~1). 높을수록 사진이 옅다.
  static double veil(AppThemeStyle style, bool dark) => switch (style) {
        AppThemeStyle.basic => dark ? 0.82 : 0.72,
        AppThemeStyle.cute => dark ? 0.80 : 0.45,
        AppThemeStyle.tough => dark ? 0.62 : 0.78,
        AppThemeStyle.marine => dark ? 0.80 : 0.74,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    final v = veil(style, dark);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (style == AppThemeStyle.cute)
          RepaintBoundary(
            child: Stack(fit: StackFit.expand, children: [
              CustomPaint(painter: _CuteDotsPainter(dark)),
              const Positioned(right: -24, bottom: 70, child: Mascot(mood: MascotMood.flex, size: 260, bob: false)),
              const Positioned(left: 10, top: 90, child: Mascot(size: 70, bob: false)),
            ]),
          )
        else
        RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(color: surface),
            child: Image.asset(
              style.backdrop,
              fit: BoxFit.cover,
              cacheWidth: 720,
              gaplessPlayback: true,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
        // 위·아래(제목줄·탭바 근처)는 조금 더 덮어서 글자가 또렷하게
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                surface.withValues(alpha: (v + 0.08).clamp(0, 1)),
                surface.withValues(alpha: v),
                surface.withValues(alpha: v),
                surface.withValues(alpha: (v + 0.06).clamp(0, 1)),
              ],
              stops: const [0.0, 0.25, 0.75, 1.0],
            ),
          ),
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

/// 귀여운 테마 배경: 원화 종이처럼 연분홍 바탕에 큰 물방울 무늬.
class _CuteDotsPainter extends CustomPainter {
  _CuteDotsPainter(this.dark);
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = dark ? const Color(0xFF3A2630) : const Color(0xFFFDEEF2));
    final dot = Paint()..color = dark ? const Color(0xFF52323F) : const Color(0xFFF9D3DE);
    const spots = [
      (0.12, 0.08, 0.10), (0.86, 0.14, 0.08), (0.55, 0.30, 0.05), (0.08, 0.46, 0.07),
      (0.92, 0.52, 0.06), (0.30, 0.66, 0.09), (0.70, 0.86, 0.07), (0.15, 0.92, 0.06), (0.48, 0.05, 0.04),
    ];
    for (final (x, y, r) in spots) {
      canvas.drawCircle(Offset(size.width * x, size.height * y), size.width * r, dot);
    }
  }

  @override
  bool shouldRepaint(_CuteDotsPainter old) => old.dark != dark;
}
