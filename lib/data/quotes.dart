/// 오늘의 한마디. 날짜로 고정 선택해서 하루 동안 같은 문구가 보인다.
/// 문구 묶음은 테마(기본·귀여운·상남자·해병대)마다 다르다 → [AppThemeStyle.quotes].
library;

import '../ui/app_theme.dart';

String quoteFor(DateTime d, [AppThemeStyle style = AppThemeStyle.basic]) => style.quoteFor(d);
