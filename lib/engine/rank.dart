/// 게임 랭크처럼 보여 주는 등급. 힘(레벨 판정 점수)과 꾸준함(최근 4주 운동 횟수)을 합친 점수로
/// 아이언 → 브론즈 → 실버 → 골드 → 플래티넘 → 다이아 → 마스터 → 그랜드마스터.
library;

import 'dart:math';

import 'package:flutter/painting.dart';

import '../models/models.dart';
import 'level_assessor.dart';

enum RankTier {
  iron('아이언', 'I', Color(0xFF6E6A66), Color(0xFF9C968F)),
  bronze('브론즈', 'B', Color(0xFF8C5A2B), Color(0xFFD08F55)),
  silver('실버', 'S', Color(0xFF7D8A96), Color(0xFFD5DEE6)),
  gold('골드', 'G', Color(0xFFB8860B), Color(0xFFF6D365)),
  platinum('플래티넘', 'P', Color(0xFF1F8A82), Color(0xFF7FE0D2)),
  diamond('다이아', 'D', Color(0xFF3B5BDB), Color(0xFF9EC5FF)),
  master('마스터', 'M', Color(0xFF7B2FBE), Color(0xFFD29BFF)),
  grandmaster('그랜드마스터', 'GM', Color(0xFFB3261E), Color(0xFFFF8A65));

  const RankTier(this.label, this.short, this.dark, this.light);
  final String label;
  final String short;
  final Color dark;
  final Color light;
}

class Rank {
  const Rank({required this.tier, required this.division, required this.points, required this.strength, required this.activity, required this.estimated});
  final RankTier tier;

  /// 3 → 2 → 1 순으로 높다. 마스터 이상은 0(구간 없음).
  final int division;

  /// 0~100 랭크 점수.
  final double points;

  /// 힘 점수(레벨 판정, 0~100)와 꾸준함 점수(최근 4주 12회 = 100).
  final double strength;
  final double activity;

  /// 3대·체성분 입력이 없어 숙련도로 힘을 어림했으면 true.
  final bool estimated;

  static const _roman = ['', 'I', 'II', 'III'];
  String get divisionLabel => division == 0 ? '' : _roman[division];

  /// '골드 II'
  String get label => division == 0 ? tier.label : '${tier.label} ${_roman[division]}';

  /// 배지 안 짧은 글자: 'G2', 'M'.
  String get short => division == 0 ? tier.short : '${tier.short}$division';

  /// 다음 등급까지 남은 점수(최고 등급이면 null).
  double? get toNext {
    for (final c in _cuts) {
      if (c > points + 1e-9) return c - points;
    }
    return null;
  }

  /// 등급 경계: [브론즈, 실버, 골드, 플래티넘, 다이아, 마스터, 그랜드마스터]가 시작하는 점수.
  static const _tierStart = [15.0, 30.0, 45.0, 60.0, 72.0, 84.0, 93.0];

  static List<double> get _cuts {
    final out = <double>[];
    var lo = 0.0;
    for (var t = 0; t < _tierStart.length; t++) {
      final hi = _tierStart[t];
      if (t < 6) {
        // 구간 3개(III, II, I)
        out.add(lo + (hi - lo) / 3);
        out.add(lo + (hi - lo) * 2 / 3);
      }
      out.add(hi);
      lo = hi;
    }
    return out;
  }

  static Rank fromPoints(double points, {double strength = 0, double activity = 0, bool estimated = false}) {
    final p = points.clamp(0, 100).toDouble();
    var t = 0;
    while (t < _tierStart.length && p >= _tierStart[t]) {
      t++;
    }
    final tier = RankTier.values[t];
    var division = 0;
    if (t <= 5) {
      final lo = t == 0 ? 0.0 : _tierStart[t - 1];
      final hi = _tierStart[t];
      final f = (p - lo) / (hi - lo);
      division = f < 1 / 3 ? 3 : f < 2 / 3 ? 2 : 1;
    }
    return Rank(tier: tier, division: division, points: p, strength: strength, activity: activity, estimated: estimated);
  }

  /// [p] 프로필(3대·체성분·숙련도)과 최근 4주 완료 운동 수 [sessions4w]로 계산.
  static Rank of(UserProfile p, {required int sessions4w, LevelAssessment? assessment}) {
    final a = assessment ?? LevelAssessor.assess(p);
    final strength = a.score ??
        switch (p.level) {
          TrainingLevel.beginner => 22.0,
          TrainingLevel.intermediate => 45.0,
          TrainingLevel.advanced => 68.0,
        };
    final activity = min(100.0, sessions4w / 12 * 100);
    return fromPoints(0.7 * strength + 0.3 * activity, strength: strength, activity: activity, estimated: a.score == null);
  }
}
