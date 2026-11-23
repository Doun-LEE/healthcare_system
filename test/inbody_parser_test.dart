import 'package:fit_routine/services/inbody_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('인바디 결과지 글자에서 체중·골격근량·체지방률·날짜', () {
    const t = '''InBody
검사일시 2026.11.20 18:32
체성분분석
체수분 (L)  48.6  41.2~50.4
단백질 (kg)  13.2  11.0~13.5
체지방량 (kg)  17.1  9.6~15.4
체중 (kg)  87.0  59.3~80.3
골격근·지방분석
70 85 100 115 130 145 160 175 190 205 %
체중  87.0
골격근량  41.2
체지방량  17.1
비만분석
BMI  27.1
체지방률  19.6  10.0~20.0
적정체중  74.5
체중조절  -12.5''';
    final r = parseInbody(t);
    expect(r.weightKg, 87.0);
    expect(r.skeletalMuscleKg, 41.2);
    expect(r.bodyFatPct, 19.6);
    expect(r.date, DateTime(2026, 11, 20));
  });

  test('체지방률이 없으면 체지방량÷체중으로', () {
    final r = parseInbody('Weight 80.0\nSkeletal Muscle Mass 36.5\nBody Fat Mass 16.0');
    expect(r.weightKg, 80.0);
    expect(r.skeletalMuscleKg, 36.5);
    expect(r.bodyFatPct, 20.0);
  });

  test('값이 다음 줄에 있어도', () {
    final r = parseInbody('골격근량\n38.4\n체중\n75.2');
    expect(r.skeletalMuscleKg, 38.4);
    expect(r.weightKg, 75.2);
  });
}
