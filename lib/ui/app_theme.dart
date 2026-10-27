import 'package:flutter/material.dart';

/// 사용자가 고르는 앱 디자인. 프로필의 `theme` 문자열(id)로 저장된다.
enum AppThemeStyle {
  basic('basic', '기본', '지금 모습 그대로. 차분한 초록.', Icons.circle_outlined),
  cute('cute', '귀여운', '파스텔 핑크 · 동글동글 · 이모지 살짝 🐣', Icons.favorite_border),
  tough('tough', '상남자', '어두운 톤 · 강한 대비 · 각진 모서리 · 굵은 숫자', Icons.fitness_center);

  const AppThemeStyle(this.id, this.label, this.description, this.icon);
  final String id;
  final String label;
  final String description;
  final IconData icon;

  static AppThemeStyle parse(String? id) =>
      AppThemeStyle.values.firstWhere((e) => e.id == id, orElse: () => AppThemeStyle.basic);

  /// 대표색(시드).
  Color get seed => switch (this) {
        AppThemeStyle.basic => const Color(0xFF7CB342),
        AppThemeStyle.cute => const Color(0xFFF48FB1),
        AppThemeStyle.tough => const Color(0xFFE53935),
      };

  /// 모서리 반지름. 카드·입력창·버튼이 모두 이 값을 따른다.
  double get radius => switch (this) {
        AppThemeStyle.basic => 16,
        AppThemeStyle.cute => 28,
        AppThemeStyle.tough => 4,
      };
}

/// 테마 하나를 ThemeData 로 만든다. 세 디자인 모두 라이트/다크를 지원한다.
ThemeData buildAppTheme(AppThemeStyle style, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final r = style.radius;
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));

  final ColorScheme scheme;
  switch (style) {
    case AppThemeStyle.basic:
      scheme = ColorScheme.fromSeed(seedColor: style.seed, brightness: brightness);
    case AppThemeStyle.cute:
      scheme = ColorScheme.fromSeed(
        seedColor: style.seed,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      ).copyWith(
        // 파스텔: 라이트는 아주 연한 분홍 바탕, 다크는 살짝 보랏빛 도는 부드러운 어둠.
        surface: dark ? const Color(0xFF221B22) : const Color(0xFFFFF6F9),
        surfaceContainerLowest: dark ? const Color(0xFF1A1419) : Colors.white,
        surfaceContainerLow: dark ? const Color(0xFF2B2229) : const Color(0xFFFFEEF3),
        surfaceContainer: dark ? const Color(0xFF32282F) : const Color(0xFFFFE4EC),
        surfaceContainerHigh: dark ? const Color(0xFF3B2F38) : const Color(0xFFFFDAE5),
        surfaceContainerHighest: dark ? const Color(0xFF463841) : const Color(0xFFFFCFDE),
        primary: dark ? const Color(0xFFFFB1C8) : const Color(0xFFD9567F),
        onPrimary: dark ? const Color(0xFF5A1B33) : Colors.white,
        primaryContainer: dark ? const Color(0xFF7A3A52) : const Color(0xFFFFD9E3),
        onPrimaryContainer: dark ? const Color(0xFFFFD9E3) : const Color(0xFF3F0019),
        secondary: dark ? const Color(0xFFB8E0C8) : const Color(0xFF5E9C7A),
        secondaryContainer: dark ? const Color(0xFF3E5A4A) : const Color(0xFFD8F3E3),
        onSecondaryContainer: dark ? const Color(0xFFD8F3E3) : const Color(0xFF0E3522),
        tertiary: dark ? const Color(0xFFCDBDF7) : const Color(0xFF8B6FD0),
        tertiaryContainer: dark ? const Color(0xFF4D3D78) : const Color(0xFFEDE4FF),
      );
    case AppThemeStyle.tough:
      final base = ColorScheme.fromSeed(
        seedColor: style.seed,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
        contrastLevel: 1.0,
      );
      scheme = dark
          ? base.copyWith(
              // 거의 검정 바탕에 짙은 회색 단계, 포인트는 선명한 빨강.
              surface: const Color(0xFF0E0E0F),
              surfaceContainerLowest: const Color(0xFF070708),
              surfaceContainerLow: const Color(0xFF161618),
              surfaceContainer: const Color(0xFF1C1C1F),
              surfaceContainerHigh: const Color(0xFF242428),
              surfaceContainerHighest: const Color(0xFF2E2E33),
              onSurface: const Color(0xFFF2F2F2),
              onSurfaceVariant: const Color(0xFFB8B8BD),
              outline: const Color(0xFF6F6F76),
              outlineVariant: const Color(0xFF3A3A40),
              primary: const Color(0xFFFF4D4D),
              onPrimary: Colors.black,
              primaryContainer: const Color(0xFF8E1B1B),
              onPrimaryContainer: const Color(0xFFFFDAD6),
              secondary: const Color(0xFFE0E0E0),
              secondaryContainer: const Color(0xFF3A3A40),
              onSecondaryContainer: const Color(0xFFF2F2F2),
              tertiary: const Color(0xFFFFB300),
              tertiaryContainer: const Color(0xFF5A3D00),
              onTertiaryContainer: const Color(0xFFFFE0A3),
            )
          : base.copyWith(
              // 라이트도 강한 대비: 차가운 회백색 바탕 + 검정 글자 + 빨강 포인트.
              surface: const Color(0xFFF4F4F5),
              surfaceContainerLowest: Colors.white,
              surfaceContainerLow: const Color(0xFFEAEAEC),
              surfaceContainer: const Color(0xFFE0E0E3),
              surfaceContainerHigh: const Color(0xFFD4D4D8),
              surfaceContainerHighest: const Color(0xFFC8C8CD),
              onSurface: const Color(0xFF111113),
              onSurfaceVariant: const Color(0xFF3F3F46),
              outline: const Color(0xFF5A5A62),
              outlineVariant: const Color(0xFFA1A1AA),
              primary: const Color(0xFFC62828),
              onPrimary: Colors.white,
              primaryContainer: const Color(0xFFFFCDD2),
              onPrimaryContainer: const Color(0xFF410002),
              secondary: const Color(0xFF1F1F23),
              secondaryContainer: const Color(0xFFD4D4D8),
              onSecondaryContainer: const Color(0xFF111113),
              tertiary: const Color(0xFFB36B00),
              tertiaryContainer: const Color(0xFFFFE0A3),
              onTertiaryContainer: const Color(0xFF2B1A00),
            );
  }

  final theme = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(style == AppThemeStyle.cute ? 18 : r)),
    ),
    cardTheme: CardThemeData(elevation: 0, color: scheme.surfaceContainerLow, shape: shape),
  );

  switch (style) {
    case AppThemeStyle.basic:
      return theme;

    case AppThemeStyle.cute:
      // 글자는 조금 통통하게(굵기 한 단계 위), 자간을 살짝 넓혀 부드럽게.
      final t = theme.textTheme;
      TextStyle? soft(TextStyle? s, {double spacing = 0.2}) =>
          s?.copyWith(letterSpacing: spacing, fontWeight: FontWeight.w600, height: 1.25);
      final textTheme = t.copyWith(
        displayLarge: soft(t.displayLarge),
        displayMedium: soft(t.displayMedium),
        displaySmall: soft(t.displaySmall),
        headlineLarge: soft(t.headlineLarge),
        headlineMedium: soft(t.headlineMedium),
        headlineSmall: soft(t.headlineSmall),
        titleLarge: soft(t.titleLarge, spacing: 0.3),
        titleMedium: soft(t.titleMedium, spacing: 0.3),
        titleSmall: soft(t.titleSmall, spacing: 0.3),
        labelLarge: soft(t.labelLarge, spacing: 0.4),
      );
      const stadium = StadiumBorder();
      return theme.copyWith(
        textTheme: textTheme,
        scaffoldBackgroundColor: scheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          centerTitle: true,
          titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.primary),
        ),
        chipTheme: theme.chipTheme.copyWith(shape: stadium, side: BorderSide(color: scheme.outlineVariant)),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: stadium)),
        elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(shape: stadium)),
        outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(shape: stadium)),
        textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: stadium)),
        segmentedButtonTheme: SegmentedButtonThemeData(style: SegmentedButton.styleFrom(shape: stadium)),
        floatingActionButtonTheme: FloatingActionButtonThemeData(shape: stadium, backgroundColor: scheme.primaryContainer),
        dialogTheme: DialogThemeData(shape: shape),
        bottomSheetTheme: BottomSheetThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(r))),
        ),
        snackBarTheme: SnackBarThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r)),
          behavior: SnackBarBehavior.floating,
        ),
        navigationBarTheme: NavigationBarThemeData(
          indicatorShape: stadium,
          backgroundColor: scheme.surfaceContainerLow,
          labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
        ),
        listTileTheme: ListTileThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
        popupMenuTheme: PopupMenuThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
        sliderTheme: theme.sliderTheme.copyWith(trackHeight: 8),
        dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      );

    case AppThemeStyle.tough:
      // 숫자·제목은 아주 굵게, 자간은 좁게. 모서리는 거의 직각.
      final t = theme.textTheme;
      const tabular = [FontFeature.tabularFigures()];
      TextStyle? heavy(TextStyle? s, {double spacing = -0.5}) =>
          s?.copyWith(fontWeight: FontWeight.w900, letterSpacing: spacing, fontFeatures: tabular);
      TextStyle? bold(TextStyle? s) => s?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2);
      final textTheme = t.copyWith(
        displayLarge: heavy(t.displayLarge, spacing: -1.5),
        displayMedium: heavy(t.displayMedium, spacing: -1),
        displaySmall: heavy(t.displaySmall, spacing: -1),
        headlineLarge: heavy(t.headlineLarge, spacing: -1),
        headlineMedium: heavy(t.headlineMedium),
        headlineSmall: heavy(t.headlineSmall),
        titleLarge: heavy(t.titleLarge),
        titleMedium: bold(t.titleMedium),
        titleSmall: bold(t.titleSmall),
        labelLarge: bold(t.labelLarge)?.copyWith(letterSpacing: 0.6),
        bodyLarge: t.bodyLarge?.copyWith(fontFeatures: tabular),
        bodyMedium: t.bodyMedium?.copyWith(fontFeatures: tabular),
      );
      final sharp = RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));
      return theme.copyWith(
        textTheme: textTheme,
        scaffoldBackgroundColor: scheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
        ),
        cardTheme: theme.cardTheme.copyWith(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r), side: BorderSide(color: scheme.outlineVariant)),
        ),
        chipTheme: theme.chipTheme.copyWith(shape: sharp, side: BorderSide(color: scheme.outline)),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: sharp, textStyle: textTheme.labelLarge)),
        elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(shape: sharp, textStyle: textTheme.labelLarge)),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(shape: sharp, side: BorderSide(color: scheme.outline, width: 1.5), textStyle: textTheme.labelLarge),
        ),
        textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: sharp, textStyle: textTheme.labelLarge)),
        segmentedButtonTheme: SegmentedButtonThemeData(style: SegmentedButton.styleFrom(shape: sharp, side: BorderSide(color: scheme.outline))),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          shape: sharp,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
        ),
        dialogTheme: DialogThemeData(shape: sharp),
        bottomSheetTheme: BottomSheetThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(r))),
        ),
        snackBarTheme: SnackBarThemeData(shape: sharp),
        navigationBarTheme: NavigationBarThemeData(
          indicatorShape: sharp,
          backgroundColor: scheme.surfaceContainerLow,
          indicatorColor: scheme.primary,
          iconTheme: WidgetStateProperty.resolveWith(
            (s) => IconThemeData(color: s.contains(WidgetState.selected) ? scheme.onPrimary : scheme.onSurfaceVariant),
          ),
          labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
        ),
        listTileTheme: ListTileThemeData(shape: sharp),
        popupMenuTheme: PopupMenuThemeData(shape: sharp),
        progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary, linearTrackColor: scheme.surfaceContainerHighest),
        sliderTheme: theme.sliderTheme.copyWith(trackHeight: 6),
        dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
      );
  }
}
