import 'package:fit_routine/models/models.dart';
import 'package:fit_routine/services/workout_photo.dart';
import 'package:fit_routine/services/workout_text_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 27);

  test('애플 워치 피트니스 요약 화면(한국어, 두 칸 배치)', () {
    const text = '''
11:43  5G 84
16°  습도 73%  대기질 49
운동 세부사항 >
운동 시간  거리
1:11:42  10.20KM
활동 킬로칼로리  총 킬로칼로리
855KCAL  989KCAL
등반 고도  평균 파워
29M  214W
평균 케이던스  평균 페이스
162SPM  7'02''/KM
평균 심박수
167BPM
운동 강도 ±
8 어려움
스플릿 >
시간  페이스  심박수
1  08:17  8'17"/KM  131BPM
2  07:55  7'55"/KM  148BPM
3  08:34  8'34"/KM  152BPM
4  06:39  6'39"/KM  175BPM
5  06:50  6'50"/KM  179BPM
구간 >
거리  시간  페이스
1  7.21KM  53:41  7'26"/KM
2  1.21KM  07:42  6'22"/KM
3  1.77KM  10:20  5'49"/KM
''';
    final r = WorkoutTextParser.parse(text, today: today);
    final s = r.stats;
    expect(s.durationSec, 4302);
    expect(s.distanceKm, closeTo(10.20, 0.001));
    expect(s.activeKcal, 855);
    expect(s.totalKcal, 989);
    expect(s.elevationM, 29);
    expect(s.powerW, 214);
    expect(s.cadence, 162);
    expect(s.paceSec, 422);
    expect(s.avgHr, 167);
    expect(s.maxHr, isNull);
    expect(s.effort, 8);
    expect(s.splits.length, 5);
    expect(s.splits.first.sec, 8 * 60 + 17);
    expect(s.splits.first.paceSec, 8 * 60 + 17);
    expect(s.splits.first.hr, 131);
    expect(s.splits.last.hr, 179);
    expect(r.minutes, 72);
    expect(r.usable, isTrue);
    expect(cardioStatChips(s), containsAll(['10.20km', '1:11:42', "7'02\"/km", '평균 167bpm', '989kcal (활동 855)']));
  });

  test('실외 달리기 상세(지면 접촉·보폭) + 날짜', () {
    const text = '''
11:54
운동 세부사항
1:11:42  실외 달리기  10.20KM
10월 25일
15분  전체
지면 접촉 시간
평균: 278MS  200~350MS
보폭 길이
평균: 0.8M  0.7~1.2M
''';
    final r = WorkoutTextParser.parse(text, today: today);
    expect(r.exerciseId, 'outdoor_run');
    expect(r.title, contains('실외 달리기'));
    expect(r.date, DateTime(2026, 10, 25));
    expect(r.stats.contactMs, 278);
    expect(r.stats.strideM, closeTo(0.8, 0.001));
    expect(r.stats.durationSec, 4302);
    expect(r.stats.distanceKm, closeTo(10.2, 0.001));
    expect(r.stats.elevationM, isNull);
    // 페이스가 안 보이면 거리·시간으로 계산
    expect(r.stats.effectivePace, (4302 / 10.2).round());
  });

  test('삼성 헬스식 영어 화면, mi 단위, 최대 심박', () {
    const text = '''
Running  Oct 25, 2026
Duration 50:12
Distance 5.00 mi
Avg pace 10'02"/mi
Avg HR 150 bpm   Max HR 181 bpm
Calories 520 kcal
''';
    final r = WorkoutTextParser.parse(text, today: today);
    expect(r.stats.durationSec, 50 * 60 + 12);
    expect(r.stats.distanceKm, closeTo(8.045, 0.01));
    expect(r.stats.avgHr, 150);
    expect(r.stats.maxHr, 181);
    expect(r.stats.totalKcal, 520);
    expect(r.stats.activeKcal, isNull);
    expect(r.exerciseId, 'outdoor_run');
  });

  test('OCR 오인식(O→0, I→1)과 상태바 시계를 운동 시간으로 집지 않음', () {
    const text = '''
I2:3O
실내 달리기
운동 시간
3O:O5
거리 5.1OKM
''';
    final r = WorkoutTextParser.parse(text, today: today);
    expect(r.stats.durationSec, 30 * 60 + 5);
    expect(r.stats.distanceKm, closeTo(5.1, 0.001));
    expect(r.exerciseId, 'treadmill_run');
  });

  test('라벨 없이 mm:ss만 있을 때 상태바(첫 줄)는 빼고 최대값', () {
    final r = WorkoutTextParser.parse('11:54\n축구\n48:30\n1 05:00 140BPM', today: today);
    expect(r.stats.durationSec, 48 * 60 + 30);
    expect(r.exerciseId, 'soccer');
  });

  test('시간·거리 둘 다 없으면 쓸 수 없는 기록', () {
    final r = WorkoutTextParser.parse('평균 심박수 150BPM', today: today);
    expect(r.usable, isFalse);
    expect(r.stats.avgHr, 150);
  });

  test('CardioStats JSON 왕복 + PlannedExercise에 실림', () {
    final r = WorkoutTextParser.parse('운동 시간 25:00\n거리 4.0KM\n1 05:00 5\'00"/KM 140BPM', today: today);
    final back = CardioStats.fromJson(r.stats.toJson());
    expect(back.durationSec, 1500);
    expect(back.distanceKm, 4.0);
    expect(back.splits.single.hr, 140);
    expect(back.source, '사진 인식');

    final pe = PlannedExercise(
      exerciseId: 'outdoor_run',
      equipmentType: EquipmentType.bodyweight,
      restSeconds: 0,
      sets: [SetEntry(targetReps: 25, targetWeight: 0, doneReps: 25, completed: true)],
      cardio: r.stats,
    );
    final pe2 = PlannedExercise.fromJson(pe.toJson());
    expect(pe2.cardio?.distanceKm, 4.0);
    expect(PlannedExercise.fromJson(PlannedExercise(exerciseId: 'x', equipmentType: EquipmentType.bodyweight, restSeconds: 0, sets: []).toJson()).cardio, isNull);
  });

  test('AI 응답 파서: 범위 밖 값은 버림', () {
    final r = WorkoutPhotoReader.parseAi({
      'exercise': 'outdoor_run',
      'durationSec': 4302,
      'distanceKm': 10.2,
      'avgHr': 300,
      'strideM': 80,
      'date': '2026-10-25',
      'splits': [
        {'sec': 497, 'hr': 131},
        {'hr': 999},
      ],
    });
    expect(r.stats.avgHr, isNull);
    expect(r.stats.strideM, closeTo(0.8, 0.001));
    expect(r.date, DateTime(2026, 10, 25));
    expect(r.stats.splits.length, 1);
    expect(r.method, 'AI 인식');
  });
}
