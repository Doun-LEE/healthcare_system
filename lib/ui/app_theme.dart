import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

/// 사용자가 고르는 앱 디자인. 프로필의 `theme` 문자열(id)로 저장된다.
/// 색·모양뿐 아니라 말투(인사·완료 문구·명언)도 테마가 정한다.
enum AppThemeStyle {
  basic('basic', '기본', '지금 모습 그대로. 차분한 초록.', Icons.circle_outlined),
  cute('cute', '귀여운', '파스텔 핑크 · 동글동글 · 마스코트 뭉치 🐣', Icons.favorite_border),
  tough('tough', '상남자', '쇳내·땀내 나는 체육관 · 검정과 불꽃 주황 · 굵은 숫자', Icons.fitness_center),
  marine('marine', '해병대', '빨강·노랑 · 각진 · 악! 기합 가득 · 오도된 말투', Icons.military_tech);

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
        AppThemeStyle.tough => const Color(0xFFFF5722),
        AppThemeStyle.marine => const Color(0xFFD7263D),
      };

  /// 모서리 반지름. 카드·입력창·버튼이 모두 이 값을 따른다.
  double get radius => switch (this) {
        AppThemeStyle.basic => 16,
        AppThemeStyle.cute => 28,
        AppThemeStyle.tough => 4,
        AppThemeStyle.marine => 2,
      };

  // ───────── 말투 ─────────

  /// 홈 인사. [hour]는 0~23.
  String greeting(int hour, String name) {
    final slot = hour < 5 ? 0 : hour < 11 ? 1 : hour < 17 ? 2 : 3;
    switch (this) {
      case AppThemeStyle.basic:
        return '${const ['늦은 밤이에요', '좋은 아침이에요', '좋은 오후예요', '좋은 저녁이에요'][slot]}, $name님';
      case AppThemeStyle.cute:
        return '${const ['늦은 밤이에요 🌙', '좋은 아침이에요 ☀️', '좋은 오후예요 🍀', '좋은 저녁이에요 ✨'][slot]}, $name님';
      case AppThemeStyle.tough:
        return '${const ['이 시간에 깨어 있나', '일어났으면 들어라', '오후다, 쇠 만질 시간', '저녁이다, 핑계 없다'][slot]}, $name';
      case AppThemeStyle.marine:
        return '악!! ${const ['심야 점호다 아쎄이', '기상!! 아쎄이 기상이다', '오후 훈련이다 아쎄이', '야간 훈련이다 아쎄이'][slot]}, $name 해병! 우라!';
    }
  }

  /// 운동 완료 버튼.
  String finishButton(int percent) => switch (this) {
        AppThemeStyle.basic => '운동 완료 ($percent%)',
        AppThemeStyle.cute => '오늘도 해냈어요 🎉 ($percent%)',
        AppThemeStyle.tough => '끝장냈다 ($percent%)',
        AppThemeStyle.marine => '악!! 임무 완수 보고 ($percent%) 우라!',
      };

  /// 완료된 날의 머리 문구.
  String finishedLine(int percent) => switch (this) {
        AppThemeStyle.basic => '완료됨 · $percent% 수행',
        AppThemeStyle.cute => '완료! $percent% 해냈어요 🎀',
        AppThemeStyle.tough => '박살 · $percent% 수행',
        AppThemeStyle.marine => '악!! 임무 완수! 빨간 명찰 값 한 것이다 · $percent% 우라!',
      };

  /// 테마별 오늘의 한마디 묶음. 날짜로 하나를 고른다.
  List<String> get quotes => switch (this) {
        AppThemeStyle.basic => _basicQuotes,
        AppThemeStyle.cute => _cuteQuotes,
        AppThemeStyle.tough => _toughQuotes,
        AppThemeStyle.marine => _marineQuotes,
      };

  String quoteFor(DateTime d) {
    final q = quotes;
    return q[(d.year * 366 + d.month * 31 + d.day) % q.length];
  }
}

/// 지금 적용 중인 테마(프로필의 theme). 위젯에서 말투·마스코트를 고를 때 쓴다.
AppThemeStyle themeStyleOf(BuildContext context) =>
    AppThemeStyle.parse(context.select<AppState, String?>((s) => s.currentUser?.theme));

const _basicQuotes = [
  '오늘 안 하면 내일은 두 배로 힘들다.',
  '근육은 거짓말을 하지 않는다. 한 만큼 돌아온다.',
  '가장 무거운 무게는 헬스장 문이다. 이미 들어왔으면 반은 끝났다.',
  '어제의 나보다 2.5kg만 더. 그게 쌓이면 다른 사람이 된다.',
  '동기부여는 시작하게 하고, 습관은 계속하게 한다.',
  '쉬는 것도 훈련이다. 단, 계획된 휴식만.',
  '마지막 두 개 반복이 몸을 바꾼다.',
  '헬스장에서 흘린 땀은 절대 배신하지 않는다.',
  '폼이 무너지면 세트를 끝내라. 자존심은 무게보다 싸다.',
  '하루 2시간이 아니라, 매주 꾸준한 3일이 몸을 만든다.',
  '오늘의 핑계는 내일의 후회다.',
  '가벼운 날도 있다. 그래도 온 사람이 이긴다.',
  '강해지는 데 지름길은 없다. 하지만 멈추지 않는 길은 있다.',
  '세트 사이 휴식은 쉬는 시간이 아니라 다음 세트 준비 시간이다.',
  '몸은 당신이 먹고, 자고, 든 것의 합이다.',
  '첫 세트는 몸을 깨우고, 마지막 세트는 몸을 바꾼다.',
  '비교할 대상은 옆 사람이 아니라 지난주의 나다.',
  '못 든 날은 실패가 아니라 데이터다. 다음엔 조정하면 된다.',
  '운동은 의지로 시작하고 루틴으로 완성된다.',
  '통증은 피하고, 불편함은 견뎌라. 그 차이를 아는 게 경험이다.',
  '오늘 1%만 더. 1년이면 37배다.',
  '하체 하는 날을 빼먹는 사람은 반쪽짜리 몸을 얻는다.',
  '물 마셔라. 단백질 먹어라. 자라. 그리고 들어라.',
  '기록하지 않은 운동은 기억되지 않는다.',
  '벤치 숫자는 내려갈 수 있어도, 다시 오는 사람은 결국 올라간다.',
  '지금 들기 싫은 그 세트가 제일 효과 좋은 세트다.',
  '좋은 날엔 PR을, 나쁜 날엔 출석을.',
  '루틴을 믿어라. 기분은 매일 바뀌지만 계획은 안 바뀐다.',
  '파트너가 있으면 마지막 한 개가 두 개가 된다.',
  '근성장은 헬스장에서 시작해서 침대에서 끝난다.',
  '어깨 넓이는 레터럴 레이즈 횟수에 비례한다.',
];

const _cuteQuotes = [
  '오늘도 왔구나! 그것만으로 반은 했어 🐣',
  '한 세트만 더 하면 뭉치가 춤출게 💃',
  '무거우면 가볍게, 대신 꾸준히! 🌱',
  '물 한 모금 마시고 가자 💧',
  '어제보다 조금만 더. 조금이면 충분해 🍀',
  '힘든 세트 뒤엔 꼭 칭찬해 주기 🎀',
  '폼이 예쁜 게 제일 멋있어 ✨',
  '쉬는 날도 열심히 쉬는 거야 😴',
  '오늘 흘린 땀은 내일의 반짝임 🌟',
  '못 들어도 괜찮아, 다음에 들면 되지 🐾',
  '하체 날도 사랑해 주기 🍑',
  '단백질 챙겼어? 뭉치는 챙겼어 🍗',
  '기록 남기면 나중에 뿌듯함 두 배 📒',
  '친구랑 같이 하면 마지막 한 개가 두 개 👯',
  '오늘의 나, 참 잘했어요 도장 쾅 🏅',
];

const _toughQuotes = [
  '쇠는 핑계를 안 듣는다.',
  '땀이 안 나면 운동이 아니라 산책이다.',
  '마지막 한 개가 진짜 첫 번째다.',
  '무게가 무서우면 네가 가벼운 거다.',
  '오늘 안 들면 어제 든 게 사라진다.',
  '하체 빼먹는 놈은 상체도 못 키운다.',
  '아프면 쉬고, 힘들면 든다. 구분해라.',
  '세트 중간에 폰 보지 마라. 쇠가 식는다.',
  '랙에 걸린 바벨은 널 기다리지 않는다.',
  '근육은 울면서 자란다. 네가 울 차례다.',
  '기록 안 하면 그 세트는 없던 거다.',
  '출석이 재능을 이긴다. 매번.',
  '숨이 턱까지 차야 세트 하나다.',
  '무게 내리는 건 패배가 아니다. 안 오는 게 패배다.',
  '한 번 더. 그 한 번이 다음 달 너다.',
];

const _marineQuotes = [
  '악!! 아쎄이, 바벨 앞에서 뭐 하는 것이냐! 해병은 물러서지 않는 것이다!',
  '악! 기열!! 안 되면 될 때까지, 한 세트 더 하는 것이다!',
  '악! 땀은 피를 아끼고 세트는 핑계를 지운다! 우라!',
  '악! 하체 훈련 미실시 아쎄이는 빨간 명찰 반납하는 것이다!',
  '악! 기합 넣고 랙에 올라간다, 실시!! 우라!!',
  '악! 오늘 임무는 오늘 완수! 내일 임무는 내일 완수! 그것이 해병인 것이다!',
  '악! 휴식도 훈련이다. 단, 계획된 휴식만! 침대에서 핑계 대는 아쎄이는 기열!',
  '악! 귀신 잡는 해병, 오늘은 PR 잡는 것이다!',
  '악! 한 번 해병은 영원한 헬창! 전역은 있어도 탈퇴는 없다!',
  '악! 무게 앞에서 떨지 않는다! 떠는 건 오직 근육뿐인 것이다!',
  '악! 물 마시고 단백질 보급, 실시! 보급 미실시 아쎄이는 근손실로 처벌한다!',
  '악! 기록 미작성 운동은 운동으로 인정 안 한다! 군번줄 걸고 적는 것이다!',
  '악! 파트너는 전우다! 마지막 한 개는 같이 드는 것이다! 우라!',
  '악! 폼 무너지면 즉시 세트 종료! 부상은 적이고 적은 섬멸하는 것이다!',
  '악! 오늘도 출석 완료! 해병 정신 이상 무! 근육 이상 무!',
  '악!! 이 아쎄이, 그 무게로 되겠나?! 원판 한 장 더 꽂는 것이다!',
  '악! 기수 열외 없다! 선임도 후임도 오늘은 하체인 것이다!',
  '악! 빨간 명찰 달았으면 랙 앞에서 도망 안 간다! 도망은 기열!',
  '악! 팔각모 눌러쓰고 벤치로 돌격, 실시!! 우라!!',
  '악! 쉬는 시간 끝! 아쎄이, 랙으로 복귀하는 것이다!',
  '악! 땀으로 샤워, 단백질로 보급, 침대로 복귀! 그것이 해병의 하루인 것이다!',
  '악!! 어깨가 좁다고? 레터럴 레이즈 100개면 팔각모가 작아지는 것이다!',
  '악! 벤치 숫자 떨어졌다고 울지 마라! 해병은 다시 와서 올리는 것이다! 기열!',
  '악! 오늘 1%만 더! 1년이면 37배! 해병 산수는 틀리지 않는 것이다!',
  '악! 이 아쎄이, 폰 보지 마라! 세트 사이에 쇠가 식는 것이다!',
  '악! 유산소도 훈련이다! 천국의 계단은 해병에게 그냥 계단인 것이다! 우라!',
  '악! 스트레칭은 정찰이다! 정찰 없이 돌격하는 아쎄이는 부상당하는 것이다!',
  '악!! 선임 해병 무게 보고 쫄았나?! 다음 달 네 무게인 것이다!',
];


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
              // 쇳덩이 체육관: 거의 검정에 녹슨 철 느낌의 따뜻한 회색, 포인트는 불꽃 주황.
              surface: const Color(0xFF0F0D0C),
              surfaceContainerLowest: const Color(0xFF080706),
              surfaceContainerLow: const Color(0xFF181412),
              surfaceContainer: const Color(0xFF1F1A17),
              surfaceContainerHigh: const Color(0xFF28211D),
              surfaceContainerHighest: const Color(0xFF342A25),
              onSurface: const Color(0xFFF3EEE9),
              onSurfaceVariant: const Color(0xFFBFB3A9),
              outline: const Color(0xFF7A6B60),
              outlineVariant: const Color(0xFF3F352F),
              primary: const Color(0xFFFF6A2B),
              onPrimary: Colors.black,
              primaryContainer: const Color(0xFF7A2A0C),
              onPrimaryContainer: const Color(0xFFFFDBCB),
              secondary: const Color(0xFFE5DED6),
              secondaryContainer: const Color(0xFF3F352F),
              onSecondaryContainer: const Color(0xFFF3EEE9),
              tertiary: const Color(0xFFFFC107),
              tertiaryContainer: const Color(0xFF5A4300),
              onTertiaryContainer: const Color(0xFFFFE6A3),
            )
          : base.copyWith(
              // 라이트: 분필 가루 묻은 콘크리트 회색 + 검정 글자 + 녹슨 주황 포인트.
              surface: const Color(0xFFF2EFEB),
              surfaceContainerLowest: Colors.white,
              surfaceContainerLow: const Color(0xFFE8E3DD),
              surfaceContainer: const Color(0xFFDDD6CF),
              surfaceContainerHigh: const Color(0xFFD0C8C0),
              surfaceContainerHighest: const Color(0xFFC3BAB1),
              onSurface: const Color(0xFF141110),
              onSurfaceVariant: const Color(0xFF473F3A),
              outline: const Color(0xFF5F554E),
              outlineVariant: const Color(0xFFA39A92),
              primary: const Color(0xFFD1400F),
              onPrimary: Colors.white,
              primaryContainer: const Color(0xFFFFD2C0),
              onPrimaryContainer: const Color(0xFF3B0E00),
              secondary: const Color(0xFF221D1A),
              secondaryContainer: const Color(0xFFD0C8C0),
              onSecondaryContainer: const Color(0xFF141110),
              tertiary: const Color(0xFF9A6A00),
              tertiaryContainer: const Color(0xFFFFE6A3),
              onTertiaryContainer: const Color(0xFF2B1F00),
            );
    case AppThemeStyle.marine:
      final base = ColorScheme.fromSeed(
        seedColor: style.seed,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
        contrastLevel: 0.5,
      );
      scheme = dark
          ? base.copyWith(
              // 야간: 짙은 남색 바탕, 빨간 명찰 색 포인트, 노란(금색) 보조.
              surface: const Color(0xFF0B1020),
              surfaceContainerLowest: const Color(0xFF060A16),
              surfaceContainerLow: const Color(0xFF121A30),
              surfaceContainer: const Color(0xFF182139),
              surfaceContainerHigh: const Color(0xFF1F2A46),
              surfaceContainerHighest: const Color(0xFF283555),
              onSurface: const Color(0xFFF4F1E8),
              onSurfaceVariant: const Color(0xFFC2BFB4),
              outline: const Color(0xFF7A7F8F),
              outlineVariant: const Color(0xFF3A4360),
              primary: const Color(0xFFFF5A6B),
              onPrimary: const Color(0xFF3A0008),
              primaryContainer: const Color(0xFF8E1024),
              onPrimaryContainer: const Color(0xFFFFDADB),
              secondary: const Color(0xFFFFD24D),
              onSecondary: const Color(0xFF3A2A00),
              secondaryContainer: const Color(0xFF5C4300),
              onSecondaryContainer: const Color(0xFFFFE8A3),
              tertiary: const Color(0xFFFFD24D),
              tertiaryContainer: const Color(0xFF5C4300),
              onTertiaryContainer: const Color(0xFFFFE8A3),
            )
          : base.copyWith(
              // 주간: 모래빛 바탕, 빨강 포인트, 노랑 보조.
              surface: const Color(0xFFF7F3EA),
              surfaceContainerLowest: Colors.white,
              surfaceContainerLow: const Color(0xFFEFE9DB),
              surfaceContainer: const Color(0xFFE6DFCD),
              surfaceContainerHigh: const Color(0xFFDCD4BF),
              surfaceContainerHighest: const Color(0xFFD1C8B1),
              onSurface: const Color(0xFF15161C),
              onSurfaceVariant: const Color(0xFF434552),
              outline: const Color(0xFF5E6170),
              outlineVariant: const Color(0xFFA6A9B6),
              primary: const Color(0xFFC8102E),
              onPrimary: Colors.white,
              primaryContainer: const Color(0xFFFFD4D8),
              onPrimaryContainer: const Color(0xFF40000A),
              secondary: const Color(0xFF8A6400),
              onSecondary: Colors.white,
              secondaryContainer: const Color(0xFFFFE28A),
              onSecondaryContainer: const Color(0xFF2E2100),
              tertiary: const Color(0xFF1E2A4A),
              tertiaryContainer: const Color(0xFFD6DEF5),
              onTertiaryContainer: const Color(0xFF0B1020),
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
    case AppThemeStyle.marine:
      // 숫자·제목은 아주 굵게, 자간은 좁게. 모서리는 거의 직각.
      final marine = style == AppThemeStyle.marine;
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
          backgroundColor: marine ? scheme.primary : scheme.surface,
          foregroundColor: marine ? scheme.onPrimary : scheme.onSurface,
          titleTextStyle: textTheme.titleLarge?.copyWith(color: marine ? scheme.onPrimary : scheme.onSurface),
        ),
        cardTheme: theme.cardTheme.copyWith(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r),
            // 해병대: 카드 왼쪽에 빨간 명찰 줄. 상남자: 쇠 테두리.
            side: marine ? BorderSide.none : BorderSide(color: scheme.outlineVariant),
          ),
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
          indicatorColor: marine ? scheme.secondary : scheme.primary,
          iconTheme: WidgetStateProperty.resolveWith(
            (s) => IconThemeData(color: s.contains(WidgetState.selected) ? (marine ? scheme.onSecondary : scheme.onPrimary) : scheme.onSurfaceVariant),
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
