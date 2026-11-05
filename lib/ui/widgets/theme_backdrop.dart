import 'package:flutter/material.dart';

import '../app_theme.dart';

/// 테마 성격에 맞춘 화면 배경 사진. 모든 페이지 뒤에 깔린다(Scaffold 는 투명).
/// 사진 위에 바탕색을 덮어 글자가 묻히지 않게 한다.
/// - 기본: 식물과 요가매트가 있는 차분한 방구석
/// - 귀여운: 분홍·민트 덤벨
/// - 상남자: 불 꺼진 쇳덩이 체육관(흑백 + 녹슨 주황)
/// - 해병대: IBS 보트를 들고 해변을 달리는 해병
class ThemeBackdrop extends StatelessWidget {
  const ThemeBackdrop({super.key, required this.style, required this.child});
  final AppThemeStyle style;
  final Widget child;

  /// 사진을 얼마나 덮을지(0~1). 높을수록 사진이 옅다.
  static double veil(AppThemeStyle style, bool dark) => switch (style) {
        AppThemeStyle.basic => dark ? 0.82 : 0.72,
        AppThemeStyle.cute => dark ? 0.84 : 0.74,
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
