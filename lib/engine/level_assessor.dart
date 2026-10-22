/// 신체 스펙 + 3대 기록으로 레벨을 입체적으로 판정한다.
///
/// 리프트는 체중 대비 배수(상대 근력)로, 체성분은 골격근 비율·체지방률로 5단계 등급을 매기고
/// 0~100 점수로 환산해 종합 레벨([TrainingLevel])을 정한다. 나이·성별로 기준을 보정한다.
library;

import 'dart:math';

import '../models/models.dart';

/// 5단계 등급.
enum Grade {
  novice('입문'),
  beginner('초급'),
  intermediate('중급'),
  advanced('고급'),
  elite('엘리트');

  const Grade(this.label);
  final String label;
}

class LevelItem {
  const LevelItem({required this.name, required this.grade, required this.score, required this.detail, this.missing = false});
  final String name;
  final Grade grade;

  /// 0~100.
  final double score;
  final String detail;

  /// 입력이 없어 판정 불가.
  final bool missing;
}

class LevelAssessment {
  const LevelAssessment({required this.score, required this.grade, required this.level, required this.items, required this.summary, required this.intensity});

  /// 종합 점수 0~100. 입력이 하나도 없으면 null.
  final double? score;
  final Grade? grade;

  /// 엔진이 쓰는 3단계 숙련도.
  final TrainingLevel level;
  final List<LevelItem> items;
  final String summary;

  /// 적용되는 평균 강도 설명.
  final String intensity;

  bool get hasData => score != null;
}

class LevelAssessor {
  LevelAssessor._();

  /// 체중 대비 1RM 배수 기준(남성, 30대 중반 기준). [입문→초급, 초급→중급, 중급→고급, 고급→엘리트] 경계.
  static const _male = {
    'squat': [0.75, 1.25, 1.75, 2.25],
    'bench': [0.5, 0.9, 1.25, 1.6],
    'deadlift': [1.0, 1.5, 2.0, 2.5],
    'ohp': [0.35, 0.55, 0.8, 1.0],
  };
  static const _femaleFactor = 0.7;

  /// 골격근량/체중 비율 경계(높을수록 좋음).
  static const _smmMale = [0.36, 0.40, 0.43, 0.46];
  static const _smmFemale = [0.28, 0.32, 0.35, 0.38];

  /// 체지방률 경계(낮을수록 좋음): [입문↔초급, 초급↔중급, 중급↔고급, 고급↔엘리트].
  static const _fatMale = [25.0, 20.0, 15.0, 11.0];
  static const _fatFemale = [35.0, 30.0, 25.0, 20.0];

  static LevelAssessment assess(UserProfile p) {
    final items = <LevelItem>[];
    final ageFactor = p.age > 35 ? max(0.75, 1 - 0.01 * (p.age - 35)) : 1.0;
    final sexFactor = p.sex == Sex.female ? _femaleFactor : 1.0;

    LevelItem lift(String key, String name, double? oneRm) {
      if (oneRm == null || oneRm <= 0 || p.weightKg <= 0) {
        return LevelItem(name: name, grade: Grade.novice, score: 0, detail: '기록 없음', missing: true);
      }
      final ratio = oneRm / p.weightKg;
      final th = _male[key]!.map((t) => t * sexFactor * ageFactor).toList();
      final score = _scoreAsc(ratio, th);
      return LevelItem(name: name, grade: _grade(score), score: score, detail: '${oneRm.round()}kg · 체중의 ${ratio.toStringAsFixed(2)}배');
    }

    items.add(lift('squat', '스쿼트', p.squat1rm));
    items.add(lift('bench', '벤치프레스', p.bench1rm));
    items.add(lift('deadlift', '데드리프트', p.deadlift1rm));
    items.add(lift('ohp', 'OHP', p.ohp1rm));

    final smm = p.skeletalMuscleKg;
    if (smm != null && smm > 0 && p.weightKg > 0) {
      final r = smm / p.weightKg;
      final s = _scoreAsc(r, p.sex == Sex.female ? _smmFemale : _smmMale);
      items.add(LevelItem(name: '골격근량', grade: _grade(s), score: s, detail: '${smm.toStringAsFixed(1)}kg · 체중의 ${(r * 100).round()}%'));
    } else {
      items.add(const LevelItem(name: '골격근량', grade: Grade.novice, score: 0, detail: '인바디 입력 없음', missing: true));
    }
    final fat = p.bodyFatPct;
    if (fat != null && fat > 0) {
      final s = _scoreDesc(fat, p.sex == Sex.female ? _fatFemale : _fatMale);
      items.add(LevelItem(name: '체지방률', grade: _grade(s), score: s, detail: '${fat.toStringAsFixed(1)}%'));
    } else {
      items.add(const LevelItem(name: '체지방률', grade: Grade.novice, score: 0, detail: '인바디 입력 없음', missing: true));
    }

    final lifts = items.take(4).where((i) => !i.missing).toList();
    final comp = items.skip(4).where((i) => !i.missing).toList();
    double? score;
    if (lifts.isNotEmpty && comp.isNotEmpty) {
      score = _mean(lifts) * 0.7 + _mean(comp) * 0.3;
    } else if (lifts.isNotEmpty) {
      score = _mean(lifts);
    } else if (comp.isNotEmpty) {
      score = _mean(comp) * 0.8; // 기록 없이 체성분만으로는 보수적으로
    }

    final grade = score == null ? null : _grade(score);
    final level = score == null
        ? p.level
        : score < 35
            ? TrainingLevel.beginner
            : score < 65
                ? TrainingLevel.intermediate
                : TrainingLevel.advanced;

    final parts = items.where((i) => !i.missing).map((i) => '${i.name} ${i.grade.label}').toList();
    final summary = score == null
        ? '3대 기록이나 인바디를 입력하면 레벨을 자동으로 판정해요.'
        : '${parts.join(' · ')} → 종합 ${grade!.label} (${score.round()}점)';

    return LevelAssessment(
      score: score,
      grade: grade,
      level: level,
      items: items,
      summary: summary,
      intensity: intensityFor(level, p.goal),
    );
  }

  /// 레벨·목표별 적용 강도 설명.
  static String intensityFor(TrainingLevel level, TrainingGoal goal) {
    final base = switch (level) {
      TrainingLevel.beginner => '복합운동 3세트 · 횟수는 범위 상한(예: 12회) · 1RM의 약 60~65%',
      TrainingLevel.intermediate => '복합운동 3~4세트 · 횟수는 범위 중간(예: 10회) · 1RM의 약 70%',
      TrainingLevel.advanced => '핵심 운동 4세트 · 횟수는 범위 하한(예: 8회) · 1RM의 약 75~80%',
    };
    final g = switch (goal) {
      TrainingGoal.strength => ' · 근력 목표라 복합운동은 3~6회로 더 무겁게',
      TrainingGoal.fatLoss => ' · 다이어트 목표라 고반복·짧은 휴식·유산소 추가',
      _ => '',
    };
    return base + g;
  }

  static double _mean(List<LevelItem> l) => l.map((i) => i.score).reduce((a, b) => a + b) / l.length;

  static Grade _grade(double score) => score < 20
      ? Grade.novice
      : score < 40
          ? Grade.beginner
          : score < 60
              ? Grade.intermediate
              : score < 80
                  ? Grade.advanced
                  : Grade.elite;

  /// 오름차순 경계(th[0]<th[1]<...): th[0]→20점, th[3]→80점, 그 위는 100점까지.
  static double _scoreAsc(double v, List<double> th) {
    final pts = [th[0] * 0.5, th[0], th[1], th[2], th[3], th[3] * 1.3];
    const sc = <double>[0, 20, 40, 60, 80, 100];
    return _interp(v, pts, sc);
  }

  /// 내림차순 경계(낮을수록 좋음).
  static double _scoreDesc(double v, List<double> th) {
    final pts = [th[3] * 0.7, th[3], th[2], th[1], th[0], th[0] * 1.4];
    const sc = <double>[100, 80, 60, 40, 20, 0];
    return _interp(v, pts, sc);
  }

  static double _interp(double v, List<double> xs, List<double> ys) {
    if (v <= xs.first) return ys.first;
    if (v >= xs.last) return ys.last;
    for (var i = 0; i < xs.length - 1; i++) {
      if (v >= xs[i] && v <= xs[i + 1]) {
        final t = (v - xs[i]) / (xs[i + 1] - xs[i]);
        return ys[i] + (ys[i + 1] - ys[i]) * t;
      }
    }
    return ys.last;
  }
}
