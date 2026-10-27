import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('앱 디자인은 프로필 JSON에 저장되고, 없거나 모르는 값이면 기본', () {
    final u = UserProfile(id: 'a', name: '도운', theme: 'cute');
    final back = UserProfile.fromJson(u.toJson());
    expect(back.theme, 'cute');
    expect(AppThemeStyle.parse(back.theme), AppThemeStyle.cute);

    final old = UserProfile(id: 'b', name: '옛날').toJson()..remove('theme');
    expect(UserProfile.fromJson(old).theme, 'basic');
    expect(AppThemeStyle.parse('???'), AppThemeStyle.basic);
    expect(AppThemeStyle.parse(null), AppThemeStyle.basic);
  });

  test('세 디자인 모두 라이트/다크 ThemeData 를 만든다', () {
    for (final s in AppThemeStyle.values) {
      for (final b in Brightness.values) {
        final t = buildAppTheme(s, b);
        expect(t.brightness, b);
        expect(t.useMaterial3, isTrue);
      }
    }
    expect(buildAppTheme(AppThemeStyle.tough, Brightness.dark).textTheme.titleLarge?.fontWeight, FontWeight.w900);
    expect((buildAppTheme(AppThemeStyle.cute, Brightness.light).cardTheme.shape as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(28));
  });
}
