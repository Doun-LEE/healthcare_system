import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_routine/ui/app_theme.dart';
import 'package:fit_routine/ui/widgets/mascot.dart';

void main() {
  testWidgets('마스코트 뭉치: 다섯 표정이 모두 예외 없이 그려진다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(children: [
          for (final m in MascotMood.values) Mascot(mood: m, size: 60, bob: false),
        ]),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(Mascot), findsNWidgets(MascotMood.values.length));
  });

  testWidgets('말풍선: 긴 문구도 넘침 없이 줄바꿈된다', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          child: MascotSays(text: '오늘도 왔구나! 그것만으로 반은 했어. 한 세트만 더 하면 뭉치가 춤출게. 물 한 모금 마시고 가자.'),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('테마 네 가지가 라이트·다크 ThemeData를 만들고 말투가 다르다', () {
    for (final s in AppThemeStyle.values) {
      for (final b in Brightness.values) {
        final t = buildAppTheme(s, b);
        expect(t.colorScheme.brightness, b);
      }
      expect(s.quotes, isNotEmpty);
      expect(s.quoteFor(DateTime(2026, 10, 27)), s.quoteFor(DateTime(2026, 10, 27, 23)));
      expect(s.greeting(8, '도운'), contains('도운'));
      expect(s.finishButton(100), contains('100%'));
      expect(s.finishedLine(90), contains('90%'));
    }
    expect(AppThemeStyle.marine.greeting(8, '도운'), startsWith('악!'));
    expect(AppThemeStyle.marine.quotes.every((q) => q.startsWith('악!')), isTrue);
    expect(AppThemeStyle.parse('marine'), AppThemeStyle.marine);
    expect(AppThemeStyle.parse('없는값'), AppThemeStyle.basic);
    // 말투가 테마마다 다르다
    expect({for (final s in AppThemeStyle.values) s.finishedLine(100)}.length, AppThemeStyle.values.length);
  });
}
